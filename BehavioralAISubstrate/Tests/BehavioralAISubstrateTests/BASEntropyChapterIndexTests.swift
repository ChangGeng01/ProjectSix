// MARK: - BASEntropyChapterIndexTests — chapter 四百三十 / M1092

import XCTest
@testable import BASRuntimeCore

final class BASEntropyChapterIndexTests: XCTestCase {

    // MARK: - 5 RADICAL EVOLUTION entries

    func testFiveRadicalEvolutionEntries() {
        XCTAssertEqual(
            BASEntropyChapterIndex
                .radicalEvolutionEntryCount, 5,
            "Phase D ships index covering the 5 RADICAL " +
            "EVOLUTION SWEEP chapters: 427/428/429/431/432")
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

    func testEntryForMNumberNilWhenInGap() {
        // M1093 lives in the M1092-M1095 reserved gap
        // — NO indexed chapter covers it
        let entry = BASEntropyChapterIndex.entry(
            forMNumber: 1093)
        XCTAssertNil(entry,
            "M1093 is in the M1092-M1095 reserved gap" +
            " for Phase D backfill — no chapter covers" +
            " it yet")
    }

    // MARK: - Aggregates

    func testTotalKnivesCount() {
        XCTAssertEqual(
            BASEntropyChapterIndex.totalKnivesCount, 20,
            "5 chapters × 4 knives each = 20")
    }

    func testEarliestMNumberIs1080() {
        XCTAssertEqual(
            BASEntropyChapterIndex.earliestMNumber, 1080)
    }

    func testLatestMNumberIs1103() {
        XCTAssertEqual(
            BASEntropyChapterIndex.latestMNumber, 1103)
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
