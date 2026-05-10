// MARK: - BASChapter432EntropyDoctrineTests — chapter 四百三十二 / M1103

import XCTest
@testable import BASRuntimeCore

final class BASChapter432EntropyDoctrineTests: XCTestCase {

    // MARK: - Chapter tag

    func testChapterTagIs432() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.chapterTag,
            "chapter 四百三十二")
    }

    // MARK: - M-number range

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.mNumberFirst,
            1100)
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.mNumberLast,
            1103)
    }

    // MARK: - V1 milestone

    func testV1MilestoneIsAtM1103() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.v1MilestoneMNumber,
            1103)
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.v1MilestoneStatus,
            "chapter-432-v1-hardware-aware-scheduler-composition")
    }

    // MARK: - 4-cut ledger

    func testKnivesLedgerCovers4Cuts() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.knives.count, 4)
    }

    func testKnivesLedgerCoversFullMRange() {
        let m = BASChapter432EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(m, [1100, 1101, 1102, 1103])
    }

    // MARK: - Entropy classes + future cuts populated

    func testEntropyClassesAttacked4() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine
                .entropyClassesAttacked.count, 4,
            "one entropy class per knife")
    }

    func testFutureCutsRoadmapNonEmpty() {
        XCTAssertFalse(
            BASChapter432EntropyDoctrine
                .plannedFutureCuts.isEmpty)
    }

    // MARK: - Chapter 431 ends at M1099, chapter 432 starts at M1100

    func testM431EndsAtM1099AndM432StartsAtM1100() {
        XCTAssertEqual(
            BASChapter431EntropyDoctrine.mNumberLast, 1099)
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.mNumberFirst,
            1100,
            "Phase F starts contiguous to Phase E close-out")
    }

    // MARK: - Phase F pin

    func testPinHeldIncludesRadicalEvolutionPhaseF() {
        XCTAssertTrue(
            BASChapter432EntropyDoctrine.pinHeld.contains(
                "RADICAL EVOLUTION SWEEP Phase F"),
            "chapter 四百三十二 ships RADICAL EVOLUTION " +
            "SWEEP Phase F entry (HARDWARE-AWARE SCHEDULER " +
            "COMPOSITION)")
    }

    // MARK: - Phase 2 doctrine cross-check (terminal)

    func testChapter432IsLastInPhase2Doctrine() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.chapterTag,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last)
    }

    func testM1103MatchesPhase2DoctrineLastMNumber() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }

    // MARK: - ADR-014 OPT-IN preservation noted in pin

    func testADR014OPTINIsExplicitlyPinned() {
        XCTAssertTrue(
            BASChapter432EntropyDoctrine.pinHeld.contains {
                $0.contains("ADR-014 OPT-IN")
            },
            "Phase F must explicitly pin ADR-014 OPT-IN" +
            " preservation (no default mode flip)")
    }

    // MARK: - Determinism

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.knives.count,
            BASChapter432EntropyDoctrine.knives.count)
        XCTAssertEqual(
            BASChapter432EntropyDoctrine.summary,
            BASChapter432EntropyDoctrine.summary)
    }
}
