// MARK: - BASChapterDoctrineRecord — chapter 四百六十三 / M1228
// 系统熵 reduction
//
// **STRUCTURAL DEBT REPAYMENT chapter 1** — closes
// the doctrine-sprawl debt called out in chapter 462's
// self-audit:
//
//   "Doctrine 收敛:60+ 个 BASChapter*EntropyDoctrine
//    .swift 文件 × ~200 LOC = ~12K LOC 散文。 原 radical
//    plan Phase D 早就说要 collapse 成 data table,从
//    未执行"
//
// Chapter 463 ships the typed Record + Registry that
// LET future chapters be data entries instead of new
// Swift files。 This chapter does NOT delete existing
// 60+ files (that's a separate destructive operation
// requiring user approval);it ships the schema +
// migrates the 10 latest chapters (453-462) into the
// registry + adds PROOF tests verifying registry
// entries byte-mirror the existing Swift files。
//
// Net effect:
//   - chapter 464+ adds entries to BASChapterDoctrine
//     Registry (~20 LOC of structured data instead
//     of ~200 LOC of Swift static surface)
//   - chapter 465+ can `git rm` the 60+ per-chapter
//     files once their callers (cross-mirror tests)
//     are migrated to registry lookups
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed value-type record;
//     no untyped dict
//   - chapter 二百一一 — single source-of-truth
//     registry;per-chapter Swift files become
//     redundant once cross-mirror proves equality
//   - chapter 三百九二 — record is Codable + Equatable
//     + Sendable so JSON round-trip is byte-stable
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive types;no existing API touched)
//   - 红线 7 — registry is observation/audit,not
//     commitment
//   - ADR-014 OPT-IN — additive

import Foundation

/// Typed record carrying the full doctrine data for
/// one chapter。 Mirrors the static surface of the
/// existing `BASChapter###EntropyDoctrine.swift`
/// files。 chapter 四百六十三 / M1228。
public struct BASChapterDoctrineRecord:
    Equatable, Hashable, Sendable, Codable
{

    /// Chapter tag,e.g. "chapter 四百五十三"。
    public let chapterTag: String

    /// First M-number this chapter covers。
    public let mNumberFirst: Int

    /// Last M-number this chapter covers。
    public let mNumberLast: Int

    /// M-number at which the chapter's v1 milestone
    /// shipped (typically mNumberLast)。
    public let v1MilestoneMNumber: Int

    /// Pinned milestone-status raw string (chapter
    /// 八十七 raw-value stability)。
    public let v1MilestoneStatus: String

    /// Per-knife (m-number,knife label,concept tag)
    /// tuples in chronological order。 Knife labels
    /// are 第一刀/第二刀/etc per chapter 二百一一's
    /// canonical knife schema。
    public let knives: [BASChapterKnife]

    /// Strings enumerating the entropy classes this
    /// chapter attacked。
    public let entropyClassesAttacked: [String]

    /// Doctrine pins held throughout the chapter's
    /// work。
    public let pinHeld: [String]

    /// Planned future cuts identified at chapter
    /// close-out time。
    public let plannedFutureCuts: [String]

    /// Long-form prose summary of the chapter。
    public let summary: String

    public init(
        chapterTag: String,
        mNumberFirst: Int,
        mNumberLast: Int,
        v1MilestoneMNumber: Int,
        v1MilestoneStatus: String,
        knives: [BASChapterKnife],
        entropyClassesAttacked: [String],
        pinHeld: [String],
        plannedFutureCuts: [String],
        summary: String
    ) {
        self.chapterTag = chapterTag
        self.mNumberFirst = max(0, mNumberFirst)
        self.mNumberLast = max(
            mNumberFirst, mNumberLast)
        self.v1MilestoneMNumber =
            max(0, v1MilestoneMNumber)
        self.v1MilestoneStatus = v1MilestoneStatus
        self.knives = knives
        self.entropyClassesAttacked =
            entropyClassesAttacked
        self.pinHeld = pinHeld
        self.plannedFutureCuts = plannedFutureCuts
        self.summary = summary
    }
}

/// Typed per-knife tuple。 Mirrors the
/// `(mNumber, knife, concept)` shape used in
/// `BASChapter###EntropyDoctrine.knives`。 chapter
/// 463 / M1228 made this a typed struct (instead of
/// a tuple) so it's Codable + Equatable + Hashable
/// for registry serialization。
public struct BASChapterKnife:
    Equatable, Hashable, Sendable, Codable
{

    public let mNumber: Int
    public let knife: String
    public let concept: String

    public init(
        mNumber: Int,
        knife: String,
        concept: String
    ) {
        self.mNumber = max(0, mNumber)
        self.knife = knife
        self.concept = concept
    }
}
