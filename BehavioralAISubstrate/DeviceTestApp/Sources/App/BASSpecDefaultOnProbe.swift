// MARK: - BASSpecDefaultOnProbe
//
// 满意收尾 — two focused on-device probes closing the last spec-decode evidence gaps:
//
// 1. BAS_SPEC_DEFAULTON=1 — verify the SHIPPING DEFAULT-ON AUTO PATH on hardware. The n=50 cert drove
//    explicitly-constructed adapters (explicit draftModel + mode); the actual default path — bare
//    `MLXOrganAdapter(model:)` → auto-resolve draft from speculativePairings → loadModel auto-loads under the
//    fit gate → temp-gated shouldSpeculate routes greedy requests — had only host tests. This probe runs THAT
//    path: a bare speculativeOptimalTarget adapter (must auto-engage; greedy streamDraft AND the non-streaming
//    draft() both speculative) byte-compared + timed against an explicit `.off` adapter, plus the dormancy check
//    (an explicitly selected Gemma experiment must report willEngageSpeculation=false WITHOUT loading anything).
//    AUDIT-4 disclosure: the probe's two adapters share the PROCESS-GLOBAL MLXRuntimeConfig — the auto adapter's
//    UNION cache cap (768MB, .explicitOverride) is set first, and the later .off adapter's 512MB .adapterDefault
//    is rejected (first-write policy) — so the baseline also ran under 768MB. Byte-equal by doctrine (the cap is
//    a recycling ceiling), but the probe's spec-vs-base LATENCY comparison is config-skewed and is therefore NOT
//    a latency claim — the latency cert remains the n=50 BAS_SPEC_DECODE run. This probe certifies PATH + BYTES.
//
// 2. BAS_SPEC_SWEEP=1 — numDraftTokens sweep for the SAMPLING lane. The n=50 cert measured sampling at the
//    default numDraftTokens=2 → ~30% slower (doNotEnable). Whether a different draft length flips it was
//    conjecture; this probe measures n ∈ {1,2,3} (10 prompts each, paired vs a single-model baseline) so the
//    doNotEnable verdict rests on a tuned measurement, not a default guess.
//
// Same conventions as BASSpeculativeDecodeProbe: Documents file log (spec-decode-<stamp>.log glob, pulled by
// the cert script), one configuration resident at a time (release + settle between phases), observation-only.

import Foundation
import os
import BASOrgan
import BASMLXAdapter

enum BASSpecDefaultOnProbe {

    private static let prompts = [
        "Summarize the water cycle in one sentence.",
        "Name three primary colors.",
        "What is the capital of France?",
        "Define gravity briefly.",
        "Name a planet in our solar system.",
        "What gas do plants breathe in?",
        "Name a shape with three sides.",
        "What is the chemical symbol for water?",
        "Give a unit of time.",
        "What is half of ten?",
    ]

    // FileLog consolidated into the shared ProbeFileLog (BASProbeCommon.swift) — Tier-B dedup.

    // MARK: - 1. Default-on auto-path verification

