// MARK: - BASChapter406EntropyDoctrineTests — chapter 四百六 / M990

import XCTest
@testable import BASRuntimeCore

final class BASChapter406EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.chapterTag,
            "chapter 四百六")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.mNumberFirst, 989)
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.mNumberLast, 997)
    }

    func testV1MilestoneIsAtM992() {
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.v1MilestoneMNumber,
            992)
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.v1MilestoneStatus,
            "chapter-406-v1-v2-lifecycle-comprehensive")
    }

    func testV2MilestoneIsAtM997() {
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.v2MilestoneMNumber,
            997)
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.v2MilestoneStatus,
            "chapter-406-v2-v2-param-comprehensive")
    }

    func testKnivesLedgerCovers9CutsAtV2() {
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.knives.count, 9)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter406EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, Array(989...997))
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter406EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter406EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testPinHeldContainsKeyPins() {
        let p = BASChapter406EntropyDoctrine.pinHeld
        XCTAssertTrue(p.contains("不变量 #1"))
        XCTAssertTrue(p.contains("ADR-014"))
        XCTAssertTrue(p.contains("系统熵 reduction"))
    }

    // MARK: - Cross-doctrine adjacency

    func testM405AndM406RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter405EntropyDoctrine.mNumberLast + 1,
            BASChapter406EntropyDoctrine.mNumberFirst)
    }

    func testAllSixChapterDoctrinesReachable() {
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
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.chapterTag,
            "chapter 四百六")
    }
}
