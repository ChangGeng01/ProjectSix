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
                .summary)
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
