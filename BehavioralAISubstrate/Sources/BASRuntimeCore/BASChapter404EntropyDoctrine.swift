// MARK: - BASChapter404EntropyDoctrine — forwarder
// chapter 四百六十六 / M1242 — Phase 3 of doctrine collapse。
//
// The original ~150-265 LOC doctrine file was REPLACED
// with this thin forwarder。 All doctrine data now lives
// in BASChapterDoctrineRegistry / BASChapterDoctrine
// RegistryAllLiterals。 This forwarder preserves the
// existing static-surface API so per-chapter tests +
// cross-doctrine tests continue to compile unchanged。

import Foundation

public enum BASChapter404EntropyDoctrine {

    private static var record: BASChapterDoctrineRecord {
        BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百四")!
    }

    public static var chapterTag: String {
        record.chapterTag
    }
    public static var mNumberFirst: Int {
        record.mNumberFirst
    }
    public static var mNumberLast: Int {
        record.mNumberLast
    }
    public static var v1MilestoneMNumber: Int {
        record.v1MilestoneMNumber
    }
    public static var v1MilestoneStatus: String {
        record.v1MilestoneStatus
    }
    public static var knives: [BASChapterKnife] {
        record.knives
    }
    public static var entropyClassesAttacked: [String] {
        record.entropyClassesAttacked
    }
    public static var pinHeld: [String] {
        record.pinHeld
    }
    public static var plannedFutureCuts: [String] {
        record.plannedFutureCuts
    }
    public static var summary: String {
        record.summary
    }

    // chapter 404 originally exposed extra v2/v3/v4
    // milestones beyond the standard v1 surface。 Phase 3
    // forwarder preserves them as static lets directly
    // (not mirrored in BASChapterDoctrineRecord since
    // only chapter 404 uses them)。 chapter 466 / M1242。
    public static let v2MilestoneMNumber: Int = 974
    public static let v2MilestoneStatus: String =
        "chapter-404-v2-complete"
    public static let v3MilestoneMNumber: Int = 977
    public static let v3MilestoneStatus: String =
        "chapter-404-v3-complete"
    public static let v4MilestoneMNumber: Int = 980
    public static let v4MilestoneStatus: String =
        "chapter-404-v4-complete-audit-projection-comprehensive"
}
