// MARK: - BASChapter463EntropyDoctrine — chapter 四百六十三 / M1231
// 系统熵 reduction
//
// **STRUCTURAL DEBT REPAYMENT chapter 1** — closes
// Phase 1 of the doctrine-collapse debt called out
// in chapter 462's self-audit。
//
// ## Why this exists (system entropy framing)
//
// Chapter 462 self-audit's residual structural debts:
//
//   "Doctrine 收敛:60+ 个 BASChapter*EntropyDoctrine
//    .swift 文件 × ~200 LOC = ~12K LOC 散文。 原 radical
//    plan Phase D 早就说要 collapse 成 data table,从
//    未执行"
//
// The original radical-evolution-sweep plan (Phase D,
// see /Users/changgeng/.claude/plans/wild-rolling-
// meerkat.md) explicitly called for collapsing 22
// chapter doctrines into one data table。 That work
// was never executed;the count has grown to 60+。
//
// Chapter 463 ships PHASE 1:
//
//   1. NEW `BASChapterDoctrineRecord` value-type
//      carrying the FULL per-chapter doctrine data
//      (knives,pins,entropy classes,future cuts,
//      summary) — Codable + Equatable + Sendable
//   2. NEW `BASChapterDoctrineRegistry` populated
//      with 10 entries for chapters 453-462,each
//      DERIVED from the corresponding per-chapter
//      Swift file's static surface
//   3. 14 PROOF tests verifying registry entries
//      byte-mirror their sources + Codable round-trip
//      preserves equality + lookup APIs work
//
// Phase 2 (chapter 464+):new chapters add entries
// DIRECTLY to the registry,no new Swift file per
// chapter
//
// Phase 3 (chapter 465+):`git rm` the 60+ historical
// `BASChapter###EntropyDoctrine.swift` files once
// their callers in cross-doctrine schema tests are
// migrated to registry lookups
//
// ## Net LOC impact
//
// Phase 1 (this chapter):
//   - +200 LOC `BASChapterDoctrineRecord.swift`
//   - +320 LOC `BASChapterDoctrineRegistry.swift`
//     (derivation expressions for 10 entries)
//   - +420 LOC `BASChapterDoctrineRegistryTests.swift`
//     (cross-mirror PROOF for 10 entries)
//
// Phase 3 (future chapter):
//   - −12,000 LOC across 60 deleted per-chapter Swift
//     files
//   - Net debt repayment after Phase 3:~−11,060 LOC
//
// ## Why DERIVATION (not duplication or rewrite)
//
// Three alternatives considered:
//
//   1. **Duplicate data** — copy each chapter's
//      knives/pins/summary into the registry as
//      literals。 ~6000 LOC of typed data + every
//      future doctrine drift breaks dual-source-of-
//      truth invariants
//
//   2. **Delete and rewrite in one chapter** —
//      `git rm` all 60 files + populate registry +
//      rewrite every cross-doctrine test in one
//      commit。 High-risk:50+ test file rewires in
//      one diff
//
//   3. **Derive from existing source** ✓ — registry
//      entries reference `BASChapter###EntropyDoctrine
//      .knives` etc。 PROOF tests pin equality。
//      Single source of truth retained。 Risk-free
//      migration path
//
// Phase 1 chose option 3 — the lowest-risk path that
// proves the registry pattern works。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed Record value-type +
//     typed Knife sub-record
//   - chapter 二百一一 — single registry for all
//     chapters;derivation references single source
//   - chapter 三百九二 — derivation deterministic per
//     source-file static surface;Codable round-trip
//     preserves byte-equal
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive types,no existing API touched)
//   - 红线 7 — registry is observation/audit,not
//     commitment
//   - ADR-014 OPT-IN — additive
//
// ## Significance — pattern proven
//
// Before chapter 463:
//   - 0 typed registry of per-chapter doctrines
//   - 60+ Swift files each holding ~200 LOC of static
//     prose surface
//   - No way for a caller to enumerate all chapters
//     programmatically (must hand-roll 60+ symbol
//     references)
//
// After chapter 463:
//   - 1 typed registry holds 10 records + lookup APIs
//     by chapterTag or mNumberFirst
//   - PROOF tests pin byte-equality with per-chapter
//     Swift sources for 10 chapters
//   - Chapter 464+ ships new chapters as REGISTRY
//     ENTRIES instead of new Swift files;chapter
//     465+ deletes the historical files

import Foundation

