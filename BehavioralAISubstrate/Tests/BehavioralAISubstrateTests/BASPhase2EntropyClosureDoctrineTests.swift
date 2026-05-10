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
                .chapterTagsShipped.count, 25,
            "M1083 RADICAL EVOLUTION SWEEP Phase A:" +
            " bumped from 24 to 25")
    }

    func testFirstChapterIs403() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.first,
            "chapter 四百三")
    }

    func testLastChapterIs427() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last,
            "chapter 四百二十七",
            "M1083 RADICAL EVOLUTION SWEEP Phase A:" +
            " bumped from 四百二十六 to 四百二十七")
    }

    // MARK: - M-number range

    func testMNumberFirstIs953() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberFirst, 953)
    }

    func testMNumberLastIs1083() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberLast, 1083,
            "M1083 RADICAL EVOLUTION SWEEP Phase A:" +
            " bumped from 1077 to 1083")
    }

    // MARK: - Cumulative metrics

    func testCommitsShipped129() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .commitsShipped, 129,
            "M1083 RADICAL EVOLUTION SWEEP Phase A:" +
            " bumped from 125 to 129 (M1078-M1079" +
            " reserved gap)")
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
