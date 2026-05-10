// MARK: - BASChapter427EntropyDoctrineTests — chapter 四百二十七 / M1083

import XCTest
@testable import BASRuntimeCore

final class BASChapter427EntropyDoctrineTests: XCTestCase {

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.chapterTag,
            "chapter 四百二十七")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.mNumberFirst,
            1080)
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.mNumberLast,
            1083)
    }

    func testV1MilestoneIsAtM1083() {
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.v1MilestoneMNumber,
            1083)
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.v1MilestoneStatus,
            "chapter-427-v1-v2-runtime-composition-surface")
    }

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter427EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1080, 1081, 1082, 1083])
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter427EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter427EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    // MARK: - M1078-M1079 reserved gap (NOT contiguous to 426)

    func testM426EndsAtM1077AndM427StartsAtM1080() {
        XCTAssertEqual(
            BASChapter426EntropyDoctrine.mNumberLast, 1077)
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.mNumberFirst,
            1080,
            "M1078-M1079 reserved gap — RADICAL EVOLUTION" +
            " SWEEP Phase A starts at M1080 with delegate" +
            " scaffolding")
    }

    func testPinHeldIncludesRadicalEvolutionPhaseA() {
        XCTAssertTrue(
            BASChapter427EntropyDoctrine.pinHeld.contains(
                "RADICAL EVOLUTION SWEEP Phase A"),
            "chapter 四百二十七 ships RADICAL EVOLUTION " +
            "SWEEP Phase A entry")
    }
}
