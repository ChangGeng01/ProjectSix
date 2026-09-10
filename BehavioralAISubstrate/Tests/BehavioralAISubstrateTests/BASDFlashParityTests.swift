import XCTest
import MLX
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import MLXLLM
import Tokenizers
#endif

/// M1 tail-closure — DFlash prose-acceptance parity probe, Swift half (BAS_DFLASH_PARITY=1, Mac).
///
/// Gate-b saw Swift LIVE prose accept ≈ half of the Python reference. Confounds: (a) fp16-vs-bf16
/// stream divergence (different TEXT was being drafted), (b) a real port/numerics gap. The Python
/// half (Tools/dflash_proto/parity_stream.py) dumped its greedy stream gt + its own teacher-forced
/// per-block accepts. Here we teacher-force the SAME gt through the Swift drafter with identical
/// block semantics (anchor=gt[j], 15 drafts vs gt[j+1..j+15], ctx = taps of positions < P,
/// stride 16) and measure the two stacks' native-stream divergence point.
///
///   Swift ≈ Python accepts on the SAME stream  ⇒ port exonerated; Gate-b gap = stream effect.
///   Residual same-stream gap                    ⇒ real numerics finding (recorded, M1 stays closed).
final class BASDFlashParityTests: XCTestCase {

    private struct Stream: Decodable {
        let tag: String, prompt: String
        let ids: [Int], gt: [Int]
        let py_accepts_bf16: [Int], py_accepts_q4: [Int]
    }

    func testTeacherForcedParity() async throws {
        guard ProcessInfo.processInfo.environment["BAS_DFLASH_PARITY"] == "1" else {
            throw XCTSkip("set BAS_DFLASH_PARITY=1 (Mac, heavy — loads Qwen3.5-4B + DFlash drafter)")
        }
        #if canImport(MLXLLM)
        let streamURL = URL(fileURLWithPath: "/tmp/gdn_coreai/dflash_parity_stream.json")
        let drafterURL = URL(fileURLWithPath: "/tmp/gdn_coreai/dflash_draft_fp16.safetensors")
        guard FileManager.default.fileExists(atPath: streamURL.path),
              FileManager.default.fileExists(atPath: drafterURL.path) else {
            throw XCTSkip("run Tools/dflash_proto/parity_stream.py first (needs stream JSON + drafter)")
        }
        let streams = try JSONDecoder().decode([Stream].self, from: Data(contentsOf: streamURL))
        XCTAssertFalse(streams.isEmpty, "empty stream dump")

        MLX.Memory.cacheLimit = 512 * 1024 * 1024
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        struct Row: Sendable {
            let tag: String, swiftAccepts: [Int], divergeAt: Int, gtLen: Int
        }
        let rows: [Row] = try await container.perform { ctx -> [Row] in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let decoder = try BASQwen35DFlashDecoder(model: qwen, draftWeightsURL: drafterURL)
            let block = BASQwen35DFlashDecoder.blockSize
            var out: [Row] = []
            for s in streams {
                let full = s.ids + s.gt
                // ONE tapped batch forward over prompt+gt — causal ⇒ decode-identical features.
                let cache = qwen.newCache(parameters: nil)
                let (_, taps) = qwen.hiddenStatesWithTaps(
                    MLXArray(full.map(Int32.init)).expandedDimensions(axis: 0),
                    cache: cache, tapLayers: BASQwen35DFlashDecoder.tapLayers)
                for t in taps { eval(t) }
                var accepts: [Int] = []
                for j in stride(from: 0, to: s.gt.count - block, by: block) {
                    let P = s.ids.count + j
                    decoder.resetStream()
                    decoder.appendCtx(taps: taps, fromRow: 0, toRow: P)
                    let ds = decoder.draftBlock(
                        anchor: MLXArray(Int32(full[P])), blockStart: P).asArray(Int32.self)
                    var acc = 0
                    for (a, b) in zip(ds.map(Int.init), s.gt[(j + 1) ..< (j + block)]) {
                        guard a == b else { break }
                        acc += 1
                    }
                    accepts.append(acc)
                }
                // Native-stream divergence: THIS stack's greedy continuation vs the Python gt.
                let cache2 = qwen.newCache(parameters: nil)
                let h0 = qwen.hiddenStatesWithCache(
                    MLXArray(s.ids.map(Int32.init)).expandedDimensions(axis: 0), cache: cache2)
                var tok = argMax(qwen.logits(fromHidden: h0)[0, h0.dim(1) - 1], axis: -1)
                    .item(Int.self)
                var native: [Int] = [tok]
                while native.count < s.gt.count {
                    let h = qwen.hiddenStatesWithCache(
                        MLXArray([Int32(tok)]).expandedDimensions(axis: 0), cache: cache2)
                    tok = argMax(qwen.logits(fromHidden: h)[0, 0], axis: -1).item(Int.self)
                    native.append(tok)
                }
                let diverge = zip(native, s.gt).prefix(while: ==).count
                out.append(Row(tag: s.tag, swiftAccepts: accepts,
                               divergeAt: diverge, gtLen: s.gt.count))
            }
            return out
        }
        for (s, r) in zip(streams, rows) {
            func mean(_ a: [Int]) -> Double { Double(a.reduce(0, +)) / Double(max(1, a.count)) }
            print(String(format:
                "[parity-swift] %-6@ %-36@ swift=%.2f pyq4=%.2f pybf16=%.2f diverge@%d/%d",
                r.tag, String(s.prompt.prefix(36)), mean(r.swiftAccepts),
                mean(s.py_accepts_q4), mean(s.py_accepts_bf16), r.divergeAt, r.gtLen))
            print("[parity-swift]   blocks swift=\(r.swiftAccepts) pyq4=\(s.py_accepts_q4)")
            XCTAssertEqual(r.swiftAccepts.count, s.py_accepts_q4.count, "block grid mismatch")
        }
        let sMean = rows.flatMap(\.swiftAccepts).reduce(0, +)
        let pMean = streams.flatMap(\.py_accepts_q4).reduce(0, +)
        print("[parity-swift] TOTAL same-stream accepted: swift=\(sMean) py_q4=\(pMean)")
        XCTAssertGreaterThan(sMean, 0, "swift drafter produced zero accepts — plumbing broke")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
