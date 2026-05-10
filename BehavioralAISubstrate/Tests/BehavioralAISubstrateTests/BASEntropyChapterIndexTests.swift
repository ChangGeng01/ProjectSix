// MARK: - BASEntropyChapterIndexTests — chapter 四百三十 / M1092

import XCTest
@testable import BASRuntimeCore

final class BASEntropyChapterIndexTests: XCTestCase {

    // MARK: - 7 RADICAL EVOLUTION entries (after M1108 extension)

    func testSevenRadicalEvolutionEntries() {
        XCTAssertEqual(
            BASEntropyChapterIndex
                .radicalEvolutionEntryCount, 7,
            "M1108 deep-review extension:index covers" +
            " all 7 RADICAL EVOLUTION SWEEP chapters" +
            " (4 phase chapters: 427/428/429/430/431/432" +
            " + 1 final close-out: 433)。 M1092 shipped 5" +
            " entries;430 + 433 added at M1108 once both" +
            " chapter doctrines existed。")
    }

    // MARK: - Entry shape

    func testEntryDirectInit() {
        let entry = BASEntropyChapterEntry(
            chapterTag: "test",
            mNumberFirst: 100,
            mNumberLast: 103,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 5,
            futureCutsCount: 2,
            summary: "test summary")
        XCTAssertEqual(entry.chapterTag, "test")
        XCTAssertEqual(entry.mNumberFirst, 100)
        XCTAssertEqual(entry.mNumberLast, 103)
        XCTAssertEqual(entry.knivesCount, 4)
        XCTAssertEqual(entry.mNumberSpan, 4)
    }

    func testMNumberSpanInclusive() {
        let entry = BASEntropyChapterEntry(
            chapterTag: "x",
            mNumberFirst: 1080,
            mNumberLast: 1083,
            knivesCount: 4,
            entropyClassesCount: 4,
            pinsCount: 0,
            futureCutsCount: 0,
            summary: "")
        XCTAssertEqual(entry.mNumberSpan, 4,
            "span is inclusive on both endpoints" +
            " (M1080+M1081+M1082+M1083 = 4)")
    }

    // MARK: - Index lookups

    func testEntryForTagFound() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: "chapter 四百三十二")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.mNumberFirst, 1100)
        XCTAssertEqual(entry?.mNumberLast, 1103)
    }

    func testEntryForTagNilWhenMissing() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: "chapter does-not-exist")
        XCTAssertNil(entry)
    }

    func testEntryForMNumberFound() {
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1097)
        XCTAssertNotNil(entry)
        XCTAssertEqual(
            entry?.chapterTag,
            "chapter 四百三十一",
            "M1097 lives in chapter 四百三十一's M1096-M1099 range")
    }

    func testEntryForMNumberNilWhenOutsideSweep() {
        // Pre-RADICAL Phase 2 chapters (e.g. M1077 from
        // chapter 426) are NOT indexed — the sweep index
        // covers M1080-M1107 only。
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1077)
        XCTAssertNil(entry,
            "M1077 is outside the RADICAL EVOLUTION" +
            " SWEEP M-range (sweep starts at M1080)")
    }

    func testEntryForMNumberInPhaseDRange() {
        // M1108 extension:M1093 now resolves to
        // chapter 四百三十 (Phase D) instead of nil
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1093)
        XCTAssertEqual(
            entry?.chapterTag,
            "chapter 四百三十",
            "M1093 lives in chapter 四百三十's M1092-M1095" +
            " range (added by M1108 deep-review extension)")
    }

    func testEntryForMNumberInChapter433Range() {
        // M1108 extension:chapter 433 entries now
        // resolve to the typed entry
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1106)
        XCTAssertEqual(
            entry?.chapterTag,
            "chapter 四百三十三",
            "M1106 lives in chapter 四百三十三's M1104-M1107" +
            " range (added by M1108 deep-review extension)")
    }

    // MARK: - Aggregates

    func testTotalKnivesCount() {
        XCTAssertEqual(
            BASEntropyChapterIndex.totalKnivesCount, 28,
            "7 chapters × 4 knives each = 28 (after" +
            " M1108 extension to cover chapters 430 + 433)")
    }

    func testEarliestMNumberIs1080() {
        XCTAssertEqual(
            BASEntropyChapterIndex.earliestMNumber, 1080)
    }

    func testLatestMNumberIs1107() {
        XCTAssertEqual(
            BASEntropyChapterIndex.latestMNumber, 1107,
            "M1108 deep-review extension bumped" +
            " latestMNumber from 1103 → 1107 once" +
            " chapter 433 entry was added")
    }

    // MARK: - Mirroring chapter doctrines

    func testIndexMirrorsChapter427() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: BASChapter427EntropyDoctrine
                .chapterTag)
        XCTAssertEqual(
            entry?.mNumberFirst,
            BASChapter427EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            entry?.mNumberLast,
            BASChapter427EntropyDoctrine.mNumberLast)
    }

    func testIndexMirrorsChapter432() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: BASChapter432EntropyDoctrine
                .chapterTag)
        XCTAssertEqual(
            entry?.mNumberFirst,
            BASChapter432EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            entry?.mNumberLast,
            BASChapter432EntropyDoctrine.mNumberLast)
    }

    // MARK: - M1108 deep-review extension cross-mirror

    func testIndexMirrorsChapter430() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: BASChapter430EntropyDoctrine
                .chapterTag)
        XCTAssertEqual(
            entry?.mNumberFirst,
            BASChapter430EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            entry?.mNumberLast,
            BASChapter430EntropyDoctrine.mNumberLast)
    }

    func testIndexMirrorsChapter433() {
        let entry = BASEntropyChapterIndex.entry(
            forTag: BASChapter433EntropyDoctrine
                .chapterTag)
        XCTAssertEqual(
            entry?.mNumberFirst,
            BASChapter433EntropyDoctrine.mNumberFirst)
        XCTAssertEqual(
            entry?.mNumberLast,
            BASChapter433EntropyDoctrine.mNumberLast)
    }

    // MARK: - Codable round-trip

    func testEntryCodableRoundTrip() throws {
        let original = BASEntropyChapterIndex
            .radicalEvolutionEntries.first!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder()
            .decode(
                BASEntropyChapterEntry.self,
                from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Determinism

    func testIndexIsDeterministic() {
        let a = BASEntropyChapterIndex
            .radicalEvolutionEntries
        let b = BASEntropyChapterIndex
            .radicalEvolutionEntries
        XCTAssertEqual(a, b)
    }
}
