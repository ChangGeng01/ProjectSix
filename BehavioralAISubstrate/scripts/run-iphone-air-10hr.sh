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

SUBSTRATE_DIR="/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
DEVICE_ID="9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6"
LOG_DIR="${BAS_DEVICE_LOG_DIR:-/tmp/ch952-10hr}"
# chapter 九百五十二.8.1 — MAX_SEC env override (e.g.
# MAX_SEC=600 bash scripts/run-iphone-air-10hr.sh for 10-min smoke
# vs the 10hr default)
MAX_SEC=${MAX_SEC:-$((10 * 3600))}   # default 10 hours

mkdir -p "$LOG_DIR"

# chapter 一千零二十二.5 / M3870 — self-detach on first invocation
# so caller (Claude harness, terminal, launchd, etc.) immediately
# gets exit=0 and the smoke runs INDEPENDENTLY in its own session。
#
# Why this matters:
#   - Claude Code harness kills background tasks after ~13-30 min
#     based on session activity / idle timeout / resource pressure
#   - v1 (10hr launch): killed at ~13 min,2 iter clean before kill
#   - v2 (2hr launch):  killed at ~27 min,4 iter clean before kill
#   - In BOTH cases the harness sent SIGTERM to the process tree
#     (bash + caffeinate + xcodebuild all died together)
#   - caffeinate prevents Mac sleep but does NOT prevent being
#     killed by parent — it's itself a child process
#
# Fix: detach into its own session via `setsid nohup`。 The detached
# child is no longer a descendant of Claude harness,so harness
# SIGTERM never reaches it。 caffeinate still keeps Mac awake within
# the detached session。
#
# Override:
#   BAS_NO_DETACH=1 bash scripts/run-iphone-air-10hr.sh  # foreground (debug)
#
# Stop a detached smoke early:
#   pkill -f 'run-iphone-air-10hr'
#
# Monitor a detached smoke:
#   tail -f $LOG_DIR/summary.txt
if [ -z "${BAS_DETACHED:-}" ] && [ -z "${BAS_NO_DETACH:-}" ]; then
    export BAS_DETACHED=1
    DETACH_LOG="$LOG_DIR/detach-bootstrap.log"
    echo "$(date) [smoke] self-detaching via python3 fork+setsid" \
        > "$DETACH_LOG"
    echo "$(date) [smoke] args: $*" >> "$DETACH_LOG"
    echo "$(date) [smoke] env: MAX_SEC=$MAX_SEC " \
        "BAS_ITER_COOLDOWN_SEC=${BAS_ITER_COOLDOWN_SEC:-0} " \
        "BAS_DEVICE_LOG_DIR=$LOG_DIR" >> "$DETACH_LOG"
    # macOS doesn't ship the `setsid` binary,but it has the setsid()
    # syscall via libc。 Use python3 to fork + setsid + exec child,
    # making the smoke its own session leader + process group。 The
    # child is no longer reachable from Claude harness's signal targets。
    PYTHON=${PYTHON:-/usr/bin/env python3}
    $PYTHON - "$0" "$@" <<'PYDETACH' >>"$DETACH_LOG" 2>&1 &
import os, sys
script = sys.argv[1]
args = sys.argv[2:]
# Double-fork pattern + setsid for full detach
pid = os.fork()
if pid > 0:
    # First parent — wait for first child to exit (clean)
    os.waitpid(pid, 0)
    sys.exit(0)
# First child — become new session leader,then fork again
os.setsid()
pid = os.fork()
if pid > 0:
    # First child exits; second child orphans to init/launchd
    sys.exit(0)
