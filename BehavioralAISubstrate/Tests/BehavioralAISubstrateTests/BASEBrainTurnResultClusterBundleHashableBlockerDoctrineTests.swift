// MARK: - BASEBrainTurnResultClusterBundleHashableBlockerDoctrineTests
// chapter 五百四十二 / M1547 — anti-drift PROOF tests for
//                              the Hashable blocker
//                              doctrine

import XCTest
@testable import BASRuntimeCore

final class BASEBrainTurnResultClusterBundleHashableBlockerDoctrineTests:
    XCTestCase
{

    // MARK: - Blocker count invariants

    func testBlockingTypeCountIsTwo() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .blockingTypeCount,
            2,
            "BASRecoveryDisposition + BASRuntimeTrace " +
            "= 2 blocking types catalogued at M1546")
    }

    func testBlockingTypesArrayMatchesCount() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .blockingTypes.count,
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .blockingTypeCount)
    }

    // MARK: - Per-type entries

    func testBASRecoveryDispositionIsCatalogued() {
        let entries =
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .blockingTypes
                .filter {
                    $0.typeName == "BASRecoveryDisposition"
                }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].category,
            .basSchemaVersionedLacksHashable)
    }

    func testBASRuntimeTraceIsCatalogued() {
        let entries =
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .blockingTypes
                .filter {
                    $0.typeName == "BASRuntimeTrace"
                }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].category,
            .basSchemaVersionedLacksHashable)
    }

    // MARK: - BlockerCategory enum

    func testBlockerCategoryHasThreeCases() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .BlockerCategory.allCases.count,
            3,
            "basSchemaVersionedLacksHashable +" +
            " referenceTypeContainment +" +
            " closureStoredProperty = 3 categories")
    }

    func testBlockerCategoryRawValuesAreStable() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .BlockerCategory
                .basSchemaVersionedLacksHashable
                .rawValue,
            "basSchemaVersionedLacksHashable")
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .BlockerCategory
                .referenceTypeContainment.rawValue,
            "referenceTypeContainment")
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .BlockerCategory
                .closureStoredProperty.rawValue,
            "closureStoredProperty")
    }

    // MARK: - Canary + decision pins

    func testCanaryBundleIsForensicMetadata() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .canaryBundleTypeName,
            "BASEBrainTurnResultForensicMetadataBundle")
    }

    func testCurrentDecisionIsPendingReview() {
        XCTAssertEqual(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .currentDecision,
            "no-hashable-conformance-pending-stakeholder-review")
    }

    func testClusterBundlesAreNotHashablePinFlag() {
        XCTAssertFalse(
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .clusterBundlesAreHashable,
            "Pinned false at M1546 — flipping requires " +
            "resolving the BASSchemaVersioned-lacks-" +
            "Hashable blocker")
    }

    // MARK: - All catalogued blockers share the
    //         basSchemaVersionedLacksHashable category

    func testAllCataloguedBlockersAreSchemaVersionedFamily() {
        let nonSchemaVersionedBlockers =
            BASEBrainTurnResultClusterBundleHashableBlockerDoctrine
                .blockingTypes
                .filter {
                    $0.category !=
                        .basSchemaVersionedLacksHashable
                }
        XCTAssertTrue(nonSchemaVersionedBlockers.isEmpty,
            "At M1546,every catalogued blocker is a " +
            "BASSchemaVersioned-family type")
    }
}