    static func runDefaultOnVerification() async {
        let decodeCap = Int(ProcessInfo.processInfo.environment["BAS_SPEC_MAX_DECODE_TOKENS"] ?? "48") ?? 48
        let fileLog = ProbeFileLog(filePrefix: "spec-decode-defaulton", category: "spec-defaulton", alsoPrint: false)
        defer { fileLog.close() }
        fileLog.emit("📊 spec-defaulton START decode_cap=\(decodeCap)")

        // Construction-only production observation: resolve the exact BAS manifest entry and mirror the
        // factory's admission policy without calling loadModel (no download and no model residency).
        do {
            let manifest = BASModelManifestRegistry.productionDefault
            let entry = try MLXModelCatalog.entry(for: manifest)
            let cap = BASMLXMemoryModel.resolvedActiveHardCapBytes()
                ?? BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes
            let productionConstruction = MLXOrganAdapter(
                model: entry,
                memoryPolicy: MLXMemoryPolicy(
                    enforceMemoryAdmission: true,
                    activeHardCapBytes: cap))
            fileLog.emit("📊 spec-defaulton manifest-construction-only model_id=\(productionConstruction.model.id) "
                + "provider_id=\(productionConstruction.descriptor.providerID) cap_bytes=\(cap) loaded=false")
        } catch {
            fileLog.emit("📊 spec-defaulton manifest-construction-only refused=\(error) loaded=false")
        }

        // Dormancy experiment FIRST (no load — pure config): explicitly selected Gemma E4B must NOT plan to engage.
        let gemmaExperiment = MLXOrganAdapter(model: MLXModelCatalog.gemma4_E4B_4bit)
        fileLog.emit("📊 spec-defaulton gemma-explicit-experiment will_engage=\(gemmaExperiment.willEngageSpeculation) "
            + "(expected false — pair exceeds the fit budget; stays single-model)")

        do {
            // THE DEFAULT PATH under test: bare adapter, no draftModel/mode args — everything auto.
            var auto: MLXOrganAdapter? = MLXOrganAdapter(model: MLXModelCatalog.speculativeOptimalTarget)
            fileLog.emit("📊 spec-defaulton auto-plan will_engage=\(auto!.willEngageSpeculation) "
                + "draft=\(auto!.draftModel?.providerID ?? "nil")")
            try await auto!.loadModel()   // must auto-load the draft under the fit gate
            let active = await auto!.isSpeculationActive
            let failReason = await auto!.draftLoadFailureReason
            fileLog.emit("📊 spec-defaulton auto-loaded speculation_active=\(active) "
                + "draft_load_failure=\(failReason ?? "none")")

            var specStream: [(String, Double)] = []
            var specDraft: [(String, Double)] = []
            for (i, p) in prompts.enumerated() {
                let req = request(i, p, decodeCap)
                specStream.append(try await timedStream(auto!, req))
                let t0 = DispatchTime.now().uptimeNanoseconds
                let d = try await auto!.draft(req)   // the NON-STREAMING speculative path (satisfaction-pass A)
                specDraft.append((d.body,
                    Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000.0))
            }
            auto = nil
            await idleGuardedSleep(seconds: 2)   // audit devicetestapp MED-2: lock-survivable cooldown

            // Reference: explicit .off adapter, same target, same requests — byte-comparison baseline.
            var off: MLXOrganAdapter? = MLXOrganAdapter(
                model: MLXModelCatalog.speculativeOptimalTarget, speculativeDecoding: .off)
            try await off!.loadModel()
            var baseStream: [(String, Double)] = []
            for (i, p) in prompts.enumerated() {
                baseStream.append(try await timedStream(off!, request(i, p, decodeCap)))
            }
            off = nil
            await idleGuardedSleep(seconds: 1)   // audit devicetestapp MED-2: lock-survivable cooldown

            let streamMatches = zip(specStream, baseStream).filter { $0.0.0 == $0.1.0 }.count
            let draftMatches = zip(specDraft, baseStream).filter { $0.0.0 == $0.1.0 }.count
            let specMean = specStream.map(\.1).reduce(0, +) / Double(specStream.count)
            let draftMean = specDraft.map(\.1).reduce(0, +) / Double(specDraft.count)
            let baseMean = baseStream.map(\.1).reduce(0, +) / Double(baseStream.count)
            fileLog.emit(String(format: "📊 spec-defaulton RESULT stream_byte_identical=%d/%d "
                + "draft_byte_identical=%d/%d spec_stream_ms=%.0f spec_draft_ms=%.0f base_ms=%.0f",
                streamMatches, prompts.count, draftMatches, prompts.count, specMean, draftMean, baseMean))
            let verified = streamMatches == prompts.count && draftMatches == prompts.count
                && active && failReason == nil && !gemmaExperiment.willEngageSpeculation
            fileLog.emit("📊 spec-defaulton FINAL verified=\(verified) "
                + "(auto speculation path: plan→load→engage→byte-identical, explicit Gemma experiment dormant; "
                + "n=1 device per run)")
        } catch {
            fileLog.emit("📊 spec-defaulton FINAL verified=false error=\(error)")
        }
    }