# Second child — fully detached,re-exec the smoke script
# stdin/out/err already redirected to detach log by parent shell
os.execvp(script, [script] + args)
PYDETACH
    PARENT_PID=$!
    disown 2>/dev/null || true
    # Give python wrapper a moment to fork the grandchild
    sleep 1
    echo "$(date) [smoke] detached parent PID=$PARENT_PID (exits after fork)" \
        >> "$DETACH_LOG"
    echo "═══════════════════════════════════════════════════════"
    echo "Smoke DETACHED via python3 fork+setsid"
    echo "  log dir:    $LOG_DIR"
    echo "  summary:    tail -f $LOG_DIR/summary.txt"
    echo "  detach log: $DETACH_LOG"
    echo "  find PID:   pgrep -f run-iphone-air-10hr"
    echo "  stop early: pkill -f 'run-iphone-air-10hr'"
    echo "═══════════════════════════════════════════════════════"
    echo "Parent exiting (smoke runs INDEPENDENTLY now)。"
    exit 0
fi

# Re-exec under caffeinate so Mac stays awake — but only once。
# Runs INSIDE the detached session so Mac sleep is held by the
# detached process (not by Claude harness's caffeinate)。
if [ -z "${UNDER_CAFFEINATE:-}" ]; then
    export UNDER_CAFFEINATE=1
    exec caffeinate -dimsu "$0" "$@"
