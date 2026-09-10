import XCTest
import MLX
import MLXLMCommon
@testable import BASMLXAdapter
#if canImport(MLXLLM)
import MLXLLM

/// audit mlx-adapter-core MED-10 — a spilled KV snapshot must be bound to the model
/// that produced it. Before this, BASSessionKVStore.restore guarded version + layer
/// count + per-layer kind only, so a SAME-SHAPE snapshot from a different model (after
/// a model swap keyed on sessionID#role, not model.id) restored cleanly and the seat
/// continued on another model's KV — a garbage continuation or a Metal shape crash.
final class BASSessionKVStoreModelIDTests: XCTestCase {

    // ungated MLX compute — probe-skip in headless sessions where the metallib can't load
    override func setUpWithError() throws {
        try BASMLXMetalAvailability.skipIfUnavailable()
    }

    private func syntheticCache() -> [KVCache] {
        let gdn = MambaCache()
        gdn[0] = MLXArray([Float]([1, 2, 3]))
        gdn[1] = MLXArray([Float]([4, 5, 6]))
        let fa = KVCacheSimple()
        _ = fa.update(keys: MLXArray.zeros([1, 2, 3, 4]), values: MLXArray.zeros([1, 2, 3, 4]))
        return [gdn, fa]
    }

    private func tmpURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("bas_kv_modelid_\(UUID().uuidString).safetensors")
    }

    func testRestoreRejectsWrongModel() throws {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try BASSessionKVStore.save(cache: syntheticCache(), tokenCount: 3, to: url, modelID: "modelA")

        // THE fix: a same-shape cache from model B must NOT accept model A's snapshot.
        XCTAssertThrowsError(
            try BASSessionKVStore.restore(into: syntheticCache(), from: url, expectedModelID: "modelB")
        ) { error in
            guard case BASSessionKVStore.StoreError.modelMismatch(let expected, let found) = error else {
                return XCTFail("expected .modelMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "modelB")
            XCTAssertEqual(found, "modelA")
        }
    }

    func testRestoreAcceptsMatchingModel() throws {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try BASSessionKVStore.save(cache: syntheticCache(), tokenCount: 3, to: url, modelID: "modelA")
        XCTAssertNoThrow(
            try BASSessionKVStore.restore(into: syntheticCache(), from: url, expectedModelID: "modelA"),
            "the same model must still warm-start from its own snapshot")
    }
}
#endif
