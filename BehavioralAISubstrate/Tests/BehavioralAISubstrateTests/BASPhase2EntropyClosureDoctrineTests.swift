// MARK: - BASPhase2EntropyClosureDoctrineTests — chapter 四百二十一 / M1055

import XCTest
@testable import BASRuntimeCore

final class BASPhase2EntropyClosureDoctrineTests:
    XCTestCase
{

    // MARK: - Phase tag pinned

    func testPhaseTagPinned() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine.phaseTag,
            "phase-2-runtime-rewrite")
    }

    // MARK: - Chapter tags count (named expected)

    func testChapterTagsCountMatchesExpected() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.count,
            BASSweepDoctrineExpectations
                .phase2ChapterCount,
            "Phase 2 chapter count must equal named" +
            " expected (derivation in" +
            " BASSweepDoctrineExpectations" +
            ".phase2ChapterCount doc-comment:24 pre-" +
            "RADICAL + 20 sweep + N post-sweep)")
    }

    func testFirstChapterIs403() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.first,
            "chapter 四百三")
    }

    func testLastChapterIs614() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last,
            "chapter 六百一十四",
            "Chapter 六百一十四:GAP-FILL HEXA CATALOG" +
            " META-META MILESTONE。 NEW BASGapFillHexa" +
            "CompletionDoctrine cataloging 6 gap-fill" +
            " chapters (608-613) within already-covered" +
            " modules — 11 types extended / 24 commits" +
            " / 4 distinct modules touched / 5 kind" +
            " buckets (chain-dep + wave-2 ×2 + wave-3" +
            " + continuation + continuation-wave-2) +" +
            " 37 anti-drift PROOF + 20 wire-in PROOF" +
            " + close-out。 PARALLEL structurally to" +
            " chapter 607 post-octa fresh-module hexa" +
            " catalog (which cataloged 6 FRESH-MODULE" +
            " entries at M1805)。 155 typed surfaces" +
            " cumulative。 420 consecutive byte-equality" +
            " clean commits")
    }

    // MARK: - M-number range

    func testMNumberFirstMatchesExpected() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberFirst,
            BASSweepDoctrineExpectations
                .phase2MNumberFirst,
            "Phase 2 mNumberFirst must equal named" +
            " expected (chapter 四百三 entry M953)")
    }

    func testMNumberLastMatchesPhase2Expected() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberLast,
            BASSweepDoctrineExpectations
                .phase2MNumberLast,
            "Phase 2 mNumberLast must equal named" +
            " expected (Phase 2 is ongoing umbrella;" +
            " SWEEP stayed frozen at chapter 446)")
        XCTAssertGreaterThanOrEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberLast,
            BASSweepDoctrineExpectations
                .sweepMNumberLast,
            "Phase 2 must >= SWEEP (SWEEP is a frozen" +
            " prefix of ongoing Phase 2)")
    }

    // MARK: - Cumulative metrics (named expected)

    func testCommitsShippedMatchesExpected() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .commitsShipped,
            BASSweepDoctrineExpectations
                .phase2CommitsShipped,
            "Phase 2 commitsShipped must equal named" +
            " expected (125 pre-RADICAL + 84 sweep +" +
            " 4 post-sweep = 213 at M1167) — see" +
            " doc-comment in BASSweepDoctrineExpectations")
    }

    func testV2FoundationsCount12() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .v2FoundationsCount, 12)
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .v2FoundationsCount,
            BASV2FoundationsRegistry.foundationCount,
            "must match V2FoundationsRegistry count")
    }

    // MARK: - Production work remaining

    func testProductionWorkRemainingMatchesExpected() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .productionWorkRemaining.count,
            BASSweepDoctrineExpectations
                .phase2ProductionWorkCount,
            "productionWorkRemaining count must match" +
            " named expected (ADR-018 4-item list)")
    }

    func testProductionRoadmapADRPinned() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .productionRoadmapADR,
            "ADR-018-pending")
    }

    // MARK: - Chapter tags include all V2 FOUNDATION chapters

    func testChapterTagsIncludeAllV2FoundationChapters() {
        let phase2Tags = Set(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped)
        for tag in BASV2FoundationsRegistry
            .allChapterTags
        {
            XCTAssertTrue(
                phase2Tags.contains(tag),
                "Phase 2 must include V2 foundation " +
                "chapter \(tag)")
        }
    }

    // MARK: - Determinism

    func testDoctrineIsDeterministic() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped,
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped)
    }
}
