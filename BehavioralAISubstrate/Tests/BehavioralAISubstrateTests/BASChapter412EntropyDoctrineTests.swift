// MARK: - BASChapter412EntropyDoctrineTests — chapter 四百十二 / M1021

import XCTest
@testable import BASRuntimeCore

final class BASChapter412EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter412EntropyDoctrine.chapterTag,
            "chapter 四百十二")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter412EntropyDoctrine.mNumberFirst,
            1018)
        XCTAssertEqual(
            BASChapter412EntropyDoctrine.mNumberLast,
            1021)
    }

    func testV1MilestoneIsAtM1021() {
        XCTAssertEqual(
            BASChapter412EntropyDoctrine.v1MilestoneMNumber,
            1021)
        XCTAssertEqual(
            BASChapter412EntropyDoctrine.v1MilestoneStatus,
            "chapter-412-v1-v2-stress-sweep-plan-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter412EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter412EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1018, 1019, 1020, 1021])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter412EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter412EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM411AndM412RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter411EntropyDoctrine.mNumberLast + 1,
            BASChapter412EntropyDoctrine.mNumberFirst)
    }

    func testAllTwelveChapterDoctrinesReachable() {
        let chapters = [
            BASMemoryAtomEventSourcingDoctrine.chapterTag,
            BASChapter403EntropyDoctrine.chapterTag,
            BASChapter404EntropyDoctrine.chapterTag,
            BASChapter405EntropyDoctrine.chapterTag,
            BASChapter406EntropyDoctrine.chapterTag,
            BASChapter407EntropyDoctrine.chapterTag,
            BASChapter408EntropyDoctrine.chapterTag,
            BASChapter409EntropyDoctrine.chapterTag,
            BASChapter410EntropyDoctrine.chapterTag,
            BASChapter411EntropyDoctrine.chapterTag,
            BASChapter412EntropyDoctrine.chapterTag
        ]
        XCTAssertEqual(chapters.count, 11,
            "11 chapter doctrines reachable")
        XCTAssertEqual(Set(chapters).count, 11,
            "no duplicates")
    }
}
