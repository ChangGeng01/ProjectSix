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
                .chapterTagsShipped.count, 31,
            "M1107 RADICAL EVOLUTION SWEEP final" +
            " close-out:bumped from 30 to 31 (added" +
            " chapter 四百三十三)")
    }

    func testFirstChapterIs403() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.first,
            "chapter 四百三")
    }

    func testLastChapterIs433() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last,
            "chapter 四百三十三",
            "M1107 RADICAL EVOLUTION SWEEP final" +
            " close-out:bumped from 四百三十二 to" +
            " 四百三十三")
    }

    // MARK: - M-number range

    func testMNumberFirstIs953() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberFirst, 953)
    }

    func testMNumberLastIs1109() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .mNumberLast, 1109,
            "M1109 deep-review remediation round 2:" +
            " bumped from 1107 to 1109 (chapter 433" +
            " self-extension covers M1108 + M1109)")
    }

    // MARK: - Cumulative metrics

    func testCommitsShipped155() {
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .commitsShipped, 155,
            "M1109 deep-review remediation round 2:" +
            " bumped from 153 to 155 (M1108 + M1109" +
            " deep-review remediations land as 5th +" +
            " 6th cuts of chapter 四百三十三)")
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
