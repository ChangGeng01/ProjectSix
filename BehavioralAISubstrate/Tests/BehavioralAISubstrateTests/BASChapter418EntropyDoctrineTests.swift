// MARK: - BASChapter418EntropyDoctrineTests — chapter 四百十八 / M1045

import XCTest
@testable import BASRuntimeCore

final class BASChapter418EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter418EntropyDoctrine.chapterTag,
            "chapter 四百十八")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter418EntropyDoctrine.mNumberFirst,
            1042)
        XCTAssertEqual(
            BASChapter418EntropyDoctrine.mNumberLast,
            1045)
    }

    func testV1MilestoneIsAtM1045() {
        XCTAssertEqual(
            BASChapter418EntropyDoctrine.v1MilestoneMNumber,
            1045)
        XCTAssertEqual(
            BASChapter418EntropyDoctrine.v1MilestoneStatus,
            "chapter-418-v1-v2-plan-ledger-coherence-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter418EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter418EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1042, 1043, 1044, 1045])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter418EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter418EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM417AndM418RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter417EntropyDoctrine.mNumberLast + 1,
            BASChapter418EntropyDoctrine.mNumberFirst)
    }

    func testAllSeventeenChapterDoctrinesReachable() {
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
            BASChapter417EntropyDoctrine.chapterTag,
            BASChapter418EntropyDoctrine.chapterTag
        ]
        XCTAssertEqual(chapters.count, 17)
        XCTAssertEqual(Set(chapters).count, 17)
    }
}
