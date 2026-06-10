#!/usr/bin/env bash
# scripts/run-device-smoke.sh
# chapter 九百四十六 / M3435 — iPhone Air 真机 14 层 2-hour 冒烟 runner
#
# User directive: 「直接 在 iPhone air 跑 测试 / 真机 跑 2 小时 冒烟 /
# 14层 每层都冒烟测试」。
#
# Runs the full BehavioralAISubstrate test suite on a physical
# iOS device via xcodebuild test -destination, with a 2-hour budget
# and per-layer + fuzz smoke focus。 Defaults to the FIRST paired
# online iPhone device。
#
# # Pre-flight (you do once)
#
#   1. Plug iPhone (Air or any paired model) via USB-C
#   2. Unlock + trust the dev machine
#   3. xcrun xctrace list devices  # confirm device shows ONLINE
#   4. (first time) Xcode → Settings → Accounts → add Apple ID for signing
#   5. (first time) open Package.swift in Xcode → set team for test target
#
# # Run
#
#   bash scripts/run-device-smoke.sh              # all device, all tests
#   bash scripts/run-device-smoke.sh L14          # 14-layer smoke focus
#   bash scripts/run-device-smoke.sh L8           # L8 routed/substance only
#   bash scripts/run-device-smoke.sh FUZZ         # fuzz-driven tests
#   DEVICE_NAME="iPhone Air" bash scripts/run-device-smoke.sh
#
# # Output
#
#   /tmp/bas-device-smoke-<timestamp>.log   # full xcodebuild output
#   /tmp/bas-device-smoke-<timestamp>.xcresult   # xcresult bundle
#   /tmp/bas-device-smoke-<timestamp>.summary    # parsed summary
#
# # 2-hour budget
#
# The runner enforces a hard 7200-second timeout via `timeout(1)`。
# Within that budget,xcodebuild runs as many test bundles as fit。
# Survivor selection:tests that COMPLETE within budget have their
# pass/fail status logged。 Tests that don't start = noted as
# 「budget-exhausted」 (not a failure)。

set -uo pipefail

# ---- Config -------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG="/tmp/bas-device-smoke-${TIMESTAMP}.log"
XCRESULT="/tmp/bas-device-smoke-${TIMESTAMP}.xcresult"
SUMMARY="/tmp/bas-device-smoke-${TIMESTAMP}.summary"

# Budget in seconds (7200 = 2 hours)
BUDGET_SEC="${BUDGET_SEC:-7200}"

# Test scope filter (passed via first arg or env var)
SCOPE="${1:-${SCOPE:-ALL}}"

# Device selection — auto-pick first ONLINE iPhone if not specified
if [ -z "${DEVICE_NAME:-}" ]; then
    DEVICE_NAME="$(xcrun xctrace list devices 2>&1 \
        | awk '/== Devices ==/{flag=1; next} /== Devices Offline ==|== Simulators ==/{flag=0} flag && /iPhone/ {print; exit}' \
        | sed 's/ ([^)]*) ([^)]*)//' \
        | sed 's/ *$//')"
fi
if [ -z "${DEVICE_NAME}" ]; then
    echo "ERROR: no online iPhone detected"
    echo "Available paired devices (offline + online):"
    xcrun xctrace list devices 2>&1 | head -20
    echo ""
    echo "Plug + unlock + trust an iPhone, then re-run。"
    exit 1
fi

DESTINATION="platform=iOS,name=${DEVICE_NAME}"

# ---- Scope → -only-testing filter --------------------------------

case "${SCOPE}" in
    ALL)
        ONLY_FILTER=""
        ;;
    L14|14LAYER)
        ONLY_FILTER="-only-testing:BehavioralAISubstrateTests/M603FourteenLayerSmokeTests \
-only-testing:BehavioralAISubstrateTests/BAS14LayerMeshMapTests \
-only-testing:BehavioralAISubstrateTests/BASChapter946FourteenLayerFuzzSmokeTests"
        ;;
    L8|L8ROUTED)
        ONLY_FILTER="-only-testing:BehavioralAISubstrateTests/BASChapter934AtomLifecycleFullRowTests \
-only-testing:BehavioralAISubstrateTests/BASChapter935DeletionManifestFullRowTests \
-only-testing:BehavioralAISubstrateTests/BASChapter936UserStateFullRowTests \
-only-testing:BehavioralAISubstrateTests/BASChapter937VersionTreeFullRowTests \
-only-testing:BehavioralAISubstrateTests/BASChapter938EventLogFullRowTests \
-only-testing:BehavioralAISubstrateTests/BASChapter926FixBackfillCoverageTests"
        ;;
    FUZZ)
        ONLY_FILTER="-only-testing:BehavioralAISubstrateTests/BASChapter946FourteenLayerFuzzSmokeTests"
        ;;
    *)
        # Pass-through: SCOPE is a literal -only-testing arg
        ONLY_FILTER="-only-testing:${SCOPE}"
        ;;
esac

# ---- Preflight check ---------------------------------------------