    // MARK: - 2. numDraftTokens sweep (sampling lane)

    static func runDraftTokenSweep() async {
        let decodeCap = Int(ProcessInfo.processInfo.environment["BAS_SPEC_MAX_DECODE_TOKENS"] ?? "48") ?? 48
        let fileLog = ProbeFileLog(filePrefix: "spec-decode-sweep", category: "spec-defaulton", alsoPrint: false)
        defer { fileLog.close() }
        fileLog.emit("📊 spec-sweep START lane=sampling decode_cap=\(decodeCap) n_prompts=\(prompts.count)")
        let target = MLXModelCatalog.speculativeOptimalTarget
        let draft = MLXModelCatalog.recommendedDraft(forTargetProviderID: target.providerID)!

        do {
            var means: [Int: Double] = [:]
            for n in [1, 2, 3] {
                var adapter: MLXOrganAdapter? = MLXOrganAdapter(
                    model: target, draftModel: draft,
                    speculativeDecoding: .sampling, numDraftTokens: n)
                try await adapter!.loadModel()
                try await adapter!.loadDraftModel()
                var total = 0.0
                for (i, p) in prompts.enumerated() {
                    total += try await timedStream(adapter!, request(i, p, decodeCap, sampling: true)).1
                }
                means[n] = total / Double(prompts.count)
                fileLog.emit(String(format: "📊 spec-sweep n=%d mean_ms=%.0f", n, means[n]!))
                adapter = nil
                await idleGuardedSleep(seconds: 2)   // audit devicetestapp MED-2: lock-survivable cooldown
            }
            var base: MLXOrganAdapter? = MLXOrganAdapter(model: target, speculativeDecoding: .off)
            try await base!.loadModel()
            var total = 0.0
            for (i, p) in prompts.enumerated() {
                total += try await timedStream(base!, request(i, p, decodeCap, sampling: true)).1
            }
            let baseMean = total / Double(prompts.count)
            base = nil
            fileLog.emit(String(format: "📊 spec-sweep baseline mean_ms=%.0f", baseMean))
            let best = means.min { $0.value < $1.value }!
            let verdict = best.value < baseMean * 0.95 ? "WIN" : (best.value > baseMean ? "LOSS" : "TIE")
            fileLog.emit(String(format: "📊 spec-sweep FINAL best_n=%d best_ms=%.0f baseline_ms=%.0f "
                + "verdict=%@ (n=1 device, 10 prompts/config — directional, not a cert)",
                best.key, best.value, baseMean, verdict))
        } catch {
            fileLog.emit("📊 spec-sweep FINAL error=\(error)")
        }
    }

