// MARK: - BASLayerCascadeRunnerTests — chapter 三百一二 / M799
//
// Phase Delta 第三刀 测试覆盖:cascading inference dispatcher。
// End-to-end integration test of registry (chapter 三百一〇) +
// rules-based head (chapter 三百一一) + runner (this chapter)。

import XCTest
@testable import BASRuntimeCore

final class BASLayerCascadeRunnerTests: XCTestCase {

    // MARK: - Outcome enum

    func testOutcomeEnumCardinality() {
        XCTAssertEqual(
            BASLayerCascadeOutcome.allCases.count, 4)
    }

    func testOutcomeRawValueStability() {
        XCTAssertEqual(
            BASLayerCascadeOutcome.headMatched.rawValue,
            "head-matched")
        XCTAssertEqual(
            BASLayerCascadeOutcome.floorMet.rawValue,
            "floor-met")
        XCTAssertEqual(
            BASLayerCascadeOutcome.fallenThrough.rawValue,
            "fallen-through")
        XCTAssertEqual(
            BASLayerCascadeOutcome.noHeadsRegistered.rawValue,
            "no-heads-registered")
    }

    func testOutcomeCodableRoundTrip() throws {
        for outcome in BASLayerCascadeOutcome.allCases {
            let data = try JSONEncoder().encode(outcome)
            let decoded = try JSONDecoder().decode(
                BASLayerCascadeOutcome.self, from: data)
            XCTAssertEqual(decoded, outcome)
        }
    }

    // MARK: - Confidence ordering

    func testConfidenceRankOrdering() {
        // .unknown < .low < .medium < .high
        XCTAssertEqual(
            BASLayerCascadeRunner.confidenceRank(.unknown), 0)
        XCTAssertEqual(
            BASLayerCascadeRunner.confidenceRank(.low), 1)
        XCTAssertEqual(
            BASLayerCascadeRunner.confidenceRank(.medium), 2)
        XCTAssertEqual(
            BASLayerCascadeRunner.confidenceRank(.high), 3)
    }

    func testIsConfidenceMet() {
        // high meets all floors
        XCTAssertTrue(BASLayerCascadeRunner.isConfidenceMet(
            output: .high, floor: .high))
        XCTAssertTrue(BASLayerCascadeRunner.isConfidenceMet(
            output: .high, floor: .medium))
        XCTAssertTrue(BASLayerCascadeRunner.isConfidenceMet(
            output: .high, floor: .low))
        XCTAssertTrue(BASLayerCascadeRunner.isConfidenceMet(
            output: .high, floor: .unknown))
        // medium meets medium and below
        XCTAssertTrue(BASLayerCascadeRunner.isConfidenceMet(
            output: .medium, floor: .medium))
        XCTAssertFalse(BASLayerCascadeRunner.isConfidenceMet(
            output: .medium, floor: .high))
        // unknown meets only unknown
        XCTAssertTrue(BASLayerCascadeRunner.isConfidenceMet(
            output: .unknown, floor: .unknown))
        XCTAssertFalse(BASLayerCascadeRunner.isConfidenceMet(
            output: .unknown, floor: .low))
    }

    // MARK: - Empty registry

