import XCTest
import MLX
import MLXLMCommon
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXHuggingFace
import HuggingFace
import MLXLLM
import Tokenizers
#endif

/// 案1 gates — BASTrunkCheckpoint semantics + the two vendor-drift pins.
///
/// Pin 1 (GDN 2-slot contract): a WARM MambaCache exposes exactly 2 slots — the whole
/// snapshot-restore family (checkpoint, BASSessionKVStore) rides this shape. A vendor bump that
/// changes it must break HERE, loudly, not silently corrupt speculative rollback.
/// Pin 2 (offset-unused) lives in the model-gated suite (BAS_CHECKPOINT_PIN=1): the vendored
/// Qwen3.5 forward must never advance ArraysCache.offset — the checkpoint deliberately does not
/// capture it.
final class BASTrunkCheckpointTests: XCTestCase {

    func testMambaCacheIsTwoSlot() {
        let m = MambaCache()
        XCTAssertEqual(m.state.count, 0, "fresh MambaCache compacts nil slots (warm-capture precondition)")
        m[0] = MLXArray([Float](repeating: 1, count: 4))
        m[1] = MLXArray([Float](repeating: 2, count: 4))
        XCTAssertEqual(m.state.count, 2, "vendored MambaCache is no longer 2-slot — audit every snapshot site")
    }

    func testCheckpointRestoresSlotsAndTrims() {
        let gdn = MambaCache()
        gdn[0] = MLXArray([Float]([1, 2, 3]))
        gdn[1] = MLXArray([Float]([4, 5, 6]))
        let fa = KVCacheSimple()
        // grow the attention cache by 3 positions
        let k = MLXArray.zeros([1, 2, 3, 4]), v = MLXArray.zeros([1, 2, 3, 4])
        _ = fa.update(keys: k, values: v)
        XCTAssertEqual(fa.offset, 3)
        let cache: [KVCache] = [gdn, fa]

        let cp = BASTrunkCheckpoint(cache: cache)
        // mutate BOTH: overwrite GDN slots, grow FA by 2 more
        gdn[0] = MLXArray([Float]([9, 9, 9]))
        gdn[1] = MLXArray([Float]([8, 8, 8]))
        _ = fa.update(keys: MLXArray.zeros([1, 2, 2, 4]), values: MLXArray.zeros([1, 2, 2, 4]))
        XCTAssertEqual(fa.offset, 5)

        XCTAssertTrue(cp.restore(cache: cache, trimming: 2), "healthy trim must report success")
        XCTAssertEqual(fa.offset, 3, "attention layer must rewind to the checkpoint")
        XCTAssertEqual(gdn[0]!.asArray(Float.self), [1, 2, 3], "GDN slot 0 must be the captured reference")
        XCTAssertEqual(gdn[1]!.asArray(Float.self), [4, 5, 6], "GDN slot 1 must be the captured reference")
    }

    func testRestoreFailsClosedOnTrimUnderrun() {
        let gdn = MambaCache()
        gdn[0] = MLXArray([Float]([1]))
        gdn[1] = MLXArray([Float]([2]))
        let fa = KVCacheSimple()
        _ = fa.update(keys: MLXArray.zeros([1, 2, 2, 4]), values: MLXArray.zeros([1, 2, 2, 4]))
        let cache: [KVCache] = [gdn, fa]
        let cp = BASTrunkCheckpoint(cache: cache)
        // ask to trim MORE than the cache holds — trim under-returns ⇒ restore must report false
        XCTAssertFalse(cp.restore(cache: cache, trimming: 7),
                       "the old idiom silently discarded trim's return — the checkpoint must not")
    }

    func testCompositionGuard() {
        XCTAssertTrue(BASTrunkCheckpoint.compositionSupported([MambaCache(), KVCacheSimple()]))
        // The REAL hazard class: a WRAPPED RotatingKVCache is not trimmable (offset ≥ maxSize) —
        // rollback through it would corrupt state; the guard must refuse speculation up front.
        let wrapped = RotatingKVCache(maxSize: 2, keep: 0)
        _ = wrapped.update(keys: MLXArray.zeros([1, 2, 2, 4]), values: MLXArray.zeros([1, 2, 2, 4]))
        XCTAssertFalse(wrapped.isTrimmable, "fixture: rotating cache must be at capacity")
        XCTAssertFalse(BASTrunkCheckpoint.compositionSupported([MambaCache(), wrapped]),
                       "untrimmable layers must refuse speculation up front")
    }

    /// Pin 2 (BAS_CHECKPOINT_PIN=1, heavy): the vendored Qwen3.5 forward never advances
    /// ArraysCache.offset — after prefill + a decode round every GDN layer's offset must be
    /// untouched (the checkpoint's not-captured contract).
    func testQwen35ForwardNeverAdvancesArraysOffset() async throws {
        guard ProcessInfo.processInfo.environment["BAS_CHECKPOINT_PIN"] == "1" else {
            throw XCTSkip("set BAS_CHECKPOINT_PIN=1 (heavy — loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: "mlx-community/Qwen3.5-4B-4bit",
                                              extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let offsets: [Int] = try await container.perform { ctx -> [Int] in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let cache = qwen.newCache(parameters: nil)
            let ids = (0 ..< 32).map { Int32(100 + $0) }
            var h = qwen.hiddenStatesWithCache(MLXArray(ids).expandedDimensions(axis: 0), cache: cache)
            for _ in 0 ..< 4 {                                   // a few decode steps
                let tok = argMax(qwen.logits(fromHidden: h)[0, h.dim(1) - 1], axis: -1).item(Int.self)
                h = qwen.hiddenStatesWithCache(MLXArray([Int32(tok)]).expandedDimensions(axis: 0), cache: cache)
            }
            return cache.compactMap { ($0 as? ArraysCache)?.offset }
        }
        XCTAssertFalse(offsets.isEmpty, "no ArraysCache layers found — model shape changed?")
        XCTAssertTrue(offsets.allSatisfy { $0 == 0 },
                      "vendored forward now ADVANCES ArraysCache.offset — the checkpoint (and the "
                      + "fused rollback family) must start capturing it: \(offsets)")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
