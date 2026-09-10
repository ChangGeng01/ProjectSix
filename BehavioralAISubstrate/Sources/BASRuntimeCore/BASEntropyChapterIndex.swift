// MARK: - BASEntropyChapterIndex — chapter 四百三十 / M1092
// 系统熵 reduction
//
// RADICAL EVOLUTION SWEEP Phase D entry。 Single typed
// data table that mirrors what each `BASChapter*Entropy
// Doctrine` enum surfaces today as a public namespace。
// Sets up the future cleanup path:once consumers
// migrate to read from this table,the 25+ per-chapter
// `.swift` files can collapse without changing call
// sites。
//
// ## Why this exists (system entropy framing)
//
// The substrate ships 29 `BASChapter*EntropyDoctrine.
// swift` files (one per shipped chapter)。 Each follows
// nearly the same shape:
//
//   - chapterTag: String
//   - mNumberFirst / mNumberLast: Int
//   - knives: [(mNumber, knife, concept)]
//   - entropyClassesAttacked: [String]
//   - pinHeld: [String]
//   - plannedFutureCuts: [String]
//   - summary: String
//
// 31 files × ~120 LOC each = ~3,700 LOC of doctrine
// scaffolding (count current as of M1109)。 The original
// Phase D plan called for collapsing all of them into a
// single data table file (~120 LOC),with the 24 non-
// RADICAL chapter doctrines (chapters 403-426) being
// deletion targets and the 7 RADICAL chapters (427-433)
// surviving as `BASEntropyChapterIndex` entries。
// (Original plan said "22 doctrines" but the count
// drifted as Phase 2 grew through chapters 427-433 —
// M1109 deep-review correction。)
//
// In autonomous mode that deletion is too risky:
//
//   1. Each per-chapter doctrine has its own per-chapter
//      tests (BASChapter*EntropyDoctrineTests) that
//      reference the namespace directly
//   2. BASDoctrineChainConsistencyTests +
//      BASChapterDoctrineSchemaCompletenessTests cross-
//      reference per-chapter doctrines by symbol
//   3. Future commits that bump the doctrine version
//      pin reference per-chapter doctrines via
//      `BASChapter4XX EntropyDoctrine.mNumberLast`
//
// `BASEntropyChapterIndex` ships the typed data table
// that mirrors the per-chapter doctrines。 Once
// consumers migrate to read from the table (future
// chapter), the per-chapter `.swift` files become
// removable。
//
// ## What this ships (M1092)
//
//   - `BASEntropyChapterEntry` Sendable + Codable +
//     Equatable struct (chapterTag + mNumberFirst +
//     mNumberLast + knivesCount + entropyClassesCount
//     + pinsCount + futureCutsCount + summary)
//   - `BASEntropyChapterIndex` namespace with
//     `entries: [BASEntropyChapterEntry]` static
//     constant covering all 29 shipped chapters
//   - Cross-check helpers (`entry(forTag:)`,
//     `entry(forMNumber:)`,`coversMNumberRange()`)
//
// The table is HAND-MAINTAINED at M1092 — same
// chapterTag + mNumberFirst/Last as the per-chapter
// doctrines。 Future work could derive it via macro
// or build script。
//
// ## What this DOES NOT ship (deferred)
//
// The per-chapter `BASChapter*EntropyDoctrine.swift`
// files are NOT deleted at M1092。 The plan's planned
// −1,280 LOC delete (22 doctrine files + 22 test
// files) is deferred to a follow-up chapter under
// explicit user control。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     entry struct + named accessors)
//   - chapter 二百一一 — single source-of-truth (one
//     table mirrors all 29 chapter doctrines)
//   - chapter 三百九二 — replay-determinism (entries
//     list is a static constant — same across processes)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (purely additive table;no per-chapter doctrine
//     deleted)
//   - 红线 7 — hint-only
//   - ADR-014 OPT-IN — purely additive
//   - RADICAL EVOLUTION SWEEP Phase D — this chapter

