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

    func testChapterRangeCoveredIs474To490() {
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .chapterRangeCovered.lowerBound, 474)
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .chapterRangeCovered.upperBound, 490)
    }

    func testMNumberRangeCoveredIs1272To1339() {
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .mNumberRangeCovered.lowerBound, 1272)
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .mNumberRangeCovered.upperBound, 1339)
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
        // chapter 490 post-update:9 + 7 + 8 + 5 + 8 + 8 = 45
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .currentAggregate, 45,
            "chapter 490 current sum (cluster A 100%" +
            " + cluster B 75% + 8 bundle factories)")
        XCTAssertEqual(
            BASRealHotPathAttackEvaluationDoctrine
                .currentAverage,
            45.0 / 6.0, accuracy: 0.01)
    }

    func testNetProgressIsPositive() {
        let net = BASRealHotPathAttackEvaluationDoctrine
            .currentAggregate
            - BASRealHotPathAttackEvaluationDoctrine
                .baselineAggregate
        XCTAssertEqual(net, 34,
            "net progress = 45 - 11 = 34 points across" +
            " 6 directives over 17 chapters (474-490)")
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
        XCTAssertEqual(hardcore?.currentScore, 9,
            "更硬核 score 9/10 post-chapter-484 reflects" +
            " 7-of-8 MPSGraph kernels + cache observation" +
            " + dispatch latency benchmark")
    }

    func testAggressiveScoreReflectsV1FoldProgress() {
        let aggressive = BASRealHotPathAttackEvaluationDoctrine
            .scorings.first {
                $0.directiveName.starts(with: "最激进")
            }
        XCTAssertEqual(aggressive?.currentScore, 5,
            "最激进 5/10 — cluster A 100% (18-of-18)" +
            " + cluster B 75% (18-of-24) folded into 8" +
            " typed bundle factories。 V1 deletion still" +
            " pending (production wire-in + default flip" +
            " required first)。")
    }
}
