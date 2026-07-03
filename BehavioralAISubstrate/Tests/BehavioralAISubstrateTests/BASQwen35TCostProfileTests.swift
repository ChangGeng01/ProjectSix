import XCTest
import MLX
import MLXHuggingFace
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
@testable import BASMLXAdapter

/// 30 tok/s campaign — cost-profile isolation: vendored forward T=1..4 + MTP draft + head (BAS_MTP_TCOST=1).
/// The T-cost curve determines BOTH remaining levers (T=2 fast path recovery + K=2 MTP viability).
final class BASQwen35TCostProfileTests: XCTestCase {
    func testTCostProfile() async throws {
        guard ProcessInfo.processInfo.environment["BAS_MTP_TCOST"] == "1" else { throw XCTSkip("BAS_MTP_TCOST=1") }
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit", extraEOSTokens: []),
            progressHandler: { _ in })
        let lines: [String] = try await container.perform { ctx -> [String] in
            guard let model = ctx.model as? Qwen35Model else { throw BASQwen35MTPSpecDecoder.SpecError.notQwen35 }
            let dec = try BASQwen35MTPSpecDecoder(
                model: model, mtpWeightsURL: URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors"))
            var out: [String] = []
            let cache = model.newCache(parameters: nil)
            let prompt = MLXArray([100, 200, 300, 400, 500, 600, 700, 800].map(Int32.init)).expandedDimensions(axis: 0)
            eval(model.hiddenStatesWithCache(prompt, cache: cache))
            func time(_ label: String, reps: Int, _ f: () -> Void) {
                f()                                            // warm
                let t0 = Date()
                for _ in 0 ..< reps { f() }
                out.append(String(format: "%@: %.2f ms", label, Date().timeIntervalSince(t0) * 1000 / Double(reps)))
            }
            for t in 1 ... 4 {
                let toks = MLXArray((0 ..< t).map { Int32(100 + $0) }).expandedDimensions(axis: 0)
                time("trunk T=\(t)", reps: 20) {
                    eval(model.hiddenStatesWithCache(toks, cache: cache))
                }
            }
            let h = model.hiddenStatesWithCache(MLXArray([Int32(42)]).expandedDimensions(axis: 0), cache: cache)
            let hRow = h[0, 0]
            time("head (quantized asLinear)", reps: 20) { eval(model.logits(fromHidden: h)) }
            let emb = model.embedding(MLXArray([Int32(7)]))[0]
            var p = 40
            time("MTP draft (block fp16 + head)", reps: 20) {
                eval(model.logits(fromHidden: dec.mtpForward(embedNext: emb, hidden: hRow, pos: p)
                    .expandedDimensions(axes: [0, 1])))
                p += 1
            }
            return out
        }
        for l in lines { print("=== TCOST \(l) ===") }
    }
}
