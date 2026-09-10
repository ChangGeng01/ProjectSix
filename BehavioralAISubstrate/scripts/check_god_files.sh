#!/usr/bin/env bash
# scripts/check_god_files.sh
# chapter 八百二十三 / M2766 — restored CI gate referenced in
# wild-rolling-meerkat plan (chapter 七百五十七 god-files gate fix)。
#
# Enforces per-file LOC ceilings for Swift sources under Sources/。
# Files exceeding their pinned ceiling fail the gate;files
# exceeding the default warn threshold print a warning。
#
# ## Pinned overrides
#
# Each pin is `<relative_path_to_Sources_file>|<max_loc>|<reason>`。
# Pin files when their growth is structural (registries /
# generated data / large enums) rather than a code-organization
# smell。 When pinning,add a justification comment so future
# maintainers can revisit。
#
# ## Defaults
#
# Files NOT in the pin list:
#   - WARNING if > 1500 LOC (might benefit from extraction)
#   - ERROR   if > 3000 LOC (almost certainly should be split)
#
# Exit codes:
#   0 = all files within ceilings
#   1 = at least one file exceeds its pinned ceiling OR default error
#   (warnings do NOT change exit code — informational only)
#
# Bash 3.2 compatible (macOS default) — uses positional arrays + helper fns。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

DEFAULT_WARN=1500
DEFAULT_ERROR=3000

# --- Pinned overrides ---
# Format: each entry is "relative_path|max_loc|justification"
PINS=(
    # chapter 八百二十七 / M2786-M2790 — 3 former god-files archived
    # to Archive/Deactivated/Sources/BASRuntimeCore/*_LegacyBlock.txt:
    #   - BASChapterDoctrineRegistry.swift:        25,215 → 178 LOC
    #   - BASEntropyChapterIndex.swift:             7,276 → 310 LOC
    #   - BASChapterDoctrineRegistry+AllLiterals:   3,940 →  62 LOC
    # All three now fall under the default warn threshold;no pin needed。
    # audit x-architecture LOW-8: three MORE pins removed as stale — the files have since shrunk far
    # below the default warn threshold, so their generous pins masked the real (small) size:
    #   - BASCognitiveBrain.swift:      pinned 4500 → actual 661 LOC
    #   - BASAutoRouteRanker.swift:     pinned 4000 → actual 502 LOC
    #   - BASMemoryUsageTracker.swift:  pinned 3000 → actual 297 LOC
    # Only the genuinely-large L7 dissection core remains pinned.
    "Sources/BASOrchestration/EBrainL7MirrorBladeDecomposeCore.swift|3000|L7 whitepaper-literal §5 dissection frame + 14 typed structs"
)

# Look up pin limit for a path — returns "limit|reason" or empty
lookup_pin() {
    local path="$1"
    local entry
    for entry in "${PINS[@]}"; do
        local p="${entry%%|*}"
        if [[ "$p" == "$path" ]]; then
            # Strip the path prefix to leave "limit|reason"
            echo "${entry#*|}"
            return
        fi
    done
}

failed=0
warned=0

while IFS= read -r -d '' file; do
    loc=$(wc -l < "$file" | tr -d ' ')
    rel="${file#./}"
    pin=$(lookup_pin "$rel")
    if [[ -n "$pin" ]]; then
        limit="${pin%%|*}"
        reason="${pin#*|}"
        if (( loc > limit )); then
            echo "ERROR: $rel = $loc LOC > pinned ceiling $limit"
            echo "  Reason for pin: $reason"
            echo "  Either:(a) split the file,or (b) update the pin with fresh justification"
            failed=$((failed + 1))
        fi
    else
        if (( loc > DEFAULT_ERROR )); then
            echo "ERROR: $rel = $loc LOC > default error threshold $DEFAULT_ERROR"
            echo "  Either:(a) split the file,or (b) add a pin to check_god_files.sh with justification"
            failed=$((failed + 1))
        elif (( loc > DEFAULT_WARN )); then
            echo "WARN:  $rel = $loc LOC > default warn threshold $DEFAULT_WARN"
            warned=$((warned + 1))
        fi
    fi
done < <(find Sources -name "*.swift" -type f -print0)

echo ""
if (( failed > 0 )); then
    echo "RESULT: $failed god-file gate violation(s),$warned warning(s)"
    exit 1
fi
echo "RESULT: god-file gate clean,$warned file(s) over warn threshold (informational)"
exit 0
