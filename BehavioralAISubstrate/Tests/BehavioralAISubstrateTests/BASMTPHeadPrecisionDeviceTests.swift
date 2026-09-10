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

/// M3 原生 MTP 头 A/B (TEST_RUNNER_BAS_MTP_HEAD_AB=1) — the production lane quantizes the native
/// MTP head to 4-bit at init (bandwidth: fp16 240MB ≈ 4.8ms/draft vs ≈1.2ms). The A/B asks the
/// FRONTIER_2026H2 M3 question: does 4-bit quantization of the head cost ACCEPTANCE, and would the
/// fp16 head's α gain pay its ~3× draft-bandwidth tax end-to-end?
///
/// Metrics per arm (production shape: fused K=3, tCap=5, adaptiveK): acc/iter, E[tok]/iter, tok/s.
/// 6 prompts = 3 reasoning (high-acceptance thinking traces) + 3 prose (the a/iter≈1.0 regime);
/// arm order alternates per prompt (thermal-drift cancellation). Verdict read from the table.
final class BASMTPHeadPrecisionDeviceTests: XCTestCase {

    private static let prompts: [(tag: String, q: String)] = [
        ("reason", "How many prime numbers are there between 10 and 50? Think step by step."),
        ("reason", "A train travels 60 km in 45 minutes. What is its speed in km/h? Show your reasoning."),
        ("reason", "If today is Wednesday, what day of the week will it be 100 days from now? Explain."),
        ("prose", "Describe a quiet morning in a mountain village."),
        ("prose", "Write a short paragraph about why libraries matter."),
        ("prose", "Explain what a tide pool is to a curious child."),
    ]

    private struct Row: Sendable {
        let tag: String
        let arm: String            // "q4" | "fp16"
        let tokens: Int
        let accepted: Int
        let iters: Int
        let seconds: Double
    }

    func testHeadPrecisionAB() async throws {
        guard ProcessInfo.processInfo.environment["BAS_MTP_HEAD_AB"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_MTP_HEAD_AB=1 (device; loads Qwen3.5-4B + MTP weights ×2)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localDir = docs.appendingPathComponent("models/Qwen3.5-4B-4bit")
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: wURL.path) else {
            throw XCTSkip("MTP weights not staged")
        }
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })

        var rows: [Row] = []
        for (i, item) in Self.prompts.enumerated() {
            let order = i % 2 == 0 ? ["q4", "fp16"] : ["fp16", "q4"]
            for arm in order {
                let input = try await container.prepare(input: UserInput(chat: [.user(item.q)]))
                let r: Row = try await container.perform(nonSendable: input) { ctx, input in
                    guard let qwen = ctx.model as? Qwen35Model else {
                        throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                    }
                    // Fresh decoder per run: chainEmaL must not leak between arms (the adaptive-K
                    // regime EMA is itself acceptance-derived — shared state would contaminate).
                    let dec = try BASQwen35MTPSpecDecoder(
                        model: qwen, mtpWeightsURL: wURL, headFP16: arm == "fp16")
                    var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                    if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                    let promptIds = input.text.tokens.asArray(Int.self)
                    let run = dec.generateSpecKFused(
                        prompt: promptIds, maxTokens: 256, eosTokens: eos,
                        k: MLXOrganAdapter.mtpProductionK,
                        tCap: MLXOrganAdapter.mtpProductionTCap, adaptiveK: true)
                    return Row(tag: item.tag, arm: arm, tokens: run.tokens.count,
                               accepted: run.accepted, iters: run.iterations,
                               seconds: run.decodeSeconds)
                }
                rows.append(r)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                MLX.Memory.clearCache()
            }
        }

        for r in rows {
            let aPerIter = r.iters > 0 ? Double(r.accepted) / Double(r.iters) : 0
            let eTok = r.iters > 0 ? Double(r.tokens) / Double(r.iters) : 0
            print(String(format: "[head-ab] %@ arm=%@ tokens=%d acc/iter=%.2f E[tok]/iter=%.2f tok/s=%.1f t=%.1fs",
                         r.tag, r.arm, r.tokens, aPerIter, eTok,
                         Double(r.tokens) / max(r.seconds, 0.001), r.seconds))
        }
        for tag in ["reason", "prose", nil] as [String?] {
            let sel = rows.filter { tag == nil || $0.tag == tag }
            func agg(_ arm: String) -> (a: Double, e: Double, tps: Double) {
                let g = sel.filter { $0.arm == arm }
                let it = g.map(\.iters).reduce(0, +)
                let tk = g.map(\.tokens).reduce(0, +)
                let sec = g.map(\.seconds).reduce(0, +)
                return (Double(g.map(\.accepted).reduce(0, +)) / Double(max(1, it)),
                        Double(tk) / Double(max(1, it)), Double(tk) / max(sec, 0.001))
            }
            let q4 = agg("q4"), fp = agg("fp16")
            print(String(format: "[head-ab] SUMMARY %@ q4: acc/iter=%.2f E[tok]=%.2f tok/s=%.1f | fp16: acc/iter=%.2f E[tok]=%.2f tok/s=%.1f | Δacc=%+.2f Δtok/s=%+.1f",
                         tag ?? "ALL", q4.a, q4.e, q4.tps, fp.a, fp.e, fp.tps,
                         fp.a - q4.a, fp.tps - q4.tps))
        }
        XCTAssertFalse(rows.isEmpty)
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
