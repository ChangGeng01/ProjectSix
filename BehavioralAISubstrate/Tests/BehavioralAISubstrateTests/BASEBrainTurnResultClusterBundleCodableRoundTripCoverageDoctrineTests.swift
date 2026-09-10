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

    func testExplicitlyCoveredCountIsNineAtM1566() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .explicitlyCoveredCount,
            9,
            "9 of 9 bundles have explicit round-trip" +
            " coverage at chapter 547 close-out (added" +
            " CognitiveFramesBundle at M1565) — 100%" +
            " MILESTONE achieved")
    }

    func testCompileTimeOnlyCountIsZeroAtM1566() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .compileTimeOnlyCount,
            0,
            "Zero bundles remain in compileTimeOnly " +
            "state — 100% explicit coverage achieved")
    }

    func testCoverageRatioIsExactlyOne() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .coverageRatio,
            1.0,
            "9/9 = 1.0 — 100% MILESTONE")
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

    func testCognitiveFramesBundleIsExplicitlyCoveredAtM1565() {
        let entry =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.first {
                    $0.bundleTypeName ==
                        "BASEBrainTurnResultCognitiveFramesBundle"
                }!
        XCTAssertEqual(entry.status,
            .explicitRoundTripCovered)
        XCTAssertEqual(entry.explicitCoverageMNumber,
            1565)
    }

    // MARK: - 100% milestone invariants

    func testAllNineBundlesAreExplicitlyCovered() {
        let allExplicit =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.allSatisfy {
                    $0.status == .explicitRoundTripCovered
                }
        XCTAssertTrue(allExplicit,
            "100% MILESTONE:every entry must be" +
            " .explicitRoundTripCovered")
    }

    func testAllCoverageMNumbersAreNonNil() {
        let allHaveCoverageMNumber =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.allSatisfy {
                    $0.explicitCoverageMNumber != nil
                }
        XCTAssertTrue(allHaveCoverageMNumber)
    }

    func testMiscBundleIsExplicitlyCoveredAtM1553() {
        let entry =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.first {
                    $0.bundleTypeName ==
                        "BASEBrainTurnResultMiscBundle"
                }!
        XCTAssertEqual(entry.status,
            .explicitRoundTripCovered)
        XCTAssertEqual(entry.explicitCoverageMNumber,
            1553)
    }

    func testDeviceLifecycleBundleIsExplicitlyCoveredAtM1557() {
        let entry =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.first {
                    $0.bundleTypeName ==
                        "BASEBrainTurnResultDeviceLifecycleBundle"
                }!
        XCTAssertEqual(entry.status,
            .explicitRoundTripCovered)
        XCTAssertEqual(entry.explicitCoverageMNumber,
            1557)
    }

    func testRiskChoiceBundleIsExplicitlyCoveredAtM1561() {
        let entry =
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
                .entries.first {
                    $0.bundleTypeName ==
                        "BASEBrainTurnResultRiskChoiceBundle"
                }!
        XCTAssertEqual(entry.status,
            .explicitRoundTripCovered)
        XCTAssertEqual(entry.explicitCoverageMNumber,
            1561)
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