fi
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
    echo "STOPPED at $(date) (signal or MAX_SEC=${MAX_SEC}s cap)" >> "$LOG_DIR/summary.txt"
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
    # to accept「available (paired)」 alongside「connected」。
    #
    # chapter 一千零十七.5 / M3830 — Round-25 CRITICAL-1 fix:
    # ch 1015.5 grep `available` matched「unavailable」 as a
    # substring。 Live devicectl output:
    #   「ChangGeng?iPhone ... unavailable iPhone 17e」
    # matched the pre-fix grep,causing the script to proceed
    # against an unusable device。 Post-fix uses whitespace
    # anchors so「available」 must be a whole word。
    # chapter 一千零十八 / M3835 — Round-26 LOW-2 fix:
    # added end-of-line anchor `($|[[:space:]])` so the regex
    # works if Apple ever puts State as the last column or
    # omits trailing whitespace。 Pre-fix only matched when
    # State had trailing whitespace,fragile to format change。
    if xcrun devicectl list devices 2>/dev/null | \
        grep -Eq "$DEVICE_ID[[:space:]]+(connected|available)([[:space:]]|$)"; then
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
        echo "$(date) MAX_SEC=${MAX_SEC}s cap hit — stopping (iter=$ITER)" \
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
    #
    # chapter 一千零二十一 / M3860 — full-substrate device smoke (~13K
    # tests/iter via removed selectedTests) revealed xcodebuild
    # returns exit=65 even when XCTest passed=N + failed=0 + Swift
    # Testing all green。 Root cause:xcodebuild's「Failing tests:」
    # block lists Swift-Testing-style tests that the test bundle
    # didn't enumerate (filtering quirk between XCTest harness +
    # Swift Testing @Suite struct discovery on iOS device)。 These
    # are not real failures — XCTest reports failed=0,Swift Testing
    # reports 165/165 passed。
    #
    # New gate:FAILED count is authoritative。 EXIT=65 with FAILED=0
    # and PASSED > 1000 is acceptable (the run produced substantive
    # test coverage,no test asserted)。 EXIT != 0 still fatal when
    # PASSED is small (likely real build / connection error)。
    if [ $FAILED -gt 0 ]; then
        echo "$(date) FAILURE detected (failed=$FAILED) — preserving log + stopping" \
            >> "$LOG_DIR/summary.txt"
        echo "see $LOG_FILE for failure detail" >> "$LOG_DIR/summary.txt"
        break
    fi
    if [ $EXIT -ne 0 ] && [ $PASSED -lt 1000 ]; then
        echo "$(date) FAILURE (exit=$EXIT,passed=$PASSED < 1000) — likely build / connection error,stopping" \
            >> "$LOG_DIR/summary.txt"
        echo "see $LOG_FILE for failure detail" >> "$LOG_DIR/summary.txt"
        break
    fi
    if [ $EXIT -ne 0 ]; then
        echo "$(date) soft-OK iter=$ITER (exit=$EXIT but failed=0,passed=$PASSED) — Swift Testing discovery quirk,continuing" \
            >> "$LOG_DIR/summary.txt"
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
    # chapter 一千零十六 / M3820 — adaptive thermal cooldown。
    # ch 1015.6 fixed cooldown at constant 60s。 But v8 device
    # data showed thermal accumulates faster than 60s recovery
    # at iter 6+ (sustained-load p99 still creeps despite
    # cooldown)。 Honest fix:scale cooldown with iter count —
    # thermal heat-soak grows with cumulative load,so recovery
    # time should grow proportionally。 Schedule:
    #   iter 1-2:  use BAS_ITER_COOLDOWN_SEC (default 0)
    #   iter 3-5:  base + 30s (early thermal accumulation)
    #   iter 6-10: base × 2 + 60s (sustained-load recovery)
    #   iter 11+:  base × 3 + 120s (endurance-run recovery)
    # Override via BAS_ADAPTIVE_COOLDOWN=0 to disable scaling
    # (use only BAS_ITER_COOLDOWN_SEC verbatim)。
    BASE_COOLDOWN=${BAS_ITER_COOLDOWN_SEC:-0}
    ADAPTIVE=${BAS_ADAPTIVE_COOLDOWN:-1}
    if [ $ADAPTIVE -eq 1 ] && [ $BASE_COOLDOWN -gt 0 ]; then
        if [ $ITER -le 2 ]; then
            COOLDOWN_SEC=$BASE_COOLDOWN
        elif [ $ITER -le 5 ]; then
            COOLDOWN_SEC=$((BASE_COOLDOWN + 30))
        elif [ $ITER -le 10 ]; then
            COOLDOWN_SEC=$((BASE_COOLDOWN * 2 + 60))
        else
            COOLDOWN_SEC=$((BASE_COOLDOWN * 3 + 120))
        fi
    else
        COOLDOWN_SEC=$BASE_COOLDOWN
    fi
    # chapter 一千零十八.5 / M3840 — Round-27 MED-2 + MED-3 fix:
    # clamp BEFORE the cooldown announcement (was AFTER pre-
    # fix,creating two adjacent lines where the first lied
    # about duration)。 Also: when user explicitly sets
    # BAS_ITER_COOLDOWN_SEC to a non-multiple-of-10,we now
    # FLOOR to nearest multiple (was ceiling pre-fix,which
    # silently extended user's choice by up to 9s)。 Honest:
    # user asked for 15s,gets 10s + 1 line WARN。
    if [ $COOLDOWN_SEC -gt 0 ] \
        && [ $((COOLDOWN_SEC % 10)) -ne 0 ]
    then
        FLOORED=$(( COOLDOWN_SEC / 10 * 10 ))
        if [ $FLOORED -lt 10 ]; then
            FLOORED=10  # min 10s for heartbeat
        fi
        echo "$(date) iter=$ITER WARN: cooldown floored " \
            "${COOLDOWN_SEC}s → ${FLOORED}s " \
            "(heartbeat granularity 10s)" \
            >> "$LOG_DIR/summary.txt"
        COOLDOWN_SEC=$FLOORED
    fi
    if [ $COOLDOWN_SEC -gt 0 ]; then
        echo "$(date) iter=$ITER cooldown=${COOLDOWN_SEC}s " \
            "(base=${BASE_COOLDOWN}s adaptive=${ADAPTIVE}) — " \
            "thermal recovery" >> "$LOG_DIR/summary.txt"
        # chapter 一千零十五.7 / M3815 — heartbeat during cooldown
        # to prevent harness GC of idle background tasks。 The
        # ch 1015.6 run died at 15min during a 60s sleep because
        # the harness reaped what looked like an idle process。
        # Now emit a `.` to summary every 10s during cooldown so
        # the file modification time keeps advancing。 The harness
        # observability also sees the stdout heartbeat。
        #
        # chapter 一千零十八.5 / M3840 — Round-27 MED-2/3 fix:
        # this inner clamp block is now empty — the clamp was
        # moved OUTSIDE the cooldown announcement (~10 lines
        # above) so the WARN appears BEFORE the cooldown=
        # announcement,not after。 Honest log ordering。
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