echo "=============================================="
echo "BAS Device Smoke Runner — ch 944/945/946"
echo "Date:       ${TIMESTAMP}"
echo "Device:     ${DEVICE_NAME}"
echo "Scope:      ${SCOPE}"
echo "Budget:     ${BUDGET_SEC}s ($((BUDGET_SEC / 60)) min)"
echo "Log:        ${LOG}"
echo "xcresult:   ${XCRESULT}"
echo "=============================================="

if ! xcrun xctrace list devices 2>&1 \
    | awk '/== Devices ==/{flag=1; next} /== Devices Offline ==/{flag=0} flag' \
    | grep -q "${DEVICE_NAME}"; then
    echo ""
    echo "WARNING: device「${DEVICE_NAME}」 not found ONLINE"
    echo "Currently paired devices:"
    xcrun xctrace list devices 2>&1 | sed -n '/== Devices/,/== Simulators/p'
    echo ""
    echo "If the device is paired but offline,unlock it + plug USB-C in。"
    echo "If you want to use a specific device,set DEVICE_NAME env var。"
    echo ""
    read -r -p "Continue anyway? [y/N] " ans
    [ "${ans}" = "y" ] || exit 1
fi

# ---- Run with timeout --------------------------------------------

echo ""
echo "Starting test run at $(date)..."
echo ""

# `timeout` not always installed on macOS — fall back to `gtimeout`
# (from coreutils via brew) or background+kill pattern
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
fi

run_xcodebuild() {
    xcodebuild test \
        -scheme BehavioralAISubstrate-Package \
        -destination "${DESTINATION}" \
        -resultBundlePath "${XCRESULT}" \
        ${ONLY_FILTER} \
        -parallel-testing-enabled NO \
        2>&1 \
        | tee "${LOG}"
}

# chapter 一千零十五.6 / M3810 pattern — pre-warm `xcodebuild build` to MATERIALIZE the SwiftPM build-tool
# plugin outputs (BASSQLSchemaGen `*.generated.swift`) BEFORE `xcodebuild test`. On cold DerivedData a single
# `xcodebuild test` races the plugin command against the Swift input-dependency check and fail-fasts with
# "Build input files cannot be found: …/BASSQLSchemaGen/NNN_*.generated.swift". One build runs the plugin +
# caches the generated files; the test then finds them as inputs. Opt out via BAS_SKIP_PREWARM=1.
if [ -z "${BAS_SKIP_PREWARM:-}" ]; then
    echo "$(date) pre-warming xcodebuild build (materialize BASSQLSchemaGen plugin outputs before test)"
    xcodebuild build \
        -scheme BehavioralAISubstrate-Package \
        -destination "${DESTINATION}" \
        -allowProvisioningUpdates \
        -skipPackagePluginValidation \
        > "${LOG}.prewarm" 2>&1 \
        || echo "$(date) pre-warm build returned non-zero — continuing to test (see ${LOG}.prewarm)"
fi

if [ -n "${TIMEOUT_BIN}" ]; then
    "${TIMEOUT_BIN}" --foreground "${BUDGET_SEC}s" bash -c "$(declare -f run_xcodebuild); run_xcodebuild"
    RC=$?
else
    # macOS without timeout: run in background,kill after budget
    run_xcodebuild &
    XCB_PID=$!
    (sleep "${BUDGET_SEC}" && kill -TERM "${XCB_PID}" 2>/dev/null) &
    TIMER_PID=$!
    wait "${XCB_PID}"
    RC=$?
    kill "${TIMER_PID}" 2>/dev/null || true
fi

# ---- Summarize ----------------------------------------------------

{
    echo "=============================================="
    echo "BAS Device Smoke Summary — ${TIMESTAMP}"
    echo "Device:     ${DEVICE_NAME}"
    echo "Scope:      ${SCOPE}"
    echo "Exit code:  ${RC}"
    echo "=============================================="
    echo ""
    if grep -q "Test session results" "${LOG}" 2>/dev/null; then
        echo "Test session summary:"
        grep -E "Test session results|Test Case|XCTAssert|with [0-9]+ failure|Executed [0-9]+ tests" "${LOG}" | tail -50
    fi
    echo ""
    if [ "${RC}" -eq 124 ]; then
        echo "STATUS: BUDGET EXHAUSTED (${BUDGET_SEC}s)"
        echo "Some tests may not have completed。 Check ${LOG} for which fired。"
    elif [ "${RC}" -eq 0 ]; then
        echo "STATUS: ALL TESTS PASSED ✓"
    else
        echo "STATUS: FAILURES (exit code ${RC})"
        echo "Failed tests:"
        grep -E "failed \([0-9.]+ seconds\)" "${LOG}" | head -20
    fi
    echo ""
    echo "Full log:  ${LOG}"
    echo "xcresult:  ${XCRESULT}"
    echo ""
    echo "Open xcresult in Xcode:"
    echo "    open ${XCRESULT}"
} | tee "${SUMMARY}"

exit "${RC}"
