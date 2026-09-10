import XCTest
import MLX
import MLXHuggingFace
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
@testable import BASMLXAdapter

final class BASQwen35MTPIdentityDiagTests: XCTestCase {
    func testIdentityDiag() async throws {
        guard ProcessInfo.processInfo.environment["BAS_MTP_DIAG"] == "1" else { throw XCTSkip("BAS_MTP_DIAG=1") }
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit", extraEOSTokens: []),
            progressHandler: { _ in })
        let lines: [String] = try await container.perform { ctx -> [String] in
            guard let model = ctx.model as? Qwen35Model else { throw BASQwen35MTPSpecDecoder.SpecError.notQwen35 }
            let dec = try BASQwen35MTPSpecDecoder(
                model: model, mtpWeightsURL: URL(fileURLWithPath: "/tmp/gdn_coreai/qwen35_mtp_folded.safetensors"))
            let prompt: [Int] = [100, 200, 300, 400, 500, 600, 700, 800]
            let n = 40
            let plain = dec.generatePlain(prompt: prompt, maxTokens: n)
            dec.forceRejectForDiagnostics = true
            let forced = dec.generateSpec(prompt: prompt, maxTokens: n)
            dec.forceRejectForDiagnostics = false
            let spec = dec.generateSpec(prompt: prompt, maxTokens: n)
            func firstDiv(_ a: [Int], _ b: [Int]) -> String {
                for i in 0 ..< min(a.count, b.count) where a[i] != b[i] {
                    let lo = max(0, i - 2), hiA = min(a.count, i + 3), hiB = min(b.count, i + 3)
                    return "div@\(i): plain\(Array(a[lo ..< hiA])) vs \(Array(b[lo ..< hiB]))"
                }
                return a.count == b.count ? "IDENTICAL" : "prefix-identical, len \(a.count) vs \(b.count)"
            }
            return ["FORCED-REJECT vs plain: \(firstDiv(plain.tokens, forced.tokens)) (iters=\(forced.iterations))",
                    "NORMAL-SPEC   vs plain: \(firstDiv(plain.tokens, spec.tokens)) (a=\(forced.iterations > 0 ? Double(spec.accepted) / Double(spec.iterations) : 0))"]
        }
        for l in lines { print("=== DIAG \(l) ===") }
    }
}
