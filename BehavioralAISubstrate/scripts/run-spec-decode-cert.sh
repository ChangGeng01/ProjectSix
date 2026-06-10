#!/usr/bin/env bash
# scripts/run-spec-decode-cert.sh
# 结构大重构 Phase 6 — on-device SPECULATIVE-DECODING certification (one device per run).
#
# Launches BASDeviceTestApp with BAS_SPEC_DECODE=1: the in-app BASSpeculativeDecodeProbe loads a same-family
# target↔draft pair (Gemma4 E4B↔E2B first; Llama 3B↔1B fail-honest fallback), drives the greedy + sampling
# speculative lanes against a single-model baseline, and folds the measurements through the observation-only
# ledger → composer → verdict (BASSpeculativeMigrationVerdict — default-deny, never auto-enables). The probe
# writes `📊 spec-decode …` lines to a Documents log this script pulls and prints.
#
# Run it ONCE PER DEVICE (the verdict gate needs ≥2 distinct devices):
#   bash scripts/run-spec-decode-cert.sh                                   # default device (Chang's iPhone Air)
#   DEVICE_ID=5E5C3C5C-A327-5971-93A5-A3E27A3FDF57 bash scripts/run-spec-decode-cert.sh   # the second iPhone Air
#   BUILD=1 bash scripts/run-spec-decode-cert.sh                           # rebuild + install first
#
# Hardened like run-concurrent-turns-cert.sh: asleep/locked detection (no fresh log ⇒ tell the user, don't
# hang) + wedge detection (line count stalls ⇒ terminate the app, report WEDGED — ADR-038: kill+relaunch is
# the only cure, never reboot). First run on a device downloads the models over the air (Gemma E4B+E2B ≈
# 4-5 GB) — use MAX_POLL/POLL_SEC to widen the budget for a cold download (DOWNLOAD=1 preset does this).
#
# Honest scope (R1): one run = n=1 device; the gate stays insufficientEvidence until BOTH devices' records are
# merged (the probe prints each device's verdict; the cross-device merge is read by a human).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# ---- Config (env-overridable) ------------------------------------
DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"   # iPhone Air #1 (Chang's)
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
MEM_BUDGET_MB="${MEM_BUDGET_MB:-6000}"
MAX_DECODE_TOKENS="${MAX_DECODE_TOKENS:-64}"     # bound the per-prompt decode so one cert run stays ~minutes
POLL_SEC="${POLL_SEC:-15}"
MAX_POLL="${MAX_POLL:-40}"                        # ~10 min default; DOWNLOAD=1 widens for the cold model pull
STALL_SEC="${STALL_SEC:-240}"                     # spec-decode line count unchanged this long (app alive) ⇒ wedge
BUILD="${BUILD:-0}"
DOWNLOAD="${DOWNLOAD:-0}"
if [ "${DOWNLOAD}" = "1" ]; then MAX_POLL=160; STALL_SEC=900; fi   # cold HF download budget (~40 min)
PULL_DIR="$(mktemp -d /tmp/bas-specdecode.XXXXXX)"
LOG_GLOB="spec-decode-2026*.log"
DD="${DD:-/tmp/bas-specdecode-build-dd}"          # own DerivedData — NEVER the user's (build.db lock)

# BAS_ENDURANCE_AUTOSTART=1 is the runner's MASTER autostart gate (autostartIfEnabled guards on it before any
# probe dispatch) — without it the app launches into idle UI and the spec-decode probe never starts.
# PAIRING (certified|fallback|all) selects which target↔draft pair to cert. A jetsam per-process-limit kill
# during a dual load is UNCATCHABLE — so to cover the fail-honest fallback across a kill, run twice:
#   PAIRING=certified bash scripts/run-spec-decode-cert.sh   # then, if it was killed with no FINAL:
#   PAIRING=fallback  bash scripts/run-spec-decode-cert.sh
PAIRING="${PAIRING:-all}"
ENV_JSON='{"BAS_ENDURANCE_AUTOSTART":"1","BAS_SPEC_DECODE":"1","BAS_SPEC_PAIRING":"'"${PAIRING}"'","BAS_SPEC_MEM_BUDGET_MB":"'"${MEM_BUDGET_MB}"'","BAS_SPEC_MAX_DECODE_TOKENS":"'"${MAX_DECODE_TOKENS}"'"}'

echo "=============================================="
echo "BAS on-device SPECULATIVE-DECODE cert (Phase 6)"
echo "Device:   ${DEVICE_ID}"
echo "Bundle:   ${BUNDLE_ID}"
echo "Budget:   mem=${MEM_BUDGET_MB}MB decode_cap=${MAX_DECODE_TOKENS}"
echo "Env:      ${ENV_JSON}"
echo "=============================================="

