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

# Per-file pinned-at-current-size overrides (M762 doctrine 「legacy god
# files PINNED at current size + 10% headroom」)。 Two substrate files
# are intentionally large because they hold consolidated data:
#   - BASChapterDoctrineRegistry.swift = registry of ALL chapter doctrine
#     records (sole-source-of-truth per chapter 七百五十二 大幅度 缩减)。
#     25,146 LOC of typed records + commented-out legacy paths per
#     「依旧 不删除 只 comment」 discipline。 Splitting would multiply
#     per-chapter file ceremony without reducing surface area。
#   - BASEntropyChapterIndex.swift = registry of entropy chapter indices。
#     7,276 LOC of similar consolidated structure。
#
# Both are tracked architectural debt with documented rationale。 The
# pinned ceiling (+10% headroom of current size) prevents UNBOUNDED
# growth while allowing the documented size。 Adding ~2.5K lines of
# headroom each gives room for chapter additions before requiring an
# explicit split refactor。
#
# Implemented as a function (not associative array) for portability —
# macOS ships bash 3.2 which lacks `declare -A`。
per_file_max_override() {
    # Returns the override max for the file path on stdout,or empty
    # string if no override exists。
    case "$1" in
        BehavioralAISubstrate/Sources/BASRuntimeCore/BASChapterDoctrineRegistry.swift)
            echo 28000 ;;
        BehavioralAISubstrate/Sources/BASRuntimeCore/BASEntropyChapterIndex.swift)
            echo 8000 ;;
        *)
            echo "" ;;
    esac
}

check_file() {
    local file=$1
    local warn_at=$2
    local max_at=$3
    local lines
    lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
    if [ -z "$lines" ]; then return; fi
    # Per-file override:if this file has a pinned max,use it instead
    # of the default max。 Allows documented-large legacy god files to
    # pass while still enforcing the default ceiling on new files。
    local override
    override=$(per_file_max_override "$file")
    if [ -n "$override" ]; then
        max_at="$override"
    fi
    if [ "$lines" -gt "$max_at" ]; then
        echo "ERROR  $file: $lines lines (max $max_at) — extract a module"
        ERRORS=$((ERRORS + 1))
    elif [ "$lines" -gt "$warn_at" ]; then
        echo "WARN   $file: $lines lines (warn $warn_at) — consider extracting"
        WARNINGS=$((WARNINGS + 1))
    fi
}

echo "=== check_god_files (M762 chapter 二百三) ==="

# SampleHost layer。 Note:SampleHostTests/ at repo root was relocated
# to SampleHost/Tests/SampleHostTests/ on 2026-05-21 (SampleHost
# reconstitution as standalone SPM package)。 Glob updated to reflect
# the new SPM-canonical Tests/ subdirectory layout。
for f in SampleHost/*.swift SampleHost/Tests/SampleHostTests/*.swift; do
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
