#!/usr/bin/env bash
# scripts/check_sdk_import_boundaries.sh
# chapter 八百二十三 / M2767 — restored CI gate referenced in
# wild-rolling-meerkat plan。
#
# Enforces the substrate ↔ SDK-consumer import direction:
#
#   SDK CONSUMERS (BASHostKit / BASAppleAdapters / BASBrainCLI /
#   BASChatCompletionsAdapter / BASMLXAdapter) MAY import any
#   substrate module。
#
#   SUBSTRATE CORE (BASRuntimeCore / BASMemory / BASPolicy /
#   BASOrchestration / BASObservability / BASEvaluation /
#   BASSovereign / BASWorldPrior / BASLeaseLife / BASOrgan /
#   BASCSystemBridge / BASSQLSchemaGen*) MUST NOT import any
#   SDK consumer module。
#
# Why:reversed-imports create dependency cycles + drag SDK
# consumer concerns into substrate core,breaking the「substrate
# is reusable façade for any host」 design intent。
#
# Exit codes:
#   0 = no boundary violations found
#   1 = at least one substrate-core file imports an SDK consumer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# SDK consumer modules — substrate core MUST NOT import these
declare -a SDK_CONSUMERS=(
    "BASHostKit"
    "BASAppleAdapters"
    "BASBrainCLI"
    "BASChatCompletionsAdapter"
    "BASMLXAdapter"
    "BASMetalSubstrate"
    "BASMPSGraphExecutableCacheCxx"
)

# Substrate core modules — these are checked for forbidden imports
declare -a SUBSTRATE_CORE=(
    "BASRuntimeCore"
    "BASMemory"
    "BASPolicy"
    "BASOrchestration"
    "BASObservability"
    "BASEvaluation"
    "BASSovereign"
    "BASWorldPrior"
    "BASLeaseLife"
    "BASOrgan"
    "BASCSystemBridge"
    "BASSQLSchemaGenCore"
    "BASSQLSchemaGenTool"
    "BASRustCoreBridge"
    "BASAdmin"
)

# Build forbidden-pattern regex (one alternation per SDK consumer)
forbidden_pattern=""
for c in "${SDK_CONSUMERS[@]}"; do
    if [[ -z "$forbidden_pattern" ]]; then
        forbidden_pattern="^import ${c}\\b"
    else
        forbidden_pattern="${forbidden_pattern}|^import ${c}\\b"
    fi
done

violations=0
for module in "${SUBSTRATE_CORE[@]}"; do
    src_dir="Sources/${module}"
    if [[ ! -d "$src_dir" ]]; then
        continue
    fi
    # grep for `import <SDK consumer>` at line start, ignore @testable
    while IFS= read -r match; do
        if [[ -n "$match" ]]; then
            echo "BOUNDARY VIOLATION: $match"
            violations=$((violations + 1))
        fi
    done < <(grep -rnE "$forbidden_pattern" "$src_dir" --include="*.swift" 2>/dev/null || true)
done

echo ""
if (( violations > 0 )); then
    echo "RESULT: $violations SDK-import boundary violation(s) found in substrate core"
    echo "Substrate core MUST NOT import any of: ${SDK_CONSUMERS[*]}"
    exit 1
fi
echo "RESULT: SDK-import boundary clean — no substrate core file imports an SDK consumer"
exit 0
