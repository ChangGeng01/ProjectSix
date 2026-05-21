// MARK: - BASChapterDoctrineRegistry — chapter 四百六十六 / M1242
// 系统熵 reduction
//
// **STRUCTURAL DEBT REPAYMENT chapter 4** — Phase 3 of
// doctrine collapse complete。 The registry now consumes
// LITERAL records exclusively (no more derivation from
// `BASChapter###EntropyDoctrine` Swift symbols)。 The
// 61 historical per-chapter Swift files were replaced
// with thin ~30-LOC forwarders that read FROM this
// registry,inverting the dependency direction:
//
//   Phase 1 (chapter 463):registry derived from Swift
//   Phase 2 (chapter 464):registry holds new chapters
//                          as literals + old as derived
//   Phase 2b (chapter 465):literal-conversion pattern
//                          proved with 1 chapter
//   **Phase 3 (chapter 466,this commit)**:
//     - Auto-extracted literals for all 61 historical
//       chapters via Python script (committed to git)
//     - Registry.all consumes literals exclusively
//     - 61 per-chapter Swift files become forwarders
//       reading FROM registry (preserves API surface)
//     - byte-mirror PROOF tests pin every literal
//       against its original Swift source
//
// All cross-doctrine tests continue to compile + pass
// because per-chapter forwarders expose the same
// static surface as the original doctrine enums。
//
// Net architectural change:doctrine data lives in
// ONE canonical location (BASChapterDoctrineRegistry
// AllLiterals.swift),accessed through ONE typed
// registry (this file),exposed through backward-
// compatible per-chapter symbols (forwarders)。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed Record value-type;
//     same surface as pre-Phase-3 derivation
//   - chapter 二百一一 — single source-of-truth
//     achieved (registry consumes literals;forwarders
//     query registry)
//   - chapter 三百九二 — literal-vs-source byte-
//     equality PROOF-tested for all 61 chapters
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (forwarders expose identical static surface)
//   - 红线 7 — registry is observation/audit
//   - ADR-014 OPT-IN — additive registry change;
//     forwarders preserve API

import Foundation

/// Single-source-of-truth registry of per-chapter
/// doctrine records。 Phase 3 (chapter 466):consumes
/// literals exclusively from BASChapterDoctrineRegistry
/// AllLiterals + ships chapters 464-466 as inline
/// literals (those don't exist as Swift forwarders;
/// they're registry-native from Phase 2 onward)。
public enum BASChapterDoctrineRegistry {

    // MARK: - chapter 七百二 第二刀 / M2168 — SQL pilot active surface
    //
    // Per 「不要 json 可以的话 就 sql」, all chapter records
    // (literals + phase2 inline) are sourced from the SQLite in-
    // memory loader fed by SQL/010_chapter_doctrine_records_schema
    // + 011_chapter_doctrine_literals_data + 012_chapter_doctrine_
    // phase2_data。
    //
    // The legacy `phase2RegistryNativeChapters` Swift literal
    // block (~25,030 LOC of inline records for chapters 464+)
    // is PRESERVED below as `// `-prefixed line comments per
    // 「目前 千万不要 删除 只能 commented 代码」 directive。

