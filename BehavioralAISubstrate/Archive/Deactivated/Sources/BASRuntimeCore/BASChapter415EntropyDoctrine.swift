import Foundation

// chapter 七百五十二 第二刀 / M2431 — thin forwarder
// DEACTIVATED per user directive 「大幅度 缩减 doctrine。
// 对比 之后 有必要的 全面 comment」。 All consumers
// (per-chapter tests + mirror tests) refactored to use
// BASChapterDoctrineRegistry directly。 Forwarder body
// preserved verbatim per 「依旧 不删除 只 comment」。

#if false  // chapter 七百五十二 第二刀 deactivated
public enum BASChapter415EntropyDoctrine {

    private static var record: BASChapterDoctrineRecord {
        BASChapterDoctrineRegistry.recordFor(
            chapterTag: "chapter 四百十五")!
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

#endif  // chapter 七百五十二 第二刀
