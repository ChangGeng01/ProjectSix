#!/usr/bin/env bash
# chapter 九百五十二.3 / M3465.3
#
# Run the full ch 952 device test suite on iPhone Air repeatedly
# for up to 10 hours, recording results + failures。
#
# Usage:
#   bash scripts/run-iphone-air-10hr.sh
#
# Pre-requisites (user must do once):
#   1. iPhone Air plugged into Mac via USB-C (charging)
#   2. iPhone Air auto-lock OFF (Settings → Display & Brightness →
#      Auto-Lock → Never)
#   3. Mac on charger + caffeinate keeps Mac awake (this script
#      uses `caffeinate` automatically)
#   4. Developer cert trusted on iPhone (ch 951 step 4)
#
# What it does:
#   - Loops `xcodebuild test -testPlan Device2HrFuzz` until either:
#     (a) 10 hours wallclock have elapsed,or
#     (b) the test bundle FAILS (preserves failure log,exits)
#   - Logs each iteration's start/end + pass count + any failures
#   - Aggregate report at end:N iterations,M total tests,F failures
#
# Output:
#   /tmp/ch952-10hr/iter-NNN.log per iteration
#   /tmp/ch952-10hr/summary.txt running tally
#
# Stop early:
#   ctrl-C any time。 Wrapper exits cleanly;current xcodebuild
#   subprocess is killed。 Summary file shows partial results。

set -uo pipefail

SUBSTRATE_DIR="/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
DEVICE_ID="9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6"
LOG_DIR="/tmp/ch952-10hr"
MAX_SEC=$((10 * 3600))   # 10 hours = 36000 seconds

mkdir -p "$LOG_DIR"
echo "ch952.3 10hr run starting at $(date)" > "$LOG_DIR/summary.txt"
echo "device=$DEVICE_ID  max_sec=$MAX_SEC" >> "$LOG_DIR/summary.txt"
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

# Wrap entire loop in caffeinate so Mac stays awake even if its
# Energy Saver settings would otherwise sleep。
caffeinate -dimsu bash -c "
while true; do
    NOW=\$(date +%s)
    ELAPSED=\$((NOW - $START_TS))
    if [ \$ELAPSED -ge $MAX_SEC ]; then
        echo \"\$(date) 10hr cap hit — stopping (iter=$ITER)\" >> \"$LOG_DIR/summary.txt\"
        break
    fi
    ITER=\$(($ITER + 1))
    LOG_FILE=\"$LOG_DIR/iter-\$(printf '%03d' \$ITER).log\"
    echo \"\$(date) iter=\$ITER (elapsed=\${ELAPSED}s / ${MAX_SEC}s) starting\" \
        >> \"$LOG_DIR/summary.txt\"
    xcodebuild test \
        -project DeviceTestApp/BASDeviceTest.xcodeproj \
        -scheme BASDeviceTestApp \
        -destination 'platform=iOS,id=$DEVICE_ID' \
        -testPlan Device2HrFuzz \
        -allowProvisioningUpdates \
        -skipPackagePluginValidation \
        > \"\$LOG_FILE\" 2>&1
    EXIT=\$?
    PASSED=\$(grep -c \"Test Case.*passed\" \"\$LOG_FILE\" || true)
    FAILED=\$(grep -c \"Test Case.*failed\" \"\$LOG_FILE\" || true)
    SKIPPED=\$(grep -c \"Test Case.*skipped\" \"\$LOG_FILE\" || true)
    TOTAL_PASSED=\$((TOTAL_PASSED + PASSED))
    TOTAL_FAILED=\$((TOTAL_FAILED + FAILED))
    TOTAL_SKIPPED=\$((TOTAL_SKIPPED + SKIPPED))
    echo \"\$(date) iter=\$ITER done exit=\$EXIT passed=\$PASSED failed=\$FAILED skipped=\$SKIPPED\" \
        >> \"$LOG_DIR/summary.txt\"
    if [ \$FAILED -gt 0 ] || [ \$EXIT -ne 0 ]; then
        echo \"\$(date) FAILURE detected — preserving log + stopping\" \
            >> \"$LOG_DIR/summary.txt\"
        echo \"see \$LOG_FILE for failure detail\" >> \"$LOG_DIR/summary.txt\"
        break
    fi
done
echo \"\" >> \"$LOG_DIR/summary.txt\"
echo \"FINAL at \$(date)\" >> \"$LOG_DIR/summary.txt\"
echo \"TOTAL: iter=$ITER passed=$TOTAL_PASSED failed=$TOTAL_FAILED skipped=$TOTAL_SKIPPED\" \
    >> \"$LOG_DIR/summary.txt\"
"
