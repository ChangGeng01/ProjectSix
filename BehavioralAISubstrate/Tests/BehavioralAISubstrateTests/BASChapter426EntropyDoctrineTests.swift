// MARK: - BASChapter426EntropyDoctrineTests — chapter 四百二十六 / M1077

import XCTest
@testable import BASRuntimeCore

final class BASChapter426EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter426EntropyDoctrine.chapterTag,
            "chapter 四百二十六")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter426EntropyDoctrine.mNumberFirst,
            1074)
        XCTAssertEqual(
            BASChapter426EntropyDoctrine.mNumberLast,
            1077)
    }

    func testV1MilestoneIsAtM1077() {
        XCTAssertEqual(
            BASChapter426EntropyDoctrine.v1MilestoneMNumber,
            1077)
        XCTAssertEqual(
            BASChapter426EntropyDoctrine.v1MilestoneStatus,
            "chapter-426-v1-v2-adr018-full-ratification")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter426EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter426EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1074, 1075, 1076, 1077])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter426EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter426EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM425AndM426RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter425EntropyDoctrine.mNumberLast + 1,
            BASChapter426EntropyDoctrine.mNumberFirst)
    }

    func testPinHeldIncludesADR018FullRatification() {
        XCTAssertTrue(
            BASChapter426EntropyDoctrine.pinHeld.contains(
                "ADR-018 FULL RATIFICATION"),
            "chapter 四百二十六 ratifies ALL 4 ADR-018 items")
        XCTAssertTrue(
            BASChapter426EntropyDoctrine.pinHeld.contains(
                "Roadmap 100% complete"),
            "Roadmap progress flips to 100% at M1076")
    }
}
