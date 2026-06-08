#!/usr/bin/env bash
# scripts/run-device-app-cert.sh
# Reusable on-device cert/smoke harness for the BASDeviceTestApp (the devicectl-LAUNCH flow), as opposed to
# scripts/run-device-smoke.sh which drives the xcodebuild TEST bundle. This codifies the install → launch →
# poll-for-fresh-log → parse-smoke-lines flow that was hand-run repeatedly during the ADR-039 Metal certs,
# and hardens it against the two failure modes that bit those runs:
#   (1) DEVICE ASLEEP/LOCKED — devicectl launches the app but iOS suspends it on a locked device, so the run
#       silently produces NO new log. This script DETECTS that (no fresh log within the poll budget) and
#       tells you to unlock the device, instead of hanging silently.
#   (2) COMPETING xcodebuild — a concurrent `xcodebuild test/build` on the Mac can kill/contend the run
#       (backlog ch1032.0 / #16). This script aborts pre-launch if one is detected.
#
# It does NOT add any thread-based MLX-wedge "recovery" — ADR-038: the wedge is prevention-only.
#
# Usage:
#   bash scripts/run-device-app-cert.sh                 # default: BAS_METAL_SMOKE=1 + L8 topK, 2 short iters
#   ENV_JSON='{"BAS_METAL_SMOKE":"1","BAS_L8_METAL_TOPK":"1","BAS_INTERNAL_ITER_COUNT":"4","BAS_INTERNAL_MLX_PROMPTS":"1","BAS_INTERNAL_MAX_DECODE_TOKENS":"96"}' \
#     bash scripts/run-device-app-cert.sh               # custom env (e.g. capture the turn-breakdown)
#   DEVICE_ID=... BUNDLE_ID=... BUILD=1 bash scripts/run-device-app-cert.sh   # rebuild+install first
#
# Output: tails the 📊 cert/breakdown lines + an overall PASS/FAIL verdict; exit 0 on PASS.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# ---- Config (env-overridable) ------------------------------------
DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"   # iPhone Air ("Chang's iPhone")
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
POLL_SEC="${POLL_SEC:-14}"
MAX_POLL="${MAX_POLL:-12}"          # ~MAX_POLL × POLL_SEC budget to see a fresh log before "asleep"
BUILD="${BUILD:-0}"                 # 1 ⇒ xcodebuild build + install before launch
PULL_DIR="$(mktemp -d /tmp/bas-devcert.XXXXXX)"
# NOTE: keep the default in a SEPARATE single-quoted var. Inlining the JSON into `${ENV_JSON:-{...}}` hits a
# bash gotcha — the JSON's own `}` closes the parameter expansion early, leaving a stray literal `}` that is
# appended to ANY overridden value (→ malformed JSON → devicectl rejects --environment-variables). Using a
# variable reference (`$DEFAULT_ENV_JSON`) has no brace collision, so overrides pass through cleanly.
DEFAULT_ENV_JSON='{"BAS_METAL_SMOKE":"1","BAS_L8_METAL_TOPK":"1","BAS_GLOBAL_RECALL":"0","BAS_INTERNAL_ITER_COUNT":"2","BAS_INTERNAL_MLX_PROMPTS":"1","BAS_INTERNAL_COOLDOWN_SEC":"0","BAS_INTERNAL_MAX_DECODE_TOKENS":"48"}'
ENV_JSON="${ENV_JSON:-$DEFAULT_ENV_JSON}"

LOG_GLOB="ch1025-endurance-2026*.log"

echo "=============================================="
echo "BAS on-device app cert/smoke harness"
echo "Device:   ${DEVICE_ID}"
echo "Bundle:   ${BUNDLE_ID}"
echo "Env:      ${ENV_JSON}"
echo "=============================================="

# ---- (1) competing-xcodebuild lockout (ch1032.0 / #16) -----------
# ONLY relevant when BUILD=1 (we invoke xcodebuild and would contend the build system / DerivedData with a
# concurrent build). With BUILD=0 (the default), this flow is pure `devicectl install/launch` against the
# physical device — it runs NO xcodebuild, so an unrelated xcodebuild (e.g. another project's simulator test)
# cannot contend with it; gating the lockout on BUILD avoids a false abort.
if [ "${BUILD}" = "1" ] && pgrep -f "xcodebuild (test|build|archive)" >/dev/null 2>&1; then
    echo "ABORT: BUILD=1 but a competing 'xcodebuild' is running — it can contend/kill the build (ch1032.0)."
    echo "       Wait for it to finish (pgrep -fl xcodebuild) or kill it, then re-run."
    exit 2
