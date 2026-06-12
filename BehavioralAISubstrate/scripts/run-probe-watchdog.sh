#!/usr/bin/env bash
# scripts/run-probe-watchdog.sh — generic device-probe watchdog (ADR-038 wedge survival for the
# Tranche-A/C/D decode probes, not just the endurance loop).
#
# The decode A/B probes (BAS_QUANT_AB, BAS_VERIFIER_LANE_AB, BAS_SPEC_GREEDY_SWEEP, BAS_LITERT_E4B_PROBE)
# run via launchSpecAux and emit their OWN log markers — the endurance watchdog (which keys off
# "🧠 ch1025 mlx") can't see them, so a wedged probe on a hot device just hangs (exactly what happened
# 2026-06-12: BASVerifierLaneABProbe stalled after START on a thermally-cooked device A). This watchdog
# keys off a probe-supplied PROGRESS/DONE marker pair and relaunches on stall/crash until the probe
# COMPLETES (a relaunch on a cooled device gets a clean run) or the budget expires.
#
# Usage:
#   PROBE_ENV='{"BAS_ENDURANCE_AUTOSTART":"1","BAS_VERIFIER_LANE_AB":"1"}' \
#   LOG_GLOB='verifier-lane-ab-*.log' DONE_GREP='verifier-lane-ab DONE|verifier-lane-ab ERROR' \
#   PROGRESS_GREP='verifier-lane-ab|LANE=' \
#   DEVICE_ID=<udid> WATCHDOG_MINUTES=40 bash scripts/run-probe-watchdog.sh
#
# Requires the iPhone UNLOCKED + awake + charging. A relaunch RESTARTS the probe from scratch (probes
# don't checkpoint) — fine for an A/B that just needs one clean run.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
WATCHDOG_MINUTES="${WATCHDOG_MINUTES:-40}"
STALL_SEC="${STALL_SEC:-180}"        # no new progress line for this long (app alive) ⇒ wedge → relaunch
POLL_SEC="${POLL_SEC:-20}"
PROBE_ENV="${PROBE_ENV:?set PROBE_ENV to the launch env JSON including the probe flag}"
LOG_GLOB="${LOG_GLOB:?set LOG_GLOB to the probe Documents log glob e.g. verifier-lane-ab-star.log}"
DONE_GREP="${DONE_GREP:?set DONE_GREP to the completion marker regex}"
PROGRESS_GREP="${PROGRESS_GREP:-${DONE_GREP}}"   # liveness marker (defaults to DONE if the probe is terse)
ARCHIVE_DIR="${ARCHIVE_DIR:-}"
PULL_DIR="$(mktemp -d /tmp/bas-probe-wd.XXXXXX)"

pull_docs() {
    rm -rf "${PULL_DIR}"; mkdir -p "${PULL_DIR}"
    xcrun devicectl device copy from --device "${DEVICE_ID}" \
        --domain-type appDataContainer --domain-identifier "${BUNDLE_ID}" \
        --source Documents --destination "${PULL_DIR}" >/dev/null 2>&1
}
newest_log() { find "${PULL_DIR}" -type f -name "${LOG_GLOB}" 2>/dev/null | sort | tail -1; }
progress_count() { local n; n=$(grep -acE "${PROGRESS_GREP}" "$1" 2>/dev/null) || true; echo "${n:-0}"; }
has_done() { grep -aqE "${DONE_GREP}" "$1" 2>/dev/null; }
app_alive() {
    local n; n=$(xcrun devicectl device info processes --device "${DEVICE_ID}" 2>/dev/null \
        | grep -ic "${BUNDLE_ID##*.}")
    [ "${n:-0}" -gt 0 ]
}
terminate_app() {
    local pid; pid=$(xcrun devicectl device info processes --device "${DEVICE_ID}" 2>/dev/null \
        | grep -i "${BUNDLE_ID##*.}" | awk '{print $1}' | head -1)
    [ -n "${pid:-}" ] && xcrun devicectl device process terminate --device "${DEVICE_ID}" --pid "${pid}" >/dev/null 2>&1
}
launch_run() {
    xcrun devicectl device process launch --terminate-existing --device "${DEVICE_ID}" \
        --environment-variables "${PROBE_ENV}" "${BUNDLE_ID}" 2>&1 | grep -iq "Launched"
}

echo "=============================================="
echo "BAS PROBE watchdog — glob:${LOG_GLOB}  done:/${DONE_GREP}/  budget:${WATCHDOG_MINUTES}min  stall:${STALL_SEC}s"
echo "=============================================="
START=$(date +%s); DEADLINE=$(( START + WATCHDOG_MINUTES * 60 ))
SEG=0; WEDGES=0; LAUNCH_FAILS=0; OUTCOME="timeout"

while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
    SEG=$(( SEG + 1 ))
    NOW=$(date +%s); ELAPSED_MIN=$(( (NOW - START) / 60 ))
    echo ""
    echo "-- segment ${SEG} (elapsed ${ELAPSED_MIN}min) -- launch probe"
    terminate_app; sleep 2
    if ! launch_run; then
        LAUNCH_FAILS=$(( LAUNCH_FAILS + 1 ))
        echo "   launch failed (device locked/asleep?) — retry"; sleep "${POLL_SEC}"; continue
    fi
    prev=-1; stall=0
    while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
        sleep "${POLL_SEC}"
        pull_docs; LG="$(newest_log)"
        if [ -z "${LG}" ]; then echo "   poll: no probe log yet"; continue; fi
        if has_done "${LG}"; then OUTCOME="completed"; echo "   ✅ probe COMPLETED"; break 2; fi
        if ! app_alive; then echo "   ⛔ APP GONE — crashed/jetsam, relaunch"; WEDGES=$(( WEDGES + 1 )); break; fi
        c=$(progress_count "${LG}")
        if [ "${c}" -eq "${prev}" ]; then stall=$(( stall + POLL_SEC )); else stall=0; fi
        if [ "${stall}" -ge "${STALL_SEC}" ]; then
            echo "   ⛔ WEDGE (progress stalled at ${c} for ${stall}s) — kill + relaunch"
            WEDGES=$(( WEDGES + 1 )); break
        fi
        echo "   poll: progress=${c} stall=${stall}s"
        prev=${c}
    done
    terminate_app; sleep 3
done

[ -n "${ARCHIVE_DIR}" ] && { mkdir -p "${ARCHIVE_DIR}"; pull_docs; cp -R "${PULL_DIR}/." "${ARCHIVE_DIR}/" 2>/dev/null; }
echo ""
echo "=============================================="
echo "PROBE WATCHDOG SUMMARY — outcome:${OUTCOME} segments:${SEG} wedges:${WEDGES} launch_fails:${LAUNCH_FAILS}"
[ "${OUTCOME}" = "completed" ] && { echo "RESULT: PASS — probe completed (wedges survived: ${WEDGES})"; exit 0; }
echo "RESULT: did not complete within budget — re-run on a cooler device or raise WATCHDOG_MINUTES"; exit 1
