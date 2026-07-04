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

/// M1 GATE-c — DFlash device final verdict (TEST_RUNNER_BAS_DFLASH_AB=1, iPhone Air).
///
/// Three arms per prompt, interleaved order per prompt (thermal-drift cancellation):
///   • dflash — BASQwen35DFlashDecoder (block-16, drafter q4, full quantized vocab head)
///   • mtp    — the PRODUCTION .mtpSpec lane (generateSpecKFused K=3/tCap=5/adaptiveK)
///   • plain  — the greedy baseline
/// The REAL question: does DFlash beat the SHIPPED lane on device (Mac Gate-b: 1.14-2.61× vs
/// plain; device verify T=16 always rides the qmm regime — the cliff paid once per ~3-7 tokens).
/// Verdict read from the printed table; assertions are plumbing-level.
final class BASDFlashDeviceTests: XCTestCase {

    private static let prompts: [(tag: String, q: String)] = [
        ("reason", "How many prime numbers are there between 10 and 50? Think step by step."),
        ("prose", "Describe a quiet morning in a mountain village."),
        ("reason", "What is 23 multiplied by 17? Show your reasoning."),
        ("prose", "Explain what a tide pool is to a curious child."),
        ("reason", "If today is Wednesday, what day of the week will it be 100 days from now? Explain."),
        ("prose", "Write a short paragraph about why libraries matter."),
    ]

    private struct Row: Sendable {
        let tag: String, arm: String
        let tokens: Int, accepted: Int, iters: Int
        let seconds: Double
    }

    func testDFlashDeviceAB() async throws {
        guard ProcessInfo.processInfo.environment["BAS_DFLASH_AB"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_DFLASH_AB=1 (device; loads Qwen3.5-4B + MTP + DFlash)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localDir = docs.appendingPathComponent("models/Qwen3.5-4B-4bit")
        let dURL = docs.appendingPathComponent("dflash_draft_fp16.safetensors")
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: dURL.path) else {
            throw XCTSkip("DFlash drafter not staged at Documents/dflash_draft_fp16.safetensors")
        }
        // Jetsam discipline (take-1/2 kills: per-process-limit at 6.29GB): cap the MLX free-buffer
        // pool exactly as production loadModel does (ADR-038 — uncapped it grows to the memory
        // limit under the per-cycle ctx-concat churn), and keep ONE decoder resident at a time.
        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })

        final class DecoderBox: @unchecked Sendable {
            var d: BASQwen35DFlashDecoder?
            var m: BASQwen35MTPSpecDecoder?
        }
        let box = DecoderBox()

        var rows: [Row] = []
        for (i, item) in Self.prompts.enumerated() {
            let arms = i % 2 == 0 ? ["plain", "mtp", "dflash"] : ["dflash", "plain", "mtp"]
            for arm in arms {
                let input = try await container.prepare(input: UserInput(chat: [.user(item.q)]))
                let r: Row = try await container.perform(nonSendable: input) { ctx, input in
                    guard let qwen = ctx.model as? Qwen35Model else {
                        throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                    }
                    var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                    if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                    let ids = input.text.tokens.asArray(Int.self)
                    let run: BASQwen35MTPSpecDecoder.Run
                    switch arm {
                    case "dflash":
                        if box.d == nil {                                   // one decoder resident
                            box.m = nil
                            MLX.GPU.clearCache()
                            box.d = try BASQwen35DFlashDecoder(model: qwen, draftWeightsURL: dURL)
                        }
                        run = box.d!.generateDFlash(prompt: ids, maxTokens: 256, eosTokens: eos)
                    default:
                        if box.m == nil {
                            box.d = nil
                            MLX.GPU.clearCache()
                            box.m = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                        }
                        if arm == "mtp" {
                            run = box.m!.generateSpecKFused(
                                prompt: ids, maxTokens: 256, eosTokens: eos,
                                k: MLXOrganAdapter.mtpProductionK,
                                tCap: MLXOrganAdapter.mtpProductionTCap, adaptiveK: true)
                        } else {
                            run = box.m!.generatePlain(prompt: ids, maxTokens: 256)
                        }
                    }
                    return Row(tag: item.tag, arm: arm, tokens: run.tokens.count,
                               accepted: run.accepted, iters: run.iterations,
                               seconds: run.decodeSeconds)
                }
                rows.append(r)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                MLX.GPU.clearCache()
            }
        }

        for r in rows {
            let acc = r.iters > 0 ? Double(r.accepted) / Double(r.iters) : 0
            print(String(format: "[dflash-c] %@ arm=%@ tokens=%d acc/cycle=%.2f tok/s=%.1f t=%.1fs",
                         r.tag, r.arm, r.tokens, acc,
                         Double(r.tokens) / max(r.seconds, 0.001), r.seconds))
        }
        for tag in ["reason", "prose", nil] as [String?] {
            let sel = rows.filter { tag == nil || $0.tag == tag }
            func tps(_ arm: String) -> Double {
                let g = sel.filter { $0.arm == arm }
                return Double(g.map(\.tokens).reduce(0, +)) / max(g.map(\.seconds).reduce(0, +), 0.001)
            }
            let d = tps("dflash"), m = tps("mtp"), p = tps("plain")
            print(String(format: "[dflash-c] SUMMARY %@ dflash=%.1f mtp=%.1f plain=%.1f | df/plain=%.2fx df/mtp=%.2fx",
                         tag ?? "ALL", d, m, p, d / max(p, 0.001), d / max(m, 0.001)))
        }
        XCTAssertFalse(rows.isEmpty)
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
