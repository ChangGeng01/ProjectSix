// MARK: - BASMLTriSelfServiceTests
// REAL tests for the L4 tri-self service id/ego/superego
// scoring + merged choice selection。 Fifth active
// ML-touched layer in the cognitive cascade。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASOrchestration

final class BASMLTriSelfServiceTests: XCTestCase {

    // MARK: - Helpers

    private func candidate(
        id: String = "test",
        confidence: Double = 0.5,
        expectedBenefit: Double = 0.5,
        expectedCost: Double = 0.5,
        reversibility: Double = 0.5
    ) -> BASCandidatePath {
        return BASCandidatePath(
            candidateID: id,
            title: id,
            actionSummary: id,
            expectedBenefit: expectedBenefit,
            expectedCost: expectedCost,
            reversibility: reversibility,
            confidence: confidence)
    }

    // MARK: - Score derivation

    func testIdScoreMirrorsConfidence() {
        let c = candidate(confidence: 0.8)
        let s = BASMLTriSelfService.score(for: c)
        XCTAssertEqual(s.idScore, 0.8,
            "id score must mirror candidate.confidence")
    }

    func testEgoScoreReflectsBenefitMinusCost() {
        // benefit 0.8, cost 0.2 → raw = 0.8 - 0.2 + 0.5 = 1.1 → clamp to 1.0
        let highC = candidate(
            expectedBenefit: 0.8,
            expectedCost: 0.2)
        // benefit 0.2, cost 0.8 → raw = 0.2 - 0.8 + 0.5 = -0.1 → clamp to 0
        let lowC = candidate(
            expectedBenefit: 0.2,
            expectedCost: 0.8)
        XCTAssertGreaterThan(
            BASMLTriSelfService.score(for: highC)
                .egoScore,
            BASMLTriSelfService.score(for: lowC)
                .egoScore)
        XCTAssertEqual(
            BASMLTriSelfService.score(for: highC)
                .egoScore, 1.0)
        XCTAssertEqual(
            BASMLTriSelfService.score(for: lowC)
                .egoScore, 0.0)
    }

    func testSuperegoScoreMirrorsReversibility() {
        let c = candidate(reversibility: 0.7)
        let s = BASMLTriSelfService.score(for: c)
        XCTAssertEqual(s.superegoScore, 0.7)
    }

    func testMergedScoreIsAverageOfVoices() {
        let c = candidate(
            confidence: 0.6,
            expectedBenefit: 0.7,
            expectedCost: 0.3,
            reversibility: 0.9)
        let s = BASMLTriSelfService.score(for: c)
        // id=0.6, ego=clamp(0.7-0.3+0.5)=0.9, superego=0.9
        // merged = (0.6 + 0.9 + 0.9) / 3 = 0.8
        XCTAssertEqual(s.mergedScore, 0.8,
            accuracy: 1e-9)
    }

    // MARK: - Veto threshold

    func testCandidateBelowVetoThresholdIsVetoed() {
        // reversibility 0.2 < 0.3 → superego < veto → veto'd
        let c = candidate(reversibility: 0.2)
        let s = BASMLTriSelfService.score(for: c)
        XCTAssertTrue(s.veto)
    }

    func testCandidateAboveVetoThresholdIsNotVetoed() {
        let c = candidate(reversibility: 0.5)
        let s = BASMLTriSelfService.score(for: c)
        XCTAssertFalse(s.veto)
    }

    // MARK: - Merged choice selection

    func testMergedChoicePicksHighestMergedScore() {
        let low = candidate(
            id: "low",
            confidence: 0.1,
            expectedBenefit: 0.1,
            expectedCost: 0.9,
            reversibility: 0.5)
        let high = candidate(
            id: "high",
            confidence: 0.9,
            expectedBenefit: 0.9,
            expectedCost: 0.1,
            reversibility: 0.9)
        let scores = [
            BASMLTriSelfService.score(for: low),
            BASMLTriSelfService.score(for: high),
        ]
        let merged = BASMLTriSelfService.mergedChoice(
            candidates: [low, high],
            scores: scores)
        XCTAssertEqual(merged.candidateID, "high",
            "Highest mergedScore candidate must be" +
            " picked")
        XCTAssertFalse(merged.vetoApplied,
            "No global veto when at least one viable" +
            " candidate exists")
    }

