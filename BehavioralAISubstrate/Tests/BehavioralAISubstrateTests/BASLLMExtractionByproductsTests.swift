// MARK: - BASLLMExtractionByproductsTests — chapter 四百一 / M930

import XCTest
@testable import BASOrgan

final class BASLLMExtractionByproductsTests: XCTestCase {

    // MARK: - Empty bundle

    func testEmptyBundleIsTextOnly() {
        let bundle = BASLLMExtractionByproducts(
            finalAnswer: "answer",
            extractedAtMs: 1_000)
        XCTAssertTrue(bundle.isTextOnly)
        XCTAssertEqual(bundle.finalAnswer, "answer")
        XCTAssertNil(bundle.structuredConclusion)
        XCTAssertEqual(bundle.memoryUpdates.count, 0)
    }

    func testFullBundleIsNotTextOnly() {
        let bundle = BASLLMExtractionByproducts(
            finalAnswer: "answer",
            structuredConclusion: "{\"k\":1}",
            memoryUpdates: [
                BASMemoryUpdateCandidate(
                    kind: "user_goal",
                    content: "x",
                    confidence: 0.8)
            ],
            extractedAtMs: 1_000)
        XCTAssertFalse(bundle.isTextOnly)
    }

    // MARK: - Memory update candidate

    func testMemoryUpdateCandidate() {
        let cand = BASMemoryUpdateCandidate(
            kind: "principle",
            content: "test",
            confidence: 0.5)
        XCTAssertEqual(cand.kind, "principle")
        XCTAssertEqual(cand.confidence, 0.5)
    }

    func testMemoryUpdateCandidateRoundTrip() throws {
        let cand = BASMemoryUpdateCandidate(
            kind: "preference",
            content: "user wants speed",
            confidence: 0.95)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(cand)
        let decoded = try JSONDecoder().decode(
            BASMemoryUpdateCandidate.self, from: data)
        XCTAssertEqual(decoded, cand)
    }

    // MARK: - Task candidate

    func testTaskCandidatePriorityRawValues() {
        XCTAssertEqual(
            BASTaskCandidate.Priority.low.rawValue, "low")
        XCTAssertEqual(
            BASTaskCandidate.Priority.medium.rawValue,
            "medium")
        XCTAssertEqual(
            BASTaskCandidate.Priority.high.rawValue, "high")
    }

    func testTaskCandidateAllPrioritiesPinned() {
        XCTAssertEqual(
            BASTaskCandidate.Priority.allCases.count, 3)
    }

    func testTaskCandidateRoundTrip() throws {
        let task = BASTaskCandidate(
            title: "review M932 plan",
            priority: .high,
            deadlineMs: 1_700_000_000_000,
            parentSessionID: "s-1")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(task)
        let decoded = try JSONDecoder().decode(
            BASTaskCandidate.self, from: data)
        XCTAssertEqual(decoded, task)
    }

    // MARK: - Eval case candidate

    func testEvalCaseScoringMethodAllCases() {
        XCTAssertEqual(
            BASEvalCaseCandidate.ScoringMethod
                .allCases.count, 4)
    }

    func testEvalCaseScoringMethodRawValues() {
        XCTAssertEqual(
            BASEvalCaseCandidate.ScoringMethod
                .stringExactMatch.rawValue,
            "stringExactMatch")
        XCTAssertEqual(
            BASEvalCaseCandidate.ScoringMethod
                .regexMatch.rawValue, "regexMatch")
        XCTAssertEqual(
            BASEvalCaseCandidate.ScoringMethod
                .semanticSimilarity.rawValue,
            "semanticSimilarity")
        XCTAssertEqual(
            BASEvalCaseCandidate.ScoringMethod
                .humanReview.rawValue, "humanReview")
    }

    // MARK: - Training example candidate

    func testTrainingExampleCandidate() {
        let ex = BASTrainingExampleCandidate(
            inputText: "Should we add Mamba?",
            contextSummary: "user is at MVP stage",
            goodAnswerTraits: [
                "warns about scope creep",
                "suggests phase 2"
            ],
            badAnswerTraits: ["lists all techs"],
            score: 0.85)
        XCTAssertEqual(ex.score, 0.85)
        XCTAssertEqual(ex.goodAnswerTraits.count, 2)
    }

    // MARK: - Bundle round trip

    func testFullBundleRoundTrip() throws {
        let bundle = BASLLMExtractionByproducts(
            finalAnswer: "ans",
            structuredConclusion: "{\"choice\":\"defer\"}",
            memoryUpdates: [
                BASMemoryUpdateCandidate(
                    kind: "user_goal",
                    content: "want minimal MVP",
                    confidence: 0.9)
            ],
            taskCandidates: [
                BASTaskCandidate(
                    title: "build MVP",
                    priority: .high,
                    deadlineMs: nil,
                    parentSessionID: "s-1")
            ],
            riskFlags: ["scope_creep"],
            confidenceScores: [
                "factual": 0.7, "strategic": 0.85
            ],
            counterArguments: [
                "but Mamba may be needed for state stream"
            ],
            evalCases: [
                BASEvalCaseCandidate(
                    inputText: "Add another model?",
                    expectedBehavior: "warn against",
                    scoringMethod: .humanReview)
            ],
            trainingExamples: [
                BASTrainingExampleCandidate(
                    inputText: "test",
                    contextSummary: "summary",
                    goodAnswerTraits: ["focused"],
                    badAnswerTraits: ["sprawling"],
                    score: 0.8)
            ],
            extractedAtMs: 1_700_000_000_000)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(bundle)
        let decoded = try JSONDecoder().decode(
            BASLLMExtractionByproducts.self, from: data)
        XCTAssertEqual(decoded, bundle)
        XCTAssertFalse(decoded.isTextOnly)
    }

    // MARK: - Field-name pin (per vision §19's 9 byproducts)

    func testNineFieldsPinned() throws {
        // Encode an empty-ish bundle and verify all 9 of the
        // user-visible byproduct fields are present in the
        // JSON output。This pins the contract — adding /
        // removing / renaming a field is a SCHEMA-class break。
        let bundle = BASLLMExtractionByproducts(
            finalAnswer: "x",
            extractedAtMs: 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(bundle)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"finalAnswer\""))
        XCTAssertTrue(json.contains("\"memoryUpdates\""))
        XCTAssertTrue(json.contains("\"taskCandidates\""))
        XCTAssertTrue(json.contains("\"riskFlags\""))
        XCTAssertTrue(json.contains("\"confidenceScores\""))
        XCTAssertTrue(json.contains("\"counterArguments\""))
        XCTAssertTrue(json.contains("\"evalCases\""))
        XCTAssertTrue(json.contains("\"trainingExamples\""))
        XCTAssertTrue(json.contains("\"extractedAtMs\""))
    }
}
