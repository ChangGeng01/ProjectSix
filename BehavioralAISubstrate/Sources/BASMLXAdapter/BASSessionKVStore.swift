// BASSessionKVStore — B5 KV 跨会话持久化 (FRONTIER_2026H2 B5; "Agent Memory Below the Prompt"
// 2603.04428 pattern): snapshot a session's trunk cache to ONE safetensors file so the session
// warm-starts across process restarts without re-prefilling its history. NOT learning — caching.
//
// Qwen3.5 hybrid cache handling:
//   • KVCacheSimple (8 full-attention layers): K/V grow with context — quantized Q4/g64 on disk
//     (the paper's recipe: ≈lossless, 4× smaller). Restored via dequantized() → fp16.
//   • MambaCache/ArraysCache (24 GDN layers): FIXED-SIZE recurrent accumulators — stored AS-IS
//     (fp16/fp32). A recurrent state integrates over the whole stream; quantization error would
//     compound, and it is small anyway — the conservative departure from the paper's pure-attention
//     setting. `offset` persisted explicitly (the ArraysCache state setter does not restore it).
//
// Save ordering contract: call save() BEFORE continuing to decode on the same cache —
// KVCacheSimple mutates its buffers in place and the state getter returns lazy slices.
import Foundation
#if canImport(MLXLLM)
import MLX
import MLXLMCommon

public enum BASSessionKVStore {

    public enum StoreError: Error {
        case badFile(String)
        case layerMismatch(expected: Int, found: Int)
        case unsupportedCache(String)
    }

    static let version = "1"

    /// Snapshot `cache` (+ the session's token count) to a safetensors file. Returns bytes written.
    /// Default fp16 = EXACT continuation (F6: 48/48 token match, 45.7× TTFT, ~32KB/token marginal)
    /// — the house lossless bar. `quantizeKV: true` = the paper's Q4 recipe (~8KB/token, continuation
    /// diverges tie-break-class after ~20 tokens; F6: 33.6× TTFT) for bulk/space-constrained tiers.
    @discardableResult
    public static func save(cache: [KVCache], tokenCount: Int, to url: URL,
                            quantizeKV: Bool = false) throws -> Int {
        var arrays: [String: MLXArray] = [:]
        var meta: [String: String] = [
            "version": Self.version,
            "tokens": "\(tokenCount)",
            "layers": "\(cache.count)",
        ]
        for (i, c) in cache.enumerated() {
            if let ac = c as? ArraysCache {                      // GDN first: MambaCache IS ArraysCache
                let st = ac.state
                meta["l\(i).kind"] = "arrays"
                meta["l\(i).count"] = "\(st.count)"
                meta["l\(i).offset"] = "\(ac.offset)"
                for (j, a) in st.enumerated() { arrays["l\(i).a\(j)"] = a }
            } else if let kv = c as? KVCacheSimple {
                let st = kv.state                                // [keys ≤offset, values ≤offset]
                if st.count == 2, !quantizeKV {                  // fp16 mode (exactness > size)
                    arrays["l\(i).kf"] = st[0]
                    arrays["l\(i).vf"] = st[1]
                    meta["l\(i).kind"] = "kv16"
                } else if st.count == 2 {
                    let (kw, ks, kb) = MLX.quantized(st[0], groupSize: 64, bits: 4)
                    let (vw, vs, vb) = MLX.quantized(st[1], groupSize: 64, bits: 4)
                    arrays["l\(i).kw"] = kw; arrays["l\(i).ks"] = ks
                    arrays["l\(i).vw"] = vw; arrays["l\(i).vs"] = vs
                    if let kb { arrays["l\(i).kb"] = kb }
                    if let vb { arrays["l\(i).vb"] = vb }
                    meta["l\(i).kind"] = "kv"
                } else {
                    meta["l\(i).kind"] = "kv-empty"
                }
            } else {
                throw StoreError.unsupportedCache(String(describing: type(of: c)))
            }
        }
        try MLX.save(arrays: arrays, metadata: meta, url: url)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return size ?? 0
    }

    /// Restore a snapshot INTO a fresh cache from `model.newCache` (layer kinds must line up).
    /// Returns the persisted token count.
    @discardableResult
    public static func restore(into cache: [KVCache], from url: URL) throws -> Int {
        let (arrays, meta) = try MLX.loadArraysAndMetadata(url: url)
        guard meta["version"] == Self.version,
              let layerCount = meta["layers"].flatMap(Int.init),
              let tokens = meta["tokens"].flatMap(Int.init) else {
            throw StoreError.badFile(url.lastPathComponent)
        }
        guard layerCount == cache.count else {
            throw StoreError.layerMismatch(expected: cache.count, found: layerCount)
        }
        for (i, c) in cache.enumerated() {
            switch meta["l\(i).kind"] {
            case "arrays":
                guard let ac = c as? ArraysCache,
                      let n = meta["l\(i).count"].flatMap(Int.init),
                      let off = meta["l\(i).offset"].flatMap(Int.init) else {
                    throw StoreError.badFile("l\(i) arrays")
                }
                var st: [MLXArray] = []
                for j in 0 ..< n {
                    guard let a = arrays["l\(i).a\(j)"] else { throw StoreError.badFile("l\(i).a\(j)") }
                    st.append(a)
                }
                ac.state = st
                ac.offset = off
            case "kv":
                guard let kv = c as? KVCacheSimple,
                      let kw = arrays["l\(i).kw"], let ks = arrays["l\(i).ks"],
                      let vw = arrays["l\(i).vw"], let vs = arrays["l\(i).vs"] else {
                    throw StoreError.badFile("l\(i) kv")
                }
                let k = dequantized(kw, scales: ks, biases: arrays["l\(i).kb"],
                                    groupSize: 64, bits: 4).asType(.float16)
                let v = dequantized(vw, scales: vs, biases: arrays["l\(i).vb"],
                                    groupSize: 64, bits: 4).asType(.float16)
                kv.state = [k, v]                                // setter derives offset from dim(2)
            case "kv16":
                guard let kv = c as? KVCacheSimple,
                      let k = arrays["l\(i).kf"], let v = arrays["l\(i).vf"] else {
                    throw StoreError.badFile("l\(i) kv16")
                }
                kv.state = [k, v]
            case "kv-empty", .none:
                continue
            case .some(let kind):
                throw StoreError.badFile("l\(i) kind=\(kind)")
            }
        }
        return tokens
    }
}
#endif
