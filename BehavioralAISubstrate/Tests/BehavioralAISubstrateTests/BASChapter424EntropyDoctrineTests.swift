// MARK: - BASChapter424EntropyDoctrineTests — chapter 四百二十四 / M1069

import XCTest
@testable import BASRuntimeCore

final class BASChapter424EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter424EntropyDoctrine.chapterTag,
            "chapter 四百二十四")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter424EntropyDoctrine.mNumberFirst,
            1066)
        XCTAssertEqual(
            BASChapter424EntropyDoctrine.mNumberLast,
            1069)
    }

    func testV1MilestoneIsAtM1069() {
        XCTAssertEqual(
            BASChapter424EntropyDoctrine.v1MilestoneMNumber,
            1069)
        XCTAssertEqual(
            BASChapter424EntropyDoctrine.v1MilestoneStatus,
            "chapter-424-v1-v2-doctrine-chain-consistency")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter424EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter424EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1066, 1067, 1068, 1069])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter424EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter424EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    func testM423AndM424RangesAreAdjacent() {
        XCTAssertEqual(
            BASChapter423EntropyDoctrine.mNumberLast + 1,
            BASChapter424EntropyDoctrine.mNumberFirst)
    }
}
