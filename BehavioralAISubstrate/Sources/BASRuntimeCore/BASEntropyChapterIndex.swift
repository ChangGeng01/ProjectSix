// MARK: - BASEntropyChapterIndex — M1092 / chapter 七百二 native-port
//
// chapter 七百二 native-port — DATA PORT。 The original
// 7,239-line Swift file held 3 hand-maintained static
// arrays (radicalEvolutionEntries, phase2Entries,
// postSweepRealExecutionEntries) of BASEntropyChapter
// Entry records。 All 3 were JSON-encoded once via
// __OneShotJSONDumper and committed as Resources/
// entropy_chapter_index.json。 This file is now a
// ~140-LOC loader + accessor preservation layer。 Net
// Swift LOC drop: ~7,100。
//
// ## Why this is safe
//
// `BASEntropyChapterIndexTests` only asserts:
//   - field values (mNumberFirst, mNumberLast, knives
//     Count, etc.) on entries retrieved via the
//     `entry(forTag:)` / `entry(forMNumber:)` accessors
//   - `totalKnivesCount`, `earliestMNumber`,
//     `latestMNumber` derived properties
// None of these are byte-pinned;all are computed by
// reduction over the array contents。 Codable round-
// trip preserves field values → tests stay green。

import Foundation

/// Typed single-table index of every shipped chapter
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

public enum BASEntropyChapterIndex {

    /// chapter 七百二 native-port — JSON-decoded triple
    /// bundle (radicalEvolutionEntries + phase2Entries +
    /// postSweepRealExecutionEntries)。 Cached via lazy
    /// static let so decode runs once。
    private struct BundleShape: Codable {
        let radicalEvolutionEntries: [BASEntropyChapterEntry]
        let phase2Entries: [BASEntropyChapterEntry]
        let postSweepRealExecutionEntries: [BASEntropyChapterEntry]
    }

    private static let bundle: BundleShape = {
        guard let url = Bundle.module.url(
            forResource: "entropy_chapter_index",
            withExtension: "json")
        else {
            fatalError(
                "chapter 七百二 native-port:" +
                " entropy_chapter_index.json missing" +
                " from BASRuntimeCore Resources")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(
                BundleShape.self, from: data)
        } catch {
            fatalError(
                "chapter 七百二 native-port:" +
                " failed to decode" +
                " entropy_chapter_index.json: \(error)")
        }
    }()

    public static var radicalEvolutionEntries:
        [BASEntropyChapterEntry] {
        return bundle.radicalEvolutionEntries
    }

    public static var radicalEvolutionEntryCount: Int {
        return radicalEvolutionEntries.count
    }

    public static var phase2Entries:
        [BASEntropyChapterEntry] {
        return bundle.phase2Entries
    }

    public static var phase2EntryCount: Int {
        return phase2Entries.count
    }

    public static var postSweepRealExecutionEntries:
        [BASEntropyChapterEntry] {
        return bundle.postSweepRealExecutionEntries
    }

    // MARK: - Phase 2 accessors (M1111)

    /// Look up a Phase 2 entry by chapter tag。 Returns
    /// nil if no match in the 31-entry Phase 2 mirror。
    public static func phase2Entry(
        forTag tag: String
    ) -> BASEntropyChapterEntry? {
        return phase2Entries.first {
            $0.chapterTag == tag
        }
    }

    /// Look up a Phase 2 entry covering the given
    /// M-number。 Returns nil if no Phase 2 chapter
    /// spans the number。
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
            if entry.mNumberFirst <= first
                && entry.mNumberLast >= last
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
