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
    "BASAdminUI"      # audit x-architecture LOW-7: SwiftUI host UI (M-o MED-2 split)
    "BASJournalCLI"   # audit x-architecture LOW-7: CLI host
    "BASAppleEdgeWiring"  # deep-audit P2-21(b): T4 edge ring that wires adapters at the boundary
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
    "BASAppleLifecycleKit"  # deep-audit P2-21(b): T4 pure, model-free lifecycle kit BASHostKit rides
)

# audit x-architecture LOW-7 — completeness gate: every Sources/ module must be classified as either
# an SDK consumer OR substrate core, else a NEW module silently escapes the boundary check entirely.
# (Skip on --self-test, which doesn't scan the tree.)
if [[ "${1:-}" != "--self-test" ]]; then
    unclassified=0
    for src_dir in Sources/*/; do
        module="$(basename "$src_dir")"
        found=0
        for c in "${SDK_CONSUMERS[@]}" "${SUBSTRATE_CORE[@]}"; do
            if [[ "$c" == "$module" ]]; then found=1; break; fi
        done
        if (( found == 0 )); then
            echo "UNCLASSIFIED MODULE: Sources/${module} is in neither SDK_CONSUMERS nor SUBSTRATE_CORE"
            echo "  → add it to one of the two lists in this script so the boundary check covers it"
            unclassified=$((unclassified + 1))
        fi
    done
    if (( unclassified > 0 )); then
        echo "RESULT: $unclassified unclassified module(s) — the boundary gate is incomplete"
        exit 1
    fi
fi

# Build forbidden-pattern regex (one alternation per SDK consumer).
# audit tools-scripts LOW: the old `^import ${c}\b` missed the declaration-kind form
# (`import struct BASHostKit.Foo`) and the `@_exported import` re-export form, both of which
# still link the module — a real boundary bypass. A follow-up (2026-07-10) generalizes the
# attribute prefix: `@_exported` alone was hardcoded, so `@preconcurrency`, `@_implementationOnly`,
# `@_spi(Foo)`, `@_weakLinked` etc. still bypassed the gate though they ALL link the module.
# `attr_re` now matches any leading Swift import-attribute(s) (each `@name` with optional `(...)`
# args), keeping the line-start anchor so `//`-comments and indented lines stay clean.
kind_re="(struct|class|enum|protocol|func|var|let|typealias|inout)"
attr_re="(@[_A-Za-z]+([[:space:]]*\\([^)]*\\))?[[:space:]]+)*"
forbidden_pattern=""
for c in "${SDK_CONSUMERS[@]}"; do
    per_c="^${attr_re}import([[:space:]]+${kind_re})?[[:space:]]+${c}\\b"
    if [[ -z "$forbidden_pattern" ]]; then
        forbidden_pattern="$per_c"
    else
        forbidden_pattern="${forbidden_pattern}|$per_c"
    fi
done

# audit tools-scripts LOW — self-test the forbidden pattern against known bypass/clean lines so the
# regex fix has teeth (reverting to `^import ${c}\b` reds the `import struct` + `@_exported` cases).
if [[ "${1:-}" == "--self-test" ]]; then
    must_match=(
        "import BASHostKit"
        "import struct BASHostKit.Foo"
        "@_exported import BASHostKit"
        "import class BASMLXAdapter.Bar"
        # audit tools-scripts LOW (2026-07-10): non-@_exported attribute prefixes must NOT bypass —
        # they all still link the module into substrate core.
        "@preconcurrency import BASHostKit"
        "@_implementationOnly import BASHostKit"
        "@_spi(Foo) import BASHostKit"
        "@_weakLinked import BASHostKit"
        "@_spi(Reflection) @_implementationOnly import BASHostKit"
    )
    must_not_match=(
        "import Foundation"
        "// import BASHostKit"
        "    import BASHostKit"          # indented (not a top-level substrate-core import line)
        "import BASRuntimeCore"          # a substrate module importing a substrate module is fine
    )
    st_fail=0
    for line in "${must_match[@]}"; do
        if ! echo "$line" | grep -qE "$forbidden_pattern"; then
            echo "SELF-TEST FAIL: expected MATCH but missed: $line"; st_fail=1
        fi
    done
    for line in "${must_not_match[@]}"; do
        if echo "$line" | grep -qE "$forbidden_pattern"; then
            echo "SELF-TEST FAIL: expected NO match but matched: $line"; st_fail=1
        fi
    done
    if (( st_fail == 0 )); then echo "SELF-TEST PASS"; fi
    exit "$st_fail"
fi

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