    // MARK: - chapter 八百二十五 / M2776-M2780 — REGISTRY DORMANCY NOTICE
    //
    // ## What happened
    //
    // The chapter doctrine registry has been dormant since
    // **chapter 七百三十四** (commit 7b3141a0,「13-file sync +
    // 10th actor-contract pillar sealed」)。 No new chapter has
    // been added to either:
    //
    //   - this Swift file's inline records (last live entry was
    //     chapter 466 — entries 464/465/466 ship as 内联 literals
    //     above; everything between 467 and 734 lives in SQL data)
    //   - `SQL/012_chapter_doctrine_phase2_data.sql` (last entry
    //     row_id=268,chapter 七百三十四)
    //
    // Between chapter 七百三十五 and the chapter 八百二十五 (this
    // note) the project shipped 4 release tags (v0.56.0 / v0.57.0
    // / v0.58.0 / v0.59.0) and is now building a v0.60.0 / v0.61.0
    // candidate — none of which restored the per-chapter
    // registry-pin discipline。
    //
    // ## Why this is documented but NOT「fixed」
    //
    // The wild-rolling-meerkat plan called this registry「sole
    // source-of-truth」 — but the actual project trajectory has
    // moved most chapter pinning into:
    //
    //   - CHANGELOG.md `[Unreleased]` + `[X.Y.Z]` sections
    //   - per-commit Conventional-Commit bodies
    //     (`feat(chapter 八百二十一 / M2756-M2760): ...`)
    //   - per-file MARK comments
    //     (`// MARK: - BASRoutedAuditReplayEngine\n// chapter ...`)
    //
    // These three locations carry the practical doctrine surface
    // for chapters 七百三十五-八百二十四。 The SQL-backed
    // `chapterDoctrineCollections` is consumed by `Registry.all`
    // (line 78) for the audit-trail use case;but no production
    // code currently reads doctrine for chapters past 七百三十四,
    // so the dormancy hasn't broken any consumer。
    //
    // Adding 87+ retroactive entries would require ~2500 SQL
    // INSERT statements (per-chapter records + knives + entropy
    // classes + pins + planned_cuts) AND would force re-validation
    // against `phase2ChapterCount = 330` expectation in
    // `BASSweepDoctrineExpectations.swift` which currently
    // matches reality with 269 SQL rows + Swift literals;a
    // mismatched count breaks proof tests。
    //
    // ## Restoration path (when someone wants to revive)
    //
    //   1. Confirm `phase2ChapterCount` expectation is still
    //      accurate vs `BASChapterDoctrineSQLLoader
    //      .chapterDoctrineCollections.phase2.count`。
    //   2. Decide:back-fill 87 missing chapters OR start fresh
    //      at the next chapter going forward。
    //   3. If back-filling:write Python extractor that scrapes
    //      per-commit body + CHANGELOG entries to auto-generate
    //      SQL INSERTs。 Update `phase2ChapterCount` accordingly。
    //   4. If starting fresh:add `INSERT INTO chapter_doctrine_
    //      records VALUES (1, 269, 'phase2', ...)` for the
    //      current chapter,bump `phase2ChapterCount`,and
    //      establish a per-chapter close-out discipline going
    //      forward。
    //
    // 严查 chapter 八百二十五 verdict:dormancy is REAL but
    // ACCEPTED — substituted by CHANGELOG + Conventional-Commit
    // + per-file MARK discipline。 Production functionality
    // unaffected。 Restoration is OPTIONAL,not blocking。

    /// chapter 七百二 第二刀 active surface — SQL-backed (literals + phase2)。
    public static let all: [BASChapterDoctrineRecord] = {
        let p = BASChapterDoctrineSQLLoader
            .chapterDoctrineCollections
        return p.literals + p.phase2
    }()

// chapter 八百二十七 / M2786-M2790 — LEGACY BLOCK ARCHIVED。
// The phase2RegistryNativeChapters Swift literal block formerly here
// (~25K commented lines for chapters 464-734) has been moved to:
//   Archive/Deactivated/Sources/BASRuntimeCore/BASChapterDoctrineRegistry_Phase2LegacyBlock.txt
// Active surface (SQL-backed) is the `public static let all` above。

    public static func recordFor(
        chapterTag: String
    ) -> BASChapterDoctrineRecord? {
        return all.first { $0.chapterTag == chapterTag }
    }

    /// Lookup by the chapter's first M-number。 Useful
    /// for callers that have the M-number range but
    /// not the human-readable tag。
    public static func recordFor(
        mNumberFirst: Int
    ) -> BASChapterDoctrineRecord? {
        return all.first {
            $0.mNumberFirst == mNumberFirst
        }
    }

    /// Count of currently registered chapters。 Phase
    /// 3 (chapter 466):64 entries (61 historical from
    /// AllLiterals + 3 inline literals for chapters
    /// 464,465,466)。
    public static var count: Int { all.count }
}
