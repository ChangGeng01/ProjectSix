// MARK: - BASLLMOutputExtractorTests — chapter 四百一 / M931

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMOutputExtractorTests: XCTestCase {

    private func makeDraft(body: String) -> BASOrganDraft {
        BASOrganDraft(
            requestID: "req-1",
            providerID: "test",
            role: .scout,
            body: body,
            inputTokensEstimated: 0,
            outputTokensEstimated: 0,
            producedAt: Date(),
            traceID: "trace-test")
    }

    private func makePackage() -> BASLLMTaskPackage {
        BASLLMTaskPackage(
            taskID: "t-1",
            originSessionID: "s-1",
            compiledAtMs: 1_000,
            intent: "ask",
            goal: "test")
    }

    func testDefaultPolicyPopulatesOnlyFinalAnswer() {
        let draft = makeDraft(body: "the answer")
        let pkg = makePackage()
        let bp = BASLLMOutputExtractor.extract(
            draft: draft,
            taskPackage: pkg,
            extractedAtMs: 2_000)
        XCTAssertEqual(bp.finalAnswer, "the answer")
        XCTAssertEqual(bp.extractedAtMs, 2_000)
        XCTAssertTrue(bp.isTextOnly)
    }

    func testCustomPolicyProducesAllNineFields() {
        let customPolicy: BASLLMOutputParserPolicy = {
            draft, pkg, ts in
            BASLLMExtractionByproducts(
                finalAnswer: "custom: \(draft.body)",
                structuredConclusion: "{\"k\":\"v\"}",
                memoryUpdates: [
                    BASMemoryUpdateCandidate(
                        kind: "user_goal",
                        content: pkg.goal,
                        confidence: 0.7)
                ],
                taskCandidates: [
                    BASTaskCandidate(
                        title: "follow up",
                        priority: .medium,
                        deadlineMs: nil,
                        parentSessionID:
                            pkg.originSessionID)
                ],
                riskFlags: ["test_risk"],
                confidenceScores: ["overall": 0.9],
                counterArguments: ["counter1"],
                evalCases: [
                    BASEvalCaseCandidate(
                        inputText: "test",
                        expectedBehavior: "behavior",
                        scoringMethod: .humanReview)
                ],
                trainingExamples: [
                    BASTrainingExampleCandidate(
                        inputText: "train",
                        contextSummary: "ctx",
                        goodAnswerTraits: ["a"],
                        badAnswerTraits: ["b"],
                        score: 0.8)
                ],
                extractedAtMs: ts)
        }

        let draft = makeDraft(body: "raw")
        let pkg = makePackage()
        let bp = BASLLMOutputExtractor.extract(
            draft: draft,
            taskPackage: pkg,
            extractedAtMs: 3_000,
            policy: customPolicy)
        XCTAssertEqual(bp.finalAnswer, "custom: raw")
        XCTAssertEqual(bp.structuredConclusion,
            "{\"k\":\"v\"}")
        XCTAssertEqual(bp.memoryUpdates.count, 1)
        XCTAssertEqual(bp.taskCandidates.count, 1)
        XCTAssertEqual(bp.riskFlags, ["test_risk"])
        XCTAssertEqual(bp.confidenceScores["overall"], 0.9)
        XCTAssertEqual(bp.counterArguments, ["counter1"])
        XCTAssertEqual(bp.evalCases.count, 1)
        XCTAssertEqual(bp.trainingExamples.count, 1)
        XCTAssertEqual(bp.extractedAtMs, 3_000)
        XCTAssertFalse(bp.isTextOnly)
    }

    func testSamePolicyProducesByteStableOutput()
        throws
    {
        let policy = BASLLMOutputExtractor.defaultPolicy
        let draft = makeDraft(body: "stable")
        let pkg = makePackage()
        let bp1 = BASLLMOutputExtractor.extract(
            draft: draft,
            taskPackage: pkg,
            extractedAtMs: 1_000,
            policy: policy)
        let bp2 = BASLLMOutputExtractor.extract(
            draft: draft,
            taskPackage: pkg,
            extractedAtMs: 1_000,
            policy: policy)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json1 = try encoder.encode(bp1)
        let json2 = try encoder.encode(bp2)
        XCTAssertEqual(json1, json2,
            "M892 replay-determinism: same inputs → byte-stable")
    }
}
