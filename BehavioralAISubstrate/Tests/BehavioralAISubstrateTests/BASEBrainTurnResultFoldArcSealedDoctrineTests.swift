// MARK: - BASEBrainTurnResultFoldArcSealedDoctrineTests
// chapter 五百三十三 / M1510 — anti-drift PROOF tests for
//                              the 9-chapter fold arc
//                              seal doctrine

import XCTest
@testable import BASRuntimeCore

final class BASEBrainTurnResultFoldArcSealedDoctrineTests:
    XCTestCase
{

    // MARK: - Cluster bundle count

    func testClusterBundleCountIsNine() {
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .clusterBundleCount,
            9,
            "9 cluster bundles shipped in the fold arc " +
            "(chapters 524-532)")
    }

    func testClusterBundlesArrayMatchesCount() {
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .clusterBundles.count,
            BASEBrainTurnResultFoldArcSealedDoctrine
                .clusterBundleCount,
            "clusterBundles array length must match " +
            "clusterBundleCount invariant")
    }

    // MARK: - Field coverage

    func testTotalFieldsCoveredEqualsFiftyTwo() {
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .totalFieldsCovered,
            52,
            "9 bundles must cover all 52 original " +
            "BASEBrainTurnResult init args")
    }

    func testOriginalArgCountIsFiftyTwo() {
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .originalArgCount,
            52)
    }

    // MARK: - 100% packaging invariant

    func testHundredPercentPackagingHolds() {
        XCTAssertTrue(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .hundredPercentPackaging,
            "100% packaging invariant must hold:" +
            " sum(bundle.fieldCount) == originalArgCount" +
            " AND postFoldArgCount == clusterBundleCount")
    }

    func testPostFoldArgCountEqualsClusterBundleCount() {
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .postFoldArgCount,
            BASEBrainTurnResultFoldArcSealedDoctrine
                .clusterBundleCount,
            "V1 call site post-fold arg count must equal" +
            " the cluster bundle count (9)")
    }

    // MARK: - Arc metadata

    func testArcCommitCountIsThirtySix() {
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .arcCommitCount,
            36,
            "9 chapters × 4 commits = 36 commits across " +
            "the fold arc")
    }

    func testReductionRatioApproxEightyThreePercent() {
        let ratio = BASEBrainTurnResultFoldArcSealedDoctrine
            .argCountReductionRatio
        // 52 → 9 means (52-9)/52 = 43/52 ≈ 0.8269
        XCTAssertGreaterThan(ratio, 0.82)
        XCTAssertLessThan(ratio, 0.83)
    }

    // MARK: - M-number range

    func testMNumberRangeMatchesArc() {
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .firstChapterMNumber,
            1473,
            "Arc opens at chapter 524 / M1473")
        XCTAssertEqual(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .lastChapterMNumber,
            1508,
            "Arc seals at chapter 532 / M1508")
    }

    // MARK: - Byte-equality

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASEBrainTurnResultFoldArcSealedDoctrine
                .byteEqualityPreserved,
            "Byte-equality preserved at every commit " +
            "boundary of the 9-chapter arc")
    }
}
