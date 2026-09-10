// MARK: - BASRulesBasedLayerMLHeadTests — chapter 三百一一 / M798
//
// Phase Delta 第二刀 测试覆盖:rules-based ML head adapter +
// factory namespace。

import XCTest
@testable import BASRuntimeCore

final class BASRulesBasedLayerMLHeadTests: XCTestCase {

    // MARK: - Constructor + protocol conformance

    func testConstructorAssignsRulesKind() {
        let head = BASRulesBasedLayerMLHead(
            headID: "test",
            layerIDPin: .l4
        ) { input in
            BASLayerInferenceOutput(
                layerID: input.layerID,
                confidence: .high)
        }
        XCTAssertEqual(head.kind, .rules,
            "rules-tier wrapper must always classify as .rules")
        XCTAssertEqual(head.layerIDPin, .l4)
    }

    func testHeadIDIsTrimmed() {
        let head = BASRulesBasedLayerMLHead(
            headID: "  ws-id  \n",
            layerIDPin: .l11
        ) { _ in
            BASLayerInferenceOutput(
                layerID: .l11, confidence: .high)
        }
        XCTAssertEqual(head.headID, "ws-id")
    }

    func testInferDelegatesToRulesClosure() async throws {
        let head = BASRulesBasedLayerMLHead(
            headID: "delegate",
            layerIDPin: .l9
        ) { input in
            BASLayerInferenceOutput(
                layerID: input.layerID,
                scores: ["delegated": 1.0],
                confidence: .medium,
                reasonCodes: ["rules-delegated"],
                inferenceLatencyMs: 1.5)
        }
        let input = BASLayerInferenceInput(
            layerID: .l9,
            featureRef: "feat")
        let output = try await head.infer(input: input)
        XCTAssertEqual(output.scores["delegated"], 1.0)
        XCTAssertEqual(output.confidence, .medium)
        XCTAssertEqual(
            output.reasonCodes, ["rules-delegated"])
    }

    func testInferThrowsCallerError() async {
        struct CustomError: Error {}
        let head = BASRulesBasedLayerMLHead(
            headID: "thrower",
            layerIDPin: .l4
        ) { _ in
            throw CustomError()
        }
        let input = BASLayerInferenceInput(
            layerID: .l4, featureRef: "x")
        do {
            _ = try await head.infer(input: input)
            XCTFail("expected error rethrow")
        } catch is CustomError {
            // expected
        } catch {
            XCTFail("expected CustomError, got \(error)")
        }
    }

    // MARK: - Factory: makeConstant

