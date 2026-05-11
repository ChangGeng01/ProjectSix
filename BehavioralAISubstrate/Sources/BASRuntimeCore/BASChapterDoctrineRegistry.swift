// MARK: - BASChapterDoctrineRegistry — chapter 四百六十三 / M1229
// 系统熵 reduction
//
// Typed registry of per-chapter doctrine records。
// Phase 1 of the doctrine-collapse structural debt
// repayment (see BASChapterDoctrineRecord.swift for
// the strategy)。
//
// Phase 1 scope (chapter 463 / M1229):
//   - Define registry surface + lookup APIs
//   - Populate 10 entries for chapters 453-462 via
//     DERIVATION from existing `BASChapter###Entropy
//     Doctrine.swift` per-chapter files
//   - PROOF tests verify registry derivation is byte-
//     mirror equal to the source files (see
//     BASChapterDoctrineRegistryTests)
//
// Phase 2 scope (chapter 464+):
//   - New chapter entries are DIRECTLY POPULATED here
//     (no new Swift file per chapter)
//   - Cross-doctrine schema completeness tests query
//     registry instead of 60+ Swift symbols
//
// Phase 3 scope (chapter 465+):
//   - `git rm` the 60+ historical `BASChapter###Entropy
//     Doctrine.swift` files,replace each `BASChapter
//     ###EntropyDoctrine.knives` lookup in tests with
//     `BASChapterDoctrineRegistry.recordFor(chapter:
//     "chapter ###")!.knives`
//
// ## Why DERIVATION first
//
// Doing a clean delete-and-rewrite of 60 files in one
// chapter is high-risk:every cross-doctrine test
// would need rewiring in the same commit。 Derivation
// keeps the existing source-of-truth + adds the
// registry as an OBSERVATION view。 PROOF tests pin
// equality;callers can migrate at their own pace。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed lookup API
//   - chapter 二百一一 — one registry for all
//     chapters;no parallel registries per concern
//   - chapter 三百九二 — derivation deterministic
//     per source-file static surface
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//   - ADR-014 OPT-IN — additive

import Foundation

/// Single-source-of-truth registry of per-chapter
/// doctrine records。 chapter 463 / M1229。
public enum BASChapterDoctrineRegistry {

