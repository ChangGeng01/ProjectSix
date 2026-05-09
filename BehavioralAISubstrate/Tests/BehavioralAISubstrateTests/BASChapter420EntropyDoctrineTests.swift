// MARK: - BASChapter420EntropyDoctrineTests — chapter 四百二十 / M1053

import XCTest
@testable import BASRuntimeCore

final class BASChapter420EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter420EntropyDoctrine.chapterTag,
            "chapter 四百二十")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter420EntropyDoctrine.mNumberFirst,
            1050)
        XCTAssertEqual(
            BASChapter420EntropyDoctrine.mNumberLast,
            1053)
    }

    func testV1MilestoneIsAtM1053() {
        XCTAssertEqual(
            BASChapter420EntropyDoctrine.v1MilestoneMNumber,
            1053)
        XCTAssertEqual(
            BASChapter420EntropyDoctrine.v1MilestoneStatus,
            "chapter-420-v1-v2-summary-digest-foundation")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter420EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter420EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1050, 1051, 1052, 1053])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter420EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter420EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM419AndM420RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter419EntropyDoctrine.mNumberLast + 1,
            BASChapter420EntropyDoctrine.mNumberFirst)
    }
}