log_stamp() { echo "${1:-}" | grep -oE '[0-9]{8}-[0-9]{6}' | tr -d '-' | tail -1; }
newest_log() {
    rm -rf "${PULL_DIR}"; mkdir -p "${PULL_DIR}"
    xcrun devicectl device copy from --device "${DEVICE_ID}" \
        --domain-type appDataContainer --domain-identifier "${BUNDLE_ID}" \
        --source Documents --destination "${PULL_DIR}" >/dev/null 2>&1
    find "${PULL_DIR}" -type f -name "${LOG_GLOB}" 2>/dev/null | sort | tail -1
}
spec_count() { grep -ac 'spec-decode' "${1:-/dev/null}" 2>/dev/null | tr -d '[:space:]'; }
has_final() { grep -aq 'spec-decode FINAL' "${1:-/dev/null}" 2>/dev/null; }
terminate_app() {
    local pid
    pid=$(xcrun devicectl device info processes --device "${DEVICE_ID}" 2>/dev/null \
        | grep -i basdevicetest | awk '{print $1}' | head -1)
    [ -n "${pid:-}" ] && xcrun devicectl device process terminate --device "${DEVICE_ID}" --pid "${pid}" >/dev/null 2>&1
}

# ---- competing-xcodebuild lockout (only when BUILD=1) ------------
if [ "${BUILD}" = "1" ] && pgrep -f "xcodebuild (test|build|archive)" >/dev/null 2>&1; then
    echo "ABORT: BUILD=1 but a competing 'xcodebuild' is running — wait for it to finish, then re-run."
    exit 2
fi

# ---- optional rebuild + install (own DerivedData) ----------------
if [ "${BUILD}" = "1" ]; then
    echo "Building + installing ${SCHEME} (DerivedData: ${DD}) ..."
    xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" \
        -destination "id=${DEVICE_ID}" -derivedDataPath "${DD}" \
        -allowProvisioningUpdates build 2>&1 \
        | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
    APP="$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_ID}" \
        -derivedDataPath "${DD}" -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"
    xcrun devicectl device install app --device "${DEVICE_ID}" "${APP}" 2>&1 | grep -iE "App installed|error" | tail -2
fi

# ---- baseline stamp ----------------------------------------------
PRIOR="$(log_stamp "$(basename "$(newest_log)")")"
echo "Baseline newest log stamp: ${PRIOR:-none}"

# ---- launch -------------------------------------------------------
echo "Launching ${BUNDLE_ID} ..."
if ! xcrun devicectl device process launch --terminate-existing --device "${DEVICE_ID}" \
        --environment-variables "${ENV_JSON}" "${BUNDLE_ID}" 2>&1 | grep -iq "Launched"; then
    echo "ABORT: devicectl launch failed (device disconnected? unlock + re-pair, then retry)."
    exit 3
fi

# ---- poll: fresh log + FINAL / wedge ------------------------------
FRESH=""; saw_fresh=0; prev_count=-1; stall_accum=0
for i in $(seq 1 "${MAX_POLL}"); do
    sleep "${POLL_SEC}"
    NEW="$(newest_log)"; NS="$(log_stamp "$(basename "${NEW:-none}")")"
    if [ -n "${NS}" ] && { [ -z "${PRIOR}" ] || [ "${NS}" -gt "${PRIOR}" ]; }; then
        FRESH="${NEW}"; saw_fresh=1
        c="$(spec_count "${NEW}")"; c="${c:-0}"
        echo "poll ${i}: fresh log $(basename "${NEW}")  spec-decode_lines=${c}"
        if has_final "${NEW}"; then echo "poll ${i}: FINAL emitted — done."; break; fi
        if [ "${c}" -eq "${prev_count}" ]; then
            stall_accum=$(( stall_accum + POLL_SEC ))
        else
            stall_accum=0; prev_count="${c}"
        fi
        if [ "${stall_accum}" -ge "${STALL_SEC}" ] && [ "${c}" -gt 0 ]; then
            echo ""
            echo "RESULT: WEDGED — spec-decode progress stalled ${stall_accum}s with no FINAL (ADR-038"
            echo "        uncancellable Metal eval / dual-pool wedge). Terminating the app."
            terminate_app
            echo "Partial log: ${NEW}"
            exit 1
        fi
    else
        echo "poll ${i}: no fresh log yet (newest stamp=${NS:-none})"
    fi
done

if [ "${saw_fresh}" = "0" ]; then
    echo ""
    echo "RESULT: NO FRESH LOG after ~$((MAX_POLL * POLL_SEC))s — the iPhone is almost certainly ASLEEP/LOCKED"
    echo "        (or a cold model download is still running — re-run with DOWNLOAD=1 for a wider budget)."
    echo "        UNLOCK + wake the iPhone (Auto-Lock=Never, charging), then re-run this script."
    exit 4
fi

echo ""
echo "===== spec-decode readings ($(basename "${FRESH}")) ====="
grep -a 'spec-decode\|speculative-decode-gate\|reasons=\|latency(\|memory:\|devices=' "${FRESH}" | sed 's/^/  /'
echo "==========================================="
if has_final "${FRESH}"; then
    echo "RESULT: COMPLETED — readings above (n=1 device; merge both devices' records for the ≥2-device gate)."
    exit 0
else
    echo "RESULT: INCOMPLETE — no FINAL line; see partial readings above."
    exit 1
fi
