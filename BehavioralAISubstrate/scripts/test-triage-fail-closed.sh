#!/bin/bash
# Regression test for the triage adjudicator (audit H22 — RSI adjudicator fail-open).
# The triage script is the machine that decides "regression vs no regression" for the whole
# suite; if IT fail-opens, every other regression gets laundered into exit 0. This test pins
# the fail-closed behaviour so H22 can never silently reopen.
#
# Usage: scripts/test-triage-fail-closed.sh   (exit 0 = all cases pass)
set -u
cd "$(dirname "$0")/.." || exit 2
TRIAGE="scripts/triage-full-suite.sh"
fails=0

expect() {  # expect <case-name> <expected-exit> <logfile>
  local name="$1" want="$2" log="$3"
  bash "$TRIAGE" "$log" >/dev/null 2>&1
  local got=$?
  if [ "$got" != "$want" ]; then
    echo "FAIL [$name]: expected exit $want, got $got"; fails=$((fails+1))
  else
    echo "ok   [$name]: exit $got"
  fi
  rm -f "$log"
}

# H22 core: aggregate counts failures but NO failing suite extracts → must fail-closed (was exit 0).
L=$(mktemp); printf 'noise\nExecuted 5 tests, with 1 failure (0 unexpected) in 2.0 seconds\na failure in an unrecognized format\n' > "$L"
expect "fail-open-guard (unextractable failure)" 1 "$L"

# Regex breadth: a failing suite in a digit/underscore MODULE must be triaged (not dropped → laundered).
# It has no flake registry entry, so isolation would mark it a regression → exit 1.
L=$(mktemp); printf "Test Case '-[BAS_Core2Tests.FooBarZzzTests testX]' failed (1.0 seconds)\nExecuted 1 test, with 1 failure (0 unexpected) in 1.0 seconds\n" > "$L"
# (isolation re-runs swift test --filter FooBarZzzTests → 0 tests found → UNGROUNDED → fail-closed exit 1)
expect "digit/underscore module extracted + fail-closed" 1 "$L"

# Clean pass: 0 failures → exit 0 (must not regress into false-positive).
L=$(mktemp); printf 'Executed 100 tests, with 0 failures (0 unexpected) in 5.0 seconds\n' > "$L"
expect "clean pass" 0 "$L"

# No aggregate line at all (compile failure / crash-before-aggregate) → fail-closed (pre-existing guard).
L=$(mktemp); printf 'error: compile failed\n' > "$L"
expect "no aggregate line" 1 "$L"

if [ "$fails" -gt 0 ]; then echo "$fails case(s) FAILED"; exit 1; fi
echo "all triage fail-closed cases pass"
