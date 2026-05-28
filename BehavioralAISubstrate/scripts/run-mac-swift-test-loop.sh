#!/usr/bin/env bash
# chapter 一千零二十二.5 / M3870 — Mac swift test loop wrapper
#
# Sibling of scripts/run-iphone-air-10hr.sh — runs `swift test`
# (full substrate ~26000+ tests INCLUDING Cognitive Brain / Rust
# bridges / Swift Testing @Suite / audit / etc.) in a 2-hour loop。
#
# Why this exists:
#   - iPhone Air device smoke source-gates ~146 test classes (Rust
#     dylib infra gap,Swift Testing @Suite iOS quirk,Mac dev tree
#     audits,etc.)
#   - To run THE ENTIRE substrate end-to-end,we ALSO need to loop
#     `swift test` on Mac (which compiles + runs all classes)
#   - This script + the iPhone Air smoke together = full substrate
#     coverage on real hardware
#
# Usage:
#   MAX_SEC=7200 bash scripts/run-mac-swift-test-loop.sh
#
# Detach:same python3 fork+setsid pattern as iPhone Air smoke。
# Override:BAS_NO_DETACH=1 to skip detach (foreground debug)。
#
# Stop early:pkill -f 'run-mac-swift-test-loop'

set -uo pipefail

SUBSTRATE_DIR="/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
LOG_DIR="${BAS_MAC_LOG_DIR:-/tmp/ch1022-mac-loop}"
MAX_SEC=${MAX_SEC:-$((2 * 3600))}   # default 2 hours

mkdir -p "$LOG_DIR"

# Self-detach on first invocation (same pattern as iPhone Air smoke)
if [ -z "${BAS_DETACHED:-}" ] && [ -z "${BAS_NO_DETACH:-}" ]; then
    export BAS_DETACHED=1
    DETACH_LOG="$LOG_DIR/detach-bootstrap.log"
    echo "$(date) [mac-loop] self-detaching via python3 fork+setsid" \
        > "$DETACH_LOG"
    echo "$(date) [mac-loop] args: $*" >> "$DETACH_LOG"
    echo "$(date) [mac-loop] env: MAX_SEC=$MAX_SEC " \
        "BAS_MAC_LOG_DIR=$LOG_DIR" >> "$DETACH_LOG"
    PYTHON=${PYTHON:-/usr/bin/env python3}
    $PYTHON - "$0" "$@" <<'PYDETACH' >>"$DETACH_LOG" 2>&1 &
import os, sys
script = sys.argv[1]
args = sys.argv[2:]
pid = os.fork()
if pid > 0:
    os.waitpid(pid, 0)
    sys.exit(0)
os.setsid()
pid = os.fork()
if pid > 0:
    sys.exit(0)
os.execvp(script, [script] + args)
PYDETACH
    PARENT_PID=$!
    disown 2>/dev/null || true
    sleep 1
    echo "$(date) [mac-loop] detached parent PID=$PARENT_PID" >> "$DETACH_LOG"
    echo "═══════════════════════════════════════════════════════"
    echo "Mac swift test loop DETACHED via python3 fork+setsid"
    echo "  log dir:    $LOG_DIR"
    echo "  summary:    tail -f $LOG_DIR/summary.txt"
    echo "  detach log: $DETACH_LOG"
    echo "  find PID:   pgrep -f run-mac-swift-test-loop"
    echo "  stop early: pkill -f 'run-mac-swift-test-loop'"
    echo "═══════════════════════════════════════════════════════"
    echo "Parent exiting (loop runs INDEPENDENTLY now)。"
    exit 0
fi

# Re-exec under caffeinate so Mac stays awake during long loops。
# Caffeinate inside detached session keeps Mac awake regardless of
# Claude session state。
if [ -z "${UNDER_CAFFEINATE:-}" ]; then
    export UNDER_CAFFEINATE=1
    exec caffeinate -dimsu "$0" "$@"
fi

echo "ch1022.5 Mac swift test loop starting at $(date)" > "$LOG_DIR/summary.txt"
echo "max_sec=$MAX_SEC  pid=$$" >> "$LOG_DIR/summary.txt"
echo "" >> "$LOG_DIR/summary.txt"

START_TS=$(date +%s)
ITER=0
TOTAL_PASSED=0
TOTAL_FAILED=0

cleanup() {
    echo "" >> "$LOG_DIR/summary.txt"
    echo "STOPPED at $(date) (signal or MAX_SEC cap)" >> "$LOG_DIR/summary.txt"
    echo "TOTAL: iter=$ITER passed=$TOTAL_PASSED failed=$TOTAL_FAILED" \
        >> "$LOG_DIR/summary.txt"
    exit 0
}
trap cleanup INT TERM

cd "$SUBSTRATE_DIR"

while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TS))
    if [ $ELAPSED -ge $MAX_SEC ]; then
        echo "$(date) MAX_SEC cap hit at iter=$ITER,stopping" \
            >> "$LOG_DIR/summary.txt"
        break
    fi
    ITER=$((ITER + 1))
    LOG_FILE="$LOG_DIR/iter-$(printf '%03d' $ITER).log"
    echo "$(date) iter=$ITER (elapsed=${ELAPSED}s / ${MAX_SEC}s) starting" \
        >> "$LOG_DIR/summary.txt"

    # Run swift test (full substrate)。
    # BAS_FUZZ_RUNTIME_SKIP=1 keeps the heavy runtime-spinning fuzz
    # tests from running EVERY iter — those are device-budget shapes,
    # not Mac iter-loop shapes。 Mac loop focuses on breadth coverage。
    BAS_FUZZ_RUNTIME_SKIP=1 swift test 2>&1 > "$LOG_FILE"
    EXIT=$?
    PASSED=$(grep -cE "Test Case.*passed" "$LOG_FILE" || true)
    FAILED=$(grep -cE "Test Case.*failed" "$LOG_FILE" || true)
    # Swift Testing format: "✔ Test ..."  /  "✘ Test ..."
    ST_PASSED=$(grep -cE "✔ Test " "$LOG_FILE" || true)
    ST_FAILED=$(grep -cE "✘ Test " "$LOG_FILE" || true)
    PASSED=$((PASSED + ST_PASSED))
    FAILED=$((FAILED + ST_FAILED))
    TOTAL_PASSED=$((TOTAL_PASSED + PASSED))
    TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
    echo "$(date) iter=$ITER done exit=$EXIT passed=$PASSED failed=$FAILED" \
        >> "$LOG_DIR/summary.txt"

    if [ $FAILED -gt 0 ]; then
        echo "$(date) FAILURE detected (failed=$FAILED) — preserving log + stopping" \
            >> "$LOG_DIR/summary.txt"
        echo "see $LOG_FILE for failure detail" >> "$LOG_DIR/summary.txt"
        break
    fi
    if [ $EXIT -ne 0 ] && [ $PASSED -lt 100 ]; then
        echo "$(date) FAILURE (exit=$EXIT passed=$PASSED < 100) — likely build error,stopping" \
            >> "$LOG_DIR/summary.txt"
        break
    fi

    # No cooldown for Mac loop — Mac doesn't thermal-throttle the
    # same way iPhone Air does。 5s breather between iters。
    sleep 5
done

echo "" >> "$LOG_DIR/summary.txt"
echo "FINAL at $(date)" >> "$LOG_DIR/summary.txt"
echo "TOTAL: iter=$ITER passed=$TOTAL_PASSED failed=$TOTAL_FAILED" \
    >> "$LOG_DIR/summary.txt"
