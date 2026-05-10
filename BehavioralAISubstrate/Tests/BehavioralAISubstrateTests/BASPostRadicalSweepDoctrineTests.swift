// MARK: - BASPostRadicalSweepDoctrineTests
// chapter 四百四十六 / M1162 — POST-RADICAL Wave 17

import XCTest
@testable import BASRuntimeCore

/// Pin tests for the M1161 close-out meta-doctrine。
/// Validates that the typed sweep-narrative anchor is
/// fully populated with the cumulative achievement
/// (chapters 427-446 / Waves 1-17 / M1080-M1163 / 84
/// commits)。 Future commits that bump the sweep range
/// without bumping these pins fail at PR-time。
final class BASPostRadicalSweepDoctrineTests:
    XCTestCase
{

    // MARK: - Identity

    func testSweepTagPinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.sweepTag,
            "post-radical-evolution-sweep")
    }

    func testTriggerDirectivePinnedVerbatim() {
        // The 2026-05-10 directive must remain
        // verbatim — chapter 八十七 raw-value stability。
        XCTAssertTrue(
            BASPostRadicalSweepDoctrine
                .triggerDirective
                .contains("进化升华"))
        XCTAssertTrue(
            BASPostRadicalSweepDoctrine
                .triggerDirective
                .contains("低熵复杂系统"))
        XCTAssertTrue(
            BASPostRadicalSweepDoctrine
                .triggerDirective
                .contains("原生利用神经引擎"))
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.triggerDate,
            "2026-05-10")
    }

    // MARK: - Range

    func testChapterRangePinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .firstChapterTag,
            "chapter 四百二十七")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .lastChapterTag,
            "chapter 四百四十六")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .chapterTagsShipped.first,
            BASPostRadicalSweepDoctrine
                .firstChapterTag,
            "chapterTagsShipped.first must equal" +
            " firstChapterTag")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .chapterTagsShipped.last,
            BASPostRadicalSweepDoctrine
                .lastChapterTag,
            "chapterTagsShipped.last must equal" +
            " lastChapterTag")
    }

    func testMNumberRangePinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberFirst,
            1080,
            "RADICAL EVOLUTION SWEEP Phase A starts at" +
            " M1080")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberLast,
            1163,
            "Wave 17 close-out chapter 446 ends at" +
            " M1163")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.mNumberSpan,
            84, "M1080-M1163 inclusive = 84 M-numbers")
    }

    func testWaveRangePinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .firstWaveNumber, 1)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .lastWaveNumber, 17)
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.waveCount, 17)
    }

    // MARK: - Counts

    func testChapterCountPinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.chapterCount,
            20,
            "chapters 427-446 inclusive = 20 chapters")
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine
                .chapterTagsShipped.count, 20,
            "chapterTagsShipped count matches" +
            " chapterCount accessor")
    }

    func testCommitsShippedPinned() {
        XCTAssertEqual(
            BASPostRadicalSweepDoctrine.commitsShipped,
            84,
            "RADICAL Phases A-F (24 commits at M1080-" +
            "M1107) + RADICAL final cuts (M1108-M1115) +" +
            " POST-RADICAL Waves 5-16 (M1110-M1159) +" +
            " chapter 446 close-out (4 cuts) ≈ 84")
    }

    // MARK: - whatsShipped + whatsDeferred + pins

    func testWhatsShippedPopulated() {
        XCTAssertGreaterThanOrEqual(
            BASPostRadicalSweepDoctrine
                .whatsShipped.count, 8,
            "Sweep must list at least 8 substrate-side" +
            " achievements")
        // Spot-check key narrative anchors
        let joined = BASPostRadicalSweepDoctrine
            .whatsShipped.joined(separator: " | ")
        XCTAssertTrue(
            joined.contains("autonomy"),
            "whatsShipped must mention substrate-side" +
            " autonomy")
        XCTAssertTrue(
            joined.contains("Replay surface"),
            "whatsShipped must mention replay surface")
        XCTAssertTrue(
            joined.contains("Apple Silicon"),
            "whatsShipped must mention native Apple" +
            " Silicon foundation")
    }

    func testWhatsDeferredPopulated() {
        XCTAssertGreaterThanOrEqual(
            BASPostRadicalSweepDoctrine
                .whatsDeferred.count, 5,
            "Sweep must explicitly defer at least 5" +
            " items with reasons")
        // Each entry must have non-empty reason
        for (item, reason) in
            BASPostRadicalSweepDoctrine.whatsDeferred
        {
            XCTAssertFalse(item.isEmpty)
            XCTAssertFalse(reason.isEmpty,
                "deferred item '\(item)' must have a" +
                " reason — silent omissions forbidden")
        }
    }

    func testPinsHeldThroughoutPopulated() {
        XCTAssertGreaterThanOrEqual(
            BASPostRadicalSweepDoctrine
                .pinsHeldThroughout.count, 10,
            "Sweep must list at least 10 doctrine pins" +
            " held at every commit boundary")
        let joined = BASPostRadicalSweepDoctrine
            .pinsHeldThroughout.joined(
                separator: " | ")
        XCTAssertTrue(
            joined.contains("不变量 #1"),
            "V1 byte-equality invariant must be in" +
            " pins-held list")
        XCTAssertTrue(
            joined.contains("ADR-014"),
            "ADR-014 OPT-IN must be in pins-held list")
        XCTAssertTrue(
            joined.contains("ADR-016"),
            "ADR-016 substrate completion must be in" +
            " pins-held list")
    }
}
