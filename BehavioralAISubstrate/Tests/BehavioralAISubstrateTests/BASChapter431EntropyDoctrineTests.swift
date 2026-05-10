// MARK: - BASChapter431EntropyDoctrineTests — chapter 四百三十一 / M1099

import XCTest
@testable import BASRuntimeCore

final class BASChapter431EntropyDoctrineTests: XCTestCase {

    // MARK: - Chapter tag

    func testChapterTagIs431() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.chapterTag,
            "chapter 四百三十一")
    }

    // MARK: - M-number range

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.mNumberFirst,
            1096)
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.mNumberLast,
            1099)
    }

    // MARK: - V1 milestone

    func testV1MilestoneIsAtM1099() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.v1MilestoneMNumber,
            1099)
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.v1MilestoneStatus,
            "chapter-431-v1-native-apple-silicon-foundation")
    }

    // MARK: - 4-cut ledger

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter431EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1096, 1097, 1098, 1099])
    }

    // MARK: - Entropy classes + future cuts populated

    func testEntropyClassesAttacked4() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine
                .entropyClassesAttacked.count, 4,
            "one entropy class per knife")
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter431EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    // MARK: - Reserved gap M1084-M1095

    func testM427EndsAtM1083AndM431StartsAtM1096() {
        XCTAssertEqual(
            BASChapter427EntropyDoctrine.mNumberLast, 1083)
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.mNumberFirst,
            1096,
            "M1084-M1095 reserved gap — Phase B/C/D" +
            " backfill at chapters 四百二十八/四百二十九/四百三十" +
            " (RADICAL EVOLUTION SWEEP Phase E starts at" +
            " M1096 with BASMetalSubstrate entry)")
    }

    // MARK: - Phase tag pin

    func testPinHeldIncludesRadicalEvolutionPhaseE() {
        XCTAssertTrue(
            BASChapter431EntropyDoctrine.pinHeld.contains(
                "RADICAL EVOLUTION SWEEP Phase E"),
            "chapter 四百三十一 ships RADICAL EVOLUTION " +
            "SWEEP Phase E entry (NATIVE APPLE SILICON " +
            "FOUNDATION)")
    }

    // MARK: - Phase 2 doctrine cross-check

    func testChapter431IsLastInPhase2Doctrine() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.chapterTag,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last)
    }

    func testM1099MatchesPhase2DoctrineLastMNumber() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    // MARK: - Determinism

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.knives.count,
            BASChapter431EntropyDoctrine.knives.count)
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.summary,
            BASChapter431EntropyDoctrine.summary)
    }
}