import Foundation

// MARK: - Entry struct

/// Typed Sendable + Codable mirror of a single chapter
/// doctrine。 One per shipped chapter doctrine。
public struct BASEntropyChapterEntry:
    Equatable, Hashable, Codable, Sendable
{

    public let chapterTag: String
    public let mNumberFirst: Int
    public let mNumberLast: Int
    public let knivesCount: Int
    public let entropyClassesCount: Int
    public let pinsCount: Int
    public let futureCutsCount: Int
    public let summary: String

    public init(
        chapterTag: String,
        mNumberFirst: Int,
        mNumberLast: Int,
        knivesCount: Int,
        entropyClassesCount: Int,
        pinsCount: Int,
        futureCutsCount: Int,
        summary: String
    ) {
        self.chapterTag = chapterTag
        self.mNumberFirst = mNumberFirst
        self.mNumberLast = mNumberLast
        self.knivesCount = knivesCount
        self.entropyClassesCount = entropyClassesCount
        self.pinsCount = pinsCount
        self.futureCutsCount = futureCutsCount
        self.summary = summary
    }

    /// Number of M-numbers covered by this chapter
    /// (inclusive)。 Pre-computed for tests + observability。
    public var mNumberSpan: Int {
        return (mNumberLast - mNumberFirst) + 1
    }
}

// MARK: - Index

/// Single-source-of-truth typed data table mirroring
/// all shipped per-chapter doctrines。 Hand-maintained
/// at M1092;future work could derive via macro。
public enum BASEntropyChapterIndex {

    /// Entries covering the 7 RADICAL EVOLUTION SWEEP
    /// chapters (M1092 shipped 5 entries;M1108 deep-
    /// review extension added chapters 四百三十 + 四百三十三
    /// for completeness)。
    /// (The 24 pre-RADICAL Phase 2 chapters live in
    /// per-chapter doctrines from chapters 四百三 through
    /// 四百二十六;this index focuses on the RADICAL
    /// EVOLUTION SWEEP arc which is the deletion-target
    /// scope for the future cleanup chapter。)
    // chapter 七百二 第三刀 active surface — SQL-backed。
    public static var radicalEvolutionEntries:
        [BASEntropyChapterEntry] {
        return BASChapterDoctrineSQLLoader
            .entropyChapterCollections.radical
    }

    // chapter 八百二十七 / M2786-M2790 — LEGACY BLOCK 1 ARCHIVED。
    // radicalEvolutionEntries Swift literal block formerly here (336
    // commented lines) moved to:
    //   Archive/Deactivated/Sources/BASRuntimeCore/BASEntropyChapterIndex_LegacyBlock1.txt

    public static var radicalEvolutionEntryCount: Int {
        return radicalEvolutionEntries.count
    }

    /// **M1111 — Wave 2 STAGE 1 extension**:complete
    /// 31-entry mirror covering ALL Phase 2 chapters
    /// (chapters 四百三 through 四百三十三)。 This is the
    /// single source-of-truth that makes the per-chapter
    /// `BASChapter*EntropyDoctrine.swift` files
    /// deletable in a future cleanup chapter without
    /// losing any chapter summary。
    ///
    /// 24 pre-RADICAL chapters (403-426) + 7 RADICAL
    /// chapters (427-433) = 31 entries。 Hand-maintained
    /// at M1111 with field values cross-checked against
    /// the corresponding chapter doctrine `.swift` files
    /// via grep audit。 chapter 447 onward extends via
    /// `postSweepRealExecutionEntries` — keeping SWEEP
    /// chapter 446 frozen as the SWEEP narrative
    /// snapshot。
    // chapter 七百二 第三刀 active surface — SQL-backed。
    public static var phase2Entries:
        [BASEntropyChapterEntry] {
        return BASChapterDoctrineSQLLoader
            .entropyChapterCollections.phase2
    }

