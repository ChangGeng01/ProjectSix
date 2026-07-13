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

/// B5 device TTFT (TEST_RUNNER_BAS_KV_TTFT=1, iPhone Air) — the last open B5 number: warm-restore
/// vs cold-re-prefill on DEVICE (Mac F6: 279→6ms = 45.7×, 48/48 exact). Same protocol: ~1.2K-token
/// session, snapshot (fp16-exact), restore into a fresh cache (timed INCLUSIVE of disk load + GPU
/// materialization), 48-token continuation fidelity.
final class BASKVPersistDeviceTests: XCTestCase {

    func testDeviceWarmTTFT() async throws {
        guard ProcessInfo.processInfo.environment["BAS_KV_TTFT"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BAS_KV_TTFT=1 (device; loads Qwen3.5-4B)")
        }
        #if canImport(MLXLLM)
        ModelFactoryRegistry.shared.addTrampoline { LLMModelFactory.shared }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        MLX.Memory.cacheLimit = 512 * 1024 * 1024
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(
                directory: docs.appendingPathComponent("models/Qwen3.5-4B-4bit"),
                extraEOSTokens: ["<|im_end|>"]),
            progressHandler: { _ in })
        let story = String(repeating: "The expedition crossed the ridge before dawn, keeping the river to the east and the storm at their backs. ", count: 55)
        let input = try await container.prepare(input: UserInput(chat: [
            .user(story + "\n\nSummarize the expedition's route in one sentence.")]))
        struct R: Sendable {
            let histLen: Int; let coldMs: Double; let saveMs: Double; let restoreMs: Double
            let bytes: Int; let match: Int
        }
        let r: R = try await container.perform(nonSendable: input) { ctx, input in
            guard let qwen = ctx.model as? Qwen35Model else {
                throw BASQwen35MTPSpecDecoder.SpecError.notQwen35
            }
            let ids = input.text.tokens.asArray(Int.self)
            let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("kv_ttft_test.safetensors")
            defer { try? FileManager.default.removeItem(at: url) }
            func greedy(_ cache: [KVCache], seed: Int, n: Int) -> [Int] {
                var out: [Int] = []
                var tok = seed
                for _ in 0 ..< n {
                    let h = qwen.hiddenStatesWithCache(
                        MLXArray([Int32(tok)]).expandedDimensions(axis: 0), cache: cache)
                    tok = argMax(qwen.logits(fromHidden: h)[0, 0], axis: -1).item(Int.self)
                    out.append(tok)
                }
                return out
            }
            let cache1 = qwen.newCache(parameters: nil)
            let t0 = Date()
            let h0 = qwen.hiddenStatesWithCache(
                MLXArray(ids.map(Int32.init)).expandedDimensions(axis: 0), cache: cache1)
            let seed = argMax(qwen.logits(fromHidden: h0)[0, h0.dim(1) - 1], axis: -1).item(Int.self)
            let coldMs = Date().timeIntervalSince(t0) * 1000
            let tS = Date()
            let bytes = try BASSessionKVStore.save(cache: cache1, tokenCount: ids.count, to: url,
                                                   modelID: "qwen3.5-device")
            let saveMs = Date().timeIntervalSince(tS) * 1000
            let live = greedy(cache1, seed: seed, n: 48)
            let cache2 = qwen.newCache(parameters: nil)
            let tR = Date()
            _ = try BASSessionKVStore.restore(into: cache2, from: url, expectedModelID: "qwen3.5-device")
            for c in cache2 { eval(c.innerState()) }
            let restoreMs = Date().timeIntervalSince(tR) * 1000
            let warm = greedy(cache2, seed: seed, n: 48)
            let match = zip(live, warm).prefix(while: ==).count
            return R(histLen: ids.count, coldMs: coldMs, saveMs: saveMs, restoreMs: restoreMs,
                     bytes: bytes, match: match)
        }
        print(String(format: "[kv-ttft] DEVICE hist=%dtok cold_prefill=%.0fms save=%.0fms restore=%.0fms (%.1fx) file=%.1fMB match=%d/48",
                     r.histLen, r.coldMs, r.saveMs, r.restoreMs, r.coldMs / max(r.restoreMs, 0.001),
                     Double(r.bytes) / 1e6, r.match))
        XCTAssertGreaterThan(r.match, 40, "device restore fidelity broke (fp16 should be exact)")
        XCTAssertLessThan(r.restoreMs, r.coldMs, "restore must beat cold re-prefill on device")
        #else
        throw XCTSkip("MLXLLM unavailable")
        #endif
    }
}
