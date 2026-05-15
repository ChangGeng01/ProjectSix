// MARK: - BASAutonomousSessionStateOfTheUnionDoctrineTests
// chapter 五百四十九 / M1574 — anti-drift PROOF tests for
//                              the substrate state-of-the-
//                              union audit doctrine

import XCTest
@testable import BASRuntimeCore

final class BASAutonomousSessionStateOfTheUnionDoctrineTests:
    XCTestCase
{

    // MARK: - Kind enum counts

    func testAchievementKindCountIsSix() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .achievementKindCount,
            6)
        XCTAssertEqual(
            BASAutonomousSessionAchievementKind
                .allCases.count,
            6)
    }

    func testRemainingKindCountIsFive() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .remainingKindCount,
            5)
        XCTAssertEqual(
            BASAutonomousSessionRemainingKind
                .allCases.count,
            5)
    }

    // MARK: - Cumulative metric pins

    func testTypedSurfaceCountIsOneHundredNinetyThree() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .typedSurfaceCount,
            193)
    }

    func testConsecutiveByteEqualityCleanCommitsIs572() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .consecutiveByteEqualityCleanCommits,
            572)
    }

    func testPhase2CommitsShippedIs1033() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .phase2CommitsShipped,
            1033)
    }

    func testChapter2NumberLastIs1988() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .chapter2NumberLast,
            1988)
    }

    // MARK: - Quality invariants

    func testSubstrateIsWarningFreeFlagSet() {
        XCTAssertTrue(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .substrateIsWarningFree)
    }

    func testV1ByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .v1ByteEqualityPreserved)
    }

    func testCodableRoundTripCoverageRatioIsOne() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .codableRoundTripCoverageRatio,
            1.0)
    }

    // MARK: - Achievement details

    func testClusterBundleCountIsNine() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .clusterBundleCount,
            9)
    }

    func testClusterBundlePackagingRatioIsOne() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .clusterBundlePackagingRatio,
            1.0)
    }

    func testObservabilitySinkCountIsThree() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .observabilitySinkCount,
            3)
    }

    func testDocumentedSilentSwallowPathCountIsEight() {
        XCTAssertEqual(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .documentedSilentSwallowPathCount,
            8)
    }

    // MARK: - Enumerated kinds

    func testAchievementKindsEnumerated() {
        let kinds = BASAutonomousSessionStateOfTheUnionDoctrine
            .achievementKindsEnumerated
        XCTAssertEqual(kinds.count, 6)
        XCTAssertTrue(kinds.contains(
            .basEBrainTurnResultFoldArc))
        XCTAssertTrue(kinds.contains(
            .codableArc))
    }

    func testRemainingKindsEnumerated() {
        let kinds = BASAutonomousSessionStateOfTheUnionDoctrine
            .remainingKindsEnumerated
        XCTAssertEqual(kinds.count, 5)
        XCTAssertTrue(kinds.contains(
            .v1MonolithInternalFold))
        XCTAssertTrue(kinds.contains(
            .genericPrimitiveAdoptionReframe))
    }

    // MARK: - Honest reframe flag

    func testOriginalPlanTierAReframeNeededIsTrue() {
        XCTAssertTrue(
            BASAutonomousSessionStateOfTheUnionDoctrine
                .originalPlanTierAReframeNeeded,
            "Honest acknowledgment that original plan's" +
            " Tier A definition doesn't fit substrate" +
            " reality")
    }
}
