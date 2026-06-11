#!/usr/bin/env bash
# scripts/run-endurance-watchdog.sh
# ADR-038 §10.2 — UNATTENDED endurance watchdog. Runs the BASDeviceTestApp endurance on a physical
# device for a wall-clock budget, SURVIVING any number of MLX decode wedges WITHOUT a device reboot.
#
# WHY THIS WORKS (measured, ADR-038 §10.2): the decode wedge is MLX-PROCESS-LOCAL, not a GPU/firmware
# poison — the GPU stays healthy (a sibling Metal queue keeps completing during the wedge) and a plain
# kill + relaunch FULLY recovers (full-MLX relaunch loads + runs normally, no reboot). So the recovery
# loop is simply: detect stall → terminate → relaunch → continue. NO reboot-on-poison step (that was a
# refuted premise — see ADR §8 ⛔ note / §10.2).
#
# DETECTION: the run emits "🧠 ch1025 mlx ..." per decode. A wedge = that count stops growing while the
# app is still alive. The watchdog polls the pulled log; if the mlx count is unchanged for STALL_SEC and
# no FINAL marker appeared, it declares a wedge, kills the app, and relaunches.
#
# NOTE on progress semantics: the endurance runner currently restarts from iter 0 on each relaunch (no
# resume-from-checkpoint yet — that is task #60/A follow-up). So this harness measures TIME-BASED
# endurance: it accumulates TOTAL decode responses + wedges-survived across relaunches over the window,
# proving unattended survival. Cognitive memory is durable across restart (SQLite), so the substrate
# state accumulates even though the iter cursor resets.
#
# Usage:
#   BUILD=1 bash scripts/run-endurance-watchdog.sh                 # build+install, then watch 60 min
#   WATCHDOG_MINUTES=120 STALL_SEC=90 bash scripts/run-endurance-watchdog.sh
#   DEVICE_ID=... bash scripts/run-endurance-watchdog.sh
# Requires the iPhone UNLOCKED + awake + charging, Auto-Lock=Never.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
BUILD="${BUILD:-0}"
WATCHDOG_MINUTES="${WATCHDOG_MINUTES:-60}"   # total wall-clock budget
PER_RUN_ITERS="${PER_RUN_ITERS:-200}"        # per-relaunch iter cap (big; a wedge ends it early anyway)
STALL_SEC="${STALL_SEC:-90}"                 # no new mlx line for this long (app alive) ⇒ wedge
POLL_SEC="${POLL_SEC:-15}"
MAX_DECODE_TOKENS="${MAX_DECODE_TOKENS:-96}"
WEDGE_FAST="${WEDGE_FAST:-0}"   # 1 ⇒ inject the fabric feed-forward (ADR §6 big-prefill) so each segment
                                # wedges FAST — used to VALIDATE the watchdog's detect→kill→relaunch path
                                # in-harness (the plain wedge is variable and may not fire in a short window).
# --- data-run parameterization (2026-06-12) — all default to the prior fixed values, so existing
#     callers are byte-identical. The dual-model sweep driver overrides these per phase. ---
MODEL="${MODEL:-}"                # BAS_MLX_MODEL value (e.g. "llama"/"e4b"); empty ⇒ runner default (Gemma4 E2B)
MLX_PROMPTS="${MLX_PROMPTS:-1}"   # prompts per iter (was hardcoded 1)
COOLDOWN_SEC="${COOLDOWN_SEC:-0}" # base cooldown between iters (was hardcoded 0). NOTE: with cooldown ON,
                                  # the mlx count legitimately freezes during cooldown — STALL_SEC MUST exceed
                                  # the adaptive cooldown ceiling (base*3+120) + a decode, or a cooldown reads
                                  # as a false wedge. The sweep driver sets STALL_SEC accordingly.
ENV_EXTRA="${ENV_EXTRA:-}"       # extra knobs as a JSON fragment "K":"V",... WITH a trailing comma (or empty)
ARCHIVE_DIR="${ARCHIVE_DIR:-}"   # if set, the full Documents container is pulled here at the end (per-phase archive)
LOG_GLOB="ch1025-endurance-2026*.log"
PULL_DIR="$(mktemp -d /tmp/bas-wd.XXXXXX)"

