// MARK: - BASQuantABProbe — Tranche C 3-bit vs 4-bit paired A/B + quality capture (2026-06-12)
//
// The promotion gate for the locally-quantized 3-bit Llama (`MLXModelCatalog.llama3_2_3B_3bit_local`):
// the cross-session smoke showed ~+26% est decode / -22% memory, but a default flip needs (a) a
// SAME-DEVICE thermal-honest speed delta and (b) a HUMAN quality read. This probe (`BAS_QUANT_AB=1`)
// delivers both:
//
//   • Speed: BRACKETED bracket — 4-bit runs FIRST and LAST, 3-bit in the middle (one model resident at
//     a time → memory-safe, no both-resident jetsam risk). drift = post−pre quantifies the thermal
//     slide; the verdict refuses drift credit (WIN only if 3-bit beats the 4-bit bracket mean by MORE
//     than the drift band), exactly like the A3 sweep。
//   • Quality: every (prompt, 4bit-body, 3bit-body) triple is written to the log so a human can read
//     the actual 3-bit output side-by-side with 4-bit and judge degradation — the INDEPENDENT gate
//     (3-bit quality loss is the known risk; speed alone never promotes)。
//
// Observation-only, MLX-free of the substrate (only the two adapters load). Promotion = a separate
// reviewed commit citing this output + the human quality verdict; else DECLINE (亏的不要)。

import Foundation
import os
import BASOrgan
import BASMLXAdapter

enum BASQuantABProbe {

    // Mix of factual + reasoning + generative — quality degradation shows most on the latter two.
    private static let prompts = [
        "What is the capital of France, and name two famous landmarks there?",
        "Explain in two sentences why the sky appears blue.",
        "A farmer has 17 sheep; all but 9 run away. How many are left? Explain.",
        "Write a two-line rhyming couplet about the ocean.",
        "Summarize the plot of Romeo and Juliet in three sentences.",
        "List three pros and three cons of remote work.",
    ]

    // FileLog consolidated into the shared ProbeFileLog (BASProbeCommon.swift) — Tier-B dedup.

