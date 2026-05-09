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
                .chapterTagsShipped.count, 21,
            "M1066 extension:bumped from 19 to 21")
    }

    func testFirstChapterIs403() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.first,
            "chapter 四百三")
    }

    func testLastChapterIs423() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last,
            "chapter 四百二十三",
            "M1066 extension:bumped from 四百二十一 to 四百二十三")
    }

    // MARK: - M-number range

    func testMNumberFirstIs953() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberFirst, 953)
    }

    func testMNumberLastIs1065() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberLast, 1065,
            "M1066 extension:bumped from 1057 to 1065")
    }

    // MARK: - Cumulative metrics

    func testCommitsShipped113() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .commitsShipped, 113,
            "M1066 extension:bumped from 105 to 113")
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