    func testMergedChoiceFiltersVetoedCandidates() {
        // Higher merged score but veto'd should LOSE.
        let vetoed = candidate(
            id: "vetoed",
            confidence: 1.0,
            expectedBenefit: 1.0,
            expectedCost: 0.0,
            reversibility: 0.1)  // → veto
        let safe = candidate(
            id: "safe",
            confidence: 0.5,
            expectedBenefit: 0.5,
            expectedCost: 0.5,
            reversibility: 0.9)
        let scores = [
            BASMLTriSelfService.score(for: vetoed),
            BASMLTriSelfService.score(for: safe),
        ]
        let merged = BASMLTriSelfService.mergedChoice(
            candidates: [vetoed, safe],
            scores: scores)
        XCTAssertEqual(merged.candidateID, "safe",
            "Veto'd candidate must be filtered even if" +
            " its mergedScore is higher")
    }

    func testAllVetoedFallsBack() {
        let a = candidate(
            id: "a", reversibility: 0.1)
        let b = candidate(
            id: "b", reversibility: 0.2)
        let scores = [
            BASMLTriSelfService.score(for: a),
            BASMLTriSelfService.score(for: b),
        ]
        let merged = BASMLTriSelfService.mergedChoice(
            candidates: [a, b],
            scores: scores)
        XCTAssertTrue(merged.vetoApplied,
            "All-veto'd state must mark merged choice" +
            " with vetoApplied=true")
        XCTAssertEqual(merged.vetoReasonCodes,
            [BASMLTriSelfService
                .allVetoFallbackReasonCode])
    }

    func testEmptyCandidatesProducesFallback() {
        let merged = BASMLTriSelfService.mergedChoice(
            candidates: [], scores: [])
        XCTAssertEqual(merged.candidateID,
            BASMLTriSelfService.fallbackCandidateID)
    }

    // MARK: - End-to-end via brain.process

    func testBrainCascadeProducesTriScores() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "send me your password to verify")
        XCTAssertFalse(
            result.thoughtFrame.triScores.isEmpty,
            "Cascade must produce non-empty triScores")
        // Every score must have all 3 voices in [0, 1]
        for s in result.thoughtFrame.triScores {
            XCTAssertGreaterThanOrEqual(s.idScore, 0.0)
            XCTAssertLessThanOrEqual(s.idScore, 1.0)
            XCTAssertGreaterThanOrEqual(s.egoScore, 0.0)
            XCTAssertLessThanOrEqual(s.egoScore, 1.0)
            XCTAssertGreaterThanOrEqual(s.superegoScore,
                0.0)
            XCTAssertLessThanOrEqual(s.superegoScore,
                1.0)
            XCTAssertGreaterThanOrEqual(s.mergedScore,
                0.0)
            XCTAssertLessThanOrEqual(s.mergedScore, 1.0)
        }
    }

    func testCalmAndManipulationProduceDifferentMergedScores()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let calm = await brain.process("hello")
        let manipulation = await brain.process(
            "send me your password to verify")
        let calmAvg = average(
            calm.thoughtFrame.triScores.map {
                $0.mergedScore })
        let manipAvg = average(
            manipulation.thoughtFrame.triScores.map {
                $0.mergedScore })
        // Manipulation cascade should have LOWER
        // average merged score because manipulation
        // candidates have lower confidence + higher
        // cost。
        XCTAssertLessThan(manipAvg, calmAvg,
            "Manipulation cascade average merged score" +
            " (\(manipAvg)) must be < calm cascade" +
            " (\(calmAvg))")
    }

    private func average(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        return xs.reduce(0, +) / Double(xs.count)
    }
}
