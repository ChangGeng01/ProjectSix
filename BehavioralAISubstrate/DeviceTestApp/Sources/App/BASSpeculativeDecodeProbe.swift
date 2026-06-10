// MARK: - BASSpeculativeDecodeProbe
//
// 结构大重构 — Phase 6 (audit-3 hardened). The ON-DEVICE cert probe for speculative decoding (BAS_SPEC_DECODE=1).
//
// Measures the three gate dimensions for the greedy AND sampling speculative lanes against a single-model
// baseline — CORRECTNESS (greedy: bytewise body identity), LATENCY (paired per-prompt speculative vs baseline),
// MEMORY (dual-residency peak vs a device budget) — then folds each lane through the observation-only
// ledger → composer → verdict (PER MODE — audit fix: lanes are never pooled) and writes the human-readable
// recommendations to a Documents log (`spec-decode-<stamp>.log`) the cert script pulls. It NEVER enables
// anything (the gate emits a recommendation a HUMAN reads).
//
// ## Phase ordering = the memory-honesty fix (audit)
// MLX's peak counter is PROCESS-LIFETIME (no reset API in the vendored surface), so the probe runs the
// DUAL-RESIDENCY lanes FIRST and captures the peak while only dual configurations have ever been resident —
// the captured value is an honest dual-phase peak. The single-model BASELINE runs AFTER (its lower residency
// cannot raise the already-captured value). Each phase's adapter is released (nil + settle) before the next
// loads, so at most ONE configuration (target+draft, or target alone) is resident at any time — never the
// triple-residency the original probe risked (baseline + target + draft ≈ 7GB on an 8GB device).
//
// ## Honest bounds (R1 / 亏的不要)
// n=1 device per run, beta toolchain, 3 short prompts/lane, decode cap from BAS_SPEC_MAX_DECODE_TOKENS.
// Greedy correctness is bytewise on-device. SAMPLING correctness is NOT re-proven here — it is the host-proven
// property of the rejection rule; the probe records sampling latency/memory only, so the sampling lane's gate
// verdict honestly stays insufficient on correctness until a device distribution check exists. Fail-honest:
// if the operator-elected Gemma4 E4B↔E2B pair fails to load, the probe retries the standard-arch
// Llama-3.2 3B↔1B lane and discloses the fallback.

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

    /// Candidate pairings in preference order: the operator-elected certified Gemma pair FIRST, then the
    /// standard-arch fallback lane (Llama — no ADR-038 Gemma-3n wedge class) if the Gemma pair won't load.
    private static let pairings: [(target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String)] = [
        (MLXModelCatalog.gemma4_E4B_4bit, MLXModelCatalog.gemma4_E2B_4bit, "certified"),
        (MLXModelCatalog.llama3_2_3B_4bit, MLXModelCatalog.llama3_2_1B_4bit, "fallback"),
    ]

    /// One per-prompt measurement from a lane drive.
    private struct PromptResult {
        let promptIndex: Int
        let body: String
        let millis: Double
    }

    // MARK: - File log (Documents/spec-decode-<stamp>.log — pulled by scripts/run-spec-decode-cert.sh)

    /// Lock-guarded file sink + os.Logger fan-out. A class instance (NOT static mutable state — Swift 6
    /// concurrency-safe); `@unchecked Sendable` is sound because every write serializes through `lock`.
    private final class FileLog: @unchecked Sendable {
        private let handle: FileHandle?
        private let lock = NSLock()

        init() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let stamp = formatter.string(from: Date())
            guard let docs = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first else {
                handle = nil
                return
            }
            let url = docs.appendingPathComponent("spec-decode-\(stamp).log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }

        func emit(_ line: String) {
            BASSpeculativeDecodeProbe.log.info("\(line, privacy: .public)")
            guard let data = (line + "\n").data(using: .utf8) else { return }
            lock.lock()
            defer { lock.unlock() }
            try? handle?.write(contentsOf: data)
        }

        func close() {
            lock.lock()
            defer { lock.unlock() }
            try? handle?.close()
        }
    }

    // MARK: - Run

    static func run() async {
        let env = ProcessInfo.processInfo.environment
        let budgetMB = Int(env["BAS_SPEC_MEM_BUDGET_MB"] ?? "6000") ?? 6000
        let decodeCap = Int(env["BAS_SPEC_MAX_DECODE_TOKENS"] ?? "64") ?? 64
        let memoryBudgetBytes = budgetMB * 1024 * 1024

        // Pairing selection (BAS_SPEC_PAIRING = certified | fallback | all). A jetsam per-process-limit kill
        // during a dual load is UNCATCHABLE (SIGKILL, not a Swift throw) — the in-process fail-honest fallback
        // below only covers a thrown load error. So the cert SCRIPT sequences across separate launches: run
        // `certified`; if the app dies with no FINAL (a kill), relaunch with `fallback`. Default `all` tries
        // both in one process (only reaches the fallback if `certified` THREW rather than was killed).
        let pairingSel = (env["BAS_SPEC_PAIRING"] ?? "all").lowercased()
        let selected = pairings.filter { pairingSel == "all" || $0.tier == pairingSel }

        let fileLog = FileLog()
        defer { fileLog.close() }
        fileLog.emit("📊 spec-decode START budget_mb=\(budgetMB) decode_cap=\(decodeCap) pairing=\(pairingSel)")

        for pairing in selected {
            do {
                try await certify(
                    pairing: pairing,
                    memoryBudgetBytes: memoryBudgetBytes,
                    decodeCap: decodeCap,
                    fileLog: fileLog)
                return
            } catch {
                fileLog.emit("📊 spec-decode pairing tier=\(pairing.tier) FAILED: \(error) — trying next lane (fail-honest)")
                continue
            }
        }
        fileLog.emit("📊 spec-decode FINAL recommendation=doNotEnable reason=NO_PAIRING_LOADED "
            + "(every selected pairing failed to load on this device)")
    }

    /// Full cert for one pairing: dual lanes first (honest peak), baseline after, per-mode verdicts.
    private static func certify(
        pairing: (target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String),
        memoryBudgetBytes: Int,
        decodeCap: Int,
        fileLog: FileLog
    ) async throws {
        // ---- PHASE A: dual-residency speculative lanes (peak captured while ONLY dual has been resident) ----
        let (greedySpec, peakA) = try await runSpecLane(
            pairing: pairing, mode: .greedy, decodeCap: decodeCap, fileLog: fileLog)
        let (samplingSpec, peakB) = try await runSpecLane(
            pairing: pairing, mode: .sampling, decodeCap: decodeCap, fileLog: fileLog)
        let dualPeakBytes = Int(max(peakA, peakB) * 1024 * 1024)
        fileLog.emit("📊 spec-decode tier=\(pairing.tier) dual_peak_mb=\(Int(max(peakA, peakB)))")

        // ---- PHASE B: single-model baseline (after the peak capture — cannot taint it) ----
        let (greedyBase, samplingBase) = try await runBaselines(
            target: pairing.target, decodeCap: decodeCap, fileLog: fileLog)

        // ---- Fold into per-prompt PAIRED records, one ledger per lane ----
        var records: [BASShadowTrialRecord] = []
        for spec in greedySpec {
            guard let base = greedyBase.first(where: { $0.promptIndex == spec.promptIndex }) else { continue }
            records.append(record(
                mode: "greedy", pairing: pairing, promptIndex: spec.promptIndex,
                specMs: spec.millis, baseMs: base.millis,
                correctness: spec.body == base.body))
        }
        for spec in samplingSpec {
            guard let base = samplingBase.first(where: { $0.promptIndex == spec.promptIndex }) else { continue }
            // Sampling bodies legitimately differ run-to-run — correctness is NOT token-checkable here
            // (host-proven distribution property); record latency only.
            records.append(record(
                mode: "sampling", pairing: pairing, promptIndex: spec.promptIndex,
                specMs: spec.millis, baseMs: base.millis,
                correctness: nil))
        }

        // ---- Per-mode verdicts (audit fix: lanes never pooled) ----
        let peakForGate = dualPeakBytes > 0 ? dualPeakBytes : nil   // 0 ⇒ no measurement ⇒ nil ⇒ NO_EVIDENCE
        for mode in ["greedy", "sampling"] {
            let (verdict, composition) = BASSpeculativeShadowComposer.decide(
                records: records,
                mode: mode,
                distinctDeviceCount: 1,
                dualPeakMemoryBytes: peakForGate,
                memoryBudgetBytes: memoryBudgetBytes)
            for line in BASSpeculativeShadowComposer
                .render(verdict: verdict, composition: composition)
                .split(separator: "\n") {
                fileLog.emit("📊 \(line)")
            }
        }
        fileLog.emit("📊 spec-decode FINAL tier=\(pairing.tier) records=\(records.count) "
            + "(n=1 device / beta — a human reads the verdicts; the gate never auto-enables)")
    }

    /// Drive ONE dual-residency speculative lane. The dual adapter is created, loaded, driven, peak-sampled,
    /// then RELEASED (nil + settle) before returning — at most one dual configuration resident at a time.
    private static func runSpecLane(
        pairing: (target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String),
        mode: BASSpeculativeMode,
        decodeCap: Int,
        fileLog: FileLog
    ) async throws -> (results: [PromptResult], peakMB: Double) {
        var adapter: MLXOrganAdapter? = MLXOrganAdapter(
            model: pairing.target, draftModel: pairing.draft, speculativeDecoding: mode)
        // Breadcrumbs: a jetsam per-process-limit kill is uncatchable, so these lines pinpoint WHERE the kill
        // landed — "loading-target" with no "loaded-target" ⇒ the target weights alone exceeded the cap;
        // "loaded-target" with no "dual-resident" ⇒ the draft pushed it over.
        fileLog.emit("📊 spec-decode loading-target tier=\(pairing.tier) mode=\(mode.rawValue) "
            + "target=\(pairing.target.providerID)")
        try await adapter!.loadModel()
        fileLog.emit("📊 spec-decode loaded-target tier=\(pairing.tier) drafting=\(pairing.draft.providerID)")
        try await adapter!.loadDraftModel()
        fileLog.emit("📊 spec-decode dual-resident tier=\(pairing.tier) mode=\(mode.rawValue)")
        var results: [PromptResult] = []
        for (i, prompt) in prompts.enumerated() {
            let (body, ms) = try await timedStream(
                adapter!, request(mode: mode, promptIndex: i, prompt: prompt, decodeCap: decodeCap))
            results.append(PromptResult(promptIndex: i, body: body, millis: ms))
            fileLog.emit("📊 spec-decode lane=\(mode.rawValue) p=\(i) spec_ms=\(String(format: "%.0f", ms))")
        }
        let peakMB = await adapter!.mlxMemoryStatsMB().peak
        adapter = nil                                       // release the dual containers
        try? await Task.sleep(nanoseconds: 2_000_000_000)   // settle: let ARC + the MLX pool reclaim
        return (results, peakMB)
    }

    /// Drive the single-model baselines for BOTH lanes' parameter shapes with ONE adapter (greedy preset and
    /// the sampling preset), after the dual phases. Released before returning.
    private static func runBaselines(
        target: MLXModelCatalog.Entry,
        decodeCap: Int,
        fileLog: FileLog
    ) async throws -> (greedy: [PromptResult], sampling: [PromptResult]) {
        var adapter: MLXOrganAdapter? = MLXOrganAdapter(model: target)
        try await adapter!.loadModel()
        var greedy: [PromptResult] = []
        var sampling: [PromptResult] = []
        for (i, prompt) in prompts.enumerated() {
            let (gBody, gMs) = try await timedStream(
                adapter!, request(mode: .greedy, promptIndex: i, prompt: prompt, decodeCap: decodeCap))
            greedy.append(PromptResult(promptIndex: i, body: gBody, millis: gMs))
            let (sBody, sMs) = try await timedStream(
                adapter!, request(mode: .sampling, promptIndex: i, prompt: prompt, decodeCap: decodeCap))
            sampling.append(PromptResult(promptIndex: i, body: sBody, millis: sMs))
            fileLog.emit("📊 spec-decode lane=baseline p=\(i) greedy_ms=\(String(format: "%.0f", gMs)) "
                + "sampling_ms=\(String(format: "%.0f", sMs))")
        }
        adapter = nil
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return (greedy, sampling)
    }

    /// The per-prompt request. Greedy lane uses the greedy-deterministic preset (temp 0). Sampling lane uses
    /// the core preset — the SPECULATIVE side forces the pure-temperature envelope internally
    /// (`_samplingParameters`, topP=1); the BASELINE side must sample the SAME distribution for an honest pair,
    /// so it uses a pure-temperature preset (core temperature, topP=1).
    private static func request(
        mode: BASSpeculativeMode, promptIndex: Int, prompt: String, decodeCap: Int
    ) -> BASOrganRequest {
        let preset: BASOrganPreset
        switch mode {
        case .greedy, .off:
            preset = .greedyDeterministic
        case .sampling:
            preset = BASOrganPreset(
                name: "bas.spec.sampling.pure-temp.v1",
                temperature: BASOrganPreset.core.temperature,
                topP: 1,                                    // pure-temperature: pairs with _samplingParameters
                maxOutputTokens: BASOrganPreset.core.maxOutputTokens)
        }
        return BASOrganRequest(
            requestID: "spec-\(mode.rawValue)-\(promptIndex)",
            role: .core, preset: preset, instruction: prompt, context: [],
            maxOutputTokens: decodeCap)
    }

    private static func record(
        mode: String,
        pairing: (target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String),
        promptIndex: Int,
        specMs: Double,
        baseMs: Double,
        correctness: Bool?
    ) -> BASShadowTrialRecord {
        var effects = [
            "mode: \(mode)",
            "speculative_latency_ms: \(String(format: "%.3f", specMs))",
            "baseline_latency_ms: \(String(format: "%.3f", baseMs))",
        ]
        if let correctness {
            effects.append("correctness_verified: \(correctness)")
        }
        return BASShadowTrialRecord(
            trialID: "spec-\(mode)-\(promptIndex)",
            candidateRef: "\(pairing.target.providerID)+\(pairing.draft.providerID)",
            trialScope: BASSpeculativeShadowComposer.trialScope,
            observedEffects: effects,
            completionState: "observing")
    }

    /// Drive the streaming draft to completion, returning (finalBody, wallClockMillis). Wall-clock includes
    /// prompt prep + prefill on BOTH sides of every pair (the speculative side prefills two models) — a paired,
    /// like-for-like end-to-end latency, disclosed as such.
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
