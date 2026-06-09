#!/usr/bin/env bash
# scripts/run-concurrent-turns-cert.sh
# ADR-039 concurrency arc #5 — on-device CONCURRENT-TURNS certification (Docs/CONCURRENCY_MEASUREMENT_FINDINGS.md).
#
# Converts the Phase-2 "concurrent turns SKIP — by DEDUCTION" into an on-device MEASUREMENT (IRON RULE R1:
# on-device proof certifies; deduction ≠ proof). Launches the BASDeviceTestApp with BAS_CONCURRENT_TURNS=N,
# which runs N full cognitive turns SEQUENTIALLY (baseline) then CONCURRENTLY (probe) against the ONE shared
# brain + adapter, emitting three `📊 ch1025 concurrent-turns` lines (phase=seq, phase=conc, verdict).
#
# DECISIVE COMPARISON: concurrent aggregate est-tokens/s should NOT beat sequential (the GPU decode is serial
# behind MLX's process-global evalLock), AND the concurrent run must complete (no deadlock/wedge). A throughput
# GAIN would REFUTE the GPU-serial deduction (the falsifiable hook → INVESTIGATE).
#
# Hardened like run-device-app-cert.sh against the two real failure modes:
#   (1) DEVICE ASLEEP/LOCKED — no fresh log within budget ⇒ tell the user to unlock, don't hang.
#   (2) WEDGE — concurrent decode amplifies the ADR-038 wedge risk; if the `concurrent-turns` line count
#       stalls for STALL_SEC with no verdict, terminate the app (no reboot — ADR-038 §10.2) and report WEDGED.
# It adds NO thread-based MLX-wedge "recovery" — the wedge is prevention-only; kill+relaunch is the only cure.
#
# Usage:
#   bash scripts/run-concurrent-turns-cert.sh                      # N=2, fullturn (Topology A)
#   N=2 MODE=decode bash scripts/run-concurrent-turns-cert.sh      # decode-only canary (Topology B)
#   BUILD=1 bash scripts/run-concurrent-turns-cert.sh              # rebuild+install first
#   N=3 STALL_SEC=200 bash scripts/run-concurrent-turns-cert.sh    # larger fan-out (raise the stall budget)
#
# Output: the seq/conc/verdict lines + a PASS / INVESTIGATE / FAIL verdict; exit 0 on PASS.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# ---- Config (env-overridable) ------------------------------------
DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"   # iPhone Air
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
N="${N:-2}"                          # concurrency level (>=2)
MODE="${MODE:-fullturn}"             # fullturn (Topology A) | decode (Topology B canary)
TIMEOUT="${TIMEOUT:-180}"            # advisory per-phase budget logged in-app (decode is uncancellable)
MAX_DECODE_TOKENS="${MAX_DECODE_TOKENS:-96}"
POLL_SEC="${POLL_SEC:-14}"
MAX_POLL="${MAX_POLL:-30}"           # ~MAX_POLL × POLL_SEC budget before "asleep" / overall cap
STALL_SEC="${STALL_SEC:-150}"        # concurrent-turns line count unchanged this long (app alive) ⇒ wedge.
                                     # Must exceed N × decode-wall (the CONC phase emits no per-turn heartbeat).
BUILD="${BUILD:-0}"
PULL_DIR="$(mktemp -d /tmp/bas-cturns.XXXXXX)"
LOG_GLOB="ch1025-endurance-2026*.log"

ENV_JSON='{"BAS_ENDURANCE_AUTOSTART":"1","BAS_CONCURRENT_TURNS":"'"${N}"'","BAS_CONCURRENT_MODE":"'"${MODE}"'","BAS_CONCURRENT_TIMEOUT_SEC":"'"${TIMEOUT}"'","BAS_INTERNAL_MLX_PROMPTS":"1","BAS_INTERNAL_COOLDOWN_SEC":"0","BAS_INTERNAL_MAX_DECODE_TOKENS":"'"${MAX_DECODE_TOKENS}"'"}'

echo "=============================================="
echo "BAS on-device CONCURRENT-TURNS cert (#5)"
echo "Device:   ${DEVICE_ID}"
echo "Bundle:   ${BUNDLE_ID}"
echo "N:        ${N}   mode: ${MODE}   stall: ${STALL_SEC}s"
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
cturns_count() { grep -ac 'ch1025 concurrent-turns' "${1:-/dev/null}" 2>/dev/null | tr -d '[:space:]'; }
has_verdict() { grep -aq 'ch1025 concurrent-turns verdict' "${1:-/dev/null}" 2>/dev/null; }
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