    /// All chapter records currently registered。
    /// Phase 1:populates chapters 453-462 from the
    /// per-chapter Swift file static surface。 Future
    /// phases will populate new chapters directly
    /// here without a separate Swift file。
    public static let all: [BASChapterDoctrineRecord] =
    [
        deriveRecord(
            chapterTag: BASChapter453EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter453EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter453EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter453EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter453EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter453EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter453EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter453EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter453EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter453EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter454EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter454EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter454EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter454EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter454EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter454EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter454EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter454EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter454EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter454EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter455EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter455EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter455EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter455EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter455EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter455EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter455EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter455EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter455EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter455EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter456EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter456EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter456EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter456EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter456EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter456EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter456EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter456EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter456EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter456EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter457EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter457EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter457EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter457EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter457EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter457EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter457EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter457EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter457EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter457EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter458EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter458EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter458EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter458EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter458EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter458EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter458EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter458EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter458EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter458EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter459EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter459EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter459EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter459EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter459EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter459EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter459EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter459EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter459EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter459EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter460EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter460EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter460EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter460EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter460EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter460EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter460EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter460EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter460EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter460EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter461EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter461EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter461EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter461EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter461EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter461EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter461EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter461EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter461EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter461EntropyDoctrine
                .summary),
        deriveRecord(
            chapterTag: BASChapter462EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter462EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter462EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter462EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter462EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter462EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter462EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter462EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter462EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter462EntropyDoctrine
                .summary),

        // chapter 463 was Phase 1 (registry shipped),
        // still has a per-chapter Swift file。 Phase 2
        // starts at chapter 464 — entries below are
        // DIRECT literals,no per-chapter Swift file
        // exists for them。 chapter 464 / M1233。
        deriveRecord(
            chapterTag: BASChapter463EntropyDoctrine
                .chapterTag,
            mNumberFirst: BASChapter463EntropyDoctrine
                .mNumberFirst,
            mNumberLast: BASChapter463EntropyDoctrine
                .mNumberLast,
            v1MilestoneMNumber:
                BASChapter463EntropyDoctrine
                    .v1MilestoneMNumber,
            v1MilestoneStatus:
                BASChapter463EntropyDoctrine
                    .v1MilestoneStatus,
            knivesRaw: BASChapter463EntropyDoctrine
                .knives,
            entropyClassesAttacked:
                BASChapter463EntropyDoctrine
                    .entropyClassesAttacked,
            pinHeld: BASChapter463EntropyDoctrine
                .pinHeld,
            plannedFutureCuts:
                BASChapter463EntropyDoctrine
                    .plannedFutureCuts,
            summary: BASChapter463EntropyDoctrine
                .summary),

        // chapter 464 / M1232-M1235 — FIRST registry-
        // only chapter doctrine。 No
        // BASChapter464EntropyDoctrine.swift file
        // exists。 The chapter's full doctrine surface
        // is THIS literal entry。 Future chapters
        // follow this pattern;chapter 465+ will then
        // delete the 60+ per-chapter Swift files for
        // pre-464 entries (Phase 3)。
        BASChapterDoctrineRecord(
            chapterTag: "chapter 四百六十四",
            mNumberFirst: 1232,
            mNumberLast: 1235,
            v1MilestoneMNumber: 1235,
            v1MilestoneStatus:
                "chapter-464-v1-doctrine-collapse-phase-2-first-registry-only-chapter",
            knives: [
                BASChapterKnife(
                    mNumber: 1232,
                    knife: "第一刀",
                    concept:
                        "Design schema-test extension" +
                        " (checkRegistryEntry helper)" +
                        " that verifies registry-only" +
                        " chapter records have full" +
                        " parity with Swift-file-backed" +
                        " chapters。 Phase 2 invariant" +
                        " established:new chapters MUST" +
                        " live as direct registry" +
                        " entries,no new BASChapter###" +
                        "EntropyDoctrine.swift files" +
                        " accepted。 No source change"),
                BASChapterKnife(
                    mNumber: 1233,
                    knife: "第二刀",
                    concept:
                        "Add chapter 464 record" +
                        " DIRECTLY into BASChapter" +
                        "DoctrineRegistry as Swift" +
                        " literal — no Swift file" +
                        " created for chapter 464。" +
                        " First instance of the Phase" +
                        " 2 pattern。 Registry now" +
                        " carries 12 entries:10" +
                        " chapters via derivation +" +
                        " chapter 463 derivation +" +
                        " chapter 464 literal"),
                BASChapterKnife(
                    mNumber: 1234,
                    knife: "第三刀",
                    concept:
                        "PROOF tests verify chapter" +
                        " 464's registry entry has" +
                        " full schema parity with" +
                        " Swift-file-backed chapters" +
                        " (knives count > 0,pin held" +
                        " count > 0,non-empty summary," +
                        " non-empty status,M-range" +
                        " contiguous with chapter 463)" +
                        " + Phase 2 chapter count" +
                        " invariant (registry has" +
                        " entries for ALL chapters in" +
                        " Phase2Doctrine.chapterTags" +
                        " Shipped past chapter 453)"),
                BASChapterKnife(
                    mNumber: 1235,
                    knife: "第四刀",
                    concept:
                        "Chapter 464 close-out — but" +
                        " the close-out doctrine ITSELF" +
                        " lives in this registry" +
                        " literal entry,not in a Swift" +
                        " file。 Phase 2 bump (chapter" +
                        " 61→62,mNumberLast 1231→1235," +
                        " commits 277→281) + ADR-016" +
                        ".M1231 → M1235 + cross-mirror" +
                        " tests + commit + push。 Phase" +
                        " 2 pattern proven viable")
            ],
            entropyClassesAttacked: [
                "no-registry-only-chapter-pattern-entropy",
                "phase-2-pattern-unverified-entropy",
                "schema-parity-untested-entropy",
                "doctrine-pin-entropy"
            ],
            pinHeld: [
                "不变量 #1",
                "不变量 #2",
                "不变量 #3",
                "红线 7 (registry observation/audit)",
                "chapter 一百八十五 (typed Record" +
                " literal — same Codable surface as" +
                " Swift-file chapters)",
                "chapter 二百一一 (chapter 464 has ONE" +
                " entry in ONE registry;no parallel" +
                " Swift file)",
                "chapter 三百九二 (registry literal" +
                " deterministic;Codable round-trip" +
                " preserves byte-equal)",
                "ADR-014 OPT-IN preserved (purely" +
                " structural;no functional surface" +
                " change)",
                "ADR-016 (advanced M1231 → M1235)",
                "系统熵 reduction",
                "STRUCTURAL DEBT REPAYMENT chapter 2" +
                " — Phase 2 of doctrine collapse" +
                " (first registry-only chapter)"
            ],
            plannedFutureCuts: [
                "chapter 465 ✓ shipped Phase 2b proof-" +
                "of-pattern (1 literal chapter + test)。" +
                " Phase 3 (`git rm` 60+ Swift files +" +
                " bulk literal conversion) DEFERRED to" +
                " a user-confirmed chapter due to" +
                " auto-mode destructive-op constraint",
                "chapter 466+:auto-checkpoint" +
                " integration with BASEventLogStorage —" +
                " observer aggregate snapshot emitted" +
                " as event-log payload kind every N" +
                " turns",
                "chapter 467+:adaptive A / τ — per-" +
                "synapse STDP params evolve via meta-" +
                "plasticity (BCM rule + sliding" +
                " modification threshold)",
                "chapter 468+:wire BASHierarchical" +
                "PredictiveCoding into" +
                " BASBiomimeticTurnObserver as 4th" +
                " optional primitive slot",
                "chapter 469+:expand benchmark harness" +
                " to cover Mamba GPU + attention GPU +" +
                " rmsNorm GPU + matMul GPU +" +
                " rotaryEmbedding GPU paths"
            ],
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 2 —" +
                " ships Phase 2 of doctrine collapse:" +
                " the FIRST chapter doctrine that lives" +
                " ONLY in BASChapterDoctrineRegistry," +
                " no per-chapter Swift file created。 4" +
                " cuts (M1232-M1235):design schema-" +
                "test extension + add chapter 464" +
                " literal entry + PROOF tests verify" +
                " full parity with Swift-file chapters" +
                " + close-out。 The chapter PROVES the" +
                " Phase 2 pattern by BEING the first" +
                " instance — its full doctrine surface" +
                " (knives,pins,entropy classes,future" +
                " cuts,summary) is exactly THIS" +
                " registry entry。 Phase 2 net per-" +
                "chapter LOC delta:~+50 LOC literal" +
                " entry vs ~+200 LOC Swift file (4×" +
                " reduction)。 Phase 3 (chapter 465+)" +
                " deletes the 60+ pre-464 Swift files" +
                " for the full ~−12K LOC repayment。" +
                " ADR-016 → M1235。 V1 byte-equality" +
                " preserved。"),

        // chapter 465 / M1236-M1239 — Phase 2b proof-
        // of-pattern。 Course-corrected from "do Phase
        // 3 in chapter 465" to "stage literal-
        // conversion safely" because Phase 3 requires
        // destructive `git rm` which auto-mode
        // prohibits without explicit user
        // confirmation。 Chapter 465 ships 1 literal
        // chapter (453) in BASChapterDoctrineRegistry
        // +Literals.swift + PROOF tests + chapter
        // 465's own registry-only entry。 Bulk
        // conversion + destructive deletion queued
        // for user-confirmed future chapter。
        BASChapterDoctrineRecord(
            chapterTag: "chapter 四百六十五",
            mNumberFirst: 1236,
            mNumberLast: 1239,
            v1MilestoneMNumber: 1239,
            v1MilestoneStatus:
                "chapter-465-v1-phase-2b-literal-proof-of-pattern",
            knives: [
                BASChapterKnife(
                    mNumber: 1236,
                    knife: "第一刀",
                    concept:
                        "Course-correct from original" +
                        " plan (chapter 465 = Phase 3" +
                        " destructive `git rm`) to" +
                        " auto-mode-safe scope (Phase" +
                        " 2b proof-of-pattern via" +
                        " literal conversion of 1" +
                        " chapter)。 Auto-mode rule:" +
                        " destructive operations" +
                        " require explicit user" +
                        " confirmation;course-correct" +
                        " to safer method instead。" +
                        " Decision pinned in chapter" +
                        " 465 close-out"),
                BASChapterKnife(
                    mNumber: 1237,
                    knife: "第二刀",
                    concept:
                        "Ship BASChapterDoctrine" +
                        "Registry+Literals.swift with" +
                        " 1 LITERAL chapter record" +
                        " (chapter 453) as proof-of-" +
                        "pattern。 Literal is fully" +
                        " self-contained,no reference" +
                        " to BASChapter453Entropy" +
                        "Doctrine symbol。 Future" +
                        " chapters extend the literals" +
                        " array until all 11 derived" +
                        " entries have counterparts"),
                BASChapterKnife(
                    mNumber: 1238,
                    knife: "第三刀",
                    concept:
                        "6 PROOF tests verifying" +
                        " literal-byte-matches-" +
                        "derivation invariant +" +
                        " literal Codable round-trip +" +
                        " literal fields non-empty +" +
                        " chapter 465 itself is" +
                        " registry-only (Phase 2" +
                        " pattern continued) + Phase" +
                        " 2 covenant unchanged + main" +
                        " registry literal accessor" +
                        " count = 1"),
                BASChapterKnife(
                    mNumber: 1239,
                    knife: "第四刀",
                    concept:
                        "chapter 465 close-out + Phase" +
                        " 2 bump (chapter 62→63," +
                        " mNumberLast 1235→1239,commits" +
                        " 281→285) + ADR-016.M1235 →" +
                        " M1239 + acknowledge Phase 3" +
                        " (destructive 60+ file `git" +
                        " rm`) requires user" +
                        " confirmation and is queued" +
                        " for a future chapter")
            ],
            entropyClassesAttacked: [
                "premature-destructive-phase3-entropy",
                "no-literal-conversion-pattern-entropy",
                "phase2b-invariant-unverified-entropy",
                "doctrine-pin-entropy"
            ],
            pinHeld: [
                "不变量 #1",
                "不变量 #2",
                "不变量 #3",
                "红线 7",
                "chapter 一百八十五 (typed literal" +
                " same surface as derived)",
                "chapter 二百一一 (one literals file)",
                "chapter 三百九二 (literal-vs-derivation" +
                " byte-equality verified)",
                "ADR-014 OPT-IN preserved (additive)",
                "ADR-016 (advanced M1235 → M1239)",
                "系统熵 reduction",
                "STRUCTURAL DEBT REPAYMENT chapter 3" +
                " — Phase 2b proof-of-pattern"
            ],
            plannedFutureCuts: [
                "chapter 466:request explicit user" +
                " confirmation for Phase 3 destructive" +
                " `git rm` of 60+ historical per-" +
                "chapter Swift files",
                "chapter 467 (user-confirmed):bulk" +
                " convert remaining 10 derived" +
                " entries to literals + swap main" +
                " BASChapterDoctrineRegistry.all to" +
                " use literals + `git rm` 60+ files" +
                " in ONE atomic commit (~−12K LOC" +
                " repayment)",
                "chapter 468+:auto-checkpoint" +
                " integration with BASEventLogStorage",
                "chapter 469+:adaptive A / τ — per-" +
                "synapse STDP meta-plasticity",
                "chapter 470+:wire BASHierarchical" +
                "PredictiveCoding into" +
                " BASBiomimeticTurnObserver as 4th" +
                " optional primitive slot"
            ],
            summary:
                "STRUCTURAL DEBT REPAYMENT chapter 3 —" +
                " ships Phase 2b proof-of-pattern for" +
                " doctrine collapse literal-conversion。" +
                " 4 cuts (M1236-M1239):course-correct" +
                " + ship literal for chapter 453 +" +
                " 6 PROOF tests + close-out。 Course-" +
                "correction motivation:original plan" +
                " said chapter 465 = Phase 3 destructive" +
                " `git rm` of 60+ Swift files,but auto-" +
                "mode prohibits destructive ops without" +
                " explicit user confirmation。 Honest" +
                " scope:ship 1 literal proving pattern" +
                " works + queue full Phase 3 for user-" +
                "confirmed chapter (466+)。 Acknowledged" +
                " net LOC delta for Phase 2b ALONE is" +
                " ~+250 LOC (literal sub-file + tests);" +
                " the real ~−12K LOC repayment requires" +
                " Phase 3 destruction。 Pattern proven" +
                " viable;chapter 466 will request user" +
                " OK to proceed。 ADR-016 → M1239。 V1" +
                " byte-equality preserved。")
    ]

