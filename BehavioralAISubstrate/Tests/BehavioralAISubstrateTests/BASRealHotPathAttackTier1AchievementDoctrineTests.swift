// MARK: - BASRealHotPathAttackTier1AchievementDoctrineTests
// chapter 六百八十九 / M2127 第二刀 — Tier 1 achievement
//                                  anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class BASRealHotPathAttackTier1AchievementDoctrineTests:
    XCTestCase
{
    typealias D = BASRealHotPathAttackTier1AchievementDoctrine

    // MARK: - Identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十九")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2127)
    }

    func testTierIs1() {
        XCTAssertEqual(D.tier, "Tier 1")
    }

    // MARK: - Directive count

    func testDirectiveCountIs6() {
        XCTAssertEqual(D.directiveCount, 6)
        XCTAssertEqual(D.directiveAchievements.count, 6)
    }

    func testAllSixDirectiveNamesPresent() {
        let names = D.directiveAchievements.map {
            $0.directive
        }
        let expected = [
            "更硬核",
            "更极致",
            "最创新",
            "最激进",
            "低熵复杂系统",
            "原生利用神经引擎"
        ]
        for name in expected {
            XCTAssertTrue(names.contains(name))
        }
    }

    func testAllDirectiveNamesUnique() {
        let names = D.directiveAchievements.map {
            $0.directive
        }
        XCTAssertEqual(Set(names).count, names.count)
    }

    // MARK: - Aggregate score arithmetic

    func testAggregateBaselineScoreIs11() {
        // 4 + 2 + 3 + 0 + 1 + 1 = 11
        XCTAssertEqual(D.aggregateBaselineScore, 11)
    }

    func testAggregateAchievedScoreIs60() {
        // 10 × 6 = 60
        XCTAssertEqual(D.aggregateAchievedScore, 60)
    }

    func testAggregateScoreDeltaIs49() {
        // 60 - 11 = 49
        XCTAssertEqual(D.aggregateScoreDelta, 49)
    }

    func testMaxAggregateScoreIs60() {
        XCTAssertEqual(D.maxAggregateScore, 60)
    }

    func testAchievedEqualsMax() {
        XCTAssertEqual(
            D.aggregateAchievedScore,
            D.maxAggregateScore)
    }

    // MARK: - Per-directive achievement

    func testEveryDirectiveReached10() {
        for achievement in D.directiveAchievements {
            XCTAssertEqual(
                achievement.achievedScore, 10,
                "Directive \(achievement.directive) " +
                "must be at 10/10")
        }
    }

    func testEveryDirectiveAtMaxFlag() {
        XCTAssertTrue(D.everyDirectiveAtMax)
    }

    func testEveryDirectiveHasPositiveScoreDelta() {
        for achievement in D.directiveAchievements {
            XCTAssertGreaterThan(
                achievement.scoreDelta, 0,
                "Every directive must show positive " +
                "score delta")
        }
    }

    func testEveryDirectiveHasContributingPhase() {
        for achievement in D.directiveAchievements {
            XCTAssertFalse(
                achievement.primaryContributingPhase
                    .isEmpty)
        }
    }

    // MARK: - Score progression checkpoints

    func testCheckpointCountIs3() {
        XCTAssertEqual(D.checkpointCount, 3)
    }

    func testProgressionCheckpointsMentionBaseline() {
        XCTAssertTrue(
            D.scoreProgressionCheckpoints[0]
                .contains("BASELINE"))
    }

    func testFinalCheckpointShowsTier1Achieved() {
        XCTAssertTrue(D.scoreProgressionCheckpoints
            .last?.contains("Tier 1 ACHIEVED") ?? false)
    }

    // MARK: - Tier 1 achievement flags

    func testTier1ScoreReached60() {
        XCTAssertTrue(D.tier1ScoreReached60)
    }

    func testTier1AggregateMatchesMaxScore() {
        XCTAssertTrue(D.tier1AggregateMatchesMaxScore)
    }

    func testEveryDirectiveAtMaxScoreFlag() {
        XCTAssertTrue(D.everyDirectiveAtMaxScore)
    }

    // MARK: - Honest scope acknowledgments

    func testIsNotPreliminary() {
        XCTAssertFalse(D.isPreliminary,
            "Tier 1 ESCALATES from PRELIMINARY to " +
            "FORMAL ACHIEVEMENT record")
    }

    func testChapter477BaselinePreserved() {
        XCTAssertTrue(
            D.chapter477BaselineDoctrinePreserved)
    }

    func testPhasePDeferred() {
        XCTAssertTrue(D.phasePDeferred)
    }

    func testTier1IsFinalForSubstrate() {
        XCTAssertTrue(D.tier1IsFinalForSubstrate)
    }

    // MARK: - Plan execution summary

    func testPlanChaptersCompleteIs24() {
        XCTAssertEqual(D.planChaptersComplete, 24)
    }

    func testPlanCommitsCompleteIs92() {
        XCTAssertEqual(D.planCommitsComplete, 92)
    }

    func testPlanEnvisionedChaptersIs46() {
        XCTAssertEqual(D.planEnvisionedChapters, 46)
    }

    func testPlanExecutionRatioApprox52Percent() {
        XCTAssertEqual(
            D.planExecutionRatio,
            52.17, accuracy: 0.5)
    }

    // MARK: - Cross-doctrine refs

    func testBaselineDoctrineRef() {
        XCTAssertEqual(
            D.baselineDoctrineRef,
            "BASRealHotPathAttackEvaluationDoctrine (chapter 477 / M1285)")
    }

    func testPhasePDeferralRef() {
        XCTAssertTrue(D.phasePDeferralRef.contains(
            "BASPhasePDeferredScopeDoctrine"))
    }

    func testTier2ForwardRef() {
        XCTAssertTrue(D.tier2DoctrineForwardRef.contains(
            "Tier2"))
    }

    // MARK: - Codable round-trip on DirectiveAchievement

    func testDirectiveAchievementCodableRoundTrip() throws {
        let original = D.directiveAchievements[0]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            D.DirectiveAchievement.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Score delta consistency

    func testPerDirectiveScoreDeltaMatchesArithmetic() {
        for achievement in D.directiveAchievements {
            XCTAssertEqual(
                achievement.scoreDelta,
                achievement.achievedScore -
                    achievement.baselineScore)
        }
    }

    // MARK: - Cross-mirror with chapter 477 baseline doctrine

    func testTier1BaselineMatchesChapter477BaselineAggregate() {
        // Cross-mirror PROOF:Tier 1 doctrine's baseline
        // aggregate (sum of per-directive baselines)
        // must EQUAL chapter 477's baselineAggregate
        // (since they're the same directives at the same
        // baseline moment)
        XCTAssertEqual(
            D.aggregateBaselineScore,
            BASRealHotPathAttackEvaluationDoctrine
                .baselineAggregate)
    }
}
