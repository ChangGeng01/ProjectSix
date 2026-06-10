// MARK: - BASSpeculativeDecodeProbe
//
// 结构大重构 — Phase 6 (audit-3 hardened + sampling distribution check). The ON-DEVICE cert probe for
// speculative decoding (BAS_SPEC_DECODE=1).
//
// Per lane, against a single-model baseline, it measures the gate's three dimensions and folds each lane through
// the observation-only ledger → composer → verdict (PER MODE — never pooled), writing the recommendations to a
// Documents log the cert script pulls. It NEVER enables anything.
//
//   • CORRECTNESS
//       greedy   — bytewise token-identity vs the single-model greedy baseline (full 64-token sequences →
//                  also certifies the shared CACHE ACCOUNTING on-device).
//       sampling — distribution-equivalence via an on-device FIRST-TOKEN check (below) → certifies the
//                  rejection-sampling ACCEPTANCE MATH. Together the two lanes cover both axes (cache mechanics
//                  via greedy full-sequence identity, acceptance distribution via sampling first-token).
//   • LATENCY — paired per-prompt speculative vs baseline, over ≥50 prompts.
//   • MEMORY  — dual-residency peak vs a device budget.
//
// ## Sampling distribution check (self-calibrated — no arbitrary tolerance)
// For each dist prompt, draw the FIRST emitted token N times via speculative sampling (histogram `spec`) and 2N
// times via target-only sampling, split into two independent halves (`baseA`, `baseB`). The finite-sample noise
// floor is `TV(baseA, baseB)` (two empirical histograms from the SAME distribution); the signal is
// `TV(spec, baseA∪baseB)`. A distribution-equivalent decoder gives signal ≈ noise floor. Verified iff
// `signal ≤ max(noise·factor, noise + absMargin)`. The effective support (distinct first tokens) is reported so a
// degenerate (too-peaked) prompt is visible rather than silently passing. First-token = the exact position-0
// conditional with a FIXED context (the prompt), which is precisely where the accept/reject/residual math runs.
//
// ## Phase ordering = memory honesty (audit)
// MLX's peak counter is process-lifetime (no reset API), so the DUAL lanes run FIRST (peak captured while only
// dual configs have been resident), each adapter released + settled before the next loads; the single-model
// baseline runs AFTER (cannot taint the peak). At most ONE configuration resident at a time.
//
// ## Honest bounds (R1 / 亏的不要)
// n=devices (≥2 for the gate) but possibly ONE hardware model; the dist check buckets by first-token TEXT (a
// detokenized proxy for the token id) at the LANE's sampling temperature; it tests position 0 (the rejection
// math) — multi-step joint structure is covered by the greedy lane's full-sequence bytewise identity + the host
// theorem. Fail-honest: if the operator-elected Gemma pair fails to load (per-process jetsam — uncatchable
// SIGKILL), the cert SCRIPT sequences `BAS_SPEC_PAIRING=fallback` to the standard-arch Llama lane.

import Foundation
import os
import BASOrgan
import BASMLXAdapter
import BASMemory
import BASAppleAdapters

enum BASSpeculativeDecodeProbe {

    private static let log = Logger(subsystem: "com.bas.devicetest", category: "spec-decode")

    /// ≥50 varied short prompts for the LATENCY lane (deterministic — no Date/random). Clears SAMPLES_BELOW_MIN.
    private static let prompts: [String] = [
        "Summarize the water cycle in one sentence.", "Name three primary colors.",
        "What is the capital of France?", "List two uses for a paperclip.",
        "Define gravity briefly.", "Translate hello into Spanish.",
        "What sound does a cat make?", "Give one synonym for happy.",
        "How many days are in a week?", "Name a fruit that is red.",
        "What is two plus two?", "Spell the word ocean.",
        "Name a planet in our solar system.", "What color is the sky on a clear day?",
        "Give an example of a mammal.", "What is the opposite of hot?",
        "Name a musical instrument.", "What gas do plants breathe in?",
        "Say a common greeting.", "Name a tool used for writing.",
        "What is the freezing point of water in Celsius?", "Give a word that rhymes with cat.",
        "Name a country in Europe.", "What is the largest ocean?",
        "List a primary emotion.", "What do bees make?",
        "Name a shape with three sides.", "What is the first month of the year?",
        "Give one word for a young dog.", "What is the chemical symbol for water?",
        "Name a vegetable that is orange.", "What is the opposite of up?",
        "Say a polite word.", "Name a day of the weekend.",
        "What animal is known as man's best friend?", "Give a unit of time.",
        "Name a color in a rainbow.", "What is half of ten?",
        "Name a body of water.", "What is the opposite of fast?",
        "Give one word for frozen rain.", "Name a season of the year.",
        "What is the capital of Japan?", "Name a metal.",
        "What do you call a baby cat?", "Give a word meaning very big.",
        "Name a flying insect.", "What is the opposite of dark?",
        "Name a sport played with a ball.", "What is the sum of three and four?",
        "Name a type of tree.", "Give a word for a place to sleep.",
    ]

