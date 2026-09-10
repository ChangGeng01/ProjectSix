// MARK: - BASSubstrateBuildWarningPurgeDoctrineTests
// chapter 五百三十五 / M1519 — anti-drift PROOF tests for
//                              the substrate-wide
//                              build-warning purge
//                              milestone doctrine

import XCTest
@testable import BASRuntimeCore

final class BASSubstrateBuildWarningPurgeDoctrineTests:
    XCTestCase
{

    // MARK: - Category invariants

    func testWarningCategoryCaseCountIsThree() {
        XCTAssertEqual(
            BASSubstrateBuildWarningPurgeDoctrine
                .WarningCategory.allCases.count,
            3,
            "3 categories of warnings purged across the " +
            "arc:neverUsedLet + neverMutatedVar + " +
            "tryDiscardUnused")
    }

    func testCategoryPurgesArrayMatchesCategoryCount() {
        let categories = Set(
            BASSubstrateBuildWarningPurgeDoctrine
                .categoryPurges.map { $0.category })
        XCTAssertEqual(
            categories.count,
            BASSubstrateBuildWarningPurgeDoctrine
                .WarningCategory.allCases.count,
            "Every category must have a purge entry")
    }

    // MARK: - Count invariants

    func testPreArcWarningCountIsSixtyFour() {
        XCTAssertEqual(
            BASSubstrateBuildWarningPurgeDoctrine
                .preArcWarningCount,
            64)
    }

    func testPostArcWarningCountIsZero() {
        XCTAssertEqual(
            BASSubstrateBuildWarningPurgeDoctrine
                .postArcWarningCount,
            0,
            "Substrate must build warning-free post-arc")
    }

    func testTotalWarningsPurgedEqualsSixtyFour() {
        XCTAssertEqual(
            BASSubstrateBuildWarningPurgeDoctrine
                .totalWarningsPurged,
            64,
            "Sum of per-category purges must equal 64")
    }

    func testSubstrateIsWarningFreeInvariantHolds() {
        XCTAssertTrue(
            BASSubstrateBuildWarningPurgeDoctrine
                .substrateIsWarningFree,
            "100% warning-free invariant must hold:" +
            " preArc - totalPurged == postArc AND " +
            "postArc == 0")
    }

    // MARK: - Per-category contribution checks

    func testNeverUsedLetPurgedSixtyAtM1513() {
        let entry = BASSubstrateBuildWarningPurgeDoctrine
            .categoryPurges
            .first { $0.category == .neverUsedLet }!
        XCTAssertEqual(entry.countPurged, 60)
        XCTAssertEqual(entry.chapterMNumber, 1513)
    }

    func testNeverMutatedVarPurgedTwoAtM1517() {
        let entry = BASSubstrateBuildWarningPurgeDoctrine
            .categoryPurges
            .first { $0.category == .neverMutatedVar }!
        XCTAssertEqual(entry.countPurged, 2)
        XCTAssertEqual(entry.chapterMNumber, 1517)
    }

    func testTryDiscardUnusedPurgedTwoAtM1517() {
        let entry = BASSubstrateBuildWarningPurgeDoctrine
            .categoryPurges
            .first { $0.category == .tryDiscardUnused }!
        XCTAssertEqual(entry.countPurged, 2)
        XCTAssertEqual(entry.chapterMNumber, 1517)
    }

    // MARK: - Determinism

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASSubstrateBuildWarningPurgeDoctrine
                .byteEqualityPreserved)
    }

    func testReplayDeterminismProofMethodIsStressSweep() {
        XCTAssertEqual(
            BASSubstrateBuildWarningPurgeDoctrine
                .replayDeterminismProof,
            "stress-sweep-canonical60-3-runs-0-divergence")
    }

    // MARK: - Arc M-number range

    func testArcMNumberRangeIs1513To1520() {
        XCTAssertEqual(
            BASSubstrateBuildWarningPurgeDoctrine
                .arcFirstMNumber, 1513)
        XCTAssertEqual(
            BASSubstrateBuildWarningPurgeDoctrine
                .arcLastMNumber, 1520)
    }
}