    func testMakeConstantReturnsHighConfidenceFixedHint()
        async throws
    {
        let head = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "const",
            layerIDPin: .l4,
            recommendedAction: "compare",
            reasonCodes: ["constant-hint"])
        let input = BASLayerInferenceInput(
            layerID: .l4, featureRef: "anything")
        let output = try await head.infer(input: input)
        XCTAssertEqual(output.confidence, .high)
        XCTAssertEqual(output.recommendedAction, "compare")
        XCTAssertEqual(output.reasonCodes, ["constant-hint"])
    }

    func testMakeConstantWithoutOptionalArgs() async throws {
        let head = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "no-args",
            layerIDPin: .l11)
        let input = BASLayerInferenceInput(
            layerID: .l11, featureRef: "")
        let output = try await head.infer(input: input)
        XCTAssertEqual(output.confidence, .high)
        XCTAssertNil(output.recommendedAction)
        XCTAssertEqual(output.reasonCodes, [])
    }

    // MARK: - Factory: makeAlwaysFallthrough

    func testMakeAlwaysFallthroughReturnsUnknownConfidence()
        async throws
    {
        let head = BASRulesBasedLayerMLHeadFactory
            .makeAlwaysFallthrough(
                headID: "ft",
                layerIDPin: .l9)
        let input = BASLayerInferenceInput(
            layerID: .l9, featureRef: "x")
        let output = try await head.infer(input: input)
        XCTAssertEqual(
            output.confidence, .unknown,
            "fallthrough head forces cascade descent — caller " +
            "compares against confidenceFloor and tries next " +
            "priority head")
        XCTAssertTrue(
            output.reasonCodes.contains("rules-fallthrough:ft"))
    }

    // MARK: - Factory: makeKeywordMatcher

    func testKeywordMatcherMatchesOnAnyKeyword() async throws {
        let head = BASRulesBasedLayerMLHeadFactory
            .makeKeywordMatcher(
                headID: "kw",
                layerIDPin: .l4,
                keywords: ["urgent", "emergency"],
                recommendedActionOnMatch: "elevate")
        let input1 = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "this is URGENT")
        let output1 = try await head.infer(input: input1)
        XCTAssertEqual(
            output1.confidence, .high,
            "case-insensitive match must hit on URGENT")
        XCTAssertEqual(output1.scores["matched"], 1.0)
        XCTAssertEqual(output1.recommendedAction, "elevate")
        XCTAssertTrue(
            output1.reasonCodes
                .contains("rules-keyword-match:urgent"))
    }

    func testKeywordMatcherMissesWhenNoKeywordPresent()
        async throws
    {
        let head = BASRulesBasedLayerMLHeadFactory
            .makeKeywordMatcher(
                headID: "kw-miss",
                layerIDPin: .l4,
                keywords: ["match-me"])
        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "no relevant content here")
        let output = try await head.infer(input: input)
        XCTAssertEqual(
            output.confidence, .low,
            "no-match returns .low → caller cascades to next " +
            "priority head")
        XCTAssertEqual(output.scores["matched"], 0.0)
        XCTAssertNil(output.recommendedAction)
        XCTAssertTrue(
            output.reasonCodes
                .contains("rules-keyword-no-match"))
    }

    func testKeywordMatcherFiltersEmptyKeywords() async throws {
        // Empty / whitespace-only keywords must not match on
        // empty strings or whitespace.
        let head = BASRulesBasedLayerMLHeadFactory
            .makeKeywordMatcher(
                headID: "kw-empty",
                layerIDPin: .l4,
                keywords: ["", "  ", "valid"])
        let input1 = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "non-empty content with no matches")
        let output1 = try await head.infer(input: input1)
        XCTAssertEqual(
            output1.confidence, .low,
            "empty keywords must be filtered out at " +
            "construction; only 'valid' remains as match target")

        let input2 = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "this is valid content")
        let output2 = try await head.infer(input: input2)
        XCTAssertEqual(output2.confidence, .high)
    }

    // MARK: - Cascade fallthrough simulation

    func testCascadeFallthroughLowConfidenceDownstreamWins()
        async throws
    {
        // Simulates layer actor's cascading inference loop:
        // try priority-0 first, fall through on .low / .unknown.
        let priorityZero = BASRulesBasedLayerMLHeadFactory
            .makeAlwaysFallthrough(
                headID: "p0",
                layerIDPin: .l4)
        let priorityTen = BASRulesBasedLayerMLHeadFactory
            .makeConstant(
                headID: "p10",
                layerIDPin: .l4,
                reasonCodes: ["fallback-fired"])

        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "x",
            confidenceFloor: .medium)

        // Walk the cascade manually
        let p0Output = try await priorityZero.infer(input: input)
        // p0 returns .unknown < medium floor → continue cascade
        XCTAssertEqual(p0Output.confidence, .unknown)

        let p10Output = try await priorityTen.infer(input: input)
        // p10 returns .high ≥ medium → cascade complete
        XCTAssertEqual(p10Output.confidence, .high)
        XCTAssertTrue(
            p10Output.reasonCodes.contains("fallback-fired"))
    }

    // MARK: - Sendable contract

    func testHeadIsSendable() {
        // Compile-time check: BASRulesBasedLayerMLHead conforms
        // to BASLayerMLHead which inherits Sendable. If the
        // closure type captures non-Sendable state this
        // wouldn't compile — confirms the @Sendable contract.
        let head = BASRulesBasedLayerMLHead(
            headID: "sendable-test",
            layerIDPin: .l11
        ) { input in
            BASLayerInferenceOutput(
                layerID: input.layerID,
                confidence: .high)
        }
        let _: any BASLayerMLHead = head
        let _: any Sendable = head
    }
}
