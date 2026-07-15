import XCTest
import MLX
import MLXNN
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import MLXLLM
import Tokenizers
#endif

/// B1-a — the MEASURE gate before any fused-kernel work (BAS_DECODE_FLOOR=1; Mac and device).
///
/// Decomposes one decode token's wall time into:
///   • FLOOR — a pure qmv sweep over every QuantizedLinear in the trunk (all weight bytes read
///     once, MLX-pipelined, batch-1 activations): the achievable weight-read time inside MLX.
///   • ACTUAL — a real single-token decode step (warm ~128-token cache).
/// ACTUAL − FLOOR = the fusion-addressable overhead (graph glue, intermediates, small non-matmul
/// kernels, sync). The implied ceiling (1/FLOOR) is the honest B1 prize; if the gap is small,
/// B1 re-scopes before any Metal is written.
final class BASDecodeFloorTests: XCTestCase {

    func testDecodeFloorVsActual() async throws {
        guard ProcessInfo.processInfo.environment["BAS_DECODE_FLOOR"] == "1" else {
            throw XCTSkip("set BAS_DECODE_FLOOR=1 (heavy — loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        #if os(iOS)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let config = ModelConfiguration(
            directory: docs.appendingPathComponent("models/Qwen3.5-4B-4bit"),
            extraEOSTokens: ["<|im_end|>"])
        #else
        let config = ModelConfiguration(
            id: "mlx-community/Qwen3.5-4B-4bit", extraEOSTokens: ["<|im_end|>"])
        #endif
        let container = try await #huggingFaceLoadModelContainer(
            configuration: config, progressHandler: { _ in })
        struct R: Sendable {
            let nLinears: Int
            let weightGB: Double
            let floorMs: Double
            let actualMs: Double
            let headMs: Double
            let rawGBs: Double
        }
        let r: R = try await container.perform { ctx -> R in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            // ---- collect every QuantizedLinear + a matching dummy activation ----
            var linears: [(QuantizedLinear, MLXArray)] = []
            var weightBytes = 0
            for m in qwen.modules() {                                // recursive walk
                if let ql = m as? QuantizedLinear {
                    let inDim = ql.weight.dim(0) > 0 ? ql.scales.dim(1) * ql.groupSize : 0
                    // input dim from packed shape: weight [out, in/8] uint32 for 4-bit
                    let realIn = ql.weight.dim(1) * 32 / ql.bits
                    let x = MLXArray.ones([1, realIn]).asType(.float16)
                    linears.append((ql, x))
                    weightBytes += ql.weight.size * 4 + ql.scales.size * 2
                        + (ql.biases.map { $0.size * 2 } ?? 0)
                    _ = inDim
                }
            }
            // ---- FLOOR: qmv sweep over all linears + the tied lm-head read (the decode step
            // projects through embed-as-linear every token — 318MB that must count) ----
            let headX = MLXArray.ones([1, 1, 2560]).asType(.float16)
            func sweep() {
                var acc: [MLXArray] = []
                for (ql, x) in linears { acc.append(ql(x)) }
                acc.append(qwen.logits(fromHidden: headX))   // tied lm-head read (public surface)
                eval(acc)
            }
            for _ in 0 ..< 4 { sweep() }
            let tF = Date()
            let reps = 32
            for _ in 0 ..< reps { sweep() }
            let floorMs = Date().timeIntervalSince(tF) * 1000 / Double(reps)
            // ---- ACTUAL: warm-cache single-token decode steps ----
            let cache = qwen.newCache(parameters: nil)
            let warm = qwen.hiddenStatesWithCache(
                MLXArray((0 ..< 128).map { Int32(100 + $0) }).expandedDimensions(axis: 0),
                cache: cache)
            eval(warm)
            var tok = 42
            for _ in 0 ..< 4 {                                        // warmup steps
                let h = qwen.hiddenStatesWithCache(
                    MLXArray([Int32(tok)]).expandedDimensions(axis: 0), cache: cache)
                tok = argMax(qwen.logits(fromHidden: h)[0, 0], axis: -1).item(Int.self)
            }
            let tA = Date()
            let steps = 48
            for _ in 0 ..< steps {
                let h = qwen.hiddenStatesWithCache(
                    MLXArray([Int32(tok)]).expandedDimensions(axis: 0), cache: cache)
                tok = argMax(qwen.logits(fromHidden: h)[0, 0], axis: -1).item(Int.self)
            }
            let actualMs = Date().timeIntervalSince(tA) * 1000 / Double(steps)
            // ---- HEAD probe: ONE large qmv (tied lm-head ≈318MB) → effective GB/s on this
            // device → analytic bandwidth floor = totalBytes / effBW (the dispatch-free floor
            // the naive 248-op sweep cannot measure on dispatch-bound hardware) ----
            for _ in 0 ..< 3 { eval(qwen.logits(fromHidden: headX)) }
            let tH = Date()
            let hReps = 24
            for _ in 0 ..< hReps { eval(qwen.logits(fromHidden: headX)) }
            let headMs = Date().timeIntervalSince(tH) * 1000 / Double(hReps)
            // ---- RAW-BW probe: pure reduction over 1GB fp16 (near-memcpy efficiency) — the
            // hardware's achievable read bandwidth, settling whether ~42GB/s is a kernel
            // deficiency (B1 prize real) or the Air's silicon wall (B1 re-scopes) ----
            let big = MLXArray.ones([512, 1024, 1024]).asType(.float16)   // 1.07GB
            eval(big)
            for _ in 0 ..< 2 { eval(big.sum()) }
            let tB = Date()
            let bReps = 8
            for _ in 0 ..< bReps { eval(big.sum()) }
            let rawMs = Date().timeIntervalSince(tB) * 1000 / Double(bReps)
            return R(nLinears: linears.count, weightGB: Double(weightBytes) / 1e9,
                     floorMs: floorMs, actualMs: actualMs, headMs: headMs,
                     rawGBs: 1.073 / (rawMs / 1000))
        }
        let headGB = 248320.0 * 2560 * 0.5625 / 1e9              // q4 packed + scales ≈ 0.36GB
        let effBW = headGB / (r.headMs / 1000)
        let totalGB = r.weightGB + headGB
        let bwFloorMs = totalGB / effBW * 1000
        print(String(format: "=== B1a linears=%d weights=%.2fGB sweep=%.1fms actual=%.1fms | head=%.2fms → qmvBW=%.0fGB/s | rawBW=%.0fGB/s | trueFloor=%.1fms → true-ceiling %.1f tok/s (addressable %.0f%%) ===",
                     r.nLinears, r.weightGB, r.floorMs, r.actualMs, r.headMs, effBW, r.rawGBs,
                     totalGB / r.rawGBs * 1000, r.rawGBs / totalGB,
                     (r.actualMs - totalGB / r.rawGBs * 1000) / r.actualMs * 100))
        XCTAssertGreaterThan(r.nLinears, 100, "linear census failed")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
