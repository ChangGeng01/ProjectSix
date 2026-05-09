// MARK: - BASChapter405EntropyDoctrineTests — chapter 四百五 / M983

import XCTest
@testable import BASRuntimeCore

final class BASChapter405EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter405EntropyDoctrine.chapterTag,
            "chapter 四百五")
    }

    func testMNumberRangeOpensAtM981() {
        XCTAssertEqual(
            BASChapter405EntropyDoctrine.mNumberFirst, 981)
        XCTAssertEqual(
            BASChapter405EntropyDoctrine.mNumberLast, 983)
    }

    func testKnivesLedgerCovers3Cuts() {
        XCTAssertEqual(
            BASChapter405EntropyDoctrine.knives.count, 3)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter405EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [981, 982, 983])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter405EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter405EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testPinHeldContainsKeyPins() {
        let p = BASChapter405EntropyDoctrine.pinHeld
        XCTAssertTrue(p.contains("不变量 #1"))
        XCTAssertTrue(p.contains("ADR-014"))
        XCTAssertTrue(p.contains("系统熵 reduction"))
    }

    // MARK: - Cross-doctrine adjacency

    func testM404AndM405RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.mNumberLast + 1,
            BASChapter405EntropyDoctrine.mNumberFirst)
    }

    func testAllFiveChapterDoctrinesReachable() {
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.chapterTag,
            "chapter 四百二")
        XCTAssertEqual(
            BASChapter403EntropyDoctrine.chapterTag,
            "chapter 四百三")
        XCTAssertEqual(
            BASChapter404EntropyDoctrine.chapterTag,
            "chapter 四百四")
        XCTAssertEqual(
            BASChapter405EntropyDoctrine.chapterTag,
            "chapter 四百五")
    }
}
