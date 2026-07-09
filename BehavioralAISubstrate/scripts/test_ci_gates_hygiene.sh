#!/usr/bin/env bash
# audit tools-scripts LOW teeth — pins the two CI-gate script hygiene fixes:
#   (1) check_sdk_import_boundaries.sh catches the `import struct`/`@_exported` bypass
#   (2) pre-commit-gates.sh uses a per-run mktemp temp, not a shared /tmp/gate.out
# Run: bash scripts/test_ci_gates_hygiene.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."
fail=0

# 1. The import-boundary regex must catch the declaration-kind + @_exported bypass forms.
if ! bash scripts/check_sdk_import_boundaries.sh --self-test >/dev/null; then
    echo "FAIL: check_sdk_import_boundaries.sh --self-test (regex bypass not caught)"; fail=1
fi

# 2. pre-commit-gates.sh must allocate a per-run temp (mktemp) and carry no fixed /tmp/gate.out
#    literal in executable code (comment lines are excluded from the literal check).
if ! grep -q "mktemp" scripts/pre-commit-gates.sh; then
    echo "FAIL: pre-commit-gates.sh must use mktemp for its per-run gate output"; fail=1
fi
if grep -vE '^[[:space:]]*#' scripts/pre-commit-gates.sh | grep -q '/tmp/gate\.out'; then
    echo "FAIL: pre-commit-gates.sh still references a fixed /tmp/gate.out in code"; fail=1
fi

# 3. audit x-architecture LOW-7 completeness gate: every Sources/ module is classified, so the full
#    boundary check passes (an unclassified module would exit 1).
if ! bash scripts/check_sdk_import_boundaries.sh >/dev/null 2>&1; then
    echo "FAIL: check_sdk_import_boundaries.sh — an unclassified module or a real boundary violation"; fail=1
fi

# 4. audit x-architecture LOW-8: the god-file gate passes (stale pins removed, small files unpinned).
if ! bash scripts/check_god_files.sh >/dev/null 2>&1; then
    echo "FAIL: check_god_files.sh — a god-file exceeds its error threshold"; fail=1
fi

if (( fail == 0 )); then echo "CI-GATE HYGIENE PASS"; fi
exit "$fail"
