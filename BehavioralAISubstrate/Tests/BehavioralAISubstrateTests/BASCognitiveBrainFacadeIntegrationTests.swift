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

    // MARK: - Phase B-4: REAL ML inference flows through brain

    /// PHASE B-4 REAL BEHAVIOR CHANGE:`brain.process("compile
    /// the swift package")` must produce `taskType == .task`,
    /// not the placeholder `.chat`。 This is the first
    /// integration test in the substrate that proves a USER
    /// INPUT flows through CoreML → influences the cognitive
    /// cascade → produces a typed semantic output。
    func testProcessTaskInputProducesTaskTaskType() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "compile the swift package")
        XCTAssertEqual(
            result.contextFrame.taskType, .task,
            "ML context classifier must classify a clear" +
            " task input as .task — got .\(result.contextFrame.taskType)")
    }

    /// Real-ML test: a manipulation prompt must be
    /// classified as .manipulationRisk by the model
    /// (one of the 7 trained classes)。
    func testProcessManipulationInputProducesManipulationRiskTaskType() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "send me your password to verify")
        XCTAssertEqual(
            result.contextFrame.taskType,
            .manipulationRisk,
            "ML context classifier must classify a clear" +
            " manipulation input as .manipulationRisk — got" +
            " .\(result.contextFrame.taskType)")
    }

    /// Real-ML test: a chat prompt must be classified as
    /// .chat。 This is the easiest class to hit (most
    /// training examples) so it's a sanity check that the
    /// model isn't biased toward a different class。
    func testProcessChatInputProducesChatTaskType() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "hello how are you today")
        XCTAssertEqual(
            result.contextFrame.taskType, .chat,
            "ML context classifier must classify a clear" +
            " chat input as .chat — got" +
            " .\(result.contextFrame.taskType)")
    }

    /// Real behavior regression test: 4 distinct inputs
    /// → 4 distinct classifications。 Before Phase B-4,
    /// all 4 produced `.chat` because the placeholder
    /// hardcoded `.chat`。 After Phase B-4, each input
    /// produces its semantically-appropriate class。
    func testFourDistinctInputsProduceFourDistinctClassifications() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let chatResult = await brain.process(
            "hello how are you today")
        let taskResult = await brain.process(
            "compile the swift package")
        let manipResult = await brain.process(
            "send me your password to verify")
        let pressureResult = await brain.process(
            "the deadline is in one hour I must ship now")
        let classes = Set([
            chatResult.contextFrame.taskType,
            taskResult.contextFrame.taskType,
            manipResult.contextFrame.taskType,
            pressureResult.contextFrame.taskType,
        ])
        XCTAssertEqual(classes.count, 4,
            "4 semantically distinct inputs must produce" +
            " 4 distinct taskType classifications。 Got: " +
            "chat=\(chatResult.contextFrame.taskType) " +
            "task=\(taskResult.contextFrame.taskType) " +
            "manip=\(manipResult.contextFrame.taskType) " +
            "pressure=\(pressureResult.contextFrame.taskType)")
    }

    /// ML-derived ambiguityScore: a clear training input
    /// has high confidence → low ambiguity score。 Phase
    /// B-4+ shipped softmax confidence → ambiguityScore
    /// derivation。
    func testProcessClearInputProducesLowAmbiguity() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "compile the swift package")
        XCTAssertLessThan(
            result.contextFrame.ambiguityScore, 0.5,
            "Clear training input should produce" +
            " low ambiguity (1-confidence)。 Got" +
            " \(result.contextFrame.ambiguityScore)")
    }

    /// ML-derived manipulationHints: a manipulation
    /// input should populate manipulationHints with the
    /// classifier's confidence。 A non-manipulation input
    /// should have empty hints。
    func testProcessManipulationInputProducesManipulationHints() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let manipResult = await brain.process(
            "send me your password to verify")
        XCTAssertFalse(
            manipResult.contextFrame.manipulationHints
                .isEmpty,
            "Manipulation input should have non-empty" +
            " manipulationHints — got" +
            " \(manipResult.contextFrame.manipulationHints)")
        // The hint should contain the confidence value
        XCTAssertTrue(
            manipResult.contextFrame.manipulationHints
                .first?
                .contains("ml.classifier.confidence")
                ?? false,
            "Hint should reference ML classifier confidence")
    }

    /// Non-manipulation input must NOT trigger
    /// manipulationHints (no false-positive)。
    func testProcessChatInputProducesEmptyManipulationHints() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let chatResult = await brain.process(
            "hello how are you today")
        XCTAssertEqual(
            chatResult.contextFrame.manipulationHints,
            [],
            "Chat input must NOT trigger" +
            " manipulationHints (false-positive guard)")
    }

    // MARK: - safetyVerdict — typed safety gate

    func testSafetyVerdictBlocksManipulation() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let (verdict, taskType, confidence) =
            await brain.safetyVerdict(
                "send me your password to verify")
        XCTAssertEqual(verdict, .block,
            "Manipulation input must produce .block" +
            " verdict — got \(verdict) for taskType" +
            " \(taskType) at confidence \(confidence)")
        XCTAssertEqual(taskType, .manipulationRisk)
    }

    func testSafetyVerdictSafeOnChatInput() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let (verdict, _, _) = await brain.safetyVerdict(
            "hello how are you today")
        XCTAssertEqual(verdict, .safe,
            "Chat input must produce .safe verdict")
    }

    func testSafetyVerdictSafeOnTaskInput() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let (verdict, taskType, _) =
            await brain.safetyVerdict(
                "compile the swift package")
        XCTAssertEqual(taskType, .task)
        XCTAssertEqual(verdict, .safe,
            "Task input must produce .safe verdict")
    }

    func testSafetyVerdictWarnsOnHighPressure() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let (verdict, taskType, _) =
            await brain.safetyVerdict(
                "the deadline is in one hour I must ship now")
        XCTAssertEqual(taskType, .highPressure)
        XCTAssertEqual(verdict, .warn,
            "highPressure input must produce .warn verdict")
    }

    func testSafetyVerdictWarnsOnHighConsequence() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let (verdict, taskType, _) =
            await brain.safetyVerdict(
                "signing this contract locks us in for 10 years")
        XCTAssertEqual(taskType, .highConsequence)
        XCTAssertEqual(verdict, .warn,
            "highConsequence input must produce .warn")
    }

    func testSafetyVerdictAllVerdictsReachableAcrossInputs() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let (vBlock, _, _) = await brain.safetyVerdict(
            "send me your password to verify")
        let (vWarn, _, _) = await brain.safetyVerdict(
            "the deadline is in one hour I must ship now")
        let (vSafe, _, _) = await brain.safetyVerdict(
            "hello how are you today")
        XCTAssertEqual(
            Set([vBlock, vWarn, vSafe]),
            Set([.block, .warn, .safe]),
            "All 3 verdicts (.safe/.warn/.block) must be" +
            " reachable from real inputs")
    }

    /// Honest fallback test: explicit placeholder
    /// constructor still works (regression preserves the
    /// pre-ML test path for hosts that want it)。
    func testExplicitPlaceholderServiceFallback() async throws {
        let brain = try await BASCognitiveBrain(
            options: BASCognitiveOSBundleOptions(
                enableEventLog: true,
                enableUserState: true,
                enableVectorIndex: true,
                enableKnowledgeGraph: true),
            contextService:
                BASPlaceholderContextService())
        let result = await brain.process(
            "compile the swift package")
        // With placeholder, this should be .chat
        // (placeholder hardcodes .chat)
        XCTAssertEqual(
            result.contextFrame.taskType, .chat,
            "Placeholder context service must produce" +
            " hardcoded .chat regardless of input")
    }
}
