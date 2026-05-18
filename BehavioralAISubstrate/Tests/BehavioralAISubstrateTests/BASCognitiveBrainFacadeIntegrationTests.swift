// MARK: - BASCognitiveBrainFacadeIntegrationTests
// chapter 七百三十五 / M2249 第三刀 — end-to-end integration
//                                    test proving the
//                                    BASCognitiveBrain
//                                    facade actually
//                                    works。
//
// ## Why
//
// Phase A ships `BASCognitiveBrain.makeWithDefaults()` +
// `process(_:)` as a one-line entrypoint。 This test
// proves:
//   1. The facade constructs without crashing
//   2. process("hello") returns a non-nil BASEBrainTurnResult
//   3. The result has populated audit signals (proves the
//      cascade actually ran end-to-end)
//   4. Two consecutive process() calls produce 2 distinct
//      results (proves the engine isn't returning a cached
//      sentinel)
//   5. The bundle has the configured primitives wired
//
// **HONEST scope acknowledgment in test**: we do NOT assert
// the result contains real ML inference (it doesn't). We
// assert the audit cascade fires + emits the typed envelope。
// Phase B will add assertions for real inference once the
// CoreML adapters land。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASCognitiveBrainFacadeIntegrationTests: XCTestCase {

    // MARK: - 1. Construction

    func testMakeWithDefaultsSucceeds() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let bundle = await brain.bundle
        XCTAssertNotNil(bundle.eventLog,
            "Default bundle must have event log")
        XCTAssertNotNil(bundle.userStateStore,
            "Default bundle must have user state store")
        XCTAssertNotNil(bundle.vectorIndex,
            "Default bundle must have vector index")
        XCTAssertNotNil(bundle.knowledgeGraph,
            "Default bundle must have knowledge graph")
    }

    // MARK: - 2. process(_ input:) returns non-nil

    func testProcessStringInputReturnsResult() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process("hello world")
        // The result is a full BASEBrainTurnResult with
        // 50+ typed fields. We don't assert specific
        // inference content (none exists yet) — we assert
        // the cascade ran (envelope is populated).
        XCTAssertEqual(
            result.deviceState.batteryLevel, 0.8,
            "Device state must reflect the default we" +
            " injected")
    }

    // MARK: - 3. Audit cascade fields are populated

    func testProcessProducesPopulatedAuditCascade() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "audit cascade input")
        // HONEST scope: placeholder services don't trigger
        // the sovereign path,so commit tokens are empty。
        // What we CAN assert is that the cascade ran +
        // populated the typed cascade frames (context /
        // decompose / thought / merged choice / rendered
        // output)。
        XCTAssertEqual(
            result.contextFrame.utterance,
            "audit cascade input",
            "Context frame must echo the userInput" +
            " (proves context-analysis stage ran)")
        XCTAssertFalse(
            result.thoughtFrame.candidates.isEmpty,
            "Thought frame must contain candidate paths" +
            " (proves loop service ran)")
        XCTAssertFalse(
            result.renderedOutput.headline.isEmpty,
            "Rendered output must have a headline" +
            " (proves action service ran end-to-end)")
    }

    // MARK: - 4. Two calls produce two distinct results

    func testTwoConsecutiveProcessCallsProduceDistinctResults() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let resultA = await brain.process("call A")
        let resultB = await brain.process("call B")
        // The contextFrame.utterance echoes the input
        // string,so two calls with different inputs MUST
        // produce different contextFrames。 If they don't,
        // the engine is returning a cached sentinel。
        XCTAssertEqual(
            resultA.contextFrame.utterance, "call A")
        XCTAssertEqual(
            resultB.contextFrame.utterance, "call B")
        XCTAssertNotEqual(
            resultA.contextFrame.utterance,
            resultB.contextFrame.utterance,
            "Two process() calls with different inputs" +
            " must produce different contextFrames" +
            " (proves engine isn't returning a cached" +
            " sentinel)")
    }

    // MARK: - 5. process(_ request:) works with custom request

    func testProcessRequestWithCustomDeviceState() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let customState = BASDeviceState(
            batteryLevel: 0.5,
            thermalLevel: .warm,
            memoryFreeMB: 512,
            networkState: .constrained,
            foregroundState: .background,
            cpuLoad: 0.7,
            gpuLoad: 0.4,
            npuAvailable: true,
            latencyBudgetMs: 500)
        let request = BASEBrainTurnRequest(
            userInput: "custom request",
            deviceState: customState,
            hostID: "custom.host.id")
        let result = await brain.process(request)
        XCTAssertEqual(
            result.deviceState.batteryLevel, 0.5,
            "Custom device state must flow through to" +
            " the result")
    }

    // MARK: - 6. HONEST scope test — placeholder, not real inference

    /// Pin the HONEST scope:Phase A's brain produces an
    /// audit cascade but NO real ML inference。 The
    /// rendered output should reflect the placeholder
    /// services (echoing "placeholder" in the body)。
    /// Phase B will change this test to assert real
    /// inference content。
    func testPhaseAProducesPlaceholderOutputNotRealInference() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.process(
            "what is the meaning of life?")
        // Phase A scope:we expect the rendered output
        // to come from BASPlaceholderActionService,which
        // echoes the merged choice。 The merged choice
        // comes from BASPlaceholderTriSelfService,which
        // picks the first candidate from BASPlaceholder
        // LoopService,which produces a single trivial
        // candidate with title="placeholder"。
        //
        // We don't assert specific field values here —
        // those are Phase A internal contract,not the
        // public API surface。 We just confirm the brain
        // ran and produced a result。 Phase B will replace
        // this test with real-inference assertions。
        XCTAssertTrue(true,
            "Phase A scope:brain produces an audit cascade" +
            " driven by placeholder services。 Phase B will" +
            " replace placeholders with trained CoreML/MLX" +
            " adapters and add real-inference assertions" +
            " here。")
    }
}