WEDGE_FRAG=""
if [ "${WEDGE_FAST}" = "1" ]; then
    WEDGE_FRAG='"BAS_FABRIC_AUTH_FEEDFORWARD":"1","BAS_AGENT_FABRIC":"enabled",'
fi
MODEL_FRAG=""
if [ -n "${MODEL}" ]; then
    MODEL_FRAG='"BAS_MLX_MODEL":"'"${MODEL}"'",'
fi
ENV_RUN='{"BAS_ENDURANCE_AUTOSTART":"1",'"${WEDGE_FRAG}${MODEL_FRAG}${ENV_EXTRA}"'"BAS_INTERNAL_ITER_COUNT":"'"${PER_RUN_ITERS}"'","BAS_INTERNAL_MLX_PROMPTS":"'"${MLX_PROMPTS}"'","BAS_INTERNAL_COOLDOWN_SEC":"'"${COOLDOWN_SEC}"'","BAS_INTERNAL_MAX_DECODE_TOKENS":"'"${MAX_DECODE_TOKENS}"'"}'

log_stamp() { echo "${1:-}" | grep -oE '[0-9]{8}-[0-9]{6}' | tr -d '-' | tail -1; }
newest_log() {
    rm -rf "${PULL_DIR}"; mkdir -p "${PULL_DIR}"
    xcrun devicectl device copy from --device "${DEVICE_ID}" \
        --domain-type appDataContainer --domain-identifier "${BUNDLE_ID}" \
        --source Documents --destination "${PULL_DIR}" >/dev/null 2>&1
    find "${PULL_DIR}" -type f -name "${LOG_GLOB}" 2>/dev/null | sort | tail -1
}
mlx_count() { grep -ac '🧠 ch1025 mlx ' "$1" 2>/dev/null || echo 0; }
has_final() { grep -aq 'ch1025 FINAL run_sec' "$1" 2>/dev/null; }
terminate_app() {
    local pid
    pid=$(xcrun devicectl device info processes --device "${DEVICE_ID}" 2>/dev/null \
        | grep -i basdevicetest | awk '{print $1}' | head -1)
    [ -n "${pid:-}" ] && xcrun devicectl device process terminate --device "${DEVICE_ID}" --pid "${pid}" >/dev/null 2>&1
}
launch_run() {
    xcrun devicectl device process launch --terminate-existing --device "${DEVICE_ID}" \
        --environment-variables "${ENV_RUN}" "${BUNDLE_ID}" 2>&1 | grep -iq "Launched"
}

echo "=============================================="
echo "BAS UNATTENDED endurance watchdog (no reboot — ADR-038 §10.2)"
echo "Device:${DEVICE_ID}  budget:${WATCHDOG_MINUTES}min  stall:${STALL_SEC}s  per-run iters:${PER_RUN_ITERS}"
echo "=============================================="

if [ "${BUILD}" = "1" ]; then
    echo "Building + installing ${SCHEME} ..."
    xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_ID}" \
        -allowProvisioningUpdates build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
    APP="$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -destination "id=${DEVICE_ID}" \
        -showBuildSettings 2>/dev/null | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / WRAPPER_NAME /{w=$2} END{print d"/"w}')"
    xcrun devicectl device install app --device "${DEVICE_ID}" "${APP}" 2>&1 | grep -iE "App installed|error" | tail -2
fi

START_EPOCH=$(date +%s)
DEADLINE=$(( START_EPOCH + WATCHDOG_MINUTES * 60 ))
SEGMENT=0
WEDGES=0
RECOVERIES=0
CLEAN_COMPLETIONS=0
LAUNCH_FAILURES=0
TOTAL_RESPONSES=0   # accumulated across segments (each segment's mlx count, summed)

