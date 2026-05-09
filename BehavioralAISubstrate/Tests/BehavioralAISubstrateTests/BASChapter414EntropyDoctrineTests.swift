// MARK: - BASChapter414EntropyDoctrineTests — chapter 四百十四 / M1029

import XCTest
@testable import BASRuntimeCore

final class BASChapter414EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter414EntropyDoctrine.chapterTag,
            "chapter 四百十四")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter414EntropyDoctrine.mNumberFirst,
            1026)
        XCTAssertEqual(
            BASChapter414EntropyDoctrine.mNumberLast,
            1029)
    }

    func testV1MilestoneIsAtM1029() {
        XCTAssertEqual(
            BASChapter414EntropyDoctrine.v1MilestoneMNumber,
            1029)
        XCTAssertEqual(
            BASChapter414EntropyDoctrine.v1MilestoneStatus,
            "chapter-414-v1-v2-parallel-dispatch-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter414EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter414EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1026, 1027, 1028, 1029])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter414EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter414EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM413AndM414RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter413EntropyDoctrine.mNumberLast + 1,
            BASChapter414EntropyDoctrine.mNumberFirst)
    }

    func testAllThirteenChapterDoctrinesReachable() {
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
            BASChapter413EntropyDoctrine.chapterTag,
            BASChapter414EntropyDoctrine.chapterTag
        ]
        XCTAssertEqual(chapters.count, 13,
            "13 chapter doctrines reachable")
        XCTAssertEqual(Set(chapters).count, 13,
            "no duplicates")
    }
}
