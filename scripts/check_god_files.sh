#!/bin/bash
# M762 chapter 二百三 — god-file size guard.
#
# Architectural pressure: prevent unbounded SampleHost*.swift /
# BAS*.swift growth. Limits informed by chapter 一百九十五 honest
# assessment ("SampleHostModel.swift 5K+ LOC = god file").
#
# Limits:
#   SampleHost/*.swift:        <= 6000 LOC each (4000 warning)
#   BAS source files:          <= 5000 LOC each (3000 warning)
#
# Doctrine: file > limit = WARNING + reminder to extract module.
# File > 1.5x limit = ERROR + CI fail.
#
# Usage:
#   bash scripts/check_god_files.sh
# Exit:
#   0 = clean (or warnings only)
#   1 = at least one ERROR (CI fail)

set -u
ERRORS=0
WARNINGS=0

# Limit definitions
# M762 doctrine: legacy god files are PINNED at current size + 10%
# headroom. New files default to 4K warn / 6K max. Prevents future
# god files; doesn't force urgent extraction of existing ones.
SAMPLE_HOST_WARN=4000
SAMPLE_HOST_MAX=6000
BAS_WARN=3000
BAS_MAX=6000  # accommodates EBrainCognitionPlaneCore 5347
QINAO_SAMPLE_HOST_MAX=9000  # main.swift 8224 (8 demo modes accumulated)

check_file() {
    local file=$1
    local warn_at=$2
    local max_at=$3
    local lines
    lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
    if [ -z "$lines" ]; then return; fi
    if [ "$lines" -gt "$max_at" ]; then
        echo "ERROR  $file: $lines lines (max $max_at) — extract a module"
        ERRORS=$((ERRORS + 1))
    elif [ "$lines" -gt "$warn_at" ]; then
        echo "WARN   $file: $lines lines (warn $warn_at) — consider extracting"
        WARNINGS=$((WARNINGS + 1))
    fi
}

echo "=== check_god_files (M762 chapter 二百三) ==="

# SampleHost layer
for f in SampleHost/*.swift SampleHostTests/*.swift; do
    [ -f "$f" ] || continue
    check_file "$f" "$SAMPLE_HOST_WARN" "$SAMPLE_HOST_MAX"
done

# BAS substrate (sources only — Tests can be large since they're
# test-data heavy)
for f in $(find BehavioralAISubstrate/Sources -name "*.swift" -type f); do
    [ -f "$f" ] || continue
    check_file "$f" "$BAS_WARN" "$BAS_MAX"
done

# Qinao SDK — main.swift gets special higher limit (CLI demo container)
for f in $(find QinaoRuntimeSDK/Sources -name "*.swift" -type f); do
    [ -f "$f" ] || continue
    if [ "$f" = "QinaoRuntimeSDK/Sources/QinaoSampleHost/main.swift" ]; then
        check_file "$f" "$QINAO_SAMPLE_HOST_MAX" "$QINAO_SAMPLE_HOST_MAX"
    else
        check_file "$f" "$BAS_WARN" "$BAS_MAX"
    fi
done

echo ""
echo "Summary: $WARNINGS warnings, $ERRORS errors"

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "REFUSED: god-file ERROR count > 0. Files above max LOC"
    echo "limit must be extracted into focused modules before CI"
    echo "passes. See chapter 一百九十五 honest residual on file"
    echo "size + chapter 二百三 ADR for extraction patterns."
    exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "OK with warnings — files near limit. Plan extraction"
    echo "before they hit ERROR threshold."
fi
exit 0
