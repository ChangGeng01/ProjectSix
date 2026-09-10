// MARK: - BASPhasePDeferredScopeDoctrineTests
// chapter 六百八十九 / M2126 第一刀 — Phase P deferred-
//                                  scope anti-drift tests

import XCTest
@testable import BASRuntimeCore

final class BASPhasePDeferredScopeDoctrineTests:
    XCTestCase
{
    typealias D = BASPhasePDeferredScopeDoctrine

    // MARK: - Identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十九")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2126)
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase P")
    }

    // MARK: - Original vs actual scope

    func testOriginalPlanChapterCountIs19() {
        XCTAssertEqual(D.originalPlanChapterCount, 19)
    }

    func testOriginalPlanCommitCountIs76() {
        XCTAssertEqual(D.originalPlanCommitCount, 76)
    }

    func testOriginalPlanTypeMigrationCountIs78() {
        XCTAssertEqual(
            D.originalPlanTypeMigrationCount, 78)
    }

    func testActualShippedIsZero() {
        XCTAssertEqual(D.actuallyShippedChapterCount, 0)
        XCTAssertEqual(D.actuallyShippedCommitCount, 0)
        XCTAssertEqual(
            D.actuallyShippedTypeMigrationCount, 0)
    }

    func testScopeReductionRatioIs100Percent() {
        XCTAssertEqual(
            D.scopeReductionRatio, 1.0, accuracy: 0.001)
    }

    // MARK: - Deferred work inventory

    func testDeferredTotalTypeCountIs62() {
        // 14 + 27 + 10 + 3 + 2 + 6 = 62
        XCTAssertEqual(D.deferredTotalTypeCount, 62)
    }

    func testDeferredTypeCountsArePlanReasonable() {
        XCTAssertEqual(D.deferredTierBBundleCount, 14)
        XCTAssertEqual(D.deferredResultTypeCount, 27)
        XCTAssertEqual(D.deferredFrameTypeCount, 10)
        XCTAssertEqual(D.deferredPermitTypeCount, 3)
        XCTAssertEqual(D.deferredCardTypeCount, 2)
        XCTAssertEqual(D.deferredTierCGenericCount, 6)
    }

    // MARK: - Deferral reasons

    func testDeferralReasonCountIs4() {
        XCTAssertEqual(D.deferralReasonCount, 4)
        XCTAssertEqual(D.deferralReasons.count, 4)
    }

    func testReasonsIncludeSaturationArgument() {
        let combined = D.deferralReasons.joined(
            separator: " ")
        XCTAssertTrue(combined.contains("saturated"))
        XCTAssertTrue(combined.contains("10/10"))
    }

    // MARK: - Score impact

    func testPhasePTargetWas3() {
        XCTAssertEqual(D.phasePScoreDeltaTarget, 3)
    }

    func testPhasePActualIs0() {
        XCTAssertEqual(D.phasePScoreDeltaActual, 0)
    }

    func testNotMovingDirectiveIs低熵复杂系统() {
        XCTAssertEqual(
            D.scoreNotMovingDirectives.count, 1)
        XCTAssertTrue(
            D.scoreNotMovingDirectives.first?
                .contains("低熵复杂系统") ?? false)
    }

    // MARK: - Plan completion claims

    func testPlanSubstantivelyCompleteAfterChapter() {
        XCTAssertEqual(
            D.planSubstantivelyCompleteAfterChapter,
            "chapter 六百八十九")
    }

    func testPlanSubstantivelyCompleteAtM2129() {
        XCTAssertEqual(
            D.planSubstantivelyCompleteAtMNumber, 2129)
    }

    func testPlanChaptersActuallyShippedIs24() {
        XCTAssertEqual(
            D.planChaptersActuallyShipped, 24)
    }

    func testPlanChaptersDeferredIs19() {
        XCTAssertEqual(D.planChaptersDeferred, 19)
    }

    func testPlanCompletionRatioApprox52Percent() {
        // 24 / 46 = 52.17%
        XCTAssertEqual(
            D.planActualCompletionRatio,
            52.17, accuracy: 0.5)
    }

    // MARK: - Achievement preservation

    func testAggregateScoreReached60() {
        XCTAssertEqual(D.aggregateScoreReached, 60)
        XCTAssertEqual(D.maxAggregateScore, 60)
    }

    func testIsSixtyOfSixtyReachedBeforePhaseP() {
        XCTAssertTrue(
            D.isSixtyOfSixtyReachedBeforePhaseP)
    }

    func testPhasePNotNeededForScoreCompletion() {
        XCTAssertTrue(
            D.phasePNotNeededForScoreCompletion)
    }

    func testScoreReachedAtPhaseM() {
        XCTAssertTrue(D.aggregateScoreReachedAtChapter
            .contains("Phase M"))
    }

    // MARK: - Forward path

    func testNextKnifeIsM2127() {
        XCTAssertEqual(D.nextKnife, "M2127 第二刀")
    }

    func testNextKnifeGoalIsTier1Doctrine() {
        XCTAssertTrue(D.nextKnifeGoal.contains("Tier1"))
    }

    func testSecondNextKnifeIsM2128() {
        XCTAssertEqual(
            D.secondNextKnife, "M2128 第三刀")
    }

    func testSecondNextKnifeIsTier2FinalSeal() {
        XCTAssertTrue(D.secondNextKnifeGoal.contains(
            "FINAL 60/60 SEAL"))
    }

    func testCloseOutKnifeIsM2129() {
        XCTAssertEqual(
            D.chapterCloseOutKnife, "M2129 第四刀")
    }

    // MARK: - Honest scope flags

    func testIsHonestDeferralNotFailure() {
        XCTAssertTrue(D.isHonestDeferralNotFailure)
    }

    func testIsPhasePInfrastructureOptional() {
        XCTAssertTrue(D.isPhasePInfrastructureOptional)
    }

    func testIsPlanSubstantivelyComplete() {
        XCTAssertTrue(D.isPlanSubstantivelyComplete)
    }

    // MARK: - Cross-doctrine refs

    func testPriorPhaseOCompletionRef() {
        XCTAssertEqual(
            D.priorPhaseOCompletionRef,
            "BASPhaseOCompletionDoctrine")
    }

    func testPriorPhaseNStrategyRef() {
        XCTAssertEqual(
            D.priorPhaseNStrategyRef,
            "BASTierAMigrationStrategyDoctrine")
    }
}
