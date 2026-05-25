#!/usr/bin/env bash
# chapter 九百五十二.3 / M3465.3 + ch 952.6 fix
#
# Run the full ch 952 device test suite on iPhone Air repeatedly
# for up to 10 hours, recording results + failures。
#
# Usage:
#   bash scripts/run-iphone-air-10hr.sh
#
# ch 952.6 FIX: previous version used `caffeinate -dimsu bash -c "..."`
# with nested escaping, which caused outer-shell $ITER (=0) to be
# baked into the inner shell every iter — so iter counter stuck at
# 1 and each new iter OVERWROTE iter-001.log。 This rewrite uses
# `exec caffeinate` to re-enter the script under caffeinate without
# nested quoting。
#
# Pre-requisites (user must do once):
#   1. iPhone Air plugged into Mac via USB-C (charging)
#   2. iPhone Air auto-lock OFF (Settings → Display & Brightness →
#      Auto-Lock → Never)
#   3. Mac on charger (caffeinate keeps Mac awake automatically)
#   4. Developer cert trusted on iPhone (ch 951 step 4)
#   5. DO NOT edit test source files while wrapper is running —
#      SwiftPM package reload interrupts running iter
#
# Output:
#   /tmp/ch952-10hr/iter-NNN.log per iteration (correctly numbered)
#   /tmp/ch952-10hr/summary.txt running tally

set -uo pipefail

# Re-exec under caffeinate so Mac stays awake — but only once
if [ -z "${UNDER_CAFFEINATE:-}" ]; then
    export UNDER_CAFFEINATE=1
    exec caffeinate -dimsu "$0" "$@"
fi

SUBSTRATE_DIR="/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
DEVICE_ID="9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6"
LOG_DIR="${BAS_DEVICE_LOG_DIR:-/tmp/ch952-10hr}"
# chapter 九百五十二.8.1 — MAX_SEC env override (e.g.
# MAX_SEC=600 bash scripts/run-iphone-air-10hr.sh for 10-min smoke
# vs the 10hr default)
MAX_SEC=${MAX_SEC:-$((10 * 3600))}   # default 10 hours

mkdir -p "$LOG_DIR"
echo "ch952.3+952.6 10hr run starting at $(date)" > "$LOG_DIR/summary.txt"
echo "device=$DEVICE_ID  max_sec=$MAX_SEC  pid=$$" >> "$LOG_DIR/summary.txt"
echo "" >> "$LOG_DIR/summary.txt"

START_TS=$(date +%s)
ITER=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

cleanup() {
    echo "" >> "$LOG_DIR/summary.txt"
    echo "STOPPED at $(date) (signal or 10hr cap)" >> "$LOG_DIR/summary.txt"
    echo "TOTAL: iter=$ITER passed=$TOTAL_PASSED failed=$TOTAL_FAILED skipped=$TOTAL_SKIPPED" \
        >> "$LOG_DIR/summary.txt"
    exit 0
}
trap cleanup INT TERM

cd "$SUBSTRATE_DIR"

# chapter 九百五十二.8 — pre-iter device-presence check helper。
# Previous wrapper:if iPhone disconnected mid-run,xcodebuild would
# fail every iter until script exit。 Now we fail-fast within 1 iter
# and report DEVICE_DISCONNECTED rather than masquerading as test fail。
check_device_connected() {
    if xcrun devicectl list devices 2>/dev/null | \
        grep -q "$DEVICE_ID.*connected"; then
        return 0
    fi
    return 1
}

# Main loop — no bash -c nesting, ITER properly local
while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TS))
    if [ $ELAPSED -ge $MAX_SEC ]; then
        echo "$(date) 10hr cap hit — stopping (iter=$ITER)" \
            >> "$LOG_DIR/summary.txt"
        break
    fi
    # chapter 九百五十二.8 — fail-fast if iPhone disconnected
    if ! check_device_connected; then
        echo "$(date) DEVICE_DISCONNECTED — iPhone Air not in " \
            "xcrun devicectl list — stopping at iter=$ITER" \
            >> "$LOG_DIR/summary.txt"
        break
    fi
    ITER=$((ITER + 1))
    LOG_FILE="$LOG_DIR/iter-$(printf '%03d' $ITER).log"
    echo "$(date) iter=$ITER (elapsed=${ELAPSED}s / ${MAX_SEC}s) starting" \
        >> "$LOG_DIR/summary.txt"
    xcodebuild test \
        -project DeviceTestApp/BASDeviceTest.xcodeproj \
        -scheme BASDeviceTestApp \
        -destination "platform=iOS,id=$DEVICE_ID" \
        -testPlan Device2HrFuzz \
        -allowProvisioningUpdates \
        -skipPackagePluginValidation \
        > "$LOG_FILE" 2>&1
    EXIT=$?
    PASSED=$(grep -c "Test Case.*passed" "$LOG_FILE" || true)
    FAILED=$(grep -c "Test Case.*failed" "$LOG_FILE" || true)
    SKIPPED=$(grep -c "Test Case.*skipped" "$LOG_FILE" || true)
    TOTAL_PASSED=$((TOTAL_PASSED + PASSED))
    TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + SKIPPED))
    echo "$(date) iter=$ITER done exit=$EXIT passed=$PASSED failed=$FAILED skipped=$SKIPPED" \
        >> "$LOG_DIR/summary.txt"
    # chapter 九百五十二.8 — sanity check:passed=0 + failed=0
    # = empty iter (likely xcodebuild error) → don't masquerade as success
    if [ $FAILED -gt 0 ] || [ $EXIT -ne 0 ]; then
        echo "$(date) FAILURE detected — preserving log + stopping" \
            >> "$LOG_DIR/summary.txt"
        echo "see $LOG_FILE for failure detail" >> "$LOG_DIR/summary.txt"
        break
    fi
    if [ $PASSED -eq 0 ] && [ $SKIPPED -eq 0 ]; then
        echo "$(date) EMPTY iter (passed=0 skipped=0) — likely " \
            "xcodebuild setup error,stopping at iter=$ITER" \
            >> "$LOG_DIR/summary.txt"
        echo "see $LOG_FILE for cause" >> "$LOG_DIR/summary.txt"
        break
    fi
done

echo "" >> "$LOG_DIR/summary.txt"
echo "FINAL at $(date)" >> "$LOG_DIR/summary.txt"
echo "TOTAL: iter=$ITER passed=$TOTAL_PASSED failed=$TOTAL_FAILED skipped=$TOTAL_SKIPPED" \
    >> "$LOG_DIR/summary.txt"
