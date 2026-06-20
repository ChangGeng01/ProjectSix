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
        let decodeCap = Int(ProcessInfo.processInfo.environment["BAS_QUANT_AB_TOKENS"] ?? "200") ?? 200
        let fourBit = MLXModelCatalog.llama3_2_3B_4bit
        let threeBit = MLXModelCatalog.llama3_2_3B_3bit_local
        fileLog.emit("📊 quant-ab START 4bit=\(fourBit.providerID) 3bit=\(threeBit.providerID) "
            + "decode_cap=\(decodeCap) n_prompts=\(prompts.count) bracket=4bit-first+last")

        func runModel(_ entry: MLXModelCatalog.Entry, label: String, captureBodies: Bool) async
            -> (meanMs: Double, bodies: [String]) {
            do {
                var adapter: MLXOrganAdapter? = MLXOrganAdapter(
                    model: entry, speculativeDecoding: .off)   // single-model: isolate the quant lever
                try await adapter!.loadModel()
                var total = 0.0
                var bodies: [String] = []
                for (i, p) in prompts.enumerated() {
                    let (body, ms) = try await timed(adapter!, i, p, decodeCap)
                    total += ms
                    if captureBodies { bodies.append(body) }
                }
                let mean = total / Double(prompts.count)
                adapter = nil
                fileLog.emit(String(format: "📊 quant-ab %@ mean_ms=%.0f", label, mean))
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return (mean, bodies)
            } catch {
                fileLog.emit("📊 quant-ab \(label) ERROR=\(error)")
                return (0, [])
            }
        }

        // Bracket: 4-bit pre → 3-bit → 4-bit post (one model resident at a time)。
        let pre = await runModel(fourBit, label: "4bit-pre", captureBodies: true)
        let three = await runModel(threeBit, label: "3bit", captureBodies: true)
        let post = await runModel(fourBit, label: "4bit-post", captureBodies: false)

        let bracket = (pre.meanMs + post.meanMs) / 2
        let driftMs = abs(post.meanMs - pre.meanMs)
        let driftPct = pre.meanMs > 0 ? (post.meanMs - pre.meanMs) / pre.meanMs * 100 : 0
        let speedup = three.meanMs > 0 ? bracket / three.meanMs : 0
        let verdict = (three.meanMs > 0 && three.meanMs < (bracket - driftMs))
            ? "SPEED-WIN" : "SPEED-INCONCLUSIVE-WITHIN-DRIFT"
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
