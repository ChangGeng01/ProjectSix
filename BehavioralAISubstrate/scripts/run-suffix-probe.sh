#!/usr/bin/env bash
# scripts/run-suffix-probe.sh
# Universal Draft Layer — Phase-1 PROMOTION GATE on the A19 (turnkey). Builds/installs the DeviceTestApp, then runs
# the cross-turn suffix probe (BAS_SUFFIX_PROBE=1) at a baseline K and an aggressive K, and prints each
# PROMOTION_GATE verdict. See Docs/UNIVERSAL_DRAFT_LAYER.md.
#
#   Build/install once, then run both K passes:   BUILD=1 bash scripts/run-suffix-probe.sh
#   Re-run (app already installed):                bash scripts/run-suffix-probe.sh
#   Custom K sweep / model:                        K_VALUES="4 8 12" SLOOKUP_MODEL=llama_3b bash scripts/run-suffix-probe.sh
#
# Requires the iPhone UNLOCKED + awake. The promotion gate (per Docs/UNIVERSAL_DRAFT_LAYER.md):
#   VALID run AND token-identical every turn AND later-turn reuse mean > 1x AND control >= 0.90x.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

DEVICE_ID="${DEVICE_ID:-9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6}"   # iPhone Air ("Chang's iPhone")
BUNDLE_ID="${BUNDLE_ID:-com.changgeng.basdevicetest}"
SCHEME="${SCHEME:-BASDeviceTestApp}"
PROJECT="${PROJECT:-DeviceTestApp/BASDeviceTest.xcodeproj}"
BUILD="${BUILD:-0}"
POLL_SEC="${POLL_SEC:-15}"
MAX_POLL="${MAX_POLL:-40}"                      # ~MAX_POLL × POLL_SEC budget per K pass
# Single-dash: an explicit empty K_VALUES="" runs ZERO passes (build/install-only); UNSET defaults to "4 8".
# Must be a non-empty space-separated list to run passes (e.g. K_VALUES="8").
K_VALUES="${K_VALUES-4 8}"                       # baseline vs aggressive
SLOOKUP_MODEL="${SLOOKUP_MODEL:-llama_3b}"      # llama_3b (default — full attention, trimmable cache) | qwen_3b
# NOTE: gemma_e2b is sliding-window (RotatingKVCache) → the byte-identity decoder fail-closes with
# nonTrimmableCache (verified on-device 2026-06-19). Use a full-attention model for the cross-turn probe.
# BAS_FP32_VERIFY bisect arm (Gemma byte-identity fix, see UNIVERSAL_DRAFT_LAYER.md): proj | sdpa | full | "" (off).
# FWDDIAG=1 runs the single-vs-multi forward diagnostic (max_logit_diff / argmax_agree) instead of the promotion gate.
FP32_VERIFY="${FP32_VERIFY:-}"
FWDDIAG="${FWDDIAG:-}"
GATE="${GATE:-}"                                 # "" (strict, default) | lossless (field-standard ADR-039, for Gemma)
LOG_GLOB="suffix-lookup-*.log"
PULL_DIR="$(mktemp -d /tmp/bas-suffix.XXXXXX)"

newest_log() {
    rm -rf "${PULL_DIR}"; mkdir -p "${PULL_DIR}"
    xcrun devicectl device copy from --device "${DEVICE_ID}" \
        --domain-type appDataContainer --domain-identifier "${BUNDLE_ID}" \
        --source Documents --destination "${PULL_DIR}" >/dev/null 2>&1
    find "${PULL_DIR}" -type f -name "${LOG_GLOB}" 2>/dev/null | sort | tail -1
}
log_stamp() { echo "${1:-}" | grep -oE '[0-9]{8}-[0-9]{6}' | tr -d '-' | tail -1; }
newer_than() {  # newer_than NEW_BASE PRIOR_BASE  → 0 iff strictly newer
    local a b; a="$(log_stamp "$1")"; b="$(log_stamp "$2")"
    [ -n "$a" ] || return 1; [ -n "$b" ] || return 0; [ "$a" -gt "$b" ]
}
terminate_app() {
    local pid
    pid=$(xcrun devicectl device info processes --device "${DEVICE_ID}" 2>/dev/null \
        | grep -i basdevicetest | awk '{print $1}' | head -1)
    [ -n "${pid:-}" ] && xcrun devicectl device process terminate --device "${DEVICE_ID}" --pid "${pid}" >/dev/null 2>&1
}

