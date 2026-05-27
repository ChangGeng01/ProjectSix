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
    # chapter 一千零十五.5 / M3805 — device-state grep widened
    # to accept「available (paired)」 alongside「connected」。 The
    # latter is the older devicectl status string;newer Xcode
    # tools report「available (paired)」 for the same usable
    # state。 Pre-fix the script bailed instantly with
    # DEVICE_DISCONNECTED when iPhone Air was actually fine,
    # just reported with the newer label。
    if xcrun devicectl list devices 2>/dev/null | \
        grep -q "$DEVICE_ID.*\(connected\|available\)"; then
        return 0
    fi
    return 1
}

# chapter 一千零十五.6 / M3810 — pre-warm xcodebuild build to
# materialize SwiftPM plugin outputs (BASSQLSchemaGen) BEFORE
# the test loop。 Pre-fix:cold DerivedData caused xcodebuild
# test to fail-fast on missing plugin-generated files at iter 1
# (race between plugin command emission + Swift input-dependency
# check)。 Post-fix:one-time build runs the plugin,materializes
# the .generated.swift files into DerivedData,then test iters
# find them as cached inputs。 Opt out via BAS_SKIP_PREWARM=1。
if [ -z "${BAS_SKIP_PREWARM:-}" ]; then
    echo "$(date) pre-warming xcodebuild build (plugin materialize)" \
        >> "$LOG_DIR/summary.txt"
    PREWARM_LOG="$LOG_DIR/prewarm.log"
    xcodebuild build \
        -project DeviceTestApp/BASDeviceTest.xcodeproj \
        -scheme BASDeviceTestApp \
        -destination "platform=iOS,id=$DEVICE_ID" \
        -allowProvisioningUpdates \
        -skipPackagePluginValidation \
        > "$PREWARM_LOG" 2>&1
    PREWARM_EXIT=$?
    if [ $PREWARM_EXIT -ne 0 ]; then
        echo "$(date) pre-warm FAILED (exit=$PREWARM_EXIT) — " \
            "see $PREWARM_LOG。 Stopping before iter loop。" \
            >> "$LOG_DIR/summary.txt"
        exit 1
    fi
    echo "$(date) pre-warm OK — starting iter loop" \
        >> "$LOG_DIR/summary.txt"
fi

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
    # chapter 一千零十五.6 / M3810 — per-iter cooldown to let
    # iPhone Air A19 thermal envelope recover between sustained-
    # MLX-load iterations。 ch 1015.5 device-test run (iter 7)
    # tripped the Gemma 4 E2B p99 latency ceiling (21.07s vs 20s)
    # after ~25 min cumulative MLX load due to thermal throttling
    # — not a substrate regression but a real thermal effect。
    # Setting BAS_ITER_COOLDOWN_SEC=N inserts a sleep N between
    # iterations so thermal can recover。 Default 0 preserves
    # prior behavior (zero cooldown,thermal will trip ~iter 7
    # under sustained load)。
    COOLDOWN_SEC=${BAS_ITER_COOLDOWN_SEC:-0}
    if [ $COOLDOWN_SEC -gt 0 ]; then
        echo "$(date) iter=$ITER cooldown=${COOLDOWN_SEC}s — " \
            "thermal recovery" >> "$LOG_DIR/summary.txt"
        # chapter 一千零十五.7 / M3815 — heartbeat during cooldown
        # to prevent harness GC of idle background tasks。 The
        # ch 1015.6 run died at 15min during a 60s sleep because
        # the harness reaped what looked like an idle process。
        # Now emit a `.` to summary every 10s during cooldown so
        # the file modification time keeps advancing。 The harness
        # observability also sees the stdout heartbeat。
        ELAPSED_COOL=0
        while [ $ELAPSED_COOL -lt $COOLDOWN_SEC ]; do
            sleep 10
            ELAPSED_COOL=$((ELAPSED_COOL + 10))
            echo "$(date) iter=$ITER cooldown-heartbeat " \
                "${ELAPSED_COOL}s/${COOLDOWN_SEC}s" \
                >> "$LOG_DIR/summary.txt"
        done
    fi
done

echo "" >> "$LOG_DIR/summary.txt"
echo "FINAL at $(date)" >> "$LOG_DIR/summary.txt"
echo "TOTAL: iter=$ITER passed=$TOTAL_PASSED failed=$TOTAL_FAILED skipped=$TOTAL_SKIPPED" \
    >> "$LOG_DIR/summary.txt"
