#!/usr/bin/env bash
# check_whitepaper_schema_parity.sh
#
# Automated drift detection for M106-M119's substrate whitepaper
# parity discipline.
#
# Invariant enforced: every `public struct BAS*: BASSchemaVersioned`
# declared in BehavioralAISubstrate/Sources/ must also have an
# entry in `BASEBrainSchemaGovernanceRegistry.governedSchemas`.
# A struct declared without registration means the governance
# audit will silently skip it — exactly the M89 / M94 class of
# "ship-without-register" drift that M115 / M118 had to retrofit.
#
# This lint surfaces that drift at build time instead of through
# manual audit months later.
#
# Exit codes:
#   0 — parity clean (every BASSchemaVersioned struct is registered)
#   1 — drift detected; names printed
#   2 — usage error (source tree missing)
#
# Design:
#   1. Find all `public struct BAS.*: *BASSchemaVersioned` in
#      Sources/ (grep pattern + line extraction).
#   2. Find all `entry(\"SomeName\", versionedType: BASXxx.self,`
#      in the registry.
#   3. Diff: structs - registry = drift.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SUBSTRATE_SRC="$ROOT/BehavioralAISubstrate/Sources"
REGISTRY="$ROOT/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift"

if [[ ! -d "$SUBSTRATE_SRC" ]]; then
    echo "check_whitepaper_schema_parity: $SUBSTRATE_SRC not found" >&2
    exit 2
fi
if [[ ! -f "$REGISTRY" ]]; then
    echo "check_whitepaper_schema_parity: $REGISTRY not found" >&2
    exit 2
fi

# 1. Extract all public struct BAS* that conform to BASSchemaVersioned.
#    Handles both single-line and multi-line (using grep context).
#    Pattern: lines like `public struct BASFoo: BASSchemaVersioned,
#    Hashable, Sendable {` or multi-line variants.
DECLARED_TYPES=$(grep -rn "public struct BAS" "$SUBSTRATE_SRC" \
    --include='*.swift' 2>/dev/null \
    | grep -E "BASSchemaVersioned" \
    | sed -E 's/.*public struct (BAS[A-Za-z0-9_]+).*/\1/' \
    | sort -u)

# Also catch multi-line declarations like:
#   public struct BASFoo:
#       BASSchemaVersioned, Hashable, Sendable
# by matching the inheritance line when it follows immediately.
MULTILINE_TYPES=$(grep -rnB1 "BASSchemaVersioned" "$SUBSTRATE_SRC" \
    --include='*.swift' 2>/dev/null \
    | grep "public struct BAS" \
    | sed -E 's/.*public struct (BAS[A-Za-z0-9_]+).*/\1/' \
    | sort -u)

# Merge the two passes, dedupe.
ALL_DECLARED=$(printf '%s\n%s\n' "$DECLARED_TYPES" "$MULTILINE_TYPES" \
    | grep -v '^$' | sort -u)

# 2. Extract all versionedType: BASXxx.self from registry.
REGISTERED_TYPES=$(grep -E "versionedType: BAS[A-Za-z0-9_]+\.self" \
    "$REGISTRY" \
    | sed -E 's/.*versionedType: (BAS[A-Za-z0-9_]+)\.self.*/\1/' \
    | sort -u)

# 3. Diff: declared but not registered.
DRIFT=$(comm -23 \
    <(printf '%s\n' "$ALL_DECLARED") \
    <(printf '%s\n' "$REGISTERED_TYPES"))

# Allowlist: types that are intentionally unregistered.
# - BASSovereignAuditEntry: overlaps with SovereignLedgerEntry
#   (whitepaper §5.11 uses one name, substrate uses the other with
#    extended fields; registration would double-count).
# Add more with clear doc rationale.
ALLOWLIST=(
    "BASSovereignAuditEntry"
)

# Filter out allowlist entries.
FILTERED_DRIFT=""
while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    skip=false
    for allowed in "${ALLOWLIST[@]}"; do
        if [[ "$name" == "$allowed" ]]; then
            skip=true
            break
        fi
    done
    if [[ "$skip" == "false" ]]; then
        FILTERED_DRIFT+="$name"$'\n'
    fi
done <<< "$DRIFT"

# Trim trailing newline.
FILTERED_DRIFT=$(printf '%s' "$FILTERED_DRIFT" | sed '/^$/d')

if [[ -z "$FILTERED_DRIFT" ]]; then
    DECLARED_COUNT=$(printf '%s\n' "$ALL_DECLARED" | wc -l | tr -d ' ')
    REGISTERED_COUNT=$(printf '%s\n' "$REGISTERED_TYPES" | wc -l | tr -d ' ')
    echo "check_whitepaper_schema_parity: clean — " \
        "$DECLARED_COUNT declared BASSchemaVersioned structs, " \
        "$REGISTERED_COUNT registered " \
        "(diff: ${#ALLOWLIST[@]} allowlist entries)."
    exit 0
fi

COUNT=$(printf '%s\n' "$FILTERED_DRIFT" | wc -l | tr -d ' ')
echo "check_whitepaper_schema_parity: $COUNT drift(s) detected — " \
    "BASSchemaVersioned struct(s) declared but not registered:" >&2
printf '  - %s\n' $FILTERED_DRIFT >&2
echo "" >&2
echo "Fix: add an entry(\"<Name>\", versionedType: <Struct>.self," \
    "tests: [...]) line to" >&2
echo "  $REGISTRY" >&2
echo "and update the three test expectation sites" >&2
echo "  (BASEBrainProgramBlueprintTests.swift expectedObjects," >&2
echo "   BASEBrainSchemaGovernanceRegistryTests.swift count + expectedVersions," >&2
echo "   QINAOSchemaGovernanceParityGateTests.swift canonical versions + migration-ID policy)." >&2
echo "" >&2
echo "If the struct is intentionally unregistered, add it to" >&2
echo "the ALLOWLIST in $0 with a doc comment explaining why." >&2
exit 1
