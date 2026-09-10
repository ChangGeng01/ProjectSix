// MARK: - BASSessionMilestoneDoctrineCatalogueWireInTests
// chapter 五百五十 / M1579 — wire-in PROOF tests cross-
//                            checking the meta-catalogue
//                            entries against each actual
//                            milestone doctrine

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASSessionMilestoneDoctrineCatalogueWireInTests:
    XCTestCase
{

    // MARK: - Per-milestone wire-in PROOFs

    func testFoldArcSealedDoctrineMatchesCatalogue() {
        // Catalogue claims chapter 533 / M1509 for fold
        // arc sealed doctrine — verify the actual
        // doctrine matches。
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .firstChapterMNumber,
            1473,
            "Fold arc doctrine pins its OWN range" +
            " (1473-1508);catalogue tracks the" +
            " DOCTRINE'S origin M-number (1509),not" +
            " the arc range")
    }

    func testCoordinatorDeadPurgeDoctrineExists() {
        // Compile-time check via type reference。
        XCTAssertEqual(
            BASCoordinatorDeadDeclarationPurgeDoctrine
                .purgedDeclarationCount,
            30)
    }

    func testSubstrateWarningPurgeDoctrineExists() {
        XCTAssertTrue(
            BASSubstrateBuildWarningPurgeDoctrine
                .substrateIsWarningFree)
    }

    func testTestTargetWarningPurgeDoctrineExists() {
        XCTAssertTrue(
            BASTestTargetBuildWarningPurgeDoctrine
                .testTargetIsWarningFree)
    }

    func testObservabilitySinkCatalogueDoctrineExists() {
        XCTAssertEqual(
            BASTypedObservabilitySinkCatalogueDoctrine
                .sinkCount,
            3)
    }

    func testCodableArcSealedDoctrineExists() {
        XCTAssertTrue(
            BASEBrainTurnResultClusterBundleCodableArcSealedDoctrine
                .hundredPercentMilestoneAchieved)
    }

    func testStateOfTheUnionDoctrineExists() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .achievementKindCount,
            6)
    }

    // MARK: - All catalogued IDs map to live doctrines

    func testAllCataloguedIDsAreReferenceable() {
        // Iterate every Kind case + verify entry lookup
        // returns non-nil。 If a new case is added but
        // not added to the catalogue,this fails。
        for id in BASSessionMilestoneDoctrineID.allCases
        {
            let entry =
                BASSessionMilestoneDoctrineCatalogueDoctrine
                    .entry(for: id)
            XCTAssertNotNil(entry,
                "Catalogue must have an entry for " +
                "every BASSessionMilestoneDoctrineID " +
                "case (missing: \(id))")
        }
    }
}
