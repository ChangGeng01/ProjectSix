// MARK: - BASChapter407EntropyDoctrine — forwarder
// chapter 四百六十六 / M1242 — Phase 3 of doctrine collapse。
//
// The original ~150-265 LOC doctrine file was REPLACED
// with this thin forwarder。 All doctrine data now lives
// in BASChapterDoctrineRegistry / BASChapterDoctrine
// RegistryAllLiterals。 This forwarder preserves the
// existing static-surface API so per-chapter tests +
// cross-doctrine tests continue to compile unchanged。

import Foundation

public enum BASChapter407EntropyDoctrine {

    private static var record: BASChapterDoctrineRecord {
        BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百七")!
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
}