    func testRunWithEmptyRegistryReturnsNoHeadsRegistered()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        let input = BASLayerInferenceInput(
            layerID: .l4, featureRef: "x")
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l4)
        XCTAssertEqual(result.outcome, .noHeadsRegistered)
        XCTAssertNil(result.matchedHeadID)
        XCTAssertNil(result.matchedOutput)
        XCTAssertTrue(result.triedHeads.isEmpty)
    }

    // MARK: - First head matches floor

    func testRunFirstHeadMatchesFloorReturnsFloorMet()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        // Single head returning .medium exactly
        let head = BASRulesBasedLayerMLHead(
            headID: "exact-medium",
            layerIDPin: .l9
        ) { input in
            BASLayerInferenceOutput(
                layerID: input.layerID,
                confidence: .medium)
        }
        try await registry.register(
            head: head, layerID: .l9, priority: 0)
        let input = BASLayerInferenceInput(
            layerID: .l9,
            featureRef: "x",
            confidenceFloor: .medium)
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l9)
        XCTAssertEqual(result.outcome, .floorMet,
            "exact floor match → outcome is .floorMet (audit " +
            "diagnostic distinct from strict-greater match)")
        XCTAssertEqual(result.matchedHeadID, "exact-medium")
        XCTAssertEqual(result.triedHeads.count, 1)
    }

    func testRunFirstHeadStrictlyExceedsFloorReturnsHeadMatched()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        let head = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "high-conf",
            layerIDPin: .l4)
        try await registry.register(
            head: head, layerID: .l4, priority: 0)
        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "x",
            confidenceFloor: .medium)
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l4)
        XCTAssertEqual(result.outcome, .headMatched,
            "strictly > floor → outcome is .headMatched")
        XCTAssertEqual(result.matchedHeadID, "high-conf")
    }

    // MARK: - Cascade fallthrough

    func testRunCascadesPastLowConfidenceHeads() async throws {
        let registry = BASLayerMLHeadRegistry()
        // priority 0: returns .unknown (cascade)
        let p0 = BASRulesBasedLayerMLHeadFactory
            .makeAlwaysFallthrough(
                headID: "p0",
                layerIDPin: .l11)
        // priority 10: returns .low (cascade against medium floor)
        let p10 = BASRulesBasedLayerMLHead(
            headID: "p10",
            layerIDPin: .l11
        ) { input in
            BASLayerInferenceOutput(
                layerID: input.layerID,
                confidence: .low)
        }
        // priority 20: returns .high (matches floor)
        let p20 = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "p20",
            layerIDPin: .l11)

        try await registry.register(
            head: p0, layerID: .l11, priority: 0)
        try await registry.register(
            head: p10, layerID: .l11, priority: 10)
        try await registry.register(
            head: p20, layerID: .l11, priority: 20)

        let input = BASLayerInferenceInput(
            layerID: .l11,
            featureRef: "x",
            confidenceFloor: .medium)
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l11)
        XCTAssertEqual(result.outcome, .headMatched)
        XCTAssertEqual(result.matchedHeadID, "p20",
            "cascade walks p0 → p10 → p20 in priority order; " +
            "first to meet floor wins")
        XCTAssertEqual(result.triedHeads.count, 3,
            "audit trail must include all 3 attempts even " +
            "though only p20 won")
        XCTAssertFalse(result.triedHeads[0].met)
        XCTAssertFalse(result.triedHeads[1].met)
        XCTAssertTrue(result.triedHeads[2].met)
    }

    // MARK: - All heads fall through

    func testRunAllHeadsLowConfidenceReturnsFallenThrough()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        for i in 0..<3 {
            let head = BASRulesBasedLayerMLHeadFactory
                .makeAlwaysFallthrough(
                    headID: "p\(i)",
                    layerIDPin: .l9)
            try await registry.register(
                head: head, layerID: .l9, priority: i * 10)
        }
        let input = BASLayerInferenceInput(
            layerID: .l9,
            featureRef: "x",
            confidenceFloor: .medium)
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l9)
        XCTAssertEqual(result.outcome, .fallenThrough,
            "all heads tried + none met floor → fallenThrough; " +
            "caller invokes layer's hardcoded rules path " +
            "(chapter 三百〇一 .mlHeadFallthrough status)")
        XCTAssertEqual(result.triedHeads.count, 3)
        XCTAssertNil(result.matchedHeadID)
        XCTAssertNil(result.matchedOutput)
    }

    // MARK: - Disabled heads skipped

    func testRunSkipsDisabledHeads() async throws {
        let registry = BASLayerMLHeadRegistry()
        let active = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "active",
            layerIDPin: .l4)
        let disabled = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "disabled-but-priority-0",
            layerIDPin: .l4)
        try await registry.register(
            head: disabled, layerID: .l4, priority: 0)
        try await registry.register(
            head: active, layerID: .l4, priority: 10)
        try await registry.setEnabled(
            headID: "disabled-but-priority-0",
            enabled: false)

        let input = BASLayerInferenceInput(
            layerID: .l4,
            featureRef: "x",
            confidenceFloor: .medium)
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l4)
        XCTAssertEqual(result.matchedHeadID, "active",
            "disabled head must be skipped even if higher priority")
        XCTAssertEqual(result.triedHeads.count, 1,
            "disabled head doesn't appear in audit trail either")
    }

    // MARK: - Caller error rethrow

    func testRunRethrowsHeadError() async {
        struct CascadeError: Error {}
        let registry = BASLayerMLHeadRegistry()
        let throwing = BASRulesBasedLayerMLHead(
            headID: "thrower",
            layerIDPin: .l4
        ) { _ in
            throw CascadeError()
        }
        do {
            try await registry.register(
                head: throwing, layerID: .l4, priority: 0)
            let input = BASLayerInferenceInput(
                layerID: .l4, featureRef: "x")
            _ = try await BASLayerCascadeRunner.run(
                input: input, registry: registry, layerID: .l4)
            XCTFail("expected error rethrow")
        } catch is CascadeError {
            // expected — cascade aborts on first error,
            // no silent swallowing
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Reason codes

    func testReasonCodesForMatchedResult() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "winner",
            layerIDPin: .l11)
        try await registry.register(
            head: head, layerID: .l11, priority: 0)
        let input = BASLayerInferenceInput(
            layerID: .l11,
            featureRef: "x",
            confidenceFloor: .medium)
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l11)
        let codes = BASLayerCascadeRunner.reasonCodes(
            for: result)
        XCTAssertTrue(
            codes.contains("cascade-outcome:head-matched"))
        XCTAssertTrue(
            codes.contains("cascade-layer:l11"))
        XCTAssertTrue(
            codes.contains("cascade-attempts:1"))
        XCTAssertTrue(
            codes.contains("cascade-matched-head:winner"))
    }

    func testReasonCodesForEmptyRegistryResult() async throws {
        let registry = BASLayerMLHeadRegistry()
        let input = BASLayerInferenceInput(
            layerID: .l4, featureRef: "x")
        let result = try await BASLayerCascadeRunner.run(
            input: input, registry: registry, layerID: .l4)
        let codes = BASLayerCascadeRunner.reasonCodes(
            for: result)
        XCTAssertTrue(
            codes.contains("cascade-outcome:no-heads-registered"))
        XCTAssertTrue(
            codes.contains("cascade-attempts:0"))
        XCTAssertFalse(
            codes.contains { $0.hasPrefix(
                "cascade-matched-head:") },
            "no matched head → no matched-head code emitted")
    }

    // MARK: - Codable round-trip

    func testCascadeAttemptCodableRoundTrip() throws {
        let attempt = BASLayerCascadeAttempt(
            headID: "rt",
            kind: .coremlOnDevice,
            confidence: .medium,
            met: true)
        let data = try JSONEncoder().encode(attempt)
        let decoded = try JSONDecoder().decode(
            BASLayerCascadeAttempt.self, from: data)
        XCTAssertEqual(decoded, attempt)
    }

    func testCascadeResultCodableRoundTrip() throws {
        let attempt = BASLayerCascadeAttempt(
            headID: "h1",
            kind: .rules,
            confidence: .high,
            met: true)
        let result = BASLayerCascadeResult(
            outcome: .headMatched,
            layerID: .l4,
            matchedHeadID: "h1",
            matchedOutput: BASLayerInferenceOutput(
                layerID: .l4, confidence: .high),
            triedHeads: [attempt])
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(
            BASLayerCascadeResult.self, from: data)
        XCTAssertEqual(decoded.outcome, result.outcome)
        XCTAssertEqual(
            decoded.matchedHeadID, result.matchedHeadID)
        XCTAssertEqual(
            decoded.triedHeads.count, result.triedHeads.count)
    }
}
