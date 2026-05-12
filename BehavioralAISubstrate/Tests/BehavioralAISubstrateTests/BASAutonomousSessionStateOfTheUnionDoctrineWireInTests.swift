// MARK: - BASAutonomousSessionStateOfTheUnionDoctrineWireInTests
// chapter 五百四十九 / M1575 — wire-in PROOF tests cross-
//                              checking the state-of-the-
//                              union doctrine against
//                              other typed surfaces in
//                              the substrate

import XCTest
@testable import BASRuntimeCore

final class BASAutonomousSessionStateOfTheUnionDoctrineWireInTests:
    XCTestCase
{

    // MARK: - clusterBundleCount cross-check vs fold
    //         arc sealed doctrine

    func testClusterBundleCountMatchesFoldArcSealed() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .clusterBundleCount,
            BASEBrainTurnResultFoldArcSealedDoctrine
                .clusterBundleCount,
            "State-of-the-union clusterBundleCount must" +
            " equal fold-arc-sealed clusterBundleCount")
    }

    // MARK: - codableRoundTripCoverageRatio cross-check
    //         vs coverage doctrine

    func testCodableRatioMatchesCoverageDoctrine() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .codableRoundTripCoverageRatio,
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .coverageRatio)
    }

    // MARK: - observabilitySinkCount cross-check vs
    //         catalogue doctrine

    func testObservabilitySinkCountMatchesCatalogue() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .observabilitySinkCount,
            BASTypedObservabilitySinkCatalogueDoctrine
                .sinkCount)
    }

    // MARK: - documentedSilentSwallowPathCount cross-
    //         check vs catalogue doctrine

    func testSilentSwallowPathCountMatchesCatalogue() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .documentedSilentSwallowPathCount,
            BASTypedObservabilitySinkCatalogueDoctrine
                .expectedTotalCoveredPathCount)
    }

    // MARK: - substrateIsWarningFree cross-check vs
    //         purge doctrines

    func testSubstrateWarningFreeMatchesCombinedPurges() {
        // Substrate warning-free if BOTH Sources/ + Tests/
        // are warning-free。 Catalogued via:
        //   - BASSubstrateBuildWarningPurgeDoctrine
        //   - BASTestTargetBuildWarningPurgeDoctrine
        let bothFree =
            BASSubstrateBuildWarningPurgeDoctrine
                .substrateIsWarningFree
            && BASTestTargetBuildWarningPurgeDoctrine
                .testTargetIsWarningFree
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .substrateIsWarningFree,
            bothFree)
    }

    // MARK: - phase2CommitsShipped cross-check vs Phase
    //         2 doctrine

    func testPhase2CommitsCrossCheck() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .phase2CommitsShipped,
            BASPhase2EntropyClosureDoctrine.commitsShipped)
    }

    // MARK: - chapter2NumberLast cross-check vs Phase 2
    //         doctrine

    func testChapter2NumberLastCrossCheck() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .chapter2NumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }
}