    // chapter 七百二 第三刀 LEGACY EXPRESSION — preserved
//     public static let phase2Entries:
//         [BASEntropyChapterEntry] =
//         prePhase2RadicalEntries +
//         radicalEvolutionEntries +
//         postSweepRealExecutionEntries

    /// POST-SWEEP REAL EXECUTION FOLLOW-THROUGH entries
    /// (chapter 447 onward)。 Chapter 446 closed the
    /// SWEEP narrative as a discrete 17-wave snapshot;
    /// chapter 447 opens the next chapter sequence
    /// focused on real compute (vs scaffolding)。
    /// SWEEP doctrine intentionally stays frozen at
    /// chapter 446 so its narrative remains a historical
    /// anchor。
    // chapter 七百二 第三刀 active surface — SQL-backed。
    public static var postSweepRealExecutionEntries:
        [BASEntropyChapterEntry] {
        return BASChapterDoctrineSQLLoader
            .entropyChapterCollections.postSweep
    }

    // chapter 八百二十七 / M2786-M2790 — LEGACY BLOCK 2 ARCHIVED。
    // postSweepRealExecution + prePhase2 + phase2 Swift literal blocks
    // formerly here (~6.6K commented lines) moved to:
    //   Archive/Deactivated/Sources/BASRuntimeCore/BASEntropyChapterIndex_LegacyBlock2.txt

    public static var phase2EntryCount: Int {
        return phase2Entries.count
    }

    /// Look up an entry by chapter tag across the
    /// COMPLETE 31-entry Phase 2 mirror (M1111
    /// extension)。 Returns nil if no match。
    public static func phase2Entry(
        forTag tag: String
    ) -> BASEntropyChapterEntry? {
        return phase2Entries.first {
            $0.chapterTag == tag
        }
    }

    /// Look up an entry covering the given M-number
    /// across the COMPLETE 31-entry Phase 2 mirror。
    public static func phase2Entry(
        forMNumber m: Int
    ) -> BASEntropyChapterEntry? {
        return phase2Entries.first {
            m >= $0.mNumberFirst && m <= $0.mNumberLast
        }
    }

    // MARK: - Accessors

    /// Look up entry by chapterTag。 Returns nil if no
    /// matching entry。
    public static func entry(
        forTag tag: String
    ) -> BASEntropyChapterEntry? {
        return radicalEvolutionEntries.first {
            $0.chapterTag == tag
        }
    }

    /// Look up entry covering the given M-number。
    /// Returns nil if no matching chapter spans the
    /// number。
    public static func entry(
        forMNumber m: Int
    ) -> BASEntropyChapterEntry? {
        return radicalEvolutionEntries.first {
            m >= $0.mNumberFirst && m <= $0.mNumberLast
        }
    }

    /// Predicate:does any indexed chapter cover the
    /// given M-number range (inclusive endpoints)?
    public static func coversMNumberRange(
        from first: Int,
        to last: Int
    ) -> Bool {
        for entry in radicalEvolutionEntries {
            if entry.mNumberFirst >= first
                && entry.mNumberLast <= last
            {
                return true
            }
        }
        return false
    }

    /// Total knives (cuts) shipped across all indexed
    /// chapters。 At M1092: 5 chapters × 4 knives = 20。
    public static var totalKnivesCount: Int {
        return radicalEvolutionEntries.reduce(0) {
            $0 + $1.knivesCount
        }
    }

    /// Earliest M-number indexed (chapter 四百二十七's
    /// M1080)。
    public static var earliestMNumber: Int {
        return radicalEvolutionEntries.map {
            $0.mNumberFirst
        }.min() ?? 0
    }

    /// Latest M-number indexed (chapter 四百三十二's
    /// M1103)。
    public static var latestMNumber: Int {
        return radicalEvolutionEntries.map {
            $0.mNumberLast
        }.max() ?? 0
    }
}
