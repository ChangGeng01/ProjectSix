// MARK: - BASChapter425EntropyDoctrineTests — chapter 四百二十五 / M1073

import XCTest
@testable import BASRuntimeCore

final class BASChapter425EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter425EntropyDoctrine.chapterTag,
            "chapter 四百二十五")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter425EntropyDoctrine.mNumberFirst,
            1070)
        XCTAssertEqual(
            BASChapter425EntropyDoctrine.mNumberLast,
            1073)
    }

    func testV1MilestoneIsAtM1073() {
        XCTAssertEqual(
            BASChapter425EntropyDoctrine.v1MilestoneMNumber,
            1073)
        XCTAssertEqual(
            BASChapter425EntropyDoctrine.v1MilestoneStatus,
            "chapter-425-v1-v2-real-executor-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter425EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter425EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1070, 1071, 1072, 1073])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter425EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter425EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM424AndM425RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter424EntropyDoctrine.mNumberLast + 1,
            BASChapter425EntropyDoctrine.mNumberFirst)
    }

    func testPinHeldIncludesADR018PartialRatification() {
        XCTAssertTrue(
            BASChapter425EntropyDoctrine.pinHeld.contains(
                "ADR-018 PARTIAL RATIFICATION"),
            "chapter 四百二十五 ratifies 2 of 4 ADR-018 items")
    }
}