    static func run() async {
        let fileLog = ProbeFileLog(filePrefix: "quant-ab", category: "quant-ab", alsoPrint: false)
        defer { fileLog.close() }
        let env = ProcessInfo.processInfo.environment
        let decodeCap = Int(env["BAS_QUANT_AB_TOKENS"] ?? "200") ?? 200
        let fourBit = MLXModelCatalog.llama3_2_3B_4bit
        // BAS_QUANT_LOWBIT selects the low-bit challenger: "3bit" (naive group-quant, DECLINED) or "mixed34"
        // (mlx_lm mixed_3_4: 3-bit base + 4-bit sensitive, 3.624 bpw — the quality-preserving bandwidth retry).
        let lowbit = env["BAS_QUANT_LOWBIT"] ?? "3bit"
        let threeBit: MLXModelCatalog.Entry
        switch lowbit {
        case "mixed_attn4":   threeBit = MLXModelCatalog.llama3_2_3B_mixed_attn4_local // embed+attn 4-bit / FFN 3-bit
        case "mixed34":       threeBit = MLXModelCatalog.llama3_2_3B_mixed34_local      // mlx_lm mixed_3_4
        case "mxfp4":         threeBit = MLXModelCatalog.llama3_2_3B_mxfp4_local        // MX block float, 4.251 bpw
        case "g128":          threeBit = MLXModelCatalog.llama3_2_3B_4bit_g128_local    // 4-bit group_size 128 (vs g64)
        case "awq3":          threeBit = MLXModelCatalog.llama3_2_3B_awq3_local        // AWQ 3-bit body / 4-bit embed
        case "dwq3":          threeBit = MLXModelCatalog.llama3_2_3B_dwq3_local        // DWQ 3-bit (distilled on AWQ)
        case "granite_micro": threeBit = MLXModelCatalog.granite4_h_micro_4bit_local    // 3B Mamba hybrid (model-axis)
        case "granite_tiny":  threeBit = MLXModelCatalog.granite4_h_tiny_4bit_local     // 7B/1B-active hybrid MoE
        default:              threeBit = MLXModelCatalog.llama3_2_3B_3bit_local         // naive 3-bit
        }
        fileLog.emit("📊 quant-ab START 4bit=\(fourBit.providerID) lowbit=\(threeBit.providerID) "
            + "decode_cap=\(decodeCap) n_prompts=\(prompts.count) bracket=4bit-first+last")

        func runModel(_ entry: MLXModelCatalog.Entry, label: String, captureBodies: Bool,
                      kvBits: Int? = nil, promptSet: [String]? = nil) async
            -> (meanMs: Double, bodies: [String]) {
            do {
                var adapter: MLXOrganAdapter? = MLXOrganAdapter(
                    model: entry,
                    speculativeDecoding: .off,                 // single-model: isolate the quant lever
                    kvCacheBits: kvBits)                       // KV-quant lever (nil = fp16 cache)
                try await adapter!.loadModel()
                var total = 0.0
                var bodies: [String] = []
                let ps = promptSet ?? prompts
                for (i, p) in ps.enumerated() {
                    let (body, ms) = try await timed(adapter!, i, p, decodeCap)
                    total += ms
                    if captureBodies { bodies.append(body) }
                }
                let mean = total / Double(ps.count)
                adapter = nil
                fileLog.emit(String(format: "📊 quant-ab %@ mean_ms=%.0f", label, mean))
                await idleGuardedSleep(seconds: 2)   // audit devicetestapp MED-2: lock-survivable cooldown
                return (mean, bodies)
            } catch {
                fileLog.emit("📊 quant-ab \(label) ERROR=\(error)")
                return (0, [])
            }
        }

        // KV-CACHE QUANT lever (BAS_QUANT_KVBITS=4|8) — the audit's only explicit re-open trigger. Same 4-bit model,
        // kvBits=nil (fp16 cache) vs kvBits=N, at LONG context (a ~2k-token prompt so the KV cache is a real fraction
        // of the per-token read). Physics caveat: at ≤4k ctx the KV is ~10-20% of bandwidth (weights dominate) →
        // expect ≤~10% even before the A19's ±78% thermal drift, so a clean win is unlikely; this MEASURES the bound.
        if let kvb = Int(env["BAS_QUANT_KVBITS"] ?? "") {
            // audit devicetestapp LOW-4: MLX kvCacheBits supports ONLY 4- or 8-bit. Any other value
            // (3, 5, 100…) would reach the MLX quant layer and crash / silently misbehave — whitelist
            // it and abort this run loudly rather than launch an invalid KV-quant measurement.
            guard kvb == 4 || kvb == 8 else {
                fileLog.emit("📊 quant-ab KVQUANT ABORT invalid BAS_QUANT_KVBITS=\(kvb) — must be 4 or 8")
                return
            }
            // ~150-token passage × 14 ≈ 2.1k-token prompt; decodeCap controls generated tokens on top.
            let passage = "In a quiet coastal town, the lighthouse keeper recorded the tides each morning, noting how "
                + "the gulls wheeled over the harbour and the fishing boats slipped out before dawn. The old ledger, "
                + "bound in cracked leather, held decades of weather, of storms that swallowed the breakwater and "
                + "calm spells when the sea lay flat as glass. Visitors rarely came, but those who did asked about "
                + "the wreck on the reef and the night the beam went dark. "
            let longP = String(repeating: passage, count: 14)
                + "\n\nBased only on the passage above, write a three-sentence summary of the lighthouse keeper's routine."
            fileLog.emit("📊 quant-ab KVQUANT START kvbits=\(kvb) model=\(fourBit.providerID) "
                + "long_ctx≈2.1k-tok decode_cap=\(decodeCap) bracket=kvNil-pre+post")
            let kpre  = await runModel(fourBit, label: "kvNil-pre",  captureBodies: true,  kvBits: nil, promptSet: [longP])
            let kq    = await runModel(fourBit, label: "kv\(kvb)",   captureBodies: true,  kvBits: kvb, promptSet: [longP])
            let kpost = await runModel(fourBit, label: "kvNil-post", captureBodies: false, kvBits: nil, promptSet: [longP])
            // device-recon id13: single-sourced through the Mac-unit-tested verdict.
            let kbv = BASBracketVerdict.classify(
                preMs: kpre.meanMs, challengerMs: kq.meanMs, postMs: kpost.meanMs)
            let kbracket = kbv.bracketMs
            let kdrift = kpre.meanMs > 0 ? (kpost.meanMs - kpre.meanMs) / kpre.meanMs * 100 : 0
            let kspeedup = kbv.speedup
            let kverdict = kbv.isWin ? "KV-SPEED-WIN" : "KV-INCONCLUSIVE-WITHIN-DRIFT"
            fileLog.emit(String(format: "📊 quant-ab KVQUANT kvbits=%d kvNil_bracket_ms=%.0f kv%d_ms=%.0f "
                + "drift_pct=%+.1f%% speedup=%.2fx verdict=%@", kvb, kbracket, kvb, kq.meanMs, kdrift, kspeedup, kverdict))
            if let a = kpre.bodies.first { fileLog.emit("   [kvNil] " + String(a.prefix(200))) }
            if let b = kq.bodies.first   { fileLog.emit("   [kv\(kvb)] " + String(b.prefix(200))) }
            fileLog.emit("📊 quant-ab DONE (KVQUANT mode — KV-cache bandwidth lever)")
            return
        }

        // Bracket: 4-bit pre → 3-bit → 4-bit post (one model resident at a time)。
        let pre = await runModel(fourBit, label: "4bit-pre", captureBodies: true)
        let three = await runModel(threeBit, label: "3bit", captureBodies: true)
        let post = await runModel(fourBit, label: "4bit-post", captureBodies: false)

        // device-recon id13: single-sourced through the Mac-unit-tested verdict.
        let bv = BASBracketVerdict.classify(
            preMs: pre.meanMs, challengerMs: three.meanMs, postMs: post.meanMs)
        let bracket = bv.bracketMs
        let driftPct = pre.meanMs > 0 ? (post.meanMs - pre.meanMs) / pre.meanMs * 100 : 0
        let speedup = bv.speedup
        let verdict = bv.isWin ? "SPEED-WIN" : "SPEED-INCONCLUSIVE-WITHIN-DRIFT"
        fileLog.emit(String(format: "📊 quant-ab SPEED 3bit_ms=%.0f 4bit_bracket_ms=%.0f "
            + "drift_pct=%+.1f%% speedup=%.2fx verdict=%@ (quality is the SEPARATE gate below)",
            three.meanMs, bracket, driftPct, speedup, verdict))

        // QUALITY: write the paired bodies so a human can read 3-bit vs 4-bit side by side。
        fileLog.emit("📊 quant-ab QUALITY-PAIRS (human-read; 3-bit degradation is the promotion gate):")
        for (i, p) in prompts.enumerated() {
            let b4 = i < pre.bodies.count ? clean(pre.bodies[i]) : "—"
            let b3 = i < three.bodies.count ? clean(three.bodies[i]) : "—"
            fileLog.emit("―― Q\(i+1): \(p)")
            fileLog.emit("   [4bit] \(b4)")
            fileLog.emit("   [3bit] \(b3)")
        }
        fileLog.emit("📊 quant-ab DONE — promote 3-bit ONLY if SPEED-WIN AND human quality holds; "
            + "else DECLINE (negative result is output).")
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(600).description
    }

    private static func timed(
        _ adapter: MLXOrganAdapter, _ i: Int, _ prompt: String, _ cap: Int
    ) async throws -> (String, Double) {
        let request = BASOrganRequest(
            requestID: "quant-\(i)", role: .core, preset: .greedyDeterministic,
            instruction: prompt, context: [], maxOutputTokens: cap)
        let start = DispatchTime.now().uptimeNanoseconds
        var body = ""
        for try await chunk in adapter.streamDraft(request) { body = chunk.cumulativeBody }
        return (body, Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0)
    }
}
