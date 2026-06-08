#!/usr/bin/env bash
# scripts/run-metal-probe-experiment.sh
# ADR-038 §10 — the discriminating experiment: is the decode wedge owned by Apple's Metal/GPU
# driver/firmware, OR by an MLX-induced GPU bug? The layer-pin (ADR-038 §10) proved the
# UNRECOVERABILITY is MLX but could NOT determine the FAULT owner. This harness runs the missing
# control: submit a TRIVIAL, MLX-FREE Metal command buffer on a CONTAMINATED GPU and see if it
# completes.
#
#   bare Metal COMPLETES on the poisoned device  → contamination is MLX-state-specific → MLX-CAUSED
#                                                  → a real PREVENTION fix could live in vendored MLX
#                                                    (reopens 完全解决).
#   bare Metal TIMES OUT / errors                → GPU client wedged below MLX → Apple-firmware-leaning
#                                                  → external watchdog + reboot-on-poison ceiling stands.
#
# PROTOCOL (two phases):
#   Phase A — WEDGE: run a normal endurance pass WITH the concurrent sibling-queue heartbeat
#     (BAS_METAL_PROBE_CONCURRENT=1) until the MLX decode wedges. The heartbeat already gives a
#     same-run signal: do `metal-probe-hb` lines keep status=completed AFTER the 🧠 mlx lines stop?
#   Phase B — PROBE-ONLY CONTROL: kill the wedged app, relaunch with BAS_METAL_PROBE_ONLY=1 (no MLX,
#     no model load) on the still-contaminated device, and read the verdict line.
#
# Build/install once first:  BUILD=1 bash scripts/run-metal-probe-experiment.sh
# Then re-runs reuse the installed app.  Requires the iPhone UNLOCKED + awake.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"   # iPhone Air ("Chang's iPhone")
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
BUILD="${BUILD:-0}"
POLL_SEC="${POLL_SEC:-15}"
# Phase A endurance sizing — ITER big enough to cross the OFF wedge point (~iter28/56resp; ADR §8).
WEDGE_ITERS="${WEDGE_ITERS:-50}"
WEDGE_MAX_POLL="${WEDGE_MAX_POLL:-60}"     # ~WEDGE_MAX_POLL × POLL_SEC budget for phase A
PROBE_MAX_POLL="${PROBE_MAX_POLL:-12}"
LOG_GLOB="ch1025-endurance-2026*.log"
PULL_DIR="$(mktemp -d /tmp/bas-probe.XXXXXX)"

newest_log() {
    rm -rf "${PULL_DIR}"; mkdir -p "${PULL_DIR}"
    xcrun devicectl device copy from --device "${DEVICE_ID}" \
        --domain-type appDataContainer --domain-identifier "${BUNDLE_ID}" \
        --source Documents --destination "${PULL_DIR}" >/dev/null 2>&1
    find "${PULL_DIR}" -type f -name "${LOG_GLOB}" 2>/dev/null | sort | tail -1
}

# Robust freshness: extract the YYYYMMDD-HHMMSS stamp → digits → numeric compare (no `\>` test-op
# dependency, which is unreliable across shells). Returns 0 (true) iff $1 is strictly newer than $2.
log_stamp() { echo "${1:-}" | grep -oE '[0-9]{8}-[0-9]{6}' | tr -d '-' | tail -1; }
newer_than() {  # newer_than NEW_BASE PRIOR_BASE
    local a b; a="$(log_stamp "$1")"; b="$(log_stamp "$2")"
    [ -n "$a" ] || return 1
    [ -n "$b" ] || return 0
    [ "$a" -gt "$b" ]
}

terminate_app() {
    local pid
    pid=$(xcrun devicectl device info processes --device "${DEVICE_ID}" 2>/dev/null \
        | grep -i basdevicetest | awk '{print $1}' | head -1)
    if [ -n "${pid:-}" ]; then
        xcrun devicectl device process terminate --device "${DEVICE_ID}" --pid "${pid}" >/dev/null 2>&1 \
            && echo "  terminated app (pid ${pid})"
    fi
}

