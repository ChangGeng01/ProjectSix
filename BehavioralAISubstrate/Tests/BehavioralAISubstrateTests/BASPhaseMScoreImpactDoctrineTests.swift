// MARK: - BASPhaseMScoreImpactDoctrineTests
// chapter 六百八十二 / M2107 第三刀 — Phase M score impact
//                                    anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class BASPhaseMScoreImpactDoctrineTests: XCTestCase {

    typealias D = BASPhaseMScoreImpactDoctrine

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十二")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2107)
    }

    // MARK: - Score progression (6 checkpoints)

    func testCheckpointCountIs6() {
        XCTAssertEqual(D.checkpointCount, 6)
        XCTAssertEqual(D.scoreProgression.count, 6)
    }

    func testFirstCheckpointIsBaseline() {
        let cp = D.scoreProgression[0]
        XCTAssertEqual(cp.label, "chapter 477 baseline")
        XCTAssertEqual(cp.aggregateScore, 45)
    }

    func testLastCheckpointIsSixtyOfSixty() {
        let cp = D.scoreProgression.last
        XCTAssertEqual(
            cp?.label,
            "post-Phase-M (real Mamba SSM kernel)")
        XCTAssertEqual(cp?.aggregateScore, 60)
    }

    func testProgressionIsMonotonicNonDecreasing() {
        let scores = D.scoreProgression.map {
            $0.aggregateScore
        }
        for i in 1..<scores.count {
            XCTAssertGreaterThanOrEqual(
                scores[i], scores[i-1],
                "score must never regress")
        }
    }

    func testHexa9CheckpointHasNoScoreChange() {
        // Index 4 = post-Hexa-9 (no score impact;catalog only)
        // Index 3 = post-Phase-L (58)
        // Index 4 = post-Hexa-9 (58 — same)
        XCTAssertEqual(
            D.scoreProgression[3].aggregateScore,
            D.scoreProgression[4].aggregateScore,
            "Hexa 9 catalog has zero score impact")
    }

    func testAverageScoreComputedConsistently() {
        // Last checkpoint:60/6 = 10.0
        guard let last = D.scoreProgression.last else {
            return XCTFail("missing last checkpoint")
        }
        XCTAssertEqual(
            last.avgScore, 10.0, accuracy: 0.001)
    }

    // MARK: - Phase M per-directive delta

    func testPhaseMPerDirectiveDeltaCountIs6() {
        XCTAssertEqual(
            D.phaseMPerDirectiveDelta.count, 6)
    }

    func testPhaseMTotalDeltaIs2() {
        XCTAssertEqual(D.phaseMTotalDelta, 2)
    }

    func testPhaseMPrimaryDirectivesAreHardcoreAndNeural() {
        XCTAssertEqual(D.phaseMPrimaryDirectives.count, 2)
        XCTAssertTrue(
            D.phaseMPrimaryDirectives.contains("更硬核"))
        XCTAssertTrue(D.phaseMPrimaryDirectives.contains(
            "原生利用神经引擎"))
    }

    func testNeuralEngineDirectiveAdvancedBy1() {
        XCTAssertEqual(
            D.phaseMPerDirectiveDelta["原生利用神经引擎"], 1)
    }

    func testHardcoreDirectiveAdvancedBy1() {
        XCTAssertEqual(D.phaseMPerDirectiveDelta["更硬核"], 1)
    }

    // MARK: - 60/60 milestone

    func testAggregateScoreReached60() {
        XCTAssertEqual(D.aggregateScoreReached, 60)
    }

    func testMaxAggregateScoreIs60() {
        XCTAssertEqual(D.maxAggregateScore, 60)
    }

    func testAggregatePercentIs100() {
        XCTAssertEqual(
            D.aggregatePercentReached,
            100.0, accuracy: 0.01)
    }

    func testIsSixtyOfSixtyReached() {
        XCTAssertTrue(D.isSixtyOfSixtyReached)
    }

    func testIsFirstSixtyOfSixtyAchievement() {
        XCTAssertTrue(D.isFirstSixtyOfSixtyAchievement)
    }

    // MARK: - Final tier seals (forward links)

    func testFinalTier1SealChapterIs708() {
        XCTAssertEqual(
            D.finalTier1SealChapter, "chapter 七百八")
        XCTAssertEqual(D.finalTier1SealMNumber, 2209)
    }

    func testFinalTier2SealChapterIs709() {
        XCTAssertEqual(
            D.finalTier2SealChapter, "chapter 七百九")
        XCTAssertEqual(D.finalTier2SealMNumber, 2216)
    }

    func testTier1ForwardRefMarksPending() {
        XCTAssertTrue(D.tier1AchievementDoctrineForwardRef
            .contains("PENDING"))
    }

    // MARK: - Honest scope acknowledgments

    func testIsPreliminarySixtySixty() {
        XCTAssertTrue(D.isPreliminarySixtySixty)
    }

    func testMostInnovativeDirectiveAtNineOrTen() {
        XCTAssertTrue(D.mostInnovativeDirectiveAtNineOrTen)
    }

    // MARK: - Cross-doctrine refs

    func testPriorBaselineDoctrineRefIsChapter477() {
        XCTAssertTrue(D.priorBaselineDoctrineRef
            .contains("chapter 477"))
    }

    func testPriorPhaseLAndMRefs() {
        XCTAssertTrue(D.priorPhaseLScoreDoctrineRef
            .contains("BASPhaseLCumulativeCompletion"))
        XCTAssertTrue(D.priorPhaseMCompletionRef
            .contains("BASPhaseMRealSSMScanKernel"))
    }

    // MARK: - Codable round-trip

    func testCheckpointCodableRoundTrip() throws {
        let cp = D.scoreProgression[0]
        let data = try JSONEncoder().encode(cp)
        let decoded = try JSONDecoder().decode(
            D.ScoreCheckpoint.self, from: data)
        XCTAssertEqual(decoded, cp)
    }
}
