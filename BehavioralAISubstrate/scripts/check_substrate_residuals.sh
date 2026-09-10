#!/usr/bin/env bash
# scripts/check_substrate_residuals.sh
# NAME-COLLISION NOTE (2026-07-12): this BAS-side script is the residuals GATE
# (print()-count + density; called by pre-commit-gates.sh). The parent repo's
# scripts/check_substrate_residuals.sh is a DIFFERENT check (residual-MARKER regex
# scan). Same filename, different jobs — compare like with like when triaging.
# chapter 八百二十三 / M2768 — restored CI gate referenced in
# wild-rolling-meerkat plan。
#
# Scans the codebase for residual / stale patterns that
# indicate work-in-progress markers leaking into committed code:
#
#   1. TODO / FIXME / XXX / HACK markers in PRODUCTION code
#      (Sources/) — tolerated up to a threshold,fails if too many
#   2. `print()` statements in production code (often debug
#      leftovers) — usually means missing logger plumbing
#   3. Force-unwrap (!) density (informational only)
#
# Thresholds are intentionally lax — this is an observability
# gate,not a quality bar。 Hosts can dial thresholds per arc by
# editing this script。
#
# Bash 3.2 compatible。 Uses `|| true` after greps to avoid set-e
# abort when a pattern matches zero files (grep exits 1 in that case)。
#
# Exit codes:
#   0 = within all thresholds
#   1 = at least one threshold exceeded

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Thresholds (per-arc dial)
MAX_TODO_PER_KLOC=2          # TODO/FIXME/XXX/HACK per 1000 LOC
MAX_PRODUCTION_PRINT=10       # print() statements in Sources/
WARN_FORCE_UNWRAP_DENSE=50    # informational only

# Helper: sum numeric column 2 of grep -c output, return 0 on no matches
count_matches() {
    local pattern="$1"
    shift
    local result
    result=$(grep -rEc "$pattern" "$@" 2>/dev/null \
        | awk -F: 'BEGIN { s=0 } { s += $2 } END { print s }')
    echo "${result:-0}"
}

# CLI/executable directories — legitimately use print() for stdout
# These are EXCLUDED from the print() check。
EXCLUDED_DIRS_PRINT_CHECK=(
    "Sources/BASBrainCLI"
    "Sources/BASJournalCLI"   # The Ledger CLI executable (2026-07 增) — stdout print() is its output, like BASBrainCLI
)

# Build find expression to exclude CLI dirs from print check
build_print_check_dirs() {
    local dirs=()
    while IFS= read -r d; do
        local skip=0
        for ex in "${EXCLUDED_DIRS_PRINT_CHECK[@]}"; do
            if [[ "$d" == "$ex" ]]; then
                skip=1
                break
            fi
        done
        if (( skip == 0 )); then
            dirs+=("$d")
        fi
    done < <(find Sources -mindepth 1 -maxdepth 1 -type d)
    echo "${dirs[@]}"
}

# 1. TODO-style markers
todo_count=$(count_matches "// *(TODO|FIXME|XXX|HACK)" Sources/ --include="*.swift")
total_loc=$(find Sources -name "*.swift" -type f -exec wc -l {} \; 2>/dev/null \
    | awk 'BEGIN { s=0 } { s += $1 } END { print s }')
total_loc="${total_loc:-0}"
if (( total_loc > 0 )); then
    todo_per_kloc=$(awk -v t="$todo_count" -v l="$total_loc" \
        'BEGIN { printf "%.2f", (t * 1000.0 / l) }')
else
    todo_per_kloc="0.00"
fi

echo "TODO/FIXME/XXX/HACK markers in Sources/: $todo_count"
echo "  Sources LOC: $total_loc"
echo "  Density: $todo_per_kloc per 1000 LOC (threshold: $MAX_TODO_PER_KLOC)"

# 2. print() statements in production (excluding CLI executables)
print_search_dirs=$(build_print_check_dirs)
# shellcheck disable=SC2086  # unquoted expansion intentional
print_count=$(count_matches "^[[:space:]]*print\\(" $print_search_dirs --include="*.swift")
echo ""
echo "print() statements in Sources/ (excluding CLI executables): $print_count (threshold: $MAX_PRODUCTION_PRINT)"
echo "  Excluded:${EXCLUDED_DIRS_PRINT_CHECK[*]} (legitimate stdout consumers)"

# 3. Force-unwrap density (informational)
force_unwrap_count=$(count_matches "[a-zA-Z_)]![^=]" Sources/ --include="*.swift")
if (( total_loc > 0 )); then
    fu_per_kloc=$(awk -v t="$force_unwrap_count" -v l="$total_loc" \
        'BEGIN { printf "%.2f", (t * 1000.0 / l) }')
else
    fu_per_kloc="0.00"
fi
echo ""
echo "Force-unwrap (!) sites in Sources/: $force_unwrap_count"
echo "  Density: $fu_per_kloc per 1000 LOC (informational,warn at: $WARN_FORCE_UNWRAP_DENSE)"

# Verdict
echo ""
failed=0
threshold_check=$(awk -v t="$todo_per_kloc" -v m="$MAX_TODO_PER_KLOC" \
    'BEGIN { print (t > m) ? "1" : "0" }')
if [[ "$threshold_check" == "1" ]]; then
    echo "ERROR: TODO density $todo_per_kloc exceeds threshold $MAX_TODO_PER_KLOC per 1000 LOC"
    failed=$((failed + 1))
fi
if (( print_count > MAX_PRODUCTION_PRINT )); then
    echo "ERROR: $print_count print() statements > threshold $MAX_PRODUCTION_PRINT"
    failed=$((failed + 1))
fi

if (( failed > 0 )); then
    echo "RESULT: substrate residuals gate FAILED ($failed threshold(s) exceeded)"
    exit 1
fi
echo "RESULT: substrate residuals gate clean"
exit 0
