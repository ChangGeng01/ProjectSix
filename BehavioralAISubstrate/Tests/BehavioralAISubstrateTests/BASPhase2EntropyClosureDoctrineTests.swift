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

    // MARK: - 19 chapter tags

    func testNineteenChapterTagsShipped() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.count, 44,
            "M1163 POST-RADICAL Wave 17 (close-out" +
            " meta-doctrine):bumped from 43 to 44" +
            " (added chapter 四百四十六)。 Sweep complete")
    }

    func testFirstChapterIs403() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.first,
            "chapter 四百三")
    }

    func testLastChapterIs446() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last,
            "chapter 四百四十六",
            "M1163 POST-RADICAL Wave 17:bumped from" +
            " 四百四十五 to 四百四十六。 Sweep complete")
    }

    // MARK: - M-number range

    func testMNumberFirstIs953() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberFirst, 953)
    }

    func testMNumberLastIs1163() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberLast, 1163,
            "M1163 POST-RADICAL Wave 17:bumped from" +
            " 1159 to 1163 (chapter 446 covers" +
            " M1160-M1163)。 Sweep complete")
    }

    // MARK: - Cumulative metrics

    func testCommitsShipped209() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .commitsShipped, 209,
            "M1163 POST-RADICAL Wave 17:bumped from" +
            " 205 to 209 (chapter 446 ships 4 cuts" +
            " M1160-M1163)。 Sweep complete")
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

    func testProductionWorkRemainingHas4Items() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .productionWorkRemaining.count, 4)
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