public enum BASChapter463EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百六十三"
    public static let mNumberFirst: Int = 1228
    public static let mNumberLast: Int = 1231

    public static let v1MilestoneMNumber: Int = 1231
    public static let v1MilestoneStatus: String =
        "chapter-463-v1-doctrine-collapse-phase-1"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1228, "第一刀",
            "Design BASChapterDoctrineRecord value-" +
            "type carrying FULL per-chapter doctrine" +
            " data (chapterTag,M-range,v1 milestone," +
            " knives,entropy classes,pins,future" +
            " cuts,summary) + BASChapterKnife typed" +
            " sub-record。 All Codable + Equatable +" +
            " Sendable + Hashable。 No source change"),
        (1229, "第二刀",
            "Ship BASChapterDoctrineRegistry with 10" +
            " entries for chapters 453-462,each" +
            " DERIVED from BASChapter###EntropyDoctrine" +
            " static surface。 Lookup APIs:recordFor" +
            "(chapterTag:),recordFor(mNumberFirst:)。" +
            " Derivation strategy chosen over duplicate-" +
            "data or delete-and-rewrite as the lowest-" +
            "risk migration path"),
        (1230, "第三刀",
            "14 PROOF tests in BASChapterDoctrine" +
            "RegistryTests:registry-size + ordering +" +
            " byte-mirror of all 10 entries against" +
            " their sources + lookup-by-tag + lookup-" +
            "by-mNumberFirst + lookup-returns-nil-for-" +
            "unknown + Codable round-trip (single +" +
            " whole array) + Knife clamping + Record" +
            " mLast >= mFirst clamping"),
        (1231, "第四刀",
            "chapter 463 close-out + Phase 2 bump" +
            " (commits 273 → 277,chapter count 60 → 61)" +
            " + ADR-016.M1227 → M1231 advance +" +
            " postSweepRealExecutionEntries entry。" +
            " Doctrine-collapse Phase 1 complete;" +
            " Phase 2 (chapter 464+) writes new chapters" +
            " as registry entries;Phase 3 (chapter" +
            " 465+) deletes the 60+ historical Swift" +
            " files")
    ]

    public static let entropyClassesAttacked: [String] = [
        "doctrine-sprawl-no-typed-record-entropy",       // M1228
        "doctrine-sprawl-no-registry-entropy",           // M1229
        "registry-correctness-unverified-entropy",       // M1230
        "doctrine-pin-entropy"                           // M1231
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7 (registry is observation,not commitment)",
        "chapter 一百八十五 (typed Record + Knife sub-" +
        "records;all Codable + Equatable + Sendable)",
        "chapter 二百一一 (single registry for all" +
        " chapters;derivation references single source)",
        "chapter 三百九二 (derivation deterministic" +
        " per source-file surface;Codable round-trip" +
        " byte-equal)",
        "ADR-014 OPT-IN preserved (additive types)",
        "ADR-016 (advanced M1227 → M1231)",
        "系统熵 reduction",
        "STRUCTURAL DEBT REPAYMENT chapter 1 — Phase 1" +
        " of doctrine collapse"
    ]

    public static let plannedFutureCuts: [String] = [
        "chapter 464+:DOCTRINE COLLAPSE Phase 2 —" +
        " ship new chapters as DIRECT registry entries" +
        " instead of new Swift files。 Establish CI" +
        " rule blocking new BASChapter###EntropyDoctrine" +
        ".swift files",
        "chapter 465+:DOCTRINE COLLAPSE Phase 3 —" +
        " `git rm` the 60+ historical per-chapter" +
        " Swift files after migrating all cross-" +
        "doctrine test references to registry lookups。" +
        " Net debt repayment after Phase 3:~−11K LOC",
        "chapter 466+:auto-checkpoint integration" +
        " with BASEventLogStorage — observer aggregate" +
        " snapshot emitted as event-log payload kind",
        "chapter 467+:adaptive A / τ — per-synapse" +
        " STDP params evolve via meta-plasticity",
        "chapter 468+:wire BASHierarchicalPredictive" +
        " Coding into BASBiomimeticTurnObserver as" +
        " 4th optional primitive slot"
    ]

    public static let summary: String =
        "STRUCTURAL DEBT REPAYMENT chapter 1 ships" +
        " Phase 1 of doctrine collapse — the structural" +
        " debt called out in chapter 462 self-audit。" +
        " 4 cuts (M1228-M1231):design Record + Knife" +
        " types + ship Registry with 10 entries" +
        " (chapters 453-462) derived from existing" +
        " Swift sources + 14 PROOF tests verify byte-" +
        "mirror equality + Codable round-trip + lookup" +
        " APIs + close-out。 Derivation chosen over" +
        " duplicate-data or delete-and-rewrite as" +
        " lowest-risk migration path。 Phase 2 (chapter" +
        " 464+) writes new chapters as direct registry" +
        " entries;Phase 3 (chapter 465+) deletes the" +
        " 60+ historical Swift files。 Net impact" +
        " after Phase 3:~−11K LOC repayment of" +
        " doctrine-sprawl debt called out in the" +
        " original radical-sweep Phase D plan that" +
        " was never executed。 ADR-016 → M1231。 V1" +
        " byte-equality preserved。"
}
