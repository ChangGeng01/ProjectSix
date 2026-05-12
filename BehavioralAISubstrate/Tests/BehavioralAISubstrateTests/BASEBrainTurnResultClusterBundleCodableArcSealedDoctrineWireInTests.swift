// MARK: - BASEBrainTurnResultClusterBundleCodableArcSealedDoctrineWireInTests
// chapter 五百四十八 / M1571 — wire-in PROOF tests cross-
//                              checking the arc sealed
//                              doctrine against actual
//                              state (coverage doctrine
//                              + fold-arc-sealed
//                              doctrine)
//
// These tests verify that the arc sealed doctrine's
// claimed state matches the actual state captured by:
//
//   1. BASEBrainTurnResultClusterBundleCodableRoundTrip
//      CoverageDoctrine (chapter 543 M1550) — explicit
//      coverage count per bundle
//   2. BASEBrainTurnResultFoldArcSealedDoctrine
//      (chapter 533) — total cluster bundle count
//
// If any doctrine drifts independently,wire-in tests
// fail loudly。

import XCTest
@testable import BASRuntimeCore

final class BASEBrainTurnResultClusterBundleCodableArcSealedDoctrineWireInTests:
    XCTestCase
{

    // MARK: - Cross-doctrine consistency:final coverage
    //         matches actual coverage doctrine

    func testFinalCoverageMatchesActualCoverageDoctrine() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .finalExplicitCoverageCount,
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .explicitlyCoveredCount,
            "Arc sealed doctrine's finalExplicitCoverage" +
            "Count must equal the live coverage" +
            " doctrine's explicitlyCoveredCount。 If" +
            " these drift,one of the doctrines is" +
            " stale。")
    }

    func testFinalRatioMatchesActualCoverageDoctrine() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .finalCoverageRatio,
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .coverageRatio)
    }

    // MARK: - Cross-doctrine consistency:final coverage
    //         matches fold-arc cluster bundle count

    func testFinalCoverageMatchesFoldArcClusterBundleCount() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .finalExplicitCoverageCount,
            BASEBrainTurnResultFoldArcSealedDoctrine
                .clusterBundleCount,
            "Arc sealed doctrine's final coverage must" +
            " equal the fold-arc-sealed doctrine's" +
            " clusterBundleCount。 Both should be 9 at" +
            " the 100% milestone。")
    }

    // MARK: - Cross-doctrine 100% invariant

    func testMilestoneAndCatalogueAreConsistent() {
        let milestoneAchieved =
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .hundredPercentMilestoneAchieved
        let catalogueConsistent =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .catalogueIsConsistent
        XCTAssertTrue(milestoneAchieved,
            "Arc sealed milestone must hold")
        XCTAssertTrue(catalogueConsistent,
            "Coverage catalogue must be consistent")
    }

    // MARK: - Arc M-number range vs Codable doctrine

    func testArcOpensAtCodableConformanceMNumber() {
        // M1541 is where Codable conformance was added
        // (chapter 541 第一刀)。
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .arcFirstMNumber,
            BASEBrainTurnResultClusterBundleCodableDoctrine
                .conformanceAddedAtMNumber)
    }

    // MARK: - Each catalogued chapter's
    //         coverageAfterChapter matches the actual
    //         coverage doctrine entry's M-number range
    //         coverage progression

    func testFinalChapterEntryMatchesActualCoverage() {
        let lastEntry =
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .chapters.last!
        XCTAssertEqual(
            lastEntry.coverageAfterChapter,
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .explicitlyCoveredCount,
            "The last chapter entry's coverageAfter" +
            "Chapter must match the live doctrine's" +
            " current count")
    }
}
