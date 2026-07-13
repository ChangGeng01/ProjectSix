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

/// M2 device sub-gate (TEST_RUNNER_BAS_DWQ3_AB=1, iPhone Air) — DWQ-3bit trunk vs the production
/// 4-bit trunk. Mac gate already PASSED quality (paired parity within noise) and 1.17× speed;
/// the device question is how much of the 1.66× weight-ratio the bandwidth-bound A19 realizes,
/// on BOTH lanes: plain greedy AND the production fused-MTP (does the folded head still pay on a
/// 3-bit trunk?).
///
/// Order: 4-bit FIRST (incumbent), 3-bit second — thermal drift then UNDERSTATES the 3-bit
/// (conservative direction for the claim). One container resident at a time (jetsam discipline).
final class BASDWQ3DeviceTests: XCTestCase {

    private static let prompts = [
        "Describe a quiet morning in a mountain village.",
        "How many prime numbers are there between 10 and 50? Think step by step.",
        "Explain what a tide pool is to a curious child.",
    ]

    private struct Row: Sendable {
        let model: String, lane: String
        let tokens: Int, accepted: Int, iters: Int
        let seconds: Double
    }

    func testDWQ3DeviceAB() async throws {
        guard ProcessInfo.processInfo.environment["BAS_DWQ3_AB"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_DWQ3_AB=1 (device; loads both trunks sequentially)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        // Take-1 lesson: block order = thermal order (the second block runs hot — its aggregate
        // is an artifact). BAS_DWQ3_ORDER=reverse mirrors the order; cool-block vs cool-block
        // across the two runs is the honest comparison.
        var variants: [(tag: String, dir: String)] = [
            ("4bit", "models/Qwen3.5-4B-4bit"),
            ("dwq3", "models/Qwen3.5-4B-dwq3"),
        ]
        if ProcessInfo.processInfo.environment["BAS_DWQ3_ORDER"] == "reverse" {
            variants.reverse()
        }
        for v in variants {
            let dir = docs.appendingPathComponent(v.dir)
            guard FileManager.default.fileExists(atPath: dir.path) else {
                throw XCTSkip("\(v.dir) not staged")
            }
        }
        MLX.Memory.cacheLimit = 512 * 1024 * 1024

        var rows: [Row] = []
        for v in variants {
            let container = try await #huggingFaceLoadModelContainer(
                configuration: ModelConfiguration(
                    directory: docs.appendingPathComponent(v.dir),
                    extraEOSTokens: ["<|im_end|>"]),
                progressHandler: { _ in })
            for (i, q) in Self.prompts.enumerated() {
                let lanes = i % 2 == 0 ? ["plain", "mtp"] : ["mtp", "plain"]
                for lane in lanes {
                    let input = try await container.prepare(input: UserInput(chat: [.user(q)]))
                    let r: Row = try await container.perform(nonSendable: input) { ctx, input in
                        guard let qwen = ctx.model as? Qwen35Model else {
                            throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                        }
                        var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                        if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                        let ids = input.text.tokens.asArray(Int.self)
                        let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                        let run = lane == "mtp"
                            ? dec.generateSpecKFused(
                                prompt: ids, maxTokens: 192, eosTokens: eos,
                                k: MLXOrganAdapter.mtpProductionK,
                                tCap: MLXOrganAdapter.mtpProductionTCap, adaptiveK: true)
                            : dec.generatePlain(prompt: ids, maxTokens: 192)
                        return Row(model: v.tag, lane: lane, tokens: run.tokens.count,
                                   accepted: run.accepted, iters: run.iterations,
                                   seconds: run.decodeSeconds)
                    }
                    rows.append(r)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    MLX.Memory.clearCache()
                }
            }
            // Release this trunk fully before the next (per-process limit discipline).
            MLX.Memory.clearCache()
        }

        for r in rows {
            let acc = r.iters > 0 ? Double(r.accepted) / Double(r.iters) : 0
            print(String(format: "[dwq3] model=%@ lane=%@ tokens=%d acc/iter=%.2f tok/s=%.1f t=%.1fs",
                         r.model, r.lane, r.tokens, acc,
                         Double(r.tokens) / max(r.seconds, 0.001), r.seconds))
        }
        for lane in ["plain", "mtp"] {
            func tps(_ m: String) -> Double {
                let g = rows.filter { $0.model == m && $0.lane == lane }
                return Double(g.map(\.tokens).reduce(0, +)) / max(g.map(\.seconds).reduce(0, +), 0.001)
            }
            let b4 = tps("4bit"), d3 = tps("dwq3")
            print(String(format: "[dwq3] SUMMARY lane=%@ 4bit=%.1f dwq3=%.1f ratio=%.2fx",
                         lane, b4, d3, d3 / max(b4, 0.001)))
        }
        XCTAssertFalse(rows.isEmpty)
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
