// MARK: - BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrineTests
// chapter 五百四十三 / M1551 — anti-drift PROOF tests for
//                              the coverage doctrine

import XCTest
@testable import BASRuntimeCore

final class BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrineTests:
    XCTestCase
{

    // MARK: - Count invariants

    func testTotalBundleCountIsNine() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .totalBundleCount,
            9,
            "9 cluster bundles in the fold arc")
    }

    func testEntriesArrayLengthIsNine() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.count,
            9)
    }

    // MARK: - Coverage counts

    func testExplicitlyCoveredCountIsFiveAtM1550() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .explicitlyCoveredCount,
            5,
            "5 of 9 bundles have explicit round-trip" +
            " coverage at chapter 543 close-out")
    }

    func testCompileTimeOnlyCountIsFourAtM1550() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .compileTimeOnlyCount,
            4)
    }

    func testCoverageRatioIsAbout556Percent() {
        let ratio = BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
            .coverageRatio
        XCTAssertGreaterThan(ratio, 0.55)
        XCTAssertLessThan(ratio, 0.56)
    }

    // MARK: - Consistency invariant

    func testCatalogueIsConsistentInvariantHolds() {
        XCTAssertTrue(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .catalogueIsConsistent)
    }

    // MARK: - Per-status enum

    func testCoverageStatusHasTwoCases() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageStatus
                .allCases.count,
            2)
    }

    // MARK: - Per-bundle lookups

    func testEvolutionBundleIsExplicitlyCovered() {
        let entry =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.first {
                    $0.bundleTypeName ==
                        "BASEBrainTurnResultEvolutionBundle"
                }!
        XCTAssertEqual(entry.status,
            .explicitRoundTripCovered)
        XCTAssertEqual(entry.explicitCoverageMNumber,
            1545)
    }

    func testHostBundleIsExplicitlyCoveredAtM1549() {
        let entry =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.first {
                    $0.bundleTypeName ==
                        "BASEBrainTurnResultHostBundle"
                }!
        XCTAssertEqual(entry.status,
            .explicitRoundTripCovered)
        XCTAssertEqual(entry.explicitCoverageMNumber,
            1549)
    }

    func testForensicMetadataBundleIsExplicitlyCoveredAtM1549()
    {
        let entry =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.first {
                    $0.bundleTypeName ==
                        "BASEBrainTurnResultForensicMetadataBundle"
                }!
        XCTAssertEqual(entry.status,
            .explicitRoundTripCovered)
        XCTAssertEqual(entry.explicitCoverageMNumber,
            1549)
    }

    func testCognitiveFramesBundleIsCompileTimeOnly() {
        let entry =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.first {
                    $0.bundleTypeName ==
                        "BASEBrainTurnResultCognitiveFramesBundle"
                }!
        XCTAssertEqual(entry.status,
            .compileTimeOnly)
        XCTAssertNil(entry.explicitCoverageMNumber)
    }

    // MARK: - Unique bundle names

    func testEntryBundleNamesAreUnique() {
        let names =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.map { $0.bundleTypeName }
        XCTAssertEqual(
            Set(names).count,
            names.count,
            "Each catalogue entry must reference a " +
            "distinct cluster bundle type")
    }

    // MARK: - Cross-doctrine invariant (total matches
    //         fold arc)

    func testTotalBundleCountMatchesFoldArcSealed() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .totalBundleCount,
            BASEBrainTurnResultFoldArcSealedDoctrine
                .clusterBundleCount,
            "totalBundleCount must equal fold-arc-" +
            "sealed clusterBundleCount")
    }
}
