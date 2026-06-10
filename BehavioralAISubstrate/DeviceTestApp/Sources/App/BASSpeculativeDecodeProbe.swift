// MARK: - BASSpeculativeDecodeProbe
//
// 结构大重构 — Phase 6. The ON-DEVICE cert probe for speculative decoding (BAS_SPEC_DECODE=1).
//
// Loads a same-family TARGET + DRAFT pair, drives the greedy and sampling speculative lanes against a
// single-model baseline, and measures the three gate dimensions — CORRECTNESS (greedy: token-identity vs the
// single-model greedy baseline), LATENCY (speculative vs baseline ms), and MEMORY (dual-residency peak vs a
// device budget) — then folds the results through the observation-only ledger → composer → verdict and prints
// the human-readable recommendation. It NEVER enables anything; it emits a `📊 spec-decode …` reading + a
// `BASSpeculativeMigrationVerdict` recommendation a HUMAN reads.
//
// Device-only (MLX SIGABRTs on the iOS Simulator). Fail-honest: if the operator-elected Gemma4 E4B↔E2B pair
// OOMs / fails to load on 8 GB, the probe retries the standard-arch Llama-3.2 3B↔1B fallback lane (no Gemma-3n
// wedge) and discloses the inversion; if that also fails, it emits a `doNotEnable`-class reading and exits.
//
// Honest bounds (R1 / 亏的不要): n=1 device, beta toolchain, a handful of short prompts. Greedy correctness is
// bytewise on-device; SAMPLING distribution-equivalence is NOT re-proven here (it is the host-proven property of
// `BASSpeculativeRejectionSampler` — the probe records sampling latency/memory but leaves sampling correctness
// unmeasured, so the gate honestly reports insufficient for the sampling lane until a distribution check is added).

import Foundation
import os
import BASOrgan
import BASMLXAdapter
import BASMemory
import BASAppleAdapters

enum BASSpeculativeDecodeProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "spec-decode")

    /// A few short, fixed prompts (deterministic — no Date/random).
    private static let prompts = [
        "Summarize the water cycle in one sentence.",
        "Name three primary colors.",
        "What is the capital of France?",
    ]

    /// The candidate pairings, in preference order: the operator-elected certified Gemma pair FIRST, then the
    /// standard-arch fallback lane (Llama) if the Gemma pair won't fit.
    private static let pairings: [(target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String)] = [
        (MLXModelCatalog.gemma4_E4B_4bit, MLXModelCatalog.gemma4_E2B_4bit, "certified"),
        (MLXModelCatalog.llama3_2_3B_4bit, MLXModelCatalog.llama3_2_1B_4bit, "fallback"),
    ]

    static func run() async {
        let env = ProcessInfo.processInfo.environment
        let budgetMB = Int(env["BAS_SPEC_MEM_BUDGET_MB"] ?? "6000") ?? 6000
        let memoryBudgetBytes = budgetMB * 1024 * 1024

        log.info("📊 spec-decode START budget_mb=\(budgetMB, privacy: .public)")

        var records: [BASShadowTrialRecord] = []
        var dualPeakBytes = 0
        var ranTier = "none"

        for pairing in pairings {
            do {
                let (trialRecords, peak) = try await driveLane(
                    target: pairing.target, draft: pairing.draft, mode: .greedy)
                records.append(contentsOf: trialRecords)
                dualPeakBytes = max(dualPeakBytes, peak)
                ranTier = pairing.tier

                // Sampling lane (latency/memory only — distribution-equivalence is host-proven, not re-checked here).
                let (samplingRecords, samplingPeak) = try await driveLane(
                    target: pairing.target, draft: pairing.draft, mode: .sampling)
                records.append(contentsOf: samplingRecords)
                dualPeakBytes = max(dualPeakBytes, samplingPeak)
                break   // a pairing loaded + ran — done (don't also run the fallback)
            } catch {
                log.error("📊 spec-decode pairing \(pairing.tier, privacy: .public) FAILED: \(String(describing: error), privacy: .public) — trying next lane (fail-honest)")
                continue
            }
        }

        guard !records.isEmpty else {
            log.error("📊 spec-decode FINAL recommendation=doNotEnable reason=NO_PAIRING_LOADED (every pairing failed to load on this device)")
            return
        }

        // Fold through the observation-only gate (n=1 device ⇒ DEVICES_BELOW_MIN ⇒ insufficientEvidence by design).
        let (verdict, composition) = BASSpeculativeShadowComposer.decide(
            records: records,
            distinctDeviceCount: 1,
            dualPeakMemoryBytes: dualPeakBytes,
            memoryBudgetBytes: memoryBudgetBytes)
        let report = BASSpeculativeShadowComposer.render(verdict: verdict, composition: composition)
        log.info("📊 spec-decode tier=\(ranTier, privacy: .public) peak_mb=\(dualPeakBytes / (1024 * 1024), privacy: .public)")
        for line in report.split(separator: "\n") {
            log.info("📊 \(String(line), privacy: .public)")
        }
        log.info("📊 spec-decode FINAL recommendation=\(verdict.recommendation.rawValue, privacy: .public) (n=1 device / beta — a human reads this; the gate never auto-enables)")
    }

    /// Drive one lane (greedy or sampling): a single-model baseline + the speculative dual adapter over the
    /// prompts, returning per-prompt trial records + the dual-residency peak memory (MB→bytes).
    private static func driveLane(
        target: MLXModelCatalog.Entry,
        draft: MLXModelCatalog.Entry,
        mode: BASSpeculativeMode
    ) async throws -> (records: [BASShadowTrialRecord], peakBytes: Int) {
        let preset: BASOrganPreset = (mode == .greedy) ? .greedyDeterministic : .core

        // Baseline: single-model target, no draft.
        let baseline = MLXOrganAdapter(model: target)
        try await baseline.loadModel()

        // Speculative: dual residency.
        let speculative = MLXOrganAdapter(
            model: target, draftModel: draft, speculativeDecoding: mode)
        try await speculative.loadModel()
        try await speculative.loadDraftModel()

        var records: [BASShadowTrialRecord] = []
        for (i, prompt) in prompts.enumerated() {
            let request = BASOrganRequest(
                requestID: "spec-\(mode.rawValue)-\(i)",
                role: .core, preset: preset, instruction: prompt, context: [])

            let (baseBody, baseMs) = try await timedStream(baseline, request)
            let (specBody, specMs) = try await timedStream(speculative, request)

            // Greedy correctness = bytewise identity to the baseline greedy stream. Sampling: not token-checkable
            // (the streams legitimately differ run-to-run) — leave correctness UNMEASURED for sampling so the gate
            // honestly reports insufficient for that lane.
            var effects = [
                "mode: \(mode.rawValue)",
                "speculative_latency_ms: \(String(format: "%.3f", specMs))",
                "baseline_latency_ms: \(String(format: "%.3f", baseMs))",
            ]
            if mode == .greedy {
                effects.append("correctness_verified: \(baseBody == specBody)")
            }
            records.append(BASShadowTrialRecord(
                trialID: "spec-\(mode.rawValue)-\(i)",
                candidateRef: "\(target.providerID)+\(draft.providerID)",
                trialScope: BASSpeculativeShadowComposer.trialScope,
                observedEffects: effects,
                completionState: "observing"))
        }

        let peak = await speculative.mlxMemoryStatsMB().peak
        return (records, Int(peak * 1024 * 1024))
    }

    /// Drive the streaming draft to completion, returning (finalBody, wallClockMillis).
    private static func timedStream(
        _ adapter: MLXOrganAdapter, _ request: BASOrganRequest
    ) async throws -> (body: String, millis: Double) {
        let start = DispatchTime.now().uptimeNanoseconds
        var body = ""
        for try await chunk in adapter.streamDraft(request) {
            body = chunk.cumulativeBody
        }
        let millis = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0
        return (body, millis)
    }
}
