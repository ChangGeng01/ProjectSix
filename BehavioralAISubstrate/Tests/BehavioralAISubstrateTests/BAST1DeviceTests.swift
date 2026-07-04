import XCTest
import BASOrgan
import BASSovereign
import BASAppleAdapters
@testable import BASHostKit
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXLLM
#endif

/// T1 (LLM-invocation-rate) device A/B — runs INSIDE an xcodebuild-test session, which is immune to the
/// locked-phone / background-launch process suspension that killed every devicectl-launched attempt
/// (2026-07-04 forensics; the 10h endurance runbook uses xcodebuild test for exactly this reason).
///
/// BAS_T1_XCTEST=1 (via TEST_RUNNER_BAS_T1_XCTEST) gates it — heavy (loads Qwen3.5-4B on device).
/// One test = both arms over the full 30-prompt mixed pool (10 covered factual / 10 casual / 10
/// substantive): CONTROL (levers off ⇒ 2.0 calls/turn expected) then GATED (covered-factual
/// short-circuit + stakes×thermal verify gate ⇒ T1 target ≤ 0.6 of control).
final class BAST1DeviceTests: XCTestCase {

    func testT1InvocationRateAB() async throws {
        guard ProcessInfo.processInfo.environment["BAS_T1_XCTEST"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_T1_XCTEST=1 (device; loads Qwen3.5-4B)")
        }
        // Test-process factory registration (take-4: noModelFactoryAvailable — the registry's
        // NSClassFromString trampolines don't resolve inside the test bundle process) + LOCAL staged
        // model dir (session-independent, the ship form).
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #endif
        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        try await adapter.loadModel()
        guard let mini = BASMiniLMEmbeddingProvider() else {
            throw XCTSkip("MiniLM unavailable on this device")
        }

        func runArm(gated: Bool) async throws -> (rate: Double, calls: Int, turns: Int) {
            let counter = BASLLMCallCounter()
            let counted = BASCountingOrganAdapter(wrapping: adapter, counter: counter)
            let bank = BASEmbeddingFactBank(facts: BAST1Topology.t1Facts(), provider: mini)
            let organ = BASSemanticAdjudicatingOrganAdapter(
                wrapping: counted, bank: bank, enabled: true, shortCircuitCovered: gated)
            await organ.warmUp()
            let verifier = BASLLMVerifierPipeline(
                adapters: [.reviewer: organ],
                verifyGate: gated
                    ? { @Sendable _, pkg in
                        BASStakesEstimator.estimate(pkg.goal, context: []) >= 0.6
                            && ProcessInfo.processInfo.thermalState.rawValue
                                <= ProcessInfo.ThermalState.fair.rawValue
                    }
                    : { @Sendable _, _ in true },
                stageMaxOutputTokens: 96)
            var calls = 0, turns = 0
            for (i, prompt) in BAST1Topology.t1PromptPool.enumerated() {
                await counter.mark()
                let req = BASOrganRequest(
                    requestID: "t1-\(gated ? "g" : "c")-\(i)", role: .core, preset: .core,
                    instruction: prompt, context: [], maxOutputTokens: 96)
                let draft = try await organ.draft(req)
                _ = await verifier.verify(
                    draft: draft,
                    taskPackage: BASLLMTaskPackage(
                        taskID: req.requestID, originSessionID: "t1-xctest",
                        compiledAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                        intent: "verify", goal: prompt))
                let d = await counter.delta()
                calls += d; turns += 1
                print("[t1-xctest] arm=\(gated ? "gated" : "control") turn=\(i + 1) llm_calls=\(d) thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
            }
            return (Double(calls) / Double(max(turns, 1)), calls, turns)
        }

        let control = try await runArm(gated: false)
        let gatedArm = try await runArm(gated: true)
        print(String(format: "[t1-xctest] VERDICT control_rate=%.2f gated_rate=%.2f ratio=%.2f (calls %d/%d over %d turns each)",
                     control.rate, gatedArm.rate, gatedArm.rate / control.rate,
                     control.calls, gatedArm.calls, control.turns))
        XCTAssertEqual(control.turns, 30)
        XCTAssertGreaterThan(control.rate, 1.9, "control should be ~2.0 calls/turn (draft+verify)")
        XCTAssertLessThan(gatedArm.rate, control.rate, "gating must reduce invocations")
    }
}
