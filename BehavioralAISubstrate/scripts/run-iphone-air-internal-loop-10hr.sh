#!/usr/bin/env bash
# chapter 一千零二十五 / M3895 — single-launch internal-loop endurance
#
# Sibling of scripts/run-iphone-air-10hr.sh。 Whereas that script does
# `xcodebuild test` PER iter (external loop with re-launches),this
# script does ONE xcodebuild test invocation,letting the test
# (BASChapter1025LongRunningEnduranceTests) run internally for 10hr。
#
# Trade-off vs external loop:
#   - PRO: single app launch on iPhone (no per-iter relaunch overhead)
#   - PRO: built-in thermal cooldown + adaptive scaling in-test
#   - PRO: detailed per-internal-iter logging tagged `internal-iter=N`
#   - CON: XCTest treats the run as ONE test (single pass/fail signal)
#   - MITIGATION: post-mortem `grep ch1025 internal-iter=N` isolates
#     any iter's behavior
#
# Usage:
#   BAS_INTERNAL_ITER_COUNT=100 BAS_INTERNAL_COOLDOWN_SEC=60 \
#       bash scripts/run-iphone-air-internal-loop-10hr.sh
#
# Detaches via python3 fork+setsid (same pattern as sibling script)。

set -uo pipefail

SUBSTRATE_DIR="/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate"
DEVICE_ID="9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6"
LOG_DIR="${BAS_DEVICE_LOG_DIR:-/tmp/ch1025-internal-loop-10hr}"

# Internal-loop env vars (passed through to test bundle)
export BAS_LONG_ENDURANCE_RUN="${BAS_LONG_ENDURANCE_RUN:-1}"
export BAS_INTERNAL_ITER_COUNT="${BAS_INTERNAL_ITER_COUNT:-100}"
export BAS_INTERNAL_COOLDOWN_SEC="${BAS_INTERNAL_COOLDOWN_SEC:-60}"
export BAS_INTERNAL_ADAPTIVE="${BAS_INTERNAL_ADAPTIVE:-1}"
export BAS_INTERNAL_MLX_PROMPTS="${BAS_INTERNAL_MLX_PROMPTS:-3}"

# xcodebuild test will spend the entire test method runtime in the
# internal loop。 No outer max-sec needed — test exits when its iter
# count completes。

mkdir -p "$LOG_DIR"

# Self-detach via python3 fork+setsid (same as sibling script)
if [ -z "${BAS_DETACHED:-}" ] && [ -z "${BAS_NO_DETACH:-}" ]; then
    export BAS_DETACHED=1
    DETACH_LOG="$LOG_DIR/detach-bootstrap.log"
    echo "$(date) [ch1025] self-detaching" > "$DETACH_LOG"
    echo "$(date) [ch1025] env: ITER=$BAS_INTERNAL_ITER_COUNT " \
        "COOLDOWN=$BAS_INTERNAL_COOLDOWN_SEC " \
        "ADAPTIVE=$BAS_INTERNAL_ADAPTIVE " \
        "MLX_PROMPTS=$BAS_INTERNAL_MLX_PROMPTS" >> "$DETACH_LOG"
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
    echo "$(date) [ch1025] detached PID=$PARENT_PID" >> "$DETACH_LOG"
    echo "═══════════════════════════════════════════════════════"
    echo "ch 1025 INTERNAL-LOOP endurance DETACHED"
    echo "  log dir:    $LOG_DIR"
    echo "  iter log:   tail -f $LOG_DIR/ch1025.log"
    echo "  summary:    grep 'ch1025 FINAL' $LOG_DIR/ch1025.log"
    echo "  per-iter:   grep 'ch1025 internal-iter=N' $LOG_DIR/ch1025.log"
    echo "  thermal:    grep 'ch1025.*thermal' $LOG_DIR/ch1025.log"
    echo "  stop early: pkill -f 'BASChapter1025LongRunning'"
    echo "═══════════════════════════════════════════════════════"
    exit 0
fi

# Caffeinate re-exec for Mac sleep prevention
if [ -z "${UNDER_CAFFEINATE:-}" ]; then
    export UNDER_CAFFEINATE=1
    exec caffeinate -dimsu "$0" "$@"
fi

cd "$SUBSTRATE_DIR"

echo "ch 1025 internal-loop endurance start $(date)" > "$LOG_DIR/summary.txt"
echo "device=$DEVICE_ID  internal-iter=$BAS_INTERNAL_ITER_COUNT" \
    >> "$LOG_DIR/summary.txt"

# Pre-warm xcodebuild build (so the long test starts with everything ready)
echo "$(date) pre-warming build" >> "$LOG_DIR/summary.txt"
xcodebuild build \
    -project DeviceTestApp/BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "platform=iOS,id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    -skipPackagePluginValidation \
    > "$LOG_DIR/prewarm.log" 2>&1
PREWARM_EXIT=$?
if [ $PREWARM_EXIT -ne 0 ]; then
    echo "$(date) pre-warm FAILED exit=$PREWARM_EXIT" \
        >> "$LOG_DIR/summary.txt"
    exit 1
fi
echo "$(date) pre-warm OK starting long test" \
    >> "$LOG_DIR/summary.txt"

# Single xcodebuild test invocation — the test method internal-loops
# for BAS_INTERNAL_ITER_COUNT × ~6min each = ~10hr total
xcodebuild test \
    -project DeviceTestApp/BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "platform=iOS,id=$DEVICE_ID" \
    -only-testing:BASDeviceTests/BASChapter1025LongRunningEnduranceTests/testSingleLaunchLongRunningEndurance \
    -allowProvisioningUpdates \
    -skipPackagePluginValidation \
    > "$LOG_DIR/ch1025.log" 2>&1
TEST_EXIT=$?

echo "$(date) test exited exit=$TEST_EXIT" >> "$LOG_DIR/summary.txt"
echo "FINAL:see ch1025.log for per-iter trajectory" \
    >> "$LOG_DIR/summary.txt"

# Extract FINAL summary line
grep "ch1025 FINAL" "$LOG_DIR/ch1025.log" >> "$LOG_DIR/summary.txt" || true
