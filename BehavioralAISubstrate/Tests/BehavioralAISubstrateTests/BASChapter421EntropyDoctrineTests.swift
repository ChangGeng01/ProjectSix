// MARK: - BASChapter421EntropyDoctrineTests — chapter 四百二十一 / M1057

import XCTest
@testable import BASRuntimeCore

final class BASChapter421EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.chapterTag,
            "chapter 四百二十一")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.mNumberFirst,
            1054)
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.mNumberLast,
            1057)
    }

    func testV1MilestoneIsAtM1057() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.v1MilestoneMNumber,
            1057)
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.v1MilestoneStatus,
            "chapter-421-v1-v2-phase-2-close-out")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter421EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1054, 1055, 1056, 1057])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter421EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter421EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM420AndM421RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter420EntropyDoctrine.mNumberLast + 1,
            BASChapter421EntropyDoctrine.mNumberFirst)
    }

    // MARK: - Phase 2 close-out cross-checks

    func testM1057MatchesPhase2DoctrineLastMNumber() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    func testChapter421IsLastInPhase2Doctrine() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.chapterTag,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last)
    }
}