    /// Lookup by exact chapter tag string。 Returns
    /// nil if no entry exists (chapter not yet
    /// migrated to the registry)。
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
    /// 1:10 chapters (453-462)。 Phase 2+ grows as
    /// new chapters are added。
    public static var count: Int { all.count }

    // MARK: - Derivation helper

    private static func deriveRecord(
        chapterTag: String,
        mNumberFirst: Int,
        mNumberLast: Int,
        v1MilestoneMNumber: Int,
        v1MilestoneStatus: String,
        knivesRaw:
            [(mNumber: Int, knife: String, concept: String)],
        entropyClassesAttacked: [String],
        pinHeld: [String],
        plannedFutureCuts: [String],
        summary: String
    ) -> BASChapterDoctrineRecord {
        return BASChapterDoctrineRecord(
            chapterTag: chapterTag,
            mNumberFirst: mNumberFirst,
            mNumberLast: mNumberLast,
            v1MilestoneMNumber: v1MilestoneMNumber,
            v1MilestoneStatus: v1MilestoneStatus,
            knives: knivesRaw.map {
                BASChapterKnife(
                    mNumber: $0.mNumber,
                    knife: $0.knife,
                    concept: $0.concept)
            },
            entropyClassesAttacked:
                entropyClassesAttacked,
            pinHeld: pinHeld,
            plannedFutureCuts: plannedFutureCuts,
            summary: summary)
    }
}
