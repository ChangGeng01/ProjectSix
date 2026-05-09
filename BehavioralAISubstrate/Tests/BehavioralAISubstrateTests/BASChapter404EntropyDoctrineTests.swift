// MARK: - BASChapter404EntropyDoctrineTests — chapter 四百四 / M965

import XCTest
@testable import BASRuntimeCore

final class BASChapter404EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.chapterTag,
            "chapter 四百四")
    }

    func testMNumberRangeOpensAtM963() {
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.mNumberFirst, 963)
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.mNumberLast, 974,
            "M974 v2 close-out bumps mNumberLast")
    }

    func testV1MilestoneIsAtM969() {
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.v1MilestoneMNumber,
            969)
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.v1MilestoneStatus,
            "chapter-404-v1-complete")
    }

    func testV2MilestoneIsAtM974() {
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.v2MilestoneMNumber,
            974)
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.v2MilestoneStatus,
            "chapter-404-v2-complete")
    }

    func testKnivesLedgerCovers12CutsAtV2() {
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.knives.count, 12,
            "M974 v2 close-out: 12 cuts ship in chapter 四百四 v2")
    }

    func testKnivesLedgerCoversFullMRange() {
        let mNumbers = BASChapter404EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(mNumbers, Array(963...974))
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter404EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter404EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testPinHeldContainsKeyPins() {
        let pins = BASChapter404EntropyDoctrine.pinHeld
        XCTAssertTrue(pins.contains("不变量 #1"))
        XCTAssertTrue(pins.contains("chapter 二百一一"))
        XCTAssertTrue(pins.contains("ADR-014"))
        XCTAssertTrue(pins.contains("系统熵 reduction"))
    }

    // MARK: - Cross-doctrine consistency

    func testM403AndM404RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter403EntropyDoctrine.mNumberLast + 1,
            BASChapter404EntropyDoctrine.mNumberFirst)
    }

    func testAllChapterDoctrinesReachable() {
        // All 4 chapter doctrines exposed from one test
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.chapterTag,
            "chapter 四百二")
        XCTAssertEqual(
            BASChapter403EntropyDoctrine.chapterTag,
            "chapter 四百三")
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.chapterTag,
            "chapter 四百四")
    }

    func testSummaryNonEmpty() {
        XCTAssertFalse(
            BASChapter404EntropyDoctrine.summary.isEmpty)
    }
}