    // MARK: - 3. Tranche A3 — GREEDY numDraftTokens sweep, thermal-confound-killed (2026-06-12)
    //
    // The prior sweep (above) had two limits: SAMPLING lane only, and SEQUENTIAL config order with the
    // baseline LAST — later configs run hotter, so "n=1 best" carried a thermal confound. This sweep:
    //   • GREEDY lane (the production lane after Tranche A: temp==0, 1.34× device-confirmed)
    //   • n ∈ {1,2,3,4} with the MIDDLE ORDER SHUFFLED per run (seeded by clock — order logged)
    //   • BASELINE BRACKET: single-model greedy runs FIRST and LAST. drift = post−pre quantifies the
    //     thermal slide across the whole sweep; config means are reported raw + the bracket, so the
    //     verdict can discount drift honestly instead of pretending it isn't there。
    // Verdict updates the numDraftTokens default ONLY via a reviewed commit citing this output。
    static func runGreedyDraftTokenSweep() async {
        let decodeCap = Int(ProcessInfo.processInfo.environment["BAS_SPEC_MAX_DECODE_TOKENS"] ?? "48") ?? 48
        let fileLog = ProbeFileLog(filePrefix: "spec-greedy-sweep", category: "spec-defaulton", alsoPrint: false)
        defer { fileLog.close() }
        let target = MLXModelCatalog.speculativeOptimalTarget
        guard let draft = MLXModelCatalog.recommendedDraft(forTargetProviderID: target.providerID) else {
            fileLog.emit("📊 greedy-sweep ABORT — no draft pairing for \(target.providerID)")
            return
        }
        var order = [1, 2, 3, 4]
        order.shuffle()
        fileLog.emit("📊 greedy-sweep START lane=greedy decode_cap=\(decodeCap) "
            + "n_prompts=\(prompts.count) shuffled_order=\(order) bracket=baseline-first+last")

        func baselineMean(_ label: String) async throws -> Double {
            var base: MLXOrganAdapter? = MLXOrganAdapter(model: target, speculativeDecoding: .off)
            try await base!.loadModel()
            var total = 0.0
            for (i, p) in prompts.enumerated() {
                total += try await timedStream(base!, request(i, p, decodeCap)).1
            }
            base = nil
            let mean = total / Double(prompts.count)
            fileLog.emit(String(format: "📊 greedy-sweep baseline-%@ mean_ms=%.0f", label, mean))
            await idleGuardedSleep(seconds: 2)   // audit devicetestapp MED-2: lock-survivable cooldown
            return mean
        }

        do {
            let basePre = try await baselineMean("pre")
            var means: [Int: Double] = [:]
            for n in order {
                var adapter: MLXOrganAdapter? = MLXOrganAdapter(
                    model: target, draftModel: draft,
                    speculativeDecoding: .greedy, numDraftTokens: n)
                try await adapter!.loadModel()
                try await adapter!.loadDraftModel()
                var total = 0.0
                for (i, p) in prompts.enumerated() {
                    total += try await timedStream(adapter!, request(i, p, decodeCap)).1
                }
                means[n] = total / Double(prompts.count)
                fileLog.emit(String(format: "📊 greedy-sweep n=%d mean_ms=%.0f", n, means[n]!))
                adapter = nil
                await idleGuardedSleep(seconds: 2)   // audit devicetestapp MED-2: lock-survivable cooldown
            }
            let basePost = try await baselineMean("post")
            let driftPct = basePre > 0 ? (basePost - basePre) / basePre * 100 : 0
            let baseMean = (basePre + basePost) / 2
            let best = means.min { $0.value < $1.value }!
            let speedup = best.value > 0 ? baseMean / best.value : 0
            // Honest verdict: a config wins only if it beats the bracket-mean baseline by more than
            // the measured drift band (no thermal-slide credit)。
            let driftBandMs = abs(basePost - basePre)
            let verdict = best.value < (baseMean - driftBandMs) ? "WIN" : "INCONCLUSIVE-WITHIN-DRIFT"
            fileLog.emit(String(format: "📊 greedy-sweep FINAL best_n=%d best_ms=%.0f "
                + "baseline_bracket_ms=%.0f drift_pct=%+.1f%% speedup=%.2fx verdict=%@ "
                + "(order=%@; n=1 device — directional re-cert input, default change needs reviewed commit)",
                best.key, best.value, baseMean, driftPct, speedup, verdict,
                "\(order)"))
        } catch {
            fileLog.emit("📊 greedy-sweep FINAL error=\(error)")
        }
    }

    // MARK: - Helpers

    private static func request(
        _ i: Int, _ prompt: String, _ decodeCap: Int, sampling: Bool = false
    ) -> BASOrganRequest {
        let preset: BASOrganPreset = sampling
            ? BASOrganPreset(name: "bas.sweep.pure-temp.v1",
                             temperature: BASOrganPreset.core.temperature,
                             topP: 1, maxOutputTokens: BASOrganPreset.core.maxOutputTokens)
            : .greedyDeterministic
        return BASOrganRequest(
            requestID: "defon-\(i)", role: .core, preset: preset,
            instruction: prompt, context: [], maxOutputTokens: decodeCap)
    }

    private static func timedStream(
        _ adapter: MLXOrganAdapter, _ request: BASOrganRequest
    ) async throws -> (String, Double) {
        let start = DispatchTime.now().uptimeNanoseconds
        var body = ""
        for try await chunk in adapter.streamDraft(request) { body = chunk.cumulativeBody }
        return (body, Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0)
    }
}
