import XCTest
import MLX
import MLXHuggingFace
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
@testable import BASMLXAdapter

/// Gates G1+G2 of the ≥20 tok/s campaign (BAS_MTP_SPEC=1; heavy — loads Qwen3.5-4B).
/// G1 — Swift MTP module fidelity vs the verified python reference (4 KV-carrying steps, exported vectors).
/// G2 — spec-vs-plain on the REAL model: greedy-identity token-for-token + Mac A/B tok/s (device = G3 probe).
final class BASQwen35MTPSpecTests: XCTestCase {

    struct Result: Sendable {
        var minCos: Float = 1
        var plainTokens: [Int] = []
        var specTokens: [Int] = []
        var plainSec = 0.0
        var specSec = 0.0
        var accepted = 0
        var iterations = 0
    }

    func testMTPSpecFidelityAndIdentity() async throws {
        guard ProcessInfo.processInfo.environment["BAS_MTP_SPEC"] == "1" else {
            throw XCTSkip("set BAS_MTP_SPEC=1 (needs /tmp/gdn_coreai/qwen35_mtp_{folded,vectors}.safetensors)")
        }
        let wURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors")
        let vURL = URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_vectors.safetensors")
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit", extraEOSTokens: []),
            progressHandler: { _ in })
        // Everything runs INSIDE the container actor (Qwen35Model is not Sendable); only Result crosses out.
        let r: Result = try await container.perform { ctx -> Result in
            guard let model = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let dec = try BASQwen35MTPSpecDecoder(model: model, mtpWeightsURL: wURL)
            var out = Result()
            // ---- G1 ----
            let vec = try MLX.loadArrays(url: vURL)
            dec.resetMTPStream()
            for t in 0 ..< 4 {
                let e = vec["in_embed_\(t)"]!, hIn = vec["in_hidden_\(t)"]!, ref = vec["out_\(t)"]!
                let o = dec.mtpForward(embedNext: e, hidden: hIn, pos: t).asType(.float32)
                let rr = ref.asType(.float32)
                let cos = (sum(o * rr) / (sqrt(sum(o * o)) * sqrt(sum(rr * rr)))).item(Float.self)
                out.minCos = min(out.minCos, cos)
            }
            // ---- G2 ----
            let prompt: [Int] = [100, 200, 300, 400, 500, 600, 700, 800]
            let n = 48
            let plain = dec.generatePlain(prompt: prompt, maxTokens: n)
            let spec = dec.generateSpec(prompt: prompt, maxTokens: n)
            out.plainTokens = plain.tokens; out.specTokens = spec.tokens
            out.plainSec = plain.decodeSeconds; out.specSec = spec.decodeSeconds
            out.accepted = spec.accepted; out.iterations = spec.iterations
            return out
        }
        print("=== G1 MTP module fidelity: min cos over 4 steps = \(r.minCos) ===")
        XCTAssertGreaterThan(r.minCos, 0.98, "Swift MTP module diverges from the verified reference")
        let same = zip(r.plainTokens, r.specTokens).filter { $0 == $1 }.count
        let total = min(r.plainTokens.count, r.specTokens.count)
        let pTok = Double(r.plainTokens.count) / r.plainSec
        let sTok = Double(r.specTokens.count) / r.specSec
        let a = r.iterations > 0 ? Double(r.accepted) / Double(r.iterations) : 0
        print(String(format: "=== G2 PLAIN %.1f tok/s | SPEC %.1f tok/s = %.2fx | a=%.2f | identity %d/%d ===",
                     pTok, sTok, sTok / pTok, a, same, total))
        XCTAssertEqual(r.plainTokens, r.specTokens, "spec stream must be greedy-identical (byte-safe)")
    }
}
