// MARK: - BASChapter416EntropyDoctrineTests — chapter 四百十六 / M1037

import XCTest
@testable import BASRuntimeCore

final class BASChapter416EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter416EntropyDoctrine.chapterTag,
            "chapter 四百十六")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter416EntropyDoctrine.mNumberFirst,
            1034)
        XCTAssertEqual(
            BASChapter416EntropyDoctrine.mNumberLast,
            1037)
    }

    func testV1MilestoneIsAtM1037() {
        XCTAssertEqual(
            BASChapter416EntropyDoctrine.v1MilestoneMNumber,
            1037)
        XCTAssertEqual(
            BASChapter416EntropyDoctrine.v1MilestoneStatus,
            "chapter-416-v1-v2-parallel-summary-envelope-integration")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter416EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter416EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1034, 1035, 1036, 1037])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter416EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter416EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM415AndM416RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter415EntropyDoctrine.mNumberLast + 1,
            BASChapter416EntropyDoctrine.mNumberFirst)
    }

    func testAllFifteenChapterDoctrinesReachable() {
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
            BASChapter414EntropyDoctrine.chapterTag,
            BASChapter415EntropyDoctrine.chapterTag,
            BASChapter416EntropyDoctrine.chapterTag
        ]
        XCTAssertEqual(chapters.count, 15)
        XCTAssertEqual(Set(chapters).count, 15)
    }
}