echo "=============================================="
echo "Universal Draft Layer — cross-turn suffix probe (promotion gate)"
echo "Device: ${DEVICE_ID}   Bundle: ${BUNDLE_ID}   Model: ${SLOOKUP_MODEL}   K: ${K_VALUES}"
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

run_pass() {  # run_pass K
    local k="$1"
    echo ""
    echo "### Pass K=${k} ----------------------------------------------"
    terminate_app; sleep 2
    local prior; prior="$(basename "$(newest_log)" 2>/dev/null || echo none)"
    local pairs="\"BAS_ENDURANCE_AUTOSTART\":\"1\",\"BAS_SUFFIX_PROBE\":\"1\",\"BAS_SL_K\":\"${k}\",\"BAS_SLOOKUP_MODEL\":\"${SLOOKUP_MODEL}\""
    [ -n "${FP32_VERIFY}" ] && pairs="${pairs},\"BAS_FP32_VERIFY\":\"${FP32_VERIFY}\""
    [ -n "${FWDDIAG}" ] && pairs="${pairs},\"BAS_SL_FWDDIAG\":\"1\""
    [ -n "${GATE}" ] && pairs="${pairs},\"BAS_SL_GATE\":\"${GATE}\""
    local env="{${pairs}}"
    echo "  env: ${env}"
    xcrun devicectl device process launch --terminate-existing --device "${DEVICE_ID}" \
        --environment-variables "${env}" "${BUNDLE_ID}" 2>&1 | grep -iq "Launched" \
        || { echo "  ABORT: launch failed (device locked/asleep? unlock + retry)"; return 3; }

    local log="" base
    for i in $(seq 1 "${MAX_POLL}"); do
        sleep "${POLL_SEC}"
        log="$(newest_log)"; base="$(basename "${log:-none}")"
        { [ -n "${log}" ] && newer_than "${base}" "${prior}"; } || { echo "  poll ${i}: no fresh log (newest=${base})"; continue; }
        if grep -aq 'suffix-lookup DONE' "${log}" 2>/dev/null; then
            echo "  done (poll ${i}, log ${base})"; break
        fi
        echo "  poll ${i}: running (${base})"
    done
    if [ -z "${log}" ] || ! grep -aq 'suffix-lookup DONE' "${log}" 2>/dev/null; then
        echo "  NO verdict within budget — device locked/asleep, or the run exceeded ${MAX_POLL}×${POLL_SEC}s."
        return 4
    fi
    echo "  --- per-turn ---"
    grep -aE 'suffix convo=|fwddiag' "${log}" 2>/dev/null | sed 's/^.*📊/    📊/; s/^[^ ]* /    /' | sed 's/^/  /' | tail -20
    echo "  --- VERDICT ---"
    grep -aE 'suffix-lookup DONE' "${log}" 2>/dev/null | tail -1 | sed 's/^/  /'
}

for k in ${K_VALUES}; do run_pass "${k}"; done

echo ""
echo "=============================================="
echo "Read PROMOTION_GATE per pass: PASS = certified net-positive (promote); FAIL = measured loss/no-win (drop or"
echo "keep gated); INVALID = infra failure (re-run, do not interpret as a measured result). The K=8 (aggressive)"
echo "pass is the headline; K=4 is the baseline. Full logs under: ${PULL_DIR}"
echo "=============================================="
