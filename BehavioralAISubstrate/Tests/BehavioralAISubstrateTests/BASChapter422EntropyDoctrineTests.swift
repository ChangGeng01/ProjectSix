// MARK: - BASChapter422EntropyDoctrineTests — chapter 四百二十二 / M1061

import XCTest
@testable import BASRuntimeCore

final class BASChapter422EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter422EntropyDoctrine.chapterTag,
            "chapter 四百二十二")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter422EntropyDoctrine.mNumberFirst,
            1058)
        XCTAssertEqual(
            BASChapter422EntropyDoctrine.mNumberLast,
            1061)
    }

    func testV1MilestoneIsAtM1061() {
        XCTAssertEqual(
            BASChapter422EntropyDoctrine.v1MilestoneMNumber,
            1061)
        XCTAssertEqual(
            BASChapter422EntropyDoctrine.v1MilestoneStatus,
            "chapter-422-v1-v2-substrate-integrity")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter422EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter422EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1058, 1059, 1060, 1061])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter422EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter422EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM421AndM422RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter421EntropyDoctrine.mNumberLast + 1,
            BASChapter422EntropyDoctrine.mNumberFirst)
    }
}