echo "=============================================="
echo "ADR-038 §10 Metal-vs-MLX discriminating experiment"
echo "Device: ${DEVICE_ID}   Bundle: ${BUNDLE_ID}"
echo "=============================================="

if [ "${BUILD}" = "1" ]; then
    echo "Building + installing ${SCHEME} ..."
    xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" \
        -destination "id=${DEVICE_ID}" -allowProvisioningUpdates build 2>&1 \
        | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
    APP="$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_ID}" \
        -showBuildSettings 2>/dev/null | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"
    xcrun devicectl device install app --device "${DEVICE_ID}" "${APP}" 2>&1 | grep -iE "App installed|error" | tail -2
fi

# ---------------------------------------------------------------- Phase A — WEDGE (with heartbeat)
echo ""
echo "### Phase A — drive a normal endurance run WITH the sibling-queue heartbeat until it wedges"
PRIOR_A="$(basename "$(newest_log)" 2>/dev/null || echo none)"
ENV_A='{"BAS_ENDURANCE_AUTOSTART":"1","BAS_METAL_PROBE_CONCURRENT":"1","BAS_METAL_PROBE_HB_SEC":"15","BAS_INTERNAL_ITER_COUNT":"'"${WEDGE_ITERS}"'","BAS_INTERNAL_MLX_PROMPTS":"1","BAS_INTERNAL_COOLDOWN_SEC":"0","BAS_INTERNAL_MAX_DECODE_TOKENS":"96"}'
echo "  env: ${ENV_A}"
terminate_app
xcrun devicectl device process launch --terminate-existing --device "${DEVICE_ID}" \
    --environment-variables "${ENV_A}" "${BUNDLE_ID}" 2>&1 | grep -iq "Launched" \
    || { echo "ABORT: phase-A launch failed (device locked/asleep? unlock + retry)"; exit 3; }

PHASE_A_LOG=""; prevmlx=-1; stable=0; wedged=0
for i in $(seq 1 "${WEDGE_MAX_POLL}"); do
    sleep "${POLL_SEC}"
    NEW="$(newest_log)"; BASE="$(basename "${NEW:-none}")"
    [ -z "${NEW}" ] && { echo "  poll ${i}: no log yet"; continue; }
    newer_than "${BASE}" "${PRIOR_A}" || { echo "  poll ${i}: no fresh log (newest=${BASE})"; continue; }
    PHASE_A_LOG="${NEW}"
    mlx=$(grep -ac '🧠 ch1025 mlx ' "${NEW}" 2>/dev/null || echo 0)
    hb=$(grep -ac 'metal-probe-hb ' "${NEW}" 2>/dev/null || echo 0)
    echo "  poll ${i}: mlx_responses=${mlx} hb_lines=${hb}"
    if grep -aq 'ch1025 FINAL run_sec' "${NEW}" 2>/dev/null; then
        echo "  phase A COMPLETED without wedging (try a larger WEDGE_ITERS to force a wedge)"; break
    fi
    if [ "${mlx}" -eq "${prevmlx}" ]; then stable=$((stable+1)); else stable=0; fi
    if [ "${stable}" -ge 4 ] && [ "${mlx}" -gt 0 ]; then wedged=1; echo "  >>> WEDGE DETECTED (mlx stalled at ${mlx} responses)"; break; fi
    prevmlx=${mlx}
done

if [ -n "${PHASE_A_LOG}" ]; then
    echo ""
    echo "  --- sibling-queue heartbeat around the wedge (last 12 lines) ---"
    grep -aE 'metal-probe-hb ' "${PHASE_A_LOG}" 2>/dev/null | tail -12 | sed 's/^/    /'
    echo "  --- last MLX response line ---"
    grep -aE '🧠 ch1025 mlx ' "${PHASE_A_LOG}" 2>/dev/null | tail -1 | sed 's/^/    /'
    echo "  READING (phase A): if metal-probe-hb keeps status=completed AFTER the mlx lines stop →"
    echo "                     GPU device is fine while MLX is wedged → MLX-state-local wedge → MLX-CAUSED."
    echo "                     if metal-probe-hb flips to status=timedOut at the wedge → whole GPU wedged → firmware-leaning."
