// MARK: - BASChapter423EntropyDoctrineTests — chapter 四百二十三 / M1065

import XCTest
@testable import BASRuntimeCore

final class BASChapter423EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter423EntropyDoctrine.chapterTag,
            "chapter 四百二十三")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter423EntropyDoctrine.mNumberFirst,
            1062)
        XCTAssertEqual(
            BASChapter423EntropyDoctrine.mNumberLast,
            1065)
    }

    func testV1MilestoneIsAtM1065() {
        XCTAssertEqual(
            BASChapter423EntropyDoctrine.v1MilestoneMNumber,
            1065)
        XCTAssertEqual(
            BASChapter423EntropyDoctrine.v1MilestoneStatus,
            "chapter-423-v1-v2-roadmap-ops-convenience")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter423EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter423EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1062, 1063, 1064, 1065])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter423EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter423EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM422AndM423RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter422EntropyDoctrine.mNumberLast + 1,
            BASChapter423EntropyDoctrine.mNumberFirst)
    }
}
