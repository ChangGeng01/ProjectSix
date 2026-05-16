// MARK: - BASMostExtremeDirectiveStatusDoctrineTests
// chapter 六百八十八 / M2124 第三刀 — 最极致 directive
//                                  status anti-drift tests

import XCTest
@testable import BASRuntimeCore

final class BASMostExtremeDirectiveStatusDoctrineTests:
    XCTestCase
{
    typealias D = BASMostExtremeDirectiveStatusDoctrine

    // MARK: - Identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十八")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2124)
    }

    func testDirectiveName() {
        XCTAssertEqual(D.directive, "最极致")
    }

    func testDirectiveEnglishGloss() {
        XCTAssertTrue(D.directiveEnglishGloss.contains(
            "most-extreme"))
    }

    // MARK: - Current score

    func testCurrentScoreIs10() {
        XCTAssertEqual(D.currentScore, 10)
    }

    func testMaxScoreIs10() {
        XCTAssertEqual(D.maxScore, 10)
    }

    func testIsAtMaxScore() {
        XCTAssertTrue(D.isAtMaxScore)
    }

    // MARK: - Score history (7 checkpoints)

    func testScoreHistoryCountIs7() {
        XCTAssertEqual(D.scoreHistoryCount, 7)
        XCTAssertEqual(D.scoreHistory.count, 7)
    }

    func testBaselineScoreIs5() {
        let baseline = D.scoreHistory[0]
        XCTAssertEqual(baseline.label,
                       "chapter 477 baseline")
        XCTAssertEqual(baseline.scoreAtCheckpoint, 5)
    }

    func testCurrentCheckpointIsAtMaxScore() {
        let last = D.scoreHistory.last
        XCTAssertEqual(last?.scoreAtCheckpoint, 10)
    }

    func testScoreProgressionIsMonotonicNonDecreasing() {
        let scores = D.scoreHistory.map {
            $0.scoreAtCheckpoint
        }
        for i in 1..<scores.count {
            XCTAssertGreaterThanOrEqual(
                scores[i], scores[i-1],
                "Score must never regress")
        }
    }

    func testPhaseMReachedMaxScore() {
        // post-Phase-M checkpoint should be index 4
        let postM = D.scoreHistory[4]
        XCTAssertEqual(postM.label, "post-Phase-M")
        XCTAssertEqual(postM.scoreAtCheckpoint, 10)
    }

    func testPostPhaseNHoldsMaxScore() {
        let postN = D.scoreHistory[5]
        XCTAssertEqual(postN.label, "post-Phase-N")
        XCTAssertEqual(postN.scoreAtCheckpoint, 10)
    }

    func testPostPhaseOHoldsMaxScore() {
        let postO = D.scoreHistory[6]
        XCTAssertEqual(postO.label, "post-Phase-O")
        XCTAssertEqual(postO.scoreAtCheckpoint, 10)
    }

    // MARK: - Phase O contribution

    func testPhaseOContributionIsStructural() {
        XCTAssertTrue(D.phaseOContributionType.contains(
            "structural"))
    }

    func testPhaseOContributionToScoreIs0() {
        XCTAssertEqual(D.phaseOContributionToScore, 0)
    }

    func testPhaseOTargetWasAspirational() {
        XCTAssertTrue(D.phaseOTargetWasAspirational)
    }

    // MARK: - Achievement contributors

    func testAchievementContributorCountIs5() {
        XCTAssertEqual(
            D.achievementContributorCount, 5)
    }

    func testContributorsIncludeAllPhases() {
        let combined = D.achievementContributors.joined(
            separator: " ")
        XCTAssertTrue(combined.contains("Phase J"))
        XCTAssertTrue(combined.contains("Phase K"))
        XCTAssertTrue(combined.contains("Phase L"))
        XCTAssertTrue(combined.contains("Phase M"))
        XCTAssertTrue(combined.contains("Phase O"))
    }

    // MARK: - Deferred work

    func testDeferredWorkCountIs5() {
        XCTAssertEqual(D.deferredWorkCount, 5)
    }

    func testDeferredWorkUnlockGateMentionsADR014() {
        XCTAssertTrue(D.deferredWorkUnlockGate.contains(
            "ADR-014"))
    }

    // MARK: - Score saturation

    func testScoreIsSaturatedAtMax() {
        XCTAssertTrue(D.scoreIsSaturatedAtMax)
    }

    func testFurtherPhaseOWorkScoreImpactIs0() {
        XCTAssertEqual(D.furtherPhaseOWorkScoreImpact, 0)
    }

    // MARK: - Achievement flags

    func testDirectiveAtMaxScore() {
        XCTAssertTrue(D.directiveAtMaxScore)
    }

    func testPhaseODidNotMoveScore() {
        XCTAssertTrue(D.phaseODidNotMoveScore)
    }

    func testScoreProtectedByPriorPhases() {
        XCTAssertTrue(D.scoreProtectedByPriorPhases)
    }

    func testV1DeletionWouldNotMoveScore() {
        XCTAssertTrue(D.v1DeletionWouldNotMoveScore)
    }

    // MARK: - Cross-doctrine refs

    func testPriorPhaseOCompletionRef() {
        XCTAssertEqual(
            D.priorPhaseOCompletionRef,
            "BASPhaseOCompletionDoctrine")
    }

    func testPriorPhaseLCompletionRef() {
        XCTAssertEqual(
            D.priorPhaseLCompletionRef,
            "BASPhaseLCumulativeCompletionDoctrine")
    }

    func testBaselineDoctrineRefMentions477() {
        XCTAssertTrue(D.baselineDoctrineRef.contains(
            "chapter 477"))
    }

    // MARK: - Codable round-trip on ScoreCheckpoint

    func testScoreCheckpointCodableRoundTrip() throws {
        let cp = D.scoreHistory[0]
        let data = try JSONEncoder().encode(cp)
        let decoded = try JSONDecoder().decode(
            D.ScoreCheckpoint.self, from: data)
        XCTAssertEqual(decoded, cp)
    }
}