# ---- baseline (newest existing log stamp, to detect a FRESH one) -
PRIOR="$(log_stamp "$(basename "$(newest_log)")")"
echo "Baseline newest log stamp: ${PRIOR:-none}"

# ---- launch (detached; no --console, per the ADR-038 harness) ----
echo "Launching ${BUNDLE_ID} ..."
if ! xcrun devicectl device process launch --terminate-existing --device "${DEVICE_ID}" \
        --environment-variables "${ENV_JSON}" "${BUNDLE_ID}" 2>&1 | grep -iq "Launched"; then
    echo "ABORT: devicectl launch failed (device disconnected? re-pair + retry)."
    exit 3
fi

# ---- poll: fresh-log detect + verdict / wedge --------------------
FRESH=""; saw_fresh=0; prev_count=-1; stall_accum=0
for i in $(seq 1 "${MAX_POLL}"); do
    sleep "${POLL_SEC}"
    NEW="$(newest_log)"; NS="$(log_stamp "$(basename "${NEW:-none}")")"
    if [ -n "${NS}" ] && { [ -z "${PRIOR}" ] || [ "${NS}" -gt "${PRIOR}" ]; }; then
        FRESH="${NEW}"; saw_fresh=1
        c="$(cturns_count "${NEW}")"; c="${c:-0}"
        echo "poll ${i}: fresh log $(basename "${NEW}")  concurrent-turns_lines=${c}"
        if has_verdict "${NEW}"; then echo "poll ${i}: verdict emitted — done."; break; fi
        # wedge detection: line count not growing while the app is alive ⇒ a concurrent-decode wedge.
        if [ "${c}" -eq "${prev_count}" ]; then
            stall_accum=$(( stall_accum + POLL_SEC ))
        else
            stall_accum=0; prev_count="${c}"
        fi
        if [ "${stall_accum}" -ge "${STALL_SEC}" ] && [ "${c}" -gt 0 ]; then
            echo ""
            echo "RESULT: WEDGED — concurrent-turns progress stalled ${stall_accum}s with no verdict (ADR-038"
            echo "        uncancellable Metal eval). Terminating the app (no reboot needed — ADR-038 §10.2)."
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
    echo "RESULT: NO FRESH LOG after ~$((MAX_POLL * POLL_SEC))s — the iPhone is almost certainly ASLEEP/LOCKED."
    echo "        UNLOCK + wake the iPhone (Auto-Lock=Never, charging), then re-run this script."
    exit 4
fi

# ---- parse + verdict --------------------------------------------
echo ""
echo "=== concurrent-turns lines ($(basename "${FRESH}")) ==="
grep -aE 'ch1025 concurrent-turns (START|progress|phase=|verdict)' "${FRESH}" | sed 's/^/  /'

V="$(grep -aE 'ch1025 concurrent-turns verdict' "${FRESH}" | tail -1)"
echo ""
case "${V}" in
    *completed=false*|"")
        echo "RESULT: FAIL — the concurrent run did not complete (deadlock / wedge / partial). See status= above."
        echo "Pulled log: ${FRESH}"; exit 1 ;;
    *speedup=some*)
        echo "RESULT: INVESTIGATE — concurrent aggregate tokens/s BEAT sequential (speedup=some). The GPU-serial"
        echo "        deduction is REFUTED on this device — dig into why (genuine overlap? measurement bug?)."
        echo "Pulled log: ${FRESH}"; exit 1 ;;
    *speedup=none*evallock_serial=confirmed*)
        echo "RESULT: PASS — concurrent aggregate tokens/s did NOT beat sequential (speedup=none) AND the run"
        echo "        completed without deadlock/wedge. The GPU decode is serial (evalLock-bound); concurrent"
        echo "        turns buy NO throughput. The Phase-2 #5 deduction is now hardware-proven (n=1)."
        echo "Pulled log: ${FRESH}"; exit 0 ;;
    *)
        echo "RESULT: INCONCLUSIVE — verdict line present but unrecognized; inspect it:"
        echo "  ${V}"
        echo "Pulled log: ${FRESH}"; exit 1 ;;
esac
