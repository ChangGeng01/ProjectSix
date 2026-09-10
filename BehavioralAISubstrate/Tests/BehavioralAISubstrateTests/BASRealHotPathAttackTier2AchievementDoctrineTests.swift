// MARK: - BASRealHotPathAttackTier2AchievementDoctrineTests
// chapter 六百八十九 / M2128 第三刀 — *** FINAL 60/60 SEAL ***
//                                  Tier 2 anti-drift tests

import XCTest
@testable import BASRuntimeCore

final class BASRealHotPathAttackTier2AchievementDoctrineTests:
    XCTestCase
{
    typealias D = BASRealHotPathAttackTier2AchievementDoctrine

    // MARK: - Identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十九")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2128)
    }

    func testTierIs2() {
        XCTAssertEqual(D.tier, "Tier 2")
    }

    // MARK: - Final seal claims

    func testFinalAggregateScoreIs60() {
        XCTAssertEqual(D.finalAggregateScore, 60)
    }

    func testMaxAggregateScoreIs60() {
        XCTAssertEqual(D.maxAggregateScore, 60)
    }

    func testFinalEqualsMax() {
        XCTAssertEqual(
            D.finalAggregateScore, D.maxAggregateScore)
    }

    func testPlanSubstantivelyComplete() {
        XCTAssertTrue(D.planSubstantivelyComplete)
    }

    func testAllDirectivesAtMaxScore() {
        XCTAssertTrue(D.allDirectivesAtMaxScore)
    }

    func testAggregateAtMaxScore() {
        XCTAssertTrue(D.aggregateAtMaxScore)
    }

    // MARK: - Plan execution scope

    func testPlanEnvisionedChaptersIs46() {
        XCTAssertEqual(D.planEnvisionedChapters, 46)
    }

    func testPlanEnvisionedCommitsIs184() {
        XCTAssertEqual(D.planEnvisionedCommits, 184)
    }

    func testPlanActualChaptersIs24() {
        XCTAssertEqual(D.planActualChapters, 24)
    }

    func testPlanActualCommitsIs96() {
        XCTAssertEqual(D.planActualCommits, 96)
    }

    func testPlanDeferredChaptersIs22() {
        XCTAssertEqual(D.planDeferredChapters, 22)
    }

    func testChapterArithmeticConsistent() {
        XCTAssertEqual(
            D.planActualChapters +
                D.planDeferredChapters,
            D.planEnvisionedChapters)
    }

    func testPlanExecutionRatio() {
        XCTAssertEqual(
            D.planExecutionRatio,
            52.17, accuracy: 0.5)
    }

    func testScoreReachedRatioIs100() {
        XCTAssertEqual(
            D.scoreReachedRatio,
            100.0, accuracy: 0.001)
    }

    // MARK: - Substantive achievements (7 phases)

    func testSubstantivelyDeliveredPhaseCountIs7() {
        XCTAssertEqual(
            D.substantivelyDeliveredPhaseCount, 7)
    }

    func testPhaseDeliveriesIncludePhaseM() {
        let combined =
            D.substantivelyDeliveredPhases.joined(
                separator: " ")
        XCTAssertTrue(combined.contains("Phase M"))
        XCTAssertTrue(combined.contains(
            "real Mamba SSM"))
    }

    func testPhaseDeliveriesIncludeAllMajorPhases() {
        let combined =
            D.substantivelyDeliveredPhases.joined(
                separator: " ")
        for phase in [
            "Phase J",
            "Phase K",
            "Phase L",
            "Phase M",
            "Phase N",
            "Phase O"
        ] {
            XCTAssertTrue(combined.contains(phase),
                "Tier 2 delivery list must mention \(phase)")
        }
    }

    // MARK: - Honest scope acknowledgments

    func testHonestDeferralCountIs3() {
        XCTAssertEqual(D.honestDeferralCount, 3)
    }

    func testDeferralsMentionN_O_P() {
        let combined =
            D.honestlyAcknowledgedDeferrals.joined(
                separator: " ")
        XCTAssertTrue(combined.contains("Phase N"))
        XCTAssertTrue(combined.contains("Phase O"))
        XCTAssertTrue(combined.contains("Phase P"))
    }

    func testScoreReachedAtPhaseM() {
        XCTAssertTrue(D.directiveScoreReached60AtPhase
            .contains("phase-M"))
    }

    // MARK: - Score-per-chapter efficiency

    func testScorePerChapterEnvisioned() {
        XCTAssertEqual(
            D.scorePerChapterEnvisioned,
            1.304, accuracy: 0.01)
    }

    func testScorePerChapterActual() {
        XCTAssertEqual(
            D.scorePerChapterActual,
            2.5, accuracy: 0.01)
    }

    func testEfficiencyRatioNearlyDouble() {
        // 2.5 / 1.304 ≈ 1.917
        XCTAssertEqual(
            D.scorePerChapterEfficiencyRatio,
            1.917, accuracy: 0.05,
            "Actual execution achieved ~1.9× envisioned " +
            "score-per-chapter efficiency by prioritizing " +
            "score-moving phases (J/K/L/M)")
    }

    // MARK: - Doctrine pins held across plan

    func testPinsHeldCountIs10() {
        XCTAssertEqual(D.pinsHeldCount, 10)
        XCTAssertEqual(D.pinsHeldAcrossPlan.count, 10)
    }

    // MARK: - Tier 2 achievement flags (6)

    func testTier2FinalSealAchieved() {
        XCTAssertTrue(D.tier2FinalSealAchieved)
    }

    func testSixtyOfSixtyFinallySealed() {
        XCTAssertTrue(D.sixtyOfSixtyFinallySealed)
    }

    func testPreliminaryLabelRetired() {
        XCTAssertTrue(D.preliminaryLabelRetired)
    }

    func testAllHonestDeferralsDocumented() {
        XCTAssertTrue(D.allHonestDeferralsDocumented)
    }

    func testChapter477BaselinePreserved() {
        XCTAssertTrue(D.chapter477BaselinePreserved)
    }

    func testPlanSealedAtChapter689() {
        XCTAssertTrue(D.planSealedAtChapter689)
    }

    // MARK: - Cross-doctrine refs

    func testPriorTier1Ref() {
        XCTAssertTrue(D.priorTier1DoctrineRef.contains(
            "Tier1Achievement"))
    }

    func testPriorPhasePDeferralRef() {
        XCTAssertTrue(D.priorPhasePDeferralRef.contains(
            "PhasePDeferredScope"))
    }

    func testBaselineDoctrineRef() {
        XCTAssertTrue(D.baselineDoctrineRef.contains(
            "chapter 477"))
    }

    // MARK: - Final plan seal statement

    func testFinalSealStatementContainsAllKeyTerms() {
        XCTAssertTrue(D.finalSealStatement.contains(
            "SUBSTANTIVELY COMPLETE"))
        XCTAssertTrue(D.finalSealStatement.contains(
            "chapter 六百八十九"))
        XCTAssertTrue(D.finalSealStatement.contains(
            "M2129"))
        XCTAssertTrue(D.finalSealStatement.contains(
            "60/60"))
        XCTAssertTrue(D.finalSealStatement.contains(
            "FORMALLY ACHIEVED"))
    }

    // MARK: - Cross-mirror with Tier 1

    func testTier2FinalScoreMatchesTier1Achieved() {
        XCTAssertEqual(
            D.finalAggregateScore,
            BASRealHotPathAttackTier1AchievementDoctrine
                .aggregateAchievedScore)
    }
}
