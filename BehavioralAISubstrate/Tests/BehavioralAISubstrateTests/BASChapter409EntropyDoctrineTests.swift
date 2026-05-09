// MARK: - BASChapter409EntropyDoctrineTests — chapter 四百九 / M1009

import XCTest
@testable import BASRuntimeCore

final class BASChapter409EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter409EntropyDoctrine.chapterTag,
            "chapter 四百九")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter409EntropyDoctrine.mNumberFirst, 1006)
        XCTAssertEqual(
            BASChapter409EntropyDoctrine.mNumberLast, 1009)
    }

    func testV1MilestoneIsAtM1009() {
        XCTAssertEqual(
            BASChapter409EntropyDoctrine.v1MilestoneMNumber,
            1009)
        XCTAssertEqual(
            BASChapter409EntropyDoctrine.v1MilestoneStatus,
            "chapter-409-v1-v2-stage-plan-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter409EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter409EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1006, 1007, 1008, 1009])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter409EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter409EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM408AndM409RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter408EntropyDoctrine.mNumberLast + 1,
            BASChapter409EntropyDoctrine.mNumberFirst)
    }

    func testAllNineChapterDoctrinesReachable() {
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
        XCTAssertEqual(
            BASChapter409EntropyDoctrine.chapterTag,
            "chapter 四百九")
    }
}
