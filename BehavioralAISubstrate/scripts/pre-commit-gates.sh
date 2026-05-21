#!/usr/bin/env bash
# scripts/pre-commit-gates.sh
# chapter 八百二十九 / M2797 — chained CI gate runner
#
# Runs the 3 substrate CI gates in sequence:
#   1. scripts/check_god_files.sh
#   2. scripts/check_sdk_import_boundaries.sh
#   3. scripts/check_substrate_residuals.sh
#
# Exit 0 iff all 3 gates pass。 Designed for use as a git
# pre-commit hook (install via `git config core.hooksPath
# .githooks`) or as a manual pre-commit/pre-push runner。
#
# Hosts dial individual gate strictness in their respective
# script files。 This wrapper just chains them。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

GATES=(
    "scripts/check_god_files.sh"
    "scripts/check_sdk_import_boundaries.sh"
    "scripts/check_substrate_residuals.sh"
)

failed=0
echo "=== Substrate CI gates ==="
for gate in "${GATES[@]}"; do
    if [[ ! -x "$gate" ]]; then
        echo "✗ MISSING/non-exec: $gate"
        failed=$((failed + 1))
        continue
    fi
    if bash "$gate" > /tmp/gate.out 2>&1; then
        # Show just the RESULT line
        result_line=$(grep "^RESULT" /tmp/gate.out | tail -1)
        echo "✓ $gate"
        echo "    ${result_line}"
    else
        echo "✗ FAILED: $gate"
        tail -10 /tmp/gate.out | sed 's/^/    /'
        failed=$((failed + 1))
    fi
done
rm -f /tmp/gate.out

echo ""
if (( failed > 0 )); then
    echo "RESULT: $failed/$(echo "${#GATES[@]}") gate(s) failed"
    exit 1
fi
echo "RESULT: all $(echo "${#GATES[@]}") gates passed"
exit 0
