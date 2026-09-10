import XCTest
@testable import QinaoLoop

/// M289 — L10 tribunal real-LLM three-voice scoring (pure helpers).
///
/// `makeTriSelfPrompt` and `parseTriSelfScore` are pure deterministic
/// functions: same inputs → same outputs. These tests pin the prompt
/// shape (so drift is caught) and the parser's contract (parse all
/// three voices or fall back wholesale).
final class QinaoLoopTriSelfFromLLMTests: XCTestCase {

    // MARK: - Fixtures

    private func makeCandidateInput(
        _ id: String = "c1",
        confidence: Double = 0.5,
        evidenceGap: Double = 0.3,
        manipulationRisk: Double = 0.2,
        emotionalBias: Double = 0.4,
        boundaryConflict: Double = 0.1,
        reversibility: Double = 0.6
    ) -> QinaoLoop.CandidateInput {
        QinaoLoop.CandidateInput(
            candidateID: id,
            title: "title-\(id)",
            actionSummary: "send-the-message",
            expectedBenefit: 0.5,
            expectedCost: 0.2,
            reversibility: reversibility,
            confidence: confidence,
            evidenceGap: evidenceGap,
            manipulationRisk: manipulationRisk,
            emotionalBias: emotionalBias,
            boundaryConflict: boundaryConflict,
            worldPriorClaim: nil)
    }

    private func heuristicFallback(
        for candidate: QinaoLoop.CandidateInput,
        wpc: Double = 0.0
    ) -> () -> QinaoLoop.TriSelfScore {
        return {
            QinaoLoop.triSelfScore(
                for: candidate,
                worldPriorContradiction: wpc)
        }
    }

    // MARK: - Prompt builder tests

    func test_promptContainsThreeVoiceSectionHeaders() {
        let p = QinaoLoop.makeTriSelfPrompt(
            for: makeCandidateInput(),
            worldPriorContradiction: 0.3)
        XCTAssertTrue(p.contains("GUARDIAN: protector"))
        XCTAssertTrue(p.contains("SCOUT: explorer"))
        XCTAssertTrue(p.contains("HARMONY: reconciler"))
    }

    func test_promptIncludesCandidateActionSummary() {
        let cand = makeCandidateInput("plan-A")
        let p = QinaoLoop.makeTriSelfPrompt(
            for: cand,
            worldPriorContradiction: 0)
        XCTAssertTrue(p.contains("send-the-message"))
        XCTAssertTrue(p.contains("plan-A"))
    }

    func test_promptIncludesNumericFieldsToTwoDecimals() {
        let cand = makeCandidateInput(
            evidenceGap: 0.234567,
            manipulationRisk: 0.6789)
        let p = QinaoLoop.makeTriSelfPrompt(
            for: cand,
            worldPriorContradiction: 0.55555)
        XCTAssertTrue(p.contains("evidence_gap: 0.23"))
        XCTAssertTrue(p.contains("manipulation_risk: 0.68"))
        XCTAssertTrue(p.contains("world_prior_contradiction: 0.56"))
    }

    func test_promptHasReplyFormatInstructions() {
        let p = QinaoLoop.makeTriSelfPrompt(
            for: makeCandidateInput(),
            worldPriorContradiction: 0)
        XCTAssertTrue(p.contains("GUARDIAN concern:"))
        XCTAssertTrue(p.contains("GUARDIAN reasons:"))
        XCTAssertTrue(p.contains("SCOUT concern:"))
        XCTAssertTrue(p.contains("SCOUT reasons:"))
        XCTAssertTrue(p.contains("HARMONY concern:"))
        XCTAssertTrue(p.contains("HARMONY reasons:"))
    }

    func test_promptIsPureDeterministic() {
        let cand = makeCandidateInput()
        let p1 = QinaoLoop.makeTriSelfPrompt(
            for: cand, worldPriorContradiction: 0.4)
        let p2 = QinaoLoop.makeTriSelfPrompt(
            for: cand, worldPriorContradiction: 0.4)
        XCTAssertEqual(p1, p2)
    }

    // MARK: - Parser happy path

