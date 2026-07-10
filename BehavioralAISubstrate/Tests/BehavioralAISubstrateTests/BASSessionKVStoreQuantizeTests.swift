import XCTest
import MLX
import MLXLMCommon
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLLM

/// device-recon id9 — teeth for the Q4-shrink EFFECT of the spill-quantize path.
/// The DECISION (quantize iff headroom ≤ 0.10) is pinned in BASSpillQuantizeTests;
/// this pins that `quantizeKV: true` actually PRODUCES a materially smaller, still-
/// restorable KV snapshot than fp16. Before this, "the memory effect is device-
/// verified" lived only in a comment — a `save()` that silently ignored `quantizeKV`
/// would have passed every existing test. Runs on the Mac MLX GPU; the same recipe
/// is A19-device-certified by BASSpillQuantizeProbe.
///
/// The file size is STRUCTURAL (4 bits/elem + group scales vs 16-bit fp16), i.e.
/// value-independent, so zero-filled KV is a faithful stand-in for real KV here.
final class BASSessionKVStoreQuantizeTests: XCTestCase {

    /// A pure-attention (KVCacheSimple) cache — only these layers quantize (GDN /
    /// ArraysCache layers pass through fp16), which is exactly the id9 contract.
    private func attentionCache(layers: Int, kvHeads: Int, headDim: Int, tokens: Int) -> [KVCache] {
        (0..<layers).map { _ in
            let fa = KVCacheSimple()
            if tokens > 0 {
                let k = MLXArray.zeros([1, kvHeads, tokens, headDim]).asType(.float16)
                let v = MLXArray.zeros([1, kvHeads, tokens, headDim]).asType(.float16)
                _ = fa.update(keys: k, values: v)
            }
            return fa
        }
    }

    private func tmpURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("bas_kv_q4_\(UUID().uuidString).safetensors")
    }

    func testQuantizeKVProducesMateriallySmallerFileThanFp16() throws {
        let fp16URL = tmpURL(); let q4URL = tmpURL()
        defer {
            try? FileManager.default.removeItem(at: fp16URL)
            try? FileManager.default.removeItem(at: q4URL)
        }
        let T = 128
        let size16 = try BASSessionKVStore.save(
            cache: attentionCache(layers: 8, kvHeads: 8, headDim: 128, tokens: T),
            tokenCount: T, to: fp16URL, modelID: "m", quantizeKV: false)
        let sizeQ4 = try BASSessionKVStore.save(
            cache: attentionCache(layers: 8, kvHeads: 8, headDim: 128, tokens: T),
            tokenCount: T, to: q4URL, modelID: "m", quantizeKV: true)

        XCTAssertGreaterThan(size16, 0)
        XCTAssertGreaterThan(sizeQ4, 0)
        // 4 bits vs 16 ⇒ the KV tensors are ~4× smaller; allow generous overhead
        // (group scales/biases + safetensors header). The discriminating bar: Q4 is
        // MATERIALLY smaller. A save() that ignored quantizeKV would tie here (red).
        XCTAssertLessThan(Double(sizeQ4), 0.6 * Double(size16),
            "Q4 spill (\(sizeQ4)B) must be materially smaller than fp16 (\(size16)B) — the id9 transient-shrink")
    }

    func testQuantizedSnapshotStillRestores() throws {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let T = 96
        _ = try BASSessionKVStore.save(
            cache: attentionCache(layers: 4, kvHeads: 8, headDim: 128, tokens: T),
            tokenCount: T, to: url, modelID: "m", quantizeKV: true)
        // A Q4 snapshot must warm-restore into a fresh same-shape cache (round-trip),
        // returning the persisted token count — a quantized spill that couldn't be
        // read back would defeat park-under-pressure → resume.
        let restored = try BASSessionKVStore.restore(
            into: attentionCache(layers: 4, kvHeads: 8, headDim: 128, tokens: T),
            from: url, expectedModelID: "m")
        XCTAssertEqual(restored, T, "the Q4 snapshot round-trips its token count")
    }
}
#endif
