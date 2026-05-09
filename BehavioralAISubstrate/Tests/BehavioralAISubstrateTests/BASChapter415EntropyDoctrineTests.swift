// MARK: - BASChapter415EntropyDoctrineTests — chapter 四百十五 / M1033

import XCTest
@testable import BASRuntimeCore

final class BASChapter415EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter415EntropyDoctrine.chapterTag,
            "chapter 四百十五")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter415EntropyDoctrine.mNumberFirst,
            1030)
        XCTAssertEqual(
            BASChapter415EntropyDoctrine.mNumberLast,
            1033)
    }

    func testV1MilestoneIsAtM1033() {
        XCTAssertEqual(
            BASChapter415EntropyDoctrine.v1MilestoneMNumber,
            1033)
        XCTAssertEqual(
            BASChapter415EntropyDoctrine.v1MilestoneStatus,
            "chapter-415-v1-v2-parallel-dispatch-summary-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter415EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter415EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1030, 1031, 1032, 1033])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter415EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter415EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM414AndM415RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter414EntropyDoctrine.mNumberLast + 1,
            BASChapter415EntropyDoctrine.mNumberFirst)
    }

    func testAllFourteenChapterDoctrinesReachable() {
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
            BASChapter415EntropyDoctrine.chapterTag
        ]
        XCTAssertEqual(chapters.count, 14)
        XCTAssertEqual(Set(chapters).count, 14)
    }
}