    func test_parseAllThreeVoicesPresent() {
        let cand = makeCandidateInput("c1")
        let llmText = """
            GUARDIAN concern: 0.7
            GUARDIAN reasons: manipulation-risk, boundary-conflict
            SCOUT concern: 0.4
            SCOUT reasons: evidence-gap
            HARMONY concern: 0.3
            HARMONY reasons:
            """
        let result = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertTrue(result.usedLLM)
        XCTAssertEqual(result.score.candidateID, "c1")
        XCTAssertEqual(
            result.score.guardVoice.concern, 0.7, accuracy: 1e-6)
        XCTAssertEqual(
            result.score.guardVoice.reasonCodes,
            ["manipulation-risk", "boundary-conflict"])
        XCTAssertEqual(
            result.score.scoutVoice.concern, 0.4, accuracy: 1e-6)
        XCTAssertEqual(
            result.score.scoutVoice.reasonCodes, ["evidence-gap"])
        XCTAssertEqual(
            result.score.harmonyVoice.concern, 0.3, accuracy: 1e-6)
        XCTAssertEqual(
            result.score.harmonyVoice.reasonCodes, [])
        XCTAssertEqual(
            result.score.dominantVoice, .guardian) // 0.7 highest
    }

    func test_parseClampOutOfRangeConcern() {
        let cand = makeCandidateInput()
        let llmText = """
            GUARDIAN concern: 1.5
            GUARDIAN reasons:
            SCOUT concern: -0.3
            SCOUT reasons:
            HARMONY concern: 0.5
            HARMONY reasons:
            """
        let result = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertTrue(result.usedLLM)
        XCTAssertEqual(
            result.score.guardVoice.concern, 1.0, accuracy: 1e-6)
        XCTAssertEqual(
            result.score.scoutVoice.concern, 0.0, accuracy: 1e-6)
    }

    func test_parseHandlesCaseInsensitive() {
        let cand = makeCandidateInput()
        let llmText = """
            guardian concern: 0.6
            guardian reasons: x
            Scout Concern: 0.4
            scout reasons: y
            HARMONY CONCERN: 0.2
            harmony reasons:
            """
        let result = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertTrue(result.usedLLM)
        XCTAssertEqual(
            result.score.guardVoice.concern, 0.6, accuracy: 1e-6)
        XCTAssertEqual(
            result.score.scoutVoice.concern, 0.4, accuracy: 1e-6)
        XCTAssertEqual(
            result.score.harmonyVoice.concern, 0.2, accuracy: 1e-6)
    }

    func test_parseHandlesTrailingJunkAfterNumber() {
        let cand = makeCandidateInput()
        let llmText = """
            GUARDIAN concern: 0.7 (high)
            GUARDIAN reasons:
            SCOUT concern: 0.3
            SCOUT reasons:
            HARMONY concern: 0.2
            HARMONY reasons:
            """
        let result = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertTrue(result.usedLLM)
        XCTAssertEqual(
            result.score.guardVoice.concern, 0.7, accuracy: 1e-6)
    }

    // MARK: - Parser fallback paths

    func test_parseMissingGuardianFallsBack() {
        let cand = makeCandidateInput()
        let llmText = """
            SCOUT concern: 0.4
            SCOUT reasons:
            HARMONY concern: 0.3
            HARMONY reasons:
            """
        let result = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertFalse(result.usedLLM)
        // Score should match heuristic baseline.
        let expected = QinaoLoop.triSelfScore(
            for: cand, worldPriorContradiction: 0)
        XCTAssertEqual(
            result.score.guardVoice.concern,
            expected.guardVoice.concern,
            accuracy: 1e-6)
    }

    func test_parseEmptyOutputFallsBack() {
        let cand = makeCandidateInput()
        let result = QinaoLoop.parseTriSelfScore(
            from: "",
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertFalse(result.usedLLM)
    }

    func test_parseGarbageFallsBack() {
        let cand = makeCandidateInput()
        let result = QinaoLoop.parseTriSelfScore(
            from: "the model refused to answer",
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertFalse(result.usedLLM)
    }

    // MARK: - Dominant voice computation

    func test_dominantVoiceFollowsHighestConcern() {
        let cand = makeCandidateInput()
        let llmText = """
            GUARDIAN concern: 0.2
            GUARDIAN reasons:
            SCOUT concern: 0.3
            SCOUT reasons:
            HARMONY concern: 0.9
            HARMONY reasons: emotional-bias
            """
        let result = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertTrue(result.usedLLM)
        XCTAssertEqual(result.score.dominantVoice, .harmony)
    }

    func test_pureDeterministic_sameInputsSameOutputs() {
        let cand = makeCandidateInput()
        let llmText = """
            GUARDIAN concern: 0.5
            GUARDIAN reasons: a
            SCOUT concern: 0.4
            SCOUT reasons: b
            HARMONY concern: 0.3
            HARMONY reasons: c
            """
        let r1 = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        let r2 = QinaoLoop.parseTriSelfScore(
            from: llmText,
            candidateID: "c1",
            fallback: heuristicFallback(for: cand))
        XCTAssertEqual(r1.score, r2.score)
        XCTAssertEqual(r1.usedLLM, r2.usedLLM)
    }
}
