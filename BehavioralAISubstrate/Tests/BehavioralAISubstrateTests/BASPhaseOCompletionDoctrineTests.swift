// MARK: - BASPhaseOCompletionDoctrineTests
// chapter 六百八十八 / M2123 第二刀 — Phase O completion
//                                  anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class BASPhaseOCompletionDoctrineTests: XCTestCase {

    typealias D = BASPhaseOCompletionDoctrine

    // MARK: - Identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十八")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2122)
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase O")
    }

    func testPhaseStatusContainsDeferred() {
        XCTAssertTrue(D.phaseStatus.contains("deferred"))
    }

    // MARK: - Phase range

    func testPhaseStartChapter() {
        XCTAssertEqual(
            D.phaseStartChapter, "chapter 六百八十六")
    }

    func testPhaseEndChapter() {
        XCTAssertEqual(
            D.phaseEndChapter, "chapter 六百八十八")
    }

    func testPhaseStartMNumberIs2114() {
        XCTAssertEqual(D.phaseStartMNumber, 2114)
    }

    func testPhaseEndMNumberIs2125() {
        XCTAssertEqual(D.phaseEndMNumber, 2125)
    }

    func testPhaseChapterCountIs3() {
        XCTAssertEqual(D.phaseChapterCount, 3)
    }

    func testPhaseCommitCountIs12() {
        XCTAssertEqual(D.phaseCommitCount, 12)
    }

    func testChapterCommitProduct() {
        XCTAssertEqual(
            D.phaseChapterCount * 4,
            D.phaseCommitCount)
    }

    // MARK: - Chapter manifest

    func testChapterManifestCountIs3() {
        XCTAssertEqual(D.phaseOChaptersCount, 3)
        XCTAssertEqual(D.phaseOChapters.count, 3)
    }

    func testChapter686MentionsRiskFree() {
        XCTAssertTrue(D.phaseOChapters[0].contains(
            "risk-free"))
    }

    func testChapter687MentionsWireIn() {
        XCTAssertTrue(D.phaseOChapters[1].contains(
            "WIRE-IN"))
    }

    func testChapter688MentionsCompletion() {
        XCTAssertTrue(D.phaseOChapters[2].contains(
            "COMPLETION"))
    }

    // MARK: - Artifacts

    func testProductionArtifactCountIs5() {
        XCTAssertEqual(D.productionArtifactCount, 5)
    }

    func testWireInLOCDeltaIs11() {
        XCTAssertEqual(
            D.plusRunTurnSwiftWireInLOCDelta, 11)
    }

    // MARK: - Aspirational vs actual

    func testAspirationalLOCDelta() {
        XCTAssertEqual(D.aspirationalLOCDelta, -1723)
    }

    func testActualLOCDelta() {
        XCTAssertEqual(D.actualLOCDelta, 11)
    }

    func testAspirationalAchievedRatioIsTiny() {
        // ~0.64% but sign-flipped (positive ratio because
        // sign of actual is opposite to sign of target)
        XCTAssertEqual(
            D.aspirationalAchievedRatio,
            0.64, accuracy: 0.01)
    }

    func testV1DeletionDeferred() {
        XCTAssertTrue(D.v1DeletionDeferred)
    }

    func testV1OptOutContractPreserved() {
        XCTAssertTrue(D.v1OptOutContractPreserved)
    }

    // MARK: - Test counts

    func testChapter686TestCountIs44() {
        XCTAssertEqual(D.chapter686TestCount, 44)
    }

    func testChapter687TestCountIs56() {
        XCTAssertEqual(D.chapter687TestCount, 56)
    }

    func testTotalPhaseOTestsAtM2122Is100() {
        // chapter 688 tests at M2122 still 0 (this
        // commit's tests land in this same commit)
        XCTAssertEqual(D.totalPhaseOTestCount, 100)
    }

    // MARK: - Score-delta

    func testScoreDeltaTargetIs5() {
        XCTAssertEqual(D.phaseOScoreDeltaTarget, 5)
    }

    func testScoreDeltaActualIs0() {
        XCTAssertEqual(D.phaseOScoreDeltaActual, 0)
    }

    func testPrePhaseOScoreIs60() {
        XCTAssertEqual(D.prePhaseOScore, 60)
    }

    func testPostPhaseOScoreIs60() {
        XCTAssertEqual(D.postPhaseOScore, 60)
    }

    func testScoreUnchanged() {
        XCTAssertEqual(
            D.prePhaseOScore, D.postPhaseOScore)
    }

    // MARK: - Honest scope flags

    func testAllSixHonestScopeFlags() {
        XCTAssertTrue(D.openingChapterRiskFree)
        XCTAssertTrue(D.wireInChapterRiskRealizedLow)
        XCTAssertTrue(D.deletionChapterScopeReduced)
        XCTAssertTrue(D.v1OptOutContractIntact)
        XCTAssertTrue(D.phaseOInfrastructureShipped)
        XCTAssertTrue(D.phaseODirectiveScoreUnchanged)
    }

    // MARK: - Doctrine pins held

    func testPinsHeldCountIs8() {
        XCTAssertEqual(D.pinsHeldThroughoutCount, 8)
        XCTAssertEqual(D.pinsHeldThroughout.count, 8)
    }

    // MARK: - Cross-doctrine refs

    func testCrossDoctrineRefs() {
        XCTAssertEqual(
            D.priorChapter686OpeningRef,
            "BASPhaseOV1MonolithDeletionPlanDoctrine")
        XCTAssertEqual(
            D.priorChapter687WireInRef,
            "BASPhaseOWireInByteEqualityProofDoctrine")
        XCTAssertEqual(
            D.priorLateClusterBundleRef,
            "BASTurnAuditProjectionsLateClusterFinalBundle")
    }

    // MARK: - Plan progress (HALFWAY MILESTONE)

    func testPlanChaptersCompletePostO() {
        XCTAssertEqual(D.planChaptersCompletePostO, 23)
    }

    func testPlanPercentCompletePostOIsExactlyFifty() {
        XCTAssertEqual(
            D.planPercentCompletePostO,
            50.0, accuracy: 0.01,
            "Phase O close-out reaches exactly the " +
            "HALFWAY MILESTONE of the wild-rolling-" +
            "meerkat plan (23/46 chapters)")
    }
}
