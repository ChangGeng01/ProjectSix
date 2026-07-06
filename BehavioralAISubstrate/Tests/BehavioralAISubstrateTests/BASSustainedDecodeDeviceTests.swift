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

/// M4-a — the 10-minute SUSTAINED decode profile of OUR production lane on the Air
/// (TEST_RUNNER_BAS_SUSTAINED=1; matches the rockyshikoku third-party protocol: continuous
/// generation, per-minute throughput). Decides whether an ANE lane project is justified:
/// third-party 17-Pro data says GPU retains 38% at 10 min — but the Air's M2-mirror data
/// suggested ~72%; this measures it cleanly on the PRODUCTION fused-MTP lane.
final class BASSustainedDecodeDeviceTests: XCTestCase {

    func testSustainedTenMinutes() async throws {
        guard ProcessInfo.processInfo.environment["BAS_SUSTAINED"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_SUSTAINED=1 (device; ~11 min continuous)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localDir = docs.appendingPathComponent("models/Qwen3.5-4B-4bit")
        let wURL = docs.appendingPathComponent("qwen35_mtp_folded.safetensors")
        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(directory: localDir, extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let prompts = [
            "Describe a quiet morning in a mountain village.",
            "Explain what a tide pool is to a curious child.",
            "Write a short paragraph about why libraries matter.",
        ]
        struct MinuteBin: Sendable { var tokens = 0; var seconds = 0.0; var thermal = 0 }
        struct S: Sendable { let bins: [MinuteBin]; let gens: Int; let totalTok: Int }
        var inputs: [[Int]] = []
        for q in prompts {
            let inp = try await container.prepare(input: UserInput(chat: [.user(q)]))
            let ids: [Int] = try await container.perform(nonSendable: inp) { _, inp in
                inp.text.tokens.asArray(Int.self)
            }
            inputs.append(ids)
        }
        let inputsFixed = inputs
        let s: S = try await container.perform { ctx -> S in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            var eos = Set([ctx.tokenizer.eosTokenId].compactMap { $0 })
            if let imEnd = ctx.tokenizer.convertTokenToId("<|im_end|>") { eos.insert(imEnd) }
            let dec = try BASQwen35MTPSpecDecoder(model: qwen, mtpWeightsURL: wURL)
            var bins = [MinuteBin](repeating: MinuteBin(), count: 11)
            let t0 = Date()
            var gens = 0, totalTok = 0
            while Date().timeIntervalSince(t0) < 600 {
                let ids = inputsFixed[gens % inputsFixed.count]
                let g0 = Date()
                let run = dec.generateSpecKFused(
                    prompt: ids, maxTokens: 192, eosTokens: eos,
                    k: MLXOrganAdapter.mtpProductionK,
                    tCap: MLXOrganAdapter.mtpProductionTCap, adaptiveK: true)
                let dt = Date().timeIntervalSince(g0)
                let minute = min(10, Int(Date().timeIntervalSince(t0) / 60))
                bins[minute].tokens += run.tokens.count
                bins[minute].seconds += dt
                bins[minute].thermal = max(bins[minute].thermal,
                                           ProcessInfo.processInfo.thermalState.rawValue)
                gens += 1
                totalTok += run.tokens.count
            }
            return S(bins: bins, gens: gens, totalTok: totalTok)
        }
        var first = 0.0
        for (i, b) in s.bins.enumerated() where b.seconds > 1 {
            let tps = Double(b.tokens) / b.seconds
            if first == 0 { first = tps }
            print(String(format: "[sustained] min=%02d tok/s=%.1f thermal=%d retention=%.0f%%",
                         i, tps, b.thermal, tps / first * 100))
        }
        print("[sustained] TOTAL gens=\(s.gens) tokens=\(s.totalTok) over 10min")
        XCTAssertGreaterThan(s.gens, 10)
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
