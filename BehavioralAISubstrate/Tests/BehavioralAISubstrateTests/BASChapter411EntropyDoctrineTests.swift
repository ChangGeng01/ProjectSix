// MARK: - BASChapter411EntropyDoctrineTests — chapter 四百十一 / M1017

import XCTest
@testable import BASRuntimeCore

final class BASChapter411EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter411EntropyDoctrine.chapterTag,
            "chapter 四百十一")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter411EntropyDoctrine.mNumberFirst,
            1014)
        XCTAssertEqual(
            BASChapter411EntropyDoctrine.mNumberLast,
            1017)
    }

    func testV1MilestoneIsAtM1017() {
        XCTAssertEqual(
            BASChapter411EntropyDoctrine.v1MilestoneMNumber,
            1017)
        XCTAssertEqual(
            BASChapter411EntropyDoctrine.v1MilestoneStatus,
            "chapter-411-v1-v2-stress-sweep-input-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter411EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter411EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1014, 1015, 1016, 1017])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter411EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter411EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM410AndM411RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter410EntropyDoctrine.mNumberLast + 1,
            BASChapter411EntropyDoctrine.mNumberFirst)
    }

    func testAllElevenChapterDoctrinesReachable() {
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
        XCTAssertEqual(
            BASChapter410EntropyDoctrine.chapterTag,
            "chapter 四百十")
        XCTAssertEqual(
            BASChapter411EntropyDoctrine.chapterTag,
            "chapter 四百十一")
    }
}
