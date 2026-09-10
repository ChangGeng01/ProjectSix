// MARK: - BASLayerReferenceActorTests — chapter 三百一六 / M803
//
// Phase Epsilon 第三刀 测试覆盖:reference layer actor demonstrating
// Phase Beta + Delta foundation integration。End-to-end test
// verifying typed primitives compose correctly。

import XCTest
@testable import BASRuntimeCore

final class BASLayerReferenceActorTests: XCTestCase {

    // MARK: - Test fixtures

    private let referenceDate = Date(
        timeIntervalSince1970: 1_700_000_000)

    private func makeBudget(
        layer: BASMotherboardLayer14 = .l4,
        allocatedMs: Double = 50,
        hardCapMs: Double = 200,
        observabilityOnly: Bool = false
    ) -> BASLayerSlice {
        BASLayerSlice(
            layerID: layer,
            allocatedMs: allocatedMs,
            hardCapMs: hardCapMs,
            observabilityOnly: observabilityOnly)
    }

    private func makeInput(
        layer: BASMotherboardLayer14 = .l4,
        turnID: String = "turn-test"
    ) -> BASLayerActorInput {
        BASLayerActorInput(
            layerID: layer,
            turnID: turnID,
            payloadRef: "payload-test",
            arrivedAt: referenceDate)
    }

    // MARK: - LayerID conformance

    func testActorLayerIDMatchesConfig() {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: .l11,
            budget: makeBudget(layer: .l11),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        XCTAssertEqual(actor.layerID, .l11)
    }

    // MARK: - Empty registry → noHeadsRegistered → partial

    func testEmptyRegistryProducesPartialStatus() async throws {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(input: makeInput())
        XCTAssertEqual(
            output.status, .partial,
            "no heads in registry → partial status (caller " +
            "falls back to its own logic)")
        XCTAssertEqual(output.confidence, .unknown)
        XCTAssertNil(output.payloadRef)
        XCTAssertTrue(
            output.reasonCodes.contains(
                "cascade-outcome:no-heads-registered"))
        XCTAssertTrue(
            output.reasonCodes.contains("layer-start:l4"))
    }

    // MARK: - Kill switch active → skippedByKill

