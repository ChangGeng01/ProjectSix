import XCTest
import BASOrgan
import BASOrchestration
import BASAppleAdapters
#if canImport(UIKit)
import UIKit
#endif
@testable import BASRuntimeCore
@testable import BASHostKit
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXLLM
#endif

/// P4 energy discipline — T3 (energy/turn) + T5 (gated session stays ≤fair) in ONE unplugged run.
/// xcodebuild-test lane (suspension-immune, wireless-capable): a ~20-min GATED mixed session — the
/// P1/P3 composed stack (covered short-circuit + classifier-casual verify gate) with paced 15s gaps
/// (conversational cadence) — sampling battery-% (1% granularity; M4 protocol: plugged samples flag
/// the run ⚠️invalid) and thermal per turn.
/// Outputs (for the qinao registry pins): battery %/turn · est %/1k-tok · thermal ≤fair fraction.
final class BAST5EnergySessionDeviceTests: XCTestCase {

    func testT5GatedEnergySession() async throws {
        guard ProcessInfo.processInfo.environment["BAS_T5_XCTEST"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_T5_XCTEST=1 (device; UNPLUG the phone; ~20 min)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #endif
        #if canImport(UIKit)
        await MainActor.run { UIDevice.current.isBatteryMonitoringEnabled = true }
        func battery() -> Double { Double(UIDevice.current.batteryLevel) * 100 }
        func plugged() -> Bool { UIDevice.current.batteryState != .unplugged }
        #else
        func battery() -> Double { -1 }
        func plugged() -> Bool { true }
        #endif

        let adapter = MLXOrganAdapter(model: MLXModelCatalog.qwen3_5_4B_4bit_local)
        try await adapter.loadModel()
        let counter = BASLLMCallCounter()
        let counted = BASCountingOrganAdapter(wrapping: adapter, counter: counter)
        guard let mini = BASMiniLMEmbeddingProvider() else { throw XCTSkip("MiniLM unavailable") }
        let bank = BASEmbeddingFactBank(facts: BAST1Topology.t1Facts(), provider: mini)
        let organ = BASSemanticAdjudicatingOrganAdapter(
            wrapping: counted, bank: bank, enabled: true, shortCircuitCovered: true)
        await organ.warmUp()
        let ctxAdapter = try? BASContextClassifierMLAdapter(computeUnits: nil)
        let casualGate: BASAdjudicationGate? = ctxAdapter.map { a in
            BASAdjudicationGate.classifierCasualSkip(classify: { text in
                (try? a.classify(text: text)).flatMap { BASContextTaskType(rawValue: $0.label) }
            })
        }
        let verifier = BASLLMVerifierPipeline(
            adapters: [.reviewer: organ],
            verifyGate: { @Sendable _, pkg in
                let thermalOK = ProcessInfo.processInfo.thermalState.rawValue
                    <= ProcessInfo.ThermalState.fair.rawValue
                guard thermalOK else { return false }
                if let casualGate {
                    return await casualGate.shouldEngage(BASOrganRequest(
                        requestID: pkg.taskID, role: .core, preset: .core, instruction: pkg.goal))
                }
                return BASStakesEstimator.estimate(pkg.goal, context: []) >= 0.6
            },
            stageMaxOutputTokens: 96)

        var battStart = battery()
        let pluggedAtStart = plugged()
        print(String(format: "[t5-xctest] session start battery=%.0f%% plugged=%@", battStart, "\(pluggedAtStart)"))

        let minutes = Double(ProcessInfo.processInfo.environment["BAS_T5_MINUTES"] ?? "") ?? 20
        let deadline = Date().addingTimeInterval(minutes * 60)
        var turns = 0, calls = 0, estTokens = 0, fairOrBetter = 0, pluggedSamples = 0
        // M4-protocol BURN-IN: at a full charge the battery reading plateaus at 100% for minutes after
        // unplugging — drain in that window is invisible. The measurement WINDOW restarts at the first
        // battery dip (and again after any plugged sample), so the pinned %/turn is drain-visible-only.
        var windowStartBattery = battStart
        var windowStartTurns = 0
        var windowStartTokens = 0
        var sawDip = false
        while Date() < deadline {
            let prompt = BAST1Topology.t1PromptPool[turns % BAST1Topology.t1PromptPool.count]
            await counter.mark()
            let req = BASOrganRequest(
                requestID: "t5-\(turns)", role: .core, preset: .core,
                instruction: prompt, maxOutputTokens: 96)
            let draft = try await organ.draft(req)
            _ = await verifier.verify(
                draft: draft,
                taskPackage: BASLLMTaskPackage(
                    taskID: req.requestID, originSessionID: "t5", compiledAtMs: 0,
                    intent: "verify", goal: prompt))
            let d = await counter.delta()
            calls += d
            estTokens += draft.outputTokensEstimated
            turns += 1
            let th = ProcessInfo.processInfo.thermalState
            if th.rawValue <= ProcessInfo.ThermalState.fair.rawValue { fairOrBetter += 1 }
            if plugged() {
                pluggedSamples += 1
                sawDip = false                              // charging resets the window
            }
            let b = battery()
            if !sawDip && b < windowStartBattery && !plugged() {
                sawDip = true
                windowStartBattery = b
                windowStartTurns = turns
                windowStartTokens = estTokens
                print(String(format: "[t5-xctest] burn-in complete at turn=%d battery=%.0f%% — measurement window starts", turns, b))
            }
            if turns % 5 == 0 {
                print(String(format: "[t5-xctest] turn=%d calls=%d battery=%.0f%% thermal=%d plugged=%@",
                             turns, calls, battery(), th.rawValue, "\(plugged())"))
            }
            try? await Task.sleep(nanoseconds: 15_000_000_000)   // conversational cadence
        }
        let battEnd = battery()
        let used = windowStartBattery - battEnd
        let windowTurns = turns - windowStartTurns
        let windowTokens = estTokens - windowStartTokens
        let pctPerTurn = windowTurns > 0 ? used / Double(windowTurns) : -1
        let pctPer1k = windowTokens > 0 ? used / (Double(windowTokens) / 1000.0) : -1
        let fairFrac = turns > 0 ? Double(fairOrBetter) / Double(turns) : 0
        // Valid = a dip-anchored window with real drain and no charging inside it.
        let valid = sawDip && used > 0 && windowTurns >= 10
        print(String(format: "[t5-xctest] VERDICT turns=%d calls=%d rate=%.2f est_tokens=%d | window: %.0f%%→%.0f%% used=%.1f%% over %d turns/%d tok → %.3f%%/turn, %.2f%%/1k-tok | fair_or_better=%.0f%% | valid=%@%@",
                     turns, calls, Double(calls) / Double(max(turns, 1)), estTokens,
                     windowStartBattery, battEnd, used, windowTurns, windowTokens,
                     pctPerTurn, pctPer1k, fairFrac * 100,
                     "\(valid)", valid ? "" : " ⚠️(no dip-anchored drain window — stay unplugged, below 100%, ≥10 window turns)"))
        XCTAssertGreaterThan(turns, 20, "session too short to measure")
        XCTAssertGreaterThanOrEqual(fairFrac, 0.9, "T5: gated conversational session must stay ≤fair ≥90% of turns")
    }
}
