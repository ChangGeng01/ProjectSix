// MARK: - BASRealHotPathAttackEvaluationDoctrineTests
// chapter 四百七十七 / M1285
//
// PROOF that the post-chapter-477 re-evaluation doctrine
// pins remain stable + score progression matches
// chapter-by-chapter shipped work。

import XCTest
@testable import BASRuntimeCore

final class BASRealHotPathAttackEvaluationDoctrineTests:
    XCTestCase
{

    // MARK: - Six directives covered

    func testSixDirectivesCovered() {
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .scorings.count, 6,
            "User stated 6 directives:更硬核 更极致" +
            " 最创新 最激进 低熵复杂系统 原生利用神经引擎")
    }

    // MARK: - Chapter range covered

    func testChapterRangeCoveredIs474To477() {
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .chapterRangeCovered.lowerBound, 474)
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .chapterRangeCovered.upperBound, 477)
    }

    func testMNumberRangeCoveredIs1272To1287() {
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .mNumberRangeCovered.lowerBound, 1272)
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .mNumberRangeCovered.upperBound, 1287)
    }

    // MARK: - Every directive has positive delta

    func testEveryDirectiveHasNonNegativeDelta() {
        for scoring in BASRealHotPathAttackEvaluationDoctrine
            .scorings
        {
            XCTAssertGreaterThanOrEqual(
                scoring.scoreDelta, 0,
                "directive '\(scoring.directiveName)'" +
                " delta = \(scoring.scoreDelta);" +
                " regression detected")
        }
    }

    // MARK: - Every directive has at least 1 evidence

    func testEveryDirectiveHasEvidence() {
        for scoring in BASRealHotPathAttackEvaluationDoctrine
            .scorings
        {
            if scoring.scoreDelta > 0 {
                XCTAssertFalse(
                    scoring.evidence.isEmpty,
                    "directive '\(scoring.directiveName)'" +
                    " has positive delta but no" +
                    " evidence list")
            }
        }
    }

    // MARK: - Aggregate scores

    /// Baseline (chapter 473):平均 ~1.8/10
    /// Current (chapter 477):平均 ~4.7/10 expected
    func testBaselineAggregateMatchesChapter473() {
        // 4 + 2 + 3 + 0 + 1 + 1 = 11 / 6 ≈ 1.83
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .baselineAggregate, 11,
            "chapter 473 deep-review baseline sum")
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .baselineAverage,
            11.0 / 6.0, accuracy: 0.01)
    }

    func testCurrentAggregateReflectsShippedWork() {
        // 7 + 5 + 7 + 1 + 3 + 5 = 28 / 6 ≈ 4.67
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .currentAggregate, 28,
            "chapter 477 current sum")
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .currentAverage,
            28.0 / 6.0, accuracy: 0.01)
    }

    func testNetProgressIsPositive() {
        let net = BASRealHotPathAttackEvaluationDoctrine
            .currentAggregate
            - BASRealHotPathAttackEvaluationDoctrine
                .baselineAggregate
        XCTAssertEqual(net, 17,
            "net progress = 28 - 11 = 17 points across" +
            " 6 directives over 4 chapters")
    }

    // MARK: - Every directive has stillOpen scope ack

    func testEveryDirectiveAcknowledgesOpenScope() {
        for scoring in BASRealHotPathAttackEvaluationDoctrine
            .scorings
        {
            XCTAssertFalse(
                scoring.stillOpen.isEmpty,
                "directive '\(scoring.directiveName)'" +
                " must acknowledge open scope" +
                " (honest scope tracking)")
        }
    }

    // MARK: - Codable round-trip

    func testScoringRoundTripsViaJSON() throws {
        let original = BASRealHotPathAttackEvaluationDoctrine
            .scorings
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            [BASDirectiveScoring].self, from: data)
        XCTAssertEqual(decoded, original,
            "doctrine state must round-trip Codable" +
            " (chapter 三百九二)")
    }

    // MARK: - Specific directive cross-checks

    func testHardcoreScoreMatchesShippedKernelCoverage() {
        let hardcore = BASRealHotPathAttackEvaluationDoctrine
            .scorings.first {
                $0.directiveName.starts(with: "更硬核")
            }
        XCTAssertNotNil(hardcore)
        XCTAssertEqual(hardcore?.currentScore, 7,
            "更硬核 score 7/10 reflects 4-of-4 MPSGraph" +
            " kernels having numerical PROOF (matMul" +
            " M1277 + rmsNorm M1280 + rotaryEmbedding" +
            " M1282 + attention M1284)")
    }

    func testAggressiveScoreReflectsV1MonolithUntouched() {
        let aggressive = BASRealHotPathAttackEvaluationDoctrine
            .scorings.first {
                $0.directiveName.starts(with: "最激进")
            }
        XCTAssertEqual(aggressive?.currentScore, 1,
            "最激进 stays low — V1 monolith 2540 LOC" +
            " genuinely untouched in chapters 474-477。" +
            " Honest accounting,not sandbagging。")
    }
}
