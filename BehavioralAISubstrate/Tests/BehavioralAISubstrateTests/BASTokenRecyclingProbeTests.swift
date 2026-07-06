import XCTest
import MLX
import BASOrgan
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import MLXLLM
import Tokenizers
#endif

/// TR-R0/R1 gate (BAS_TR_PROBE_TEST=1, Mac, heavy). Run TWICE:
///   BAS_TR_PROBE_TEST=1 BAS_TR_PROBE=1 BAS_MTP_FUSED_DEBUG=1  → acceptance stats + probed timing
///   BAS_TR_PROBE_TEST=1 BAS_MTP_FUSED_DEBUG=1                 → baseline timing (R0 comparison)
/// The probe is observation-only (emissions untouched); per-link [tr-probe] lines are the R1 data:
/// TR-hit vs MTP-hit on the SAME rows with the SAME truths, per chain position.
final class BASTokenRecyclingProbeTests: XCTestCase {

    func testRecyclingCounterfactualAcceptance() async throws {
        guard ProcessInfo.processInfo.environment["BAS_TR_PROBE_TEST"] == "1" else {
            throw XCTSkip("set BAS_TR_PROBE_TEST=1 (+BAS_TR_PROBE=1 for the probed arm; heavy)")
        }
        #if canImport(MLXLLM)
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        guard FileManager.default.fileExists(atPath: wURL.path) else {
            throw XCTSkip("MTP weights missing at /tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        }
        // The device harness prompt families (reason + prose + factual — prose is the wall).
        let prompts = [
            "How many prime numbers are there between 10 and 50? Think step by step.",
            "Describe a quiet morning in a mountain village.",
            "What is 23 multiplied by 17? Show your reasoning.",
            "Explain what a tide pool is to a curious child.",
            "Write a short paragraph about why libraries matter.",
            "If today is Wednesday, what day of the week will it be 100 days from now? Explain.",
        ]
        struct R: Sendable { let tag: String; let tokens: Int; let secs: Double; let accepted: Int; let rounds: Int }
        var rows: [R] = []
        for (i, q) in prompts.enumerated() {
            let input = try await container.prepare(input: UserInput(chat: [.user(q)]))
            let r: R = try await container.perform(nonSendable: input) { ctx, input in
                guard let qwen = ctx.model as? Qwen35Model else {
                    throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
                }
                let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
                var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
                if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
                let ids = input.text.tokens.asArray(Int.self)
                let run = dec.generateSpecKFused(
                    prompt: ids, maxTokens: 192, eosTokens: eos,
                    k: 3, tCap: BASQwen35MTPSpecDecoder.maxSeq > 0 ? 12 : 12, adaptiveK: true)
                return R(tag: "p\(i)", tokens: run.tokens.count, secs: run.decodeSeconds,
                         accepted: run.accepted, rounds: run.iterations)
            }
            print(String(format: "[tr-gate] %@ tok=%d %.1f tok/s a/round=%.2f",
                         r.tag, r.tokens, Double(r.tokens) / max(r.secs, 0.001),
                         Double(r.accepted) / Double(max(1, r.rounds))))
            rows.append(r)
        }
        let total = rows.reduce(0) { $0 + $1.tokens }
        let secs = rows.reduce(0.0) { $0 + $1.secs }
        print(String(format: "[tr-gate] TOTAL tok=%d %.1f tok/s probe=%@",
                     total, Double(total) / max(secs, 0.001),
                     ProcessInfo.processInfo.environment["BAS_TR_PROBE"] == "1" ? "ON" : "OFF"))
        XCTAssertGreaterThan(total, 500, "harness produced too little text to judge")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
