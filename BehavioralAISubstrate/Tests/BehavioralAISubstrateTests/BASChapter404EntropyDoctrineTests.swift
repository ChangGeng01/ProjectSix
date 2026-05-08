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
            BASChapter404EntropyDoctrine.mNumberLast, 965)
    }

    func testKnivesLedgerCovers3Cuts() {
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.knives.count, 3)
    }

    func testKnivesLedgerCoversFullMRange() {
        let mNumbers = BASChapter404EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(mNumbers, [963, 964, 965])
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