fi

# ---------------------------------------------------------------- Phase B — PROBE-ONLY control
echo ""
echo "### Phase B — kill the wedged app, relaunch PROBE-ONLY (no MLX) on the contaminated device"
terminate_app
sleep 3
PRIOR_B="$(basename "$(newest_log)" 2>/dev/null || echo none)"
ENV_B='{"BAS_ENDURANCE_AUTOSTART":"1","BAS_METAL_PROBE_ONLY":"1","BAS_METAL_PROBE_ITERS":"6","BAS_METAL_PROBE_TIMEOUT_SEC":"8"}'
echo "  env: ${ENV_B}"
xcrun devicectl device process launch --terminate-existing --device "${DEVICE_ID}" \
    --environment-variables "${ENV_B}" "${BUNDLE_ID}" 2>&1 | grep -iq "Launched" \
    || { echo "ABORT: phase-B launch failed"; exit 3; }

PROBE_LOG=""
for i in $(seq 1 "${PROBE_MAX_POLL}"); do
    sleep "${POLL_SEC}"
    NEW="$(newest_log)"; BASE="$(basename "${NEW:-none}")"
    { [ -n "${NEW}" ] && newer_than "${BASE}" "${PRIOR_B}"; } || { echo "  poll ${i}: no fresh probe log (newest=${BASE})"; continue; }
    PROBE_LOG="${NEW}"
    echo "  poll ${i}: probe log ${BASE}"
    if grep -aq 'metal-probe context=probe-only' "${NEW}" 2>/dev/null \
       || grep -aq 'metal-probe-only done' "${NEW}" 2>/dev/null; then break; fi
done

echo ""
echo "=============================================="
echo "VERDICT"
echo "=============================================="
if [ -z "${PROBE_LOG}" ]; then
    echo "Phase B produced NO fresh log within budget."
    echo "  → If the device was contaminated, even the MLX-FREE probe app could not log — i.e. device/queue"
    echo "    creation itself wedged. That is a STRONG GPU-client-wedge signal (Apple-firmware-leaning),"
    echo "    OR the device is simply locked/asleep — verify it is unlocked + awake, then re-run Phase B."
    exit 4
fi
echo "Phase B probe-only per-iter:"
grep -aE 'ch1025 metal-probe iter=' "${PROBE_LOG}" 2>/dev/null | sed 's/^/  /'
echo ""
echo "Phase B verdict line:"
grep -aE 'ch1025 metal-probe context=probe-only' "${PROBE_LOG}" 2>/dev/null | sed 's/^/  /'
echo ""
V="$(grep -aE 'ch1025 metal-probe context=probe-only' "${PROBE_LOG}" 2>/dev/null | tail -1)"
case "${V}" in
    *verdict=ALL_COMPLETED*)
        echo "→ ALL_COMPLETED on the contaminated device ⇒ bare Metal WORKS ⇒ the contamination is"
        echo "  MLX-state-specific ⇒ MLX-CAUSED ⇒ a real PREVENTION fix could live in vendored MLX."
        echo "  (NOTE: confirm the device was actually contaminated — Phase A must have WEDGED for this to mean MLX-caused.)" ;;
    *verdict=WEDGED*)
        echo "→ WEDGED ⇒ the bare-Metal command buffer ALSO hangs/errors ⇒ the GPU client is wedged"
        echo "  below MLX ⇒ leaning Apple driver/firmware ⇒ the external watchdog + reboot-on-poison ceiling stands." ;;
    *verdict=SETUP_FAILED*)
        echo "→ SETUP_FAILED ⇒ could not even build device/queue/pipeline ⇒ either no Metal device, or GPU"
        echo "  client wedged at setup (firmware-leaning if the device was contaminated)." ;;
    *)  echo "→ INCONCLUSIVE — see the lines above; full log: ${PROBE_LOG}" ;;
esac
echo ""
echo "Phase A log:  ${PHASE_A_LOG:-<none>}"
echo "Phase B log:  ${PROBE_LOG}"