fi

newest_log() {
    rm -rf "${PULL_DIR}"; mkdir -p "${PULL_DIR}"
    xcrun devicectl device copy from --device "${DEVICE_ID}" \
        --domain-type appDataContainer --domain-identifier "${BUNDLE_ID}" \
        --source Documents --destination "${PULL_DIR}" >/dev/null 2>&1
    find "${PULL_DIR}" -type f -name "${LOG_GLOB}" 2>/dev/null | sort | tail -1
}

# ---- optional rebuild + install ----------------------------------
if [ "${BUILD}" = "1" ]; then
    echo "Building + installing ${SCHEME} ..."
    xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" \
        -destination "id=${DEVICE_ID}" -allowProvisioningUpdates build 2>&1 \
        | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
    APP="$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_ID}" \
        -showBuildSettings 2>/dev/null | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"
    xcrun devicectl device install app --device "${DEVICE_ID}" "${APP}" 2>&1 | grep -iE "App installed|error" | tail -2
fi

# ---- baseline (newest existing log, to detect a FRESH one) -------
PRIOR="$(newest_log)"; PRIOR_BASE="$(basename "${PRIOR:-none}")"
echo "Baseline newest log: ${PRIOR_BASE}"

# ---- launch (detached; no --console, per the ADR-038 harness) ----
echo "Launching ${BUNDLE_ID} ..."
if ! xcrun devicectl device process launch --terminate-existing --device "${DEVICE_ID}" \
        --environment-variables "${ENV_JSON}" "${BUNDLE_ID}" 2>&1 | grep -iq "Launched"; then
    echo "ABORT: devicectl launch failed (device disconnected? re-pair + retry)."
    exit 3
fi

# ---- (2) poll for a FRESH log; detect asleep/locked --------------
FRESH=""
for i in $(seq 1 "${MAX_POLL}"); do
    sleep "${POLL_SEC}"
    NEW="$(newest_log)"; BASE="$(basename "${NEW:-none}")"
    if [ -n "${NEW}" ] && [ "${BASE}" \> "${PRIOR_BASE}" ]; then
        FRESH="${NEW}"
        echo "poll ${i}: FRESH log ${BASE}"
        # Stop once the run has clearly produced cert lines or a FINAL marker.
        if grep -aq "ch1025 FINAL run_sec\|metal-smoke gpu" "${NEW}" 2>/dev/null; then break; fi
    else
        echo "poll ${i}: no fresh log yet (newest=${BASE})"
    fi
done

if [ -z "${FRESH}" ]; then
    echo ""
    echo "RESULT: NO FRESH LOG after ~$((MAX_POLL * POLL_SEC))s — the iPhone is almost certainly ASLEEP/LOCKED."
    echo "        devicectl launched the app but iOS suspended it on the locked device (the silent-failure"
    echo "        mode the ADR-039 certs kept hitting). UNLOCK + wake the iPhone, then re-run this script."
    exit 4
fi

# ---- parse + verdict --------------------------------------------
echo ""
echo "=== cert / breakdown lines (${BASE}) ==="
grep -aE "ch1025 (metal-smoke|ssm-metal-smoke|attn-metal-smoke|l8-metal-topk|turn-breakdown) " "${FRESH}" | sed 's/^/  /'

FAIL=0
# Any smoke line present must be gpu=true (a 'gpu=false FALLBACK' is a fail).
if grep -aE "ch1025 (metal-smoke|ssm-metal-smoke|attn-metal-smoke) gpu=false" "${FRESH}" >/dev/null 2>&1; then
    echo "  ✗ a Metal smoke fell back to CPU (gpu=false) — Metal did not run on the GPU."
    FAIL=1
fi
# topK parity must hold if present.
if grep -aE "metal-smoke gpu=true" "${FRESH}" >/dev/null 2>&1 && \
   ! grep -aE "metal-smoke gpu=true.*parity_set_ok=true" "${FRESH}" >/dev/null 2>&1; then
    echo "  ✗ topK parity_set_ok != true"
    FAIL=1
fi

echo ""
if [ "${FAIL}" = "0" ]; then
    echo "RESULT: PASS — Metal kernels ran on the GPU with parity (see lines above)."
else
    echo "RESULT: FAIL — see the ✗ markers above; full log: ${FRESH}"
fi
echo "Pulled log: ${FRESH}"
exit "${FAIL}"
