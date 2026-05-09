// MARK: - BASChapter417EntropyDoctrineTests — chapter 四百十七 / M1041

import XCTest
@testable import BASRuntimeCore

final class BASChapter417EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter417EntropyDoctrine.chapterTag,
            "chapter 四百十七")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter417EntropyDoctrine.mNumberFirst,
            1038)
        XCTAssertEqual(
            BASChapter417EntropyDoctrine.mNumberLast,
            1041)
    }

    func testV1MilestoneIsAtM1041() {
        XCTAssertEqual(
            BASChapter417EntropyDoctrine.v1MilestoneMNumber,
            1041)
        XCTAssertEqual(
            BASChapter417EntropyDoctrine.v1MilestoneStatus,
            "chapter-417-v1-v2-stage-ledger-validation-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter417EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter417EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1038, 1039, 1040, 1041])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter417EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter417EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM416AndM417RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter416EntropyDoctrine.mNumberLast + 1,
            BASChapter417EntropyDoctrine.mNumberFirst)
    }

    func testAllSixteenChapterDoctrinesReachable() {
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
            BASChapter416EntropyDoctrine.chapterTag,
            BASChapter417EntropyDoctrine.chapterTag
        ]
        XCTAssertEqual(chapters.count, 16)
        XCTAssertEqual(Set(chapters).count, 16)
    }
}
