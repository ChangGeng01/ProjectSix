// MARK: - BASChapter419EntropyDoctrineTests — chapter 四百十九 / M1049

import XCTest
@testable import BASRuntimeCore

final class BASChapter419EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter419EntropyDoctrine.chapterTag,
            "chapter 四百十九")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter419EntropyDoctrine.mNumberFirst,
            1046)
        XCTAssertEqual(
            BASChapter419EntropyDoctrine.mNumberLast,
            1049)
    }

    func testV1MilestoneIsAtM1049() {
        XCTAssertEqual(
            BASChapter419EntropyDoctrine.v1MilestoneMNumber,
            1049)
        XCTAssertEqual(
            BASChapter419EntropyDoctrine.v1MilestoneStatus,
            "chapter-419-v1-v2-coherence-envelope-integration")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter419EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter419EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1046, 1047, 1048, 1049])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter419EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter419EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM418AndM419RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter418EntropyDoctrine.mNumberLast + 1,
            BASChapter419EntropyDoctrine.mNumberFirst)
    }
}
