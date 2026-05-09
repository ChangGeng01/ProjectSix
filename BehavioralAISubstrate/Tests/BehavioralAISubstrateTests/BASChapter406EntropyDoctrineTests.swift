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
            BASChapter406EntropyDoctrine.mNumberLast, 990)
    }

    func testKnivesLedgerCovers2Cuts() {
        XCTAssertEqual(
            BASChapter406EntropyDoctrine.knives.count, 2)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter406EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [989, 990])
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