    /// Open-ended HIGH-ENTROPY prompts for the distribution check (genuine first-token spread at temp 0.7).
    private static let distPrompts: [String] = [
        "Write one random English word:",
        "Continue this story: Once upon a time, there was a",
    ]

    private static let pairings: [(target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String)] = [
        (MLXModelCatalog.gemma4_E4B_4bit, MLXModelCatalog.gemma4_E2B_4bit, "certified"),
        (MLXModelCatalog.llama3_2_3B_4bit, MLXModelCatalog.llama3_2_1B_4bit, "fallback"),
    ]

    private struct PromptResult {
        let promptIndex: Int
        let body: String
        let millis: Double
    }

    // MARK: - File log

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
            lock.lock(); defer { lock.unlock() }
            try? handle?.write(contentsOf: data)
        }

        func close() { lock.lock(); defer { lock.unlock() }; try? handle?.close() }
    }

    /// Knobs (env-tunable so a slow device can dial down).
    private struct Config {
        let memoryBudgetBytes: Int
        let decodeCap: Int
        let promptCount: Int
        let distSamples: Int      // N first-token samples per dist prompt for `spec` (and N each for baseA/baseB)
        let distTemp: Double
        let distFactor: Double    // verified iff signalTV <= max(noiseTV*factor, noiseTV + distAbsMargin)
        let distAbsMargin: Double
        let pairingSel: String
    }

    // MARK: - Run

    static func run() async {
        let env = ProcessInfo.processInfo.environment
        let cfg = Config(
            memoryBudgetBytes: (Int(env["BAS_SPEC_MEM_BUDGET_MB"] ?? "6000") ?? 6000) * 1024 * 1024,
            decodeCap: Int(env["BAS_SPEC_MAX_DECODE_TOKENS"] ?? "48") ?? 48,
            promptCount: min(prompts.count, Int(env["BAS_SPEC_PROMPTS"] ?? "\(prompts.count)") ?? prompts.count),
            distSamples: Int(env["BAS_SPEC_DIST_SAMPLES"] ?? "128") ?? 128,
            distTemp: Double(env["BAS_SPEC_DIST_TEMP"] ?? "\(BASOrganPreset.core.temperature)")
                ?? BASOrganPreset.core.temperature,
            distFactor: Double(env["BAS_SPEC_DIST_FACTOR"] ?? "2.5") ?? 2.5,
            distAbsMargin: Double(env["BAS_SPEC_DIST_MARGIN"] ?? "0.05") ?? 0.05,
            pairingSel: (env["BAS_SPEC_PAIRING"] ?? "all").lowercased())

        let selected = pairings.filter { cfg.pairingSel == "all" || $0.tier == cfg.pairingSel }
        let fileLog = FileLog()
        defer { fileLog.close() }
        fileLog.emit("📊 spec-decode START budget_mb=\(cfg.memoryBudgetBytes / (1024 * 1024)) "
            + "decode_cap=\(cfg.decodeCap) prompts=\(cfg.promptCount) dist_n=\(cfg.distSamples) "
            + "dist_temp=\(String(format: "%.2f", cfg.distTemp)) pairing=\(cfg.pairingSel)")

        for pairing in selected {
            do {
                try await certify(pairing: pairing, cfg: cfg, fileLog: fileLog)
                return
            } catch {
                fileLog.emit("📊 spec-decode pairing tier=\(pairing.tier) FAILED: \(error) — trying next lane")
                continue
            }
        }
        fileLog.emit("📊 spec-decode FINAL recommendation=doNotEnable reason=NO_PAIRING_LOADED "
            + "(every selected pairing failed to load on this device)")
    }

    private static func certify(
        pairing: (target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String),
        cfg: Config, fileLog: FileLog
    ) async throws {
        let lanePrompts = Array(prompts.prefix(cfg.promptCount))
        let distIdx = distPrompts.indices.map { $0 }

        // ---- PHASE A: dual-residency lanes first (honest peak). The SAMPLING lane also collects the spec
        //               first-token histograms while its dual adapter is resident. ----
        let (greedySpec, peakA, _) = try await runSpecLane(
            pairing: pairing, mode: .greedy, lanePrompts: lanePrompts, cfg: cfg, collectDist: false, fileLog: fileLog)
        let (samplingSpec, peakB, specHist) = try await runSpecLane(
            pairing: pairing, mode: .sampling, lanePrompts: lanePrompts, cfg: cfg, collectDist: true, fileLog: fileLog)
        let dualPeakBytes = Int(max(peakA, peakB) * 1024 * 1024)
        fileLog.emit("📊 spec-decode tier=\(pairing.tier) dual_peak_mb=\(Int(max(peakA, peakB)))")

        // ---- PHASE B: single-model baseline (latency for both lanes + the base first-token halves) ----
        let (greedyBase, samplingBase, baseA, baseB) = try await runBaselines(
            target: pairing.target, lanePrompts: lanePrompts, cfg: cfg, fileLog: fileLog)

        // ---- Sampling distribution check: TV(spec, base) vs the self-calibrated noise floor TV(baseA, baseB) ----
        var distVerifiedAll = !distIdx.isEmpty
        for i in distIdx {
            let spec = specHist[i] ?? [:]
            let a = baseA[i] ?? [:]
            let b = baseB[i] ?? [:]
            let noise = totalVariation(a, b)
            let merged = mergeHist(a, b)
            let signal = totalVariation(spec, merged)
            let support = Set(spec.keys).union(merged.keys).count
            let verified = signal <= max(noise * cfg.distFactor, noise + cfg.distAbsMargin)
            distVerifiedAll = distVerifiedAll && verified
            fileLog.emit(String(
                format: "📊 spec-decode dist-check p=%d support=%d noise_tv=%.4f spec_tv=%.4f verified=%@",
                i, support, noise, signal, verified ? "true" : "false"))
        }
        let samplingCorrectness: Bool? = distIdx.isEmpty ? nil : distVerifiedAll

        // ---- Fold into per-prompt PAIRED records, one ledger per lane ----
        var records: [BASShadowTrialRecord] = []
        for spec in greedySpec {
            guard let base = greedyBase.first(where: { $0.promptIndex == spec.promptIndex }) else { continue }
            records.append(record(mode: "greedy", pairing: pairing, promptIndex: spec.promptIndex,
                specMs: spec.millis, baseMs: base.millis, correctness: spec.body == base.body))
        }
        for spec in samplingSpec {
            guard let base = samplingBase.first(where: { $0.promptIndex == spec.promptIndex }) else { continue }
            records.append(record(mode: "sampling", pairing: pairing, promptIndex: spec.promptIndex,
                specMs: spec.millis, baseMs: base.millis, correctness: samplingCorrectness))
        }

        let peakForGate = dualPeakBytes > 0 ? dualPeakBytes : nil
        for mode in ["greedy", "sampling"] {
            let (verdict, composition) = BASSpeculativeShadowComposer.decide(
                records: records, mode: mode, distinctDeviceCount: 1,
                dualPeakMemoryBytes: peakForGate, memoryBudgetBytes: cfg.memoryBudgetBytes)
            for line in BASSpeculativeShadowComposer.render(verdict: verdict, composition: composition)
                .split(separator: "\n") { fileLog.emit("📊 \(line)") }
        }
        fileLog.emit("📊 spec-decode FINAL tier=\(pairing.tier) records=\(records.count) "
            + "(n=1 device / beta — a human reads the verdicts; the gate never auto-enables)")
    }

    // MARK: - Lane drives

    private static func runSpecLane(
        pairing: (target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String),
        mode: BASSpeculativeMode, lanePrompts: [String], cfg: Config, collectDist: Bool, fileLog: FileLog
    ) async throws -> (results: [PromptResult], peakMB: Double, distHist: [Int: [String: Int]]) {
        var adapter: MLXOrganAdapter? = MLXOrganAdapter(
            model: pairing.target, draftModel: pairing.draft, speculativeDecoding: mode)
        fileLog.emit("📊 spec-decode loading-target tier=\(pairing.tier) mode=\(mode.rawValue) "
            + "target=\(pairing.target.providerID)")
        try await adapter!.loadModel()
        fileLog.emit("📊 spec-decode loaded-target tier=\(pairing.tier) drafting=\(pairing.draft.providerID)")
        try await adapter!.loadDraftModel()
        fileLog.emit("📊 spec-decode dual-resident tier=\(pairing.tier) mode=\(mode.rawValue)")

        var results: [PromptResult] = []
        for (i, prompt) in lanePrompts.enumerated() {
            let (body, ms) = try await timedStream(
                adapter!, request(mode: mode, promptIndex: i, prompt: prompt, decodeCap: cfg.decodeCap))
            results.append(PromptResult(promptIndex: i, body: body, millis: ms))
            // Emit EVERY prompt — the cross-device merge test reconstructs per-prompt records from these lines.
            fileLog.emit("📊 spec-decode lane=\(mode.rawValue) p=\(i) spec_ms=\(String(format: "%.0f", ms))")
        }
        fileLog.emit("📊 spec-decode lane=\(mode.rawValue) DONE n=\(results.count)")

        var distHist: [Int: [String: Int]] = [:]
        if collectDist {
            for (i, prompt) in distPrompts.enumerated() {
                distHist[i] = try await firstTokenHistogram(
                    adapter!, mode: .sampling, promptIndex: i, prompt: prompt,
                    samples: cfg.distSamples, temp: cfg.distTemp, decodeCap: cfg.decodeCap)
                fileLog.emit("📊 spec-decode dist-spec p=\(i) drew=\(cfg.distSamples)")
            }
        }

        let peakMB = await adapter!.mlxMemoryStatsMB().peak
        adapter = nil
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return (results, peakMB, distHist)
    }

    private static func runBaselines(
        target: MLXModelCatalog.Entry, lanePrompts: [String], cfg: Config, fileLog: FileLog
    ) async throws -> (greedy: [PromptResult], sampling: [PromptResult],
                       baseA: [Int: [String: Int]], baseB: [Int: [String: Int]]) {
        var adapter: MLXOrganAdapter? = MLXOrganAdapter(model: target)
        try await adapter!.loadModel()
        var greedy: [PromptResult] = []
        var sampling: [PromptResult] = []
        for (i, prompt) in lanePrompts.enumerated() {
            let (gBody, gMs) = try await timedStream(
                adapter!, request(mode: .greedy, promptIndex: i, prompt: prompt, decodeCap: cfg.decodeCap))
            greedy.append(PromptResult(promptIndex: i, body: gBody, millis: gMs))
            let (sBody, sMs) = try await timedStream(
                adapter!, request(mode: .sampling, promptIndex: i, prompt: prompt, decodeCap: cfg.decodeCap))
            sampling.append(PromptResult(promptIndex: i, body: sBody, millis: sMs))
            // Emit EVERY prompt — the cross-device merge test reconstructs the paired baselines from these lines.
            fileLog.emit("📊 spec-decode lane=baseline p=\(i) greedy_ms=\(String(format: "%.0f", gMs)) "
                + "sampling_ms=\(String(format: "%.0f", sMs))")
        }
        fileLog.emit("📊 spec-decode lane=baseline DONE n=\(greedy.count)")

        // Two independent base halves per dist prompt → the self-calibrated noise floor.
        var baseA: [Int: [String: Int]] = [:]
        var baseB: [Int: [String: Int]] = [:]
        for (i, prompt) in distPrompts.enumerated() {
            baseA[i] = try await firstTokenHistogram(
                adapter!, mode: .sampling, promptIndex: i, prompt: prompt,
                samples: cfg.distSamples, temp: cfg.distTemp, decodeCap: cfg.decodeCap)
            baseB[i] = try await firstTokenHistogram(
                adapter!, mode: .sampling, promptIndex: i, prompt: prompt,
                samples: cfg.distSamples, temp: cfg.distTemp, decodeCap: cfg.decodeCap)
            fileLog.emit("📊 spec-decode dist-base p=\(i) drew=\(2 * cfg.distSamples)")
        }

        adapter = nil
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return (greedy, sampling, baseA, baseB)
    }

    // MARK: - First-token sampling + histograms

    /// Draw the first emitted token `samples` times (maxOutputTokens=1) at the given temperature, bucketed by the
    /// first body delta (detokenized first-token text). Each call is an independent draw (fresh per-iterator RNG).
    private static func firstTokenHistogram(
        _ adapter: MLXOrganAdapter, mode: BASSpeculativeMode, promptIndex: Int, prompt: String,
        samples: Int, temp: Double, decodeCap: Int
    ) async throws -> [String: Int] {
        var hist: [String: Int] = [:]
        let req = distRequest(promptIndex: promptIndex, prompt: prompt, temp: temp)
        for _ in 0..<samples {
            let first = try await firstTokenText(adapter, req)
            hist[first, default: 0] += 1
        }
        return hist
    }

    private static func firstTokenText(
        _ adapter: MLXOrganAdapter, _ request: BASOrganRequest
    ) async throws -> String {
        for try await chunk in adapter.streamDraft(request) {
            return chunk.bodyDelta   // first chunk = first token's text (maxOutputTokens=1)
        }
        return ""   // immediate EOS — a valid (empty) outcome
    }

    // MARK: - Requests

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
                temperature: BASOrganPreset.core.temperature, topP: 1,
                maxOutputTokens: BASOrganPreset.core.maxOutputTokens)
        }
        return BASOrganRequest(
            requestID: "spec-\(mode.rawValue)-\(promptIndex)", role: .core, preset: preset,
            instruction: prompt, context: [], maxOutputTokens: decodeCap)
    }

    /// First-token sampling request: pure-temperature (topP=1) at the dist-check temperature, 1 output token.
    private static func distRequest(promptIndex: Int, prompt: String, temp: Double) -> BASOrganRequest {
        let preset = BASOrganPreset(
            name: "bas.spec.dist.v1", temperature: temp, topP: 1, maxOutputTokens: 1)
        return BASOrganRequest(
            requestID: "spec-dist-\(promptIndex)", role: .core, preset: preset,
            instruction: prompt, context: [], maxOutputTokens: 1)
    }

    // MARK: - Pure helpers

    private static func mergeHist(_ a: [String: Int], _ b: [String: Int]) -> [String: Int] {
        var out = a
        for (k, v) in b { out[k, default: 0] += v }
        return out
    }

    /// Total-variation distance between two count histograms (each normalized to a distribution).
    private static func totalVariation(_ a: [String: Int], _ b: [String: Int]) -> Double {
        let na = Double(a.values.reduce(0, +)), nb = Double(b.values.reduce(0, +))
        guard na > 0, nb > 0 else { return 1.0 }
        var sum = 0.0
        for k in Set(a.keys).union(b.keys) {
            sum += abs(Double(a[k] ?? 0) / na - Double(b[k] ?? 0) / nb)
        }
        return 0.5 * sum
    }

    private static func record(
        mode: String, pairing: (target: MLXModelCatalog.Entry, draft: MLXModelCatalog.Entry, tier: String),
        promptIndex: Int, specMs: Double, baseMs: Double, correctness: Bool?
    ) -> BASShadowTrialRecord {
        var effects = [
            "mode: \(mode)",
            "speculative_latency_ms: \(String(format: "%.3f", specMs))",
            "baseline_latency_ms: \(String(format: "%.3f", baseMs))",
        ]
        if let correctness { effects.append("correctness_verified: \(correctness)") }
        return BASShadowTrialRecord(
            trialID: "spec-\(mode)-\(promptIndex)",
            candidateRef: "\(pairing.target.providerID)+\(pairing.draft.providerID)",
            trialScope: BASSpeculativeShadowComposer.trialScope,
            observedEffects: effects, completionState: "observing")
    }

    private static func timedStream(
        _ adapter: MLXOrganAdapter, _ request: BASOrganRequest
    ) async throws -> (body: String, millis: Double) {
        let start = DispatchTime.now().uptimeNanoseconds
        var body = ""
        for try await chunk in adapter.streamDraft(request) { body = chunk.cumulativeBody }
        let millis = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0
        return (body, millis)
    }
}
