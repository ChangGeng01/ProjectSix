// MARK: - BASChapterDoctrineRegistry+AllLiterals — chapter 四百六十六 / M1241
// 系统熵 reduction
//
// **STRUCTURAL DEBT REPAYMENT chapter 4** — Phase 3
// of doctrine collapse。 Ships LITERAL records for
// all 61 chapters (403-463),AUTO-EXTRACTED from
// the corresponding BASChapter###EntropyDoctrine.swift
// source files via /tmp/extract_doctrines.py (committed
// to git history for reproducibility but the generated
// file below is the canonical source going forward)。
//
// PROOF tests verify byte-equality between these
// literals and the original Swift sources。 After this
// commit:
//   - BASChapterDoctrineRegistry.all consumes these
//     literals (not derivations)
//   - The 61 original BASChapter###EntropyDoctrine.swift
//     files become thin ~30-LOC forwarders that read
//     from the registry instead of holding data directly
//
// Architectural change:doctrine data lives in ONE
// place (this file) + ONE registry surface;backward-
// compat preserved through per-chapter forwarders。

import Foundation

public enum BASChapterDoctrineRegistryAllLiterals {

    // MARK: - chapter 七百二 第一刀 / M2167 — SQL pilot active surface
    //
    // Per user directive 「不要 json 可以的话 就 sql」, the 61
    // chapter-403-through-463 literal records are now sourced
    // from a SQLite in-memory loader fed by
    //   Sources/BASRuntimeCore/SQL/010_chapter_doctrine_records_schema.sql
    //   Sources/BASRuntimeCore/SQL/011_chapter_doctrine_literals_data.sql
    //
    // The legacy Swift literal block (chapter403...chapter463 +
    // the original `static let all = [...]` aggregation) is
    // PRESERVED in a `/* */` block comment immediately below
    // per user directive 「目前 千万不要 删除 只能 commented 代码」。
    //
    // ## Frozen-hash invariant
    //
    // `BASRegistryFrozenHashTests.testRegistryLiteralsHaveStable
    //  Hash` asserts SHA256 of `JSONEncoder.encode(.all)` with
    // sortedKeys equals a frozen hex string。 The SQL loader
    // returns `[BASChapterDoctrineRecord]` byte-equivalent to
    // what the legacy Swift literal block returned (Codable
    // round-trip preserves field bytes),so the frozen hash
    // stays green。

    /// chapter 七百二 第一刀 active surface — SQL-backed。
    public static let all: [BASChapterDoctrineRecord] =
        BASChapterDoctrineSQLLoader
            .chapterDoctrineCollections.literals

    // chapter 八百二十七 / M2786-M2790 — LEGACY BLOCK ARCHIVED。
    // 61-chapter Swift literal block (chapters 403-463) formerly here
    // (~3.9K commented lines) moved to:
    //   Archive/Deactivated/Sources/BASRuntimeCore/BASChapterDoctrineRegistry+AllLiterals_LegacyBlock.txt
    // Active surface (SQL-backed) is the `public static let all` above。

}