    func testActiveKillSwitchProducesSkippedByKill() async throws {
        let registry = BASLayerMLHeadRegistry()
        let killState = BASLayerKillSwitchState(
            switchID: .l4Horizon,
            active: true,
            reason: .thermalEmergency,
            detail: "test thermal critical")
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { switchID in
                switchID == .l4Horizon ? killState : nil
            })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(input: makeInput())
        XCTAssertEqual(
            output.status, .skippedByKill,
            "active kill switch → skippedByKill (chapter 三百〇一 " +
            "doctrine)")
        XCTAssertTrue(
            output.reasonCodes.contains(
                "kill-switch:active:thermal-emergency"))
    }

    func testInactiveKillSwitchDoesNotShortCircuit() async throws {
        let registry = BASLayerMLHeadRegistry()
        let killState = BASLayerKillSwitchState(
            switchID: .l4Horizon,
            active: false)
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { _ in killState })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(input: makeInput())
        // Still partial because empty registry, but NOT
        // skippedByKill — kill state is inactive so process
        // continues to cascade stage.
        XCTAssertNotEqual(output.status, .skippedByKill)
        XCTAssertEqual(output.status, .partial)
    }

    // MARK: - Cascade match → completed

    func testCascadeMatchProducesCompleted() async throws {
        let registry = BASLayerMLHeadRegistry()
        let head = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "test-winner",
            layerIDPin: .l4,
            recommendedAction: "compare")
        try await registry.register(
            head: head, layerID: .l4, priority: 0)
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(input: makeInput())
        XCTAssertEqual(output.status, .completed)
        XCTAssertEqual(output.confidence, .high)
        XCTAssertEqual(output.payloadRef, "test-winner")
        XCTAssertTrue(
            output.reasonCodes.contains(
                "cascade-outcome:head-matched"))
        XCTAssertTrue(
            output.reasonCodes.contains(
                "cascade-matched-head:test-winner"))
    }

    // MARK: - Cascade fallthrough

    func testCascadeFallthroughProducesMLHeadFallthroughStatus()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        let lowConfHead = BASRulesBasedLayerMLHeadFactory
            .makeAlwaysFallthrough(
                headID: "fallthrough-head",
                layerIDPin: .l4)
        try await registry.register(
            head: lowConfHead, layerID: .l4, priority: 0)
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(input: makeInput())
        XCTAssertEqual(
            output.status, .mlHeadFallthrough,
            "all heads tried with confidence < floor → " +
            "mlHeadFallthrough status (chapter 三百〇一)")
        XCTAssertEqual(output.confidence, .unknown)
        XCTAssertTrue(
            output.reasonCodes.contains(
                "cascade-outcome:fallen-through"))
    }

    // MARK: - Multiple heads cascade walks priority order

    func testMultipleHeadsCascadeWalkPriorityOrder()
        async throws
    {
        let registry = BASLayerMLHeadRegistry()
        // priority 0: returns .unknown (cascade)
        let p0 = BASRulesBasedLayerMLHeadFactory
            .makeAlwaysFallthrough(
                headID: "p0",
                layerIDPin: .l11)
        // priority 10: returns .high (matches floor)
        let p10 = BASRulesBasedLayerMLHeadFactory.makeConstant(
            headID: "p10",
            layerIDPin: .l11)

        try await registry.register(
            head: p0, layerID: .l11, priority: 0)
        try await registry.register(
            head: p10, layerID: .l11, priority: 10)

        let config = BASLayerReferenceActorConfig(
            layerID: .l11,
            budget: makeBudget(layer: .l11),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(
            input: makeInput(layer: .l11))
        XCTAssertEqual(output.status, .completed)
        XCTAssertEqual(output.payloadRef, "p10",
            "cascade walks p0 → p10; first to meet floor wins")
        XCTAssertTrue(
            output.reasonCodes.contains("cascade-attempts:2"))
    }

    // MARK: - Audit trail composition

    func testAuditTrailContainsBudgetReasonCodes() async throws {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: .l9,
            budget: makeBudget(
                layer: .l9, allocatedMs: 25, hardCapMs: 100),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(
            input: makeInput(layer: .l9))
        XCTAssertTrue(
            output.reasonCodes.contains(
                "budget:allocated-ms:25.0"))
        XCTAssertTrue(
            output.reasonCodes.contains(
                "budget:hard-cap-ms:100.0"))
    }

    func testAuditTrailContainsLayerStartCode() async throws {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: .l14,
            budget: makeBudget(layer: .l14),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(
            input: makeInput(layer: .l14))
        XCTAssertTrue(
            output.reasonCodes.contains("layer-start:l14"))
    }

    // MARK: - turnID flows through

    func testTurnIDPropagatesFromInputToOutput() async throws {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let input = makeInput(turnID: "turn-flow-7")
        let output = try await actor.process(input: input)
        XCTAssertEqual(
            output.turnID, "turn-flow-7",
            "audit chain doctrine: output.turnID 必须等于 " +
            "input.turnID — chapter 二百一一 audit doctrine")
    }

    // MARK: - Latency tracked

    func testLatencyMsIsNonNegative() async throws {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(input: makeInput())
        XCTAssertGreaterThanOrEqual(output.latencyMs, 0,
            "latencyMs is wall-clock duration; must be ≥ 0")
    }

    // MARK: - Conformance to BASLayerActor protocol

    func testActorConformsToBASLayerActorProtocol() {
        let registry = BASLayerMLHeadRegistry()
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor: any BASLayerActor =
            BASLayerReferenceActor(config: config)
        XCTAssertEqual(actor.layerID, .l4)
    }

    // MARK: - Floor met (.medium meets .medium)

    func testFloorMetMatchesAsCompleted() async throws {
        let registry = BASLayerMLHeadRegistry()
        let exactMedium = BASRulesBasedLayerMLHead(
            headID: "exact-medium",
            layerIDPin: .l4
        ) { input in
            BASLayerInferenceOutput(
                layerID: input.layerID,
                confidence: .medium)
        }
        try await registry.register(
            head: exactMedium, layerID: .l4, priority: 0)
        let config = BASLayerReferenceActorConfig(
            layerID: .l4,
            budget: makeBudget(),
            registry: registry,
            killSwitchLookup: { _ in nil })
        let actor = BASLayerReferenceActor(config: config)
        let output = try await actor.process(input: makeInput())
        // .medium matches .medium floor (configured in actor's
        // BASLayerInferenceInput conversion)
        XCTAssertEqual(
            output.status, .completed,
            ".medium === .medium floor → outcome .floorMet → " +
            "actor maps to status .completed")
        XCTAssertEqual(output.confidence, .medium)
        XCTAssertTrue(
            output.reasonCodes.contains(
                "cascade-outcome:floor-met"))
    }
}