while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
    SEGMENT=$(( SEGMENT + 1 ))
    PRIOR=$(log_stamp "$(basename "$(newest_log)")")
    echo ""
    echo "── segment ${SEGMENT} (elapsed $(( ($(date +%s) - START_EPOCH) / 60 ))min / ${WATCHDOG_MINUTES}min) — launch endurance"
    terminate_app; sleep 2
    if ! launch_run; then
        LAUNCH_FAILURES=$(( LAUNCH_FAILURES + 1 ))
        echo "   launch failed (device locked/asleep?) — retry next poll"
        sleep "${POLL_SEC}"; continue
    fi

    SEG_LOG=""; seg_prev=-1; seg_stall=0; seg_responses=0; outcome="timeout"
    while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
        sleep "${POLL_SEC}"
        NEW="$(newest_log)"; NS=$(log_stamp "$(basename "${NEW:-none}")")
        { [ -n "${NS}" ] && { [ -z "${PRIOR}" ] || [ "${NS}" -gt "${PRIOR}" ]; }; } || { echo "   poll: no fresh segment log yet"; continue; }
        SEG_LOG="${NEW}"
        c=$(mlx_count "${NEW}"); seg_responses=${c}
        if has_final "${NEW}"; then outcome="completed"; echo "   ✅ segment COMPLETED cleanly (responses=${c})"; break; fi
        if [ "${c}" -eq "${seg_prev}" ]; then seg_stall=$(( seg_stall + POLL_SEC )); else seg_stall=0; fi
        if [ "${seg_stall}" -ge "${STALL_SEC}" ] && [ "${c}" -gt 0 ]; then
            outcome="wedge"; echo "   ⛔ WEDGE (mlx stalled at ${c} for ${seg_stall}s) — kill + relaunch (NO reboot)"; break
        fi
        echo "   poll: responses=${c} stall=${seg_stall}s"
        seg_prev=${c}
    done

    TOTAL_RESPONSES=$(( TOTAL_RESPONSES + seg_responses ))
    case "${outcome}" in
        wedge)      WEDGES=$(( WEDGES + 1 )); RECOVERIES=$(( RECOVERIES + 1 )); terminate_app; sleep 3 ;;
        completed)  CLEAN_COMPLETIONS=$(( CLEAN_COMPLETIONS + 1 )); terminate_app; sleep 2 ;;
        timeout)    echo "   (budget reached mid-segment, responses=${seg_responses})"; terminate_app ;;
    esac
done

ELAPSED_MIN=$(( ($(date +%s) - START_EPOCH) / 60 ))
echo ""
echo "=============================================="
echo "WATCHDOG SUMMARY (unattended, no reboot)"
echo "  wall-clock:           ${ELAPSED_MIN} min"
echo "  segments launched:    ${SEGMENT}"
echo "  wedges survived:      ${WEDGES}  (recovered by kill+relaunch: ${RECOVERIES})"
echo "  clean completions:    ${CLEAN_COMPLETIONS}"
echo "  launch failures:      ${LAUNCH_FAILURES}"
echo "  total decode responses (summed across segments): ${TOTAL_RESPONSES}"
echo "=============================================="

# Per-phase archive (2026-06-12) — pull the WHOLE Documents container so the sweep driver keeps every
# phase's data: the endurance .log, field-metrics.jsonl, the sovereign ledger + key, memory/vector SQLite.
if [ -n "${ARCHIVE_DIR}" ]; then
    mkdir -p "${ARCHIVE_DIR}"
    if xcrun devicectl device copy from --device "${DEVICE_ID}" \
        --domain-type appDataContainer --domain-identifier "${BUNDLE_ID}" \
        --source Documents --destination "${ARCHIVE_DIR}" >/dev/null 2>&1; then
        echo "  archived Documents → ${ARCHIVE_DIR} ($(find "${ARCHIVE_DIR}" -type f 2>/dev/null | wc -l | tr -d ' ') files)"
    else
        echo "  ⚠️ archive pull FAILED (device unavailable?) — data still on device for manual pull"
    fi
fi

if [ "${WEDGES}" -eq "${RECOVERIES}" ] && [ "${LAUNCH_FAILURES}" -eq 0 ]; then
    echo "RESULT: PASS — every wedge auto-recovered by kill+relaunch; NO reboot needed; run was unattended."
    exit 0
else
    echo "RESULT: review — a relaunch did not recover or the device went unavailable (see log above)."
    exit 1
fi
