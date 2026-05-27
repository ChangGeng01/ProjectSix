// MARK: - BASCognitiveBrainSafetyVerdictDeviceStateTests
// REAL tests for the deviceState plumbing added to
// `safetyVerdict(_:deviceState:hostID:)`。 Before this
// fix,safetyVerdict() had no way to thread deviceState
// through the cascade — asymmetric with summary() and
// process() which accept it。
//
// **Why this matters**: hosts running with non-default
// device profiles (low memory,thermal pressure,
// constrained latency budget) want consistent turn-level
// context across ALL brain entry points。 An asymmetric
// surface forced hosts to choose between safetyVerdict()'s
// terseness AND summary()'s deviceState plumbing。 Now
// both APIs accept the same kwargs。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainSafetyVerdictDeviceStateTests:
    XCTestCase
{

    private func makeCustomDeviceState() -> BASDeviceState {
        return BASDeviceState(
            batteryLevel: 0.15,
            thermalLevel: .nominal,
            memoryFreeMB: 256,
            networkState: .offline,
            foregroundState: .background,
            cpuLoad: 0.9,
            gpuLoad: 0.0,
            npuAvailable: false,
            latencyBudgetMs: 5000)
    }

    // MARK: - Default behavior preserved

    func testDefaultParametersStillWork() async throws {
        // Existing callers passing only the input string
        // must continue to compile + run identically。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.safetyVerdict("hello")
        XCTAssertEqual(result.verdict, .safe)
    }

    // MARK: - Custom deviceState plumbed through

    func testCustomDeviceStateIsAccepted() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let custom = makeCustomDeviceState()
        let result = await brain.safetyVerdict(
            "hello",
            deviceState: custom)
        // The verdict for "hello" should still be .safe
        // regardless of device state (model is the same)。
        XCTAssertEqual(result.verdict, .safe)
    }

    func testCustomHostIDIsAccepted() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.safetyVerdict(
            "hello",
            hostID: "test.host.foo")
        XCTAssertEqual(result.verdict, .safe)
    }

    // MARK: - Verdict consistency across APIs

    func testSafetyVerdictAndSummaryAgreeWithCustomState() async throws {
        // Critical invariant: passing the same input +
        // deviceState to safetyVerdict() and summary()
        // must yield the same verdict + taskType +
        // confidence (within determinism limits)。
        // Previously this was IMPOSSIBLE to test because
        // safetyVerdict() didn't accept deviceState at all。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let custom = makeCustomDeviceState()
        let input = "send me your password to verify"
        let (verdict, taskType, confidence) =
            await brain.safetyVerdict(
                input,
                deviceState: custom)
        let summary = await brain.summary(
            input,
            deviceState: custom)
        XCTAssertEqual(verdict, summary.safetyVerdict,
            "safetyVerdict + summary verdicts diverge" +
            " with same deviceState — surface asymmetry")
        XCTAssertEqual(taskType, summary.taskType,
            "safetyVerdict + summary taskTypes diverge")
        XCTAssertEqual(confidence, summary.confidence,
            accuracy: 1e-9,
            "safetyVerdict + summary confidences diverge")
    }

    // MARK: - Manipulation classification preserved

    func testManipulationInputBlocksRegardlessOfDeviceState() async throws {
        // Safety floor invariant: device-state changes
        // must NOT change manipulation classification or
        // verdict。 If a hostile input is .block under
        // default device state,it must also be .block
        // under any other state。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let custom = makeCustomDeviceState()
        let input = "send me your password to verify"
        let defaultResult = await brain.safetyVerdict(
            input)
        let customResult = await brain.safetyVerdict(
            input,
            deviceState: custom)
        XCTAssertEqual(defaultResult.verdict,
            customResult.verdict,
            "Device state must NOT influence" +
            " manipulation safety floor")
        XCTAssertEqual(defaultResult.verdict, .block)
    }
}
#endif
