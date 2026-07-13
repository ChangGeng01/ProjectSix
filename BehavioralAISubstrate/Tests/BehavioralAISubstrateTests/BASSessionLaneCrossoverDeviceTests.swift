import XCTest
import BASOrgan
import MLX
@testable import BASHostKit
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import MLXLLM
import Tokenizers
#endif

/// 会话→加速lane — MEASURE-BEFORE-BUILD (the eval-rigor discipline): does the stateless MTP-fused path
/// (re-prefill the WHOLE conversation each turn + fast 30 tok/s decode) actually beat the ChatSession
/// KV-reuse path (prefill only the NEW turn + plain ~20 tok/s decode) for a growing seat conversation?
///
/// The router is worth building ONLY if the crossover is deep enough to matter. Coarse physics predicts
/// a shallow crossover (~150 history tokens): re-prefill of H tokens at ~140 tok/s prefill = H/140 s,
/// vs the MTP decode gain of ~1s on 64 output tokens. This measures the ACTUAL per-turn wall clock of
/// both lanes across conversation depth on device, and prints the crossover so the build/skip decision
/// is evidence-based.
final class BASSessionLaneCrossoverDeviceTests: XCTestCase {

    func testSessionLaneCrossover() async throws {
        guard ProcessInfo.processInfo.environment["BAS_XOVER_XCTEST"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_XOVER_XCTEST=1 (device; loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #endif
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localDir = docs.appendingPathComponent("models/Qwen3.5-4B-4bit")
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: wURL.path) else {
            throw XCTSkip("MTP weights not staged at Documents/qwen35_mtp_folded.safetensors")
        }
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })

        struct Row: Sendable { let depth: Int; let histTokens: Int; let statelessMs: Double; let reuseMs: Double }
        let rows: [Row] = try await container.perform { ctx -> [Row] in
            guard let qwen = ctx.model as? Qwen35Model else { throw BASQwen35MTPSpecDecoder.SpecError.notQwen35 }
            let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
            var out: [Row] = []
            let userTurn: [Int] = Array(500 ..< 520)   // ~20-token "new user turn"
            // 3 representative depths (light — 6×full-history prefill + MTP state jetsammed take-1);
            // eval+clearCache between measurements to bound peak memory.
            for (depth, histLen) in [(1, 40), (2, 160), (3, 400)] {
                let history = Array(100 ..< (100 + histLen))
                let fullPrompt = history + userTurn
                // (a) STATELESS MTP: re-prefill the whole conversation each turn + fast decode.
                dec.resetMTPStream()
                let a0 = Date()
                let sRun = dec.generateSpecKFused(prompt: fullPrompt, maxTokens: 32, k: 3, tCap: 5, adaptiveK: true)
                eval(MLXArray(Int32(sRun.tokens.count)))
                let statelessMs = Date().timeIntervalSince(a0) * 1000
                MLX.Memory.clearCache()

                // (b) KV-REUSE per-turn cost: prefill only the NEW turn against a warm cache + plain decode.
                let cache = qwen.newCache(parameters: nil)
                let warm = qwen.hiddenStatesWithCache(MLXArray(history.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                eval(warm)                                                    // amortized-once history prefill
                let b0 = Date()
                let h = qwen.hiddenStatesWithCache(MLXArray(userTurn.map(Int32.init)).expandedDimensions(axis: 0), cache: cache)
                eval(h)                                                       // new-turn prefill (the only reuse prefill cost)
                let plain = dec.generatePlain(prompt: userTurn, maxTokens: 32)  // decode-bound proxy
                let reuseTotalMs = Date().timeIntervalSince(b0) * 1000 - plain.decodeSeconds * 1000 + plain.decodeSeconds * 1000
                out.append(Row(depth: depth, histTokens: history.count,
                               statelessMs: statelessMs, reuseMs: reuseTotalMs))
                MLX.Memory.clearCache()
            }
            return out
        }

        var crossoverDepth = -1
        for r in rows {
            print(String(format: "[xover] depth=%d hist_tokens=%d stateless_mtp=%.0fms kv_reuse=%.0fms winner=%@",
                         r.depth, r.histTokens, r.statelessMs, r.reuseMs,
                         r.statelessMs < r.reuseMs ? "stateless" : "reuse"))
            if crossoverDepth < 0 && r.reuseMs < r.statelessMs { crossoverDepth = r.depth }
        }
        print("[xover] VERDICT crossover_depth=\(crossoverDepth) (reuse wins from this depth; -1 = stateless always won in range)")
        XCTAssertFalse(rows.isEmpty)
    }

    /// The ROUTER end-to-end: fused lane serves short-history greedy session turns; crossing the
    /// budget re-hydrates a ChatSession (vendored init(history:)) and the conversation continues
    /// coherently on the pooled path.
    func testFusedSessionRouterAndTransition() async throws {
        guard ProcessInfo.processInfo.environment["BAS_XOVER_XCTEST"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_XOVER_XCTEST=1 (device; loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        #endif
        let adapter = MLXOrganAdapter(
            model: MLXModelCatalog.qwen3_5_4B_4bit_local, sessionFusedLane: true)
        try await adapter.loadModel()

        func turn(_ i: Int, _ text: String) async throws -> BASOrganDraft {
            try await adapter.draft(BASOrganRequest(
                requestID: "fs-\(i)", role: .core, preset: .greedyDeterministic,
                instruction: text, maxOutputTokens: 48,
                sessionID: "seat:router", personaInstructions: "You are a terse planning seat."))
        }

        // Turns 1-2: short history → the fused lane must serve them.
        let d1 = try await turn(1, "Name one crop for a small garden.")
        let d2 = try await turn(2, "Name one more, different from before.")
        let fusedAfter2 = await adapter.fusedSessionTurnCount
        let sessionsAfter2 = await adapter.sessionCount()
        print("[fs-router] after 2 turns fused_turns=\(fusedAfter2) live_sessions=\(sessionsAfter2)")
        XCTAssertEqual(fusedAfter2, 2, "short-history greedy turns must ride the fused lane")
        XCTAssertEqual(sessionsAfter2, 0, "no ChatSession yet — transcript-owned")
        XCTAssertFalse(d1.body.isEmpty); XCTAssertFalse(d2.body.isEmpty)

        // Force the budget crossing: a long user turn pushes est tokens past the threshold.
        let long = String(repeating: "Consider constraints of soil, light, water, budget. ", count: 24)
        let d3 = try await turn(3, long + "Now summarize the plan in one sentence.")
        let fusedAfter3 = await adapter.fusedSessionTurnCount
        let sessionsAfter3 = await adapter.sessionCount()
        print("[fs-router] after long turn fused_turns=\(fusedAfter3) live_sessions=\(sessionsAfter3) body_len=\(d3.body.count)")
        XCTAssertEqual(fusedAfter3, 2, "the long turn must NOT ride the fused lane (budget crossed)")
        XCTAssertEqual(sessionsAfter3, 1, "transition must re-hydrate exactly one ChatSession")
        XCTAssertFalse(d3.body.isEmpty)

        // Turn 4 continues on the pooled path, KV warm.
        let d4 = try await turn(4, "One-word answer: is the plan feasible?")
        print("[fs-router] turn4 body=\(d4.body.prefix(60)) prompt_tokens=\(d4.completionMetrics?.promptTokens ?? -1)")
        XCTAssertFalse(d4.body.isEmpty)
        let fusedAfter4 = await adapter.fusedSessionTurnCount
        XCTAssertEqual(fusedAfter4, 2)
        print("[fs-router] VERDICT PASS — fused turns 2, transition 1, pooled continuation OK")
    }
}
