// MARK: - BASChapter413EntropyDoctrineTests — chapter 四百十三 / M1025

import XCTest
@testable import BASRuntimeCore

final class BASChapter413EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter413EntropyDoctrine.chapterTag,
            "chapter 四百十三")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter413EntropyDoctrine.mNumberFirst,
            1022)
        XCTAssertEqual(
            BASChapter413EntropyDoctrine.mNumberLast,
            1025)
    }

    func testV1MilestoneIsAtM1025() {
        XCTAssertEqual(
            BASChapter413EntropyDoctrine.v1MilestoneMNumber,
            1025)
        XCTAssertEqual(
            BASChapter413EntropyDoctrine.v1MilestoneStatus,
            "chapter-413-v1-v2-stress-sweep-verdict-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter413EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter413EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1022, 1023, 1024, 1025])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter413EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter413EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM412AndM413RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter412EntropyDoctrine.mNumberLast + 1,
            BASChapter413EntropyDoctrine.mNumberFirst)
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
            BASChapter412EntropyDoctrine.chapterTag,
            BASChapter413EntropyDoctrine.chapterTag
        ]
        XCTAssertEqual(chapters.count, 12,
            "12 chapter doctrines reachable")
        XCTAssertEqual(Set(chapters).count, 12,
            "no duplicates")
    }
}
