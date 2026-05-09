// MARK: - BASChapter408EntropyDoctrineTests — chapter 四百八 / M1005

import XCTest
@testable import BASRuntimeCore

final class BASChapter408EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter408EntropyDoctrine.chapterTag,
            "chapter 四百八")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter408EntropyDoctrine.mNumberFirst, 1002)
        XCTAssertEqual(
            BASChapter408EntropyDoctrine.mNumberLast, 1005)
    }

    func testV1MilestoneIsAtM1005() {
        XCTAssertEqual(
            BASChapter408EntropyDoctrine.v1MilestoneMNumber,
            1005)
        XCTAssertEqual(
            BASChapter408EntropyDoctrine.v1MilestoneStatus,
            "chapter-408-v1-v2-stage-execution-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter408EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter408EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1002, 1003, 1004, 1005])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter408EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter408EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM407AndM408RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter407EntropyDoctrine.mNumberLast + 1,
            BASChapter408EntropyDoctrine.mNumberFirst)
    }

    func testAllEightChapterDoctrinesReachable() {
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
        XCTAssertEqual(
            BASChapter407EntropyDoctrine.chapterTag,
            "chapter 四百七")
        XCTAssertEqual(
            BASChapter408EntropyDoctrine.chapterTag,
            "chapter 四百八")
    }
}
