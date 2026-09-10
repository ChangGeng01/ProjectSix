#if canImport(MLXLLM)
import Foundation
import MLX
import MLXLMCommon

/// Append-only KV cache that enforces a sliding window via the MASK instead of physical ring-buffer eviction —
/// making speculative decode (cross-turn / prompt-lookup) BYTE-IDENTICAL on sliding-window models (Gemma).
///
/// WHY: the stock `RotatingKVCache` is byte-unsafe for spec-decode (device-measured byte_identical=1/8 on
/// Gemma-4-E4B). Root cause is NOT the attention forward — it is the ring rollback: a K-token verify forward takes
/// `updateConcat` (temporal reorder + grow), then `trimPromptCache` cannot physically rewind a rotated/rebuilt ring
/// (`RotatingKVCache.trim` only does `offset-=n; idx-=n`), so the cache desyncs from the committed prefix on partial
/// acceptance. (See the fail-closed guard in `BASPromptLookupDecoder`.)
///
/// FIX (rigorously byte-identical): drive the verify lane with this cache. It has ONE append-only update path
/// (`update` writes at `[offset..<offset+S]`, grows by `step`) — logic copied from `KVCacheSimple` — and a
/// trivially-correct `trim` (`offset -= n`, nothing overwritten). On that single path, "write K tokens at once" and
/// "write K tokens one-at-a-time" produce a BIT-IDENTICAL buffer (same slots, same data, same returned `[..<offset]`
/// slice), with identical RoPE offset. The sliding window is recreated by the MASK (`makeMask`): each query row is
/// restricted to its causal `(pos-window, pos]` band, so the extra keys the ring would have evicted physically exist
/// but contribute 0 to the softmax → the attention OUTPUT equals the stock windowed cache, while the cache stays
/// fully trimmable. No `S==1` vs `S>1` fork, no ring to corrupt → spec verify == sequential greedy, token-for-token.
///
/// (Conforms to the public `KVCache` protocol directly — `KVCacheSimple`/`BaseKVCache` are non-open/internal-init, so
/// it cannot subclass them; this keeps the fix entirely in BAS code with no vendor patch.)
///
/// SCOPE: a full cache wearing a window mask — memory grows to the generated length instead of capping at `window`,
/// so it is for the bounded spec-decode verify/probe lane (cap `maxTokens`), NOT a drop-in for long-context serving.
/// Assumes `keep == 0` (Gemma's `RotatingKVCache(maxSize:keep:0)`); a non-zero `keep` (pinned prefix) is not modeled.
/// Residual: bf16 multi-token-vs-single-token SDPA reduction-order ULP noise is ORTHOGONAL (a kernel property) — it
/// must be confirmed by the on-device byte_identical probe; if it flips an argmax, force fp32 verify-lane attention.
public final class BASWindowMaskedCache: KVCache {

    /// The sliding-window size (carried over from the swapped-out `RotatingKVCache.maxSize`).
    public let window: Int
    public var offset: Int = 0
    public var maxSize: Int? { nil }   // window enforced by the mask, not by eviction → fully trimmable single buffer
    private var keys: MLXArray?
    private var values: MLXArray?
    public var step = 256

    public init(window: Int) { self.window = window }

    public func innerState() -> [MLXArray] { [self.keys, self.values].compactMap { $0 } }

    // --- Append-only buffer (logic from KVCacheSimple.update) — writes at [offset..<offset+S], grows by step. ---
    public func update(keys: MLXArray, values: MLXArray) -> (MLXArray, MLXArray) {
        let previous = self.offset
        let reset =
            if let currentKeys = self.keys, (previous + keys.dim(2)) > currentKeys.dim(2) {
                true
            } else {
                self.keys == nil
            }
        if reset {
            let B = keys.dim(0)
            let kvHeads = keys.dim(1)
            let kHeadDim = keys.dim(3)
            let vHeadDim = values.dim(3)
            let nSteps = (step + keys.dim(2) - 1) / step
            let newK = MLXArray.zeros([B, kvHeads, nSteps * step, kHeadDim], dtype: keys.dtype)
            let newV = MLXArray.zeros([B, kvHeads, nSteps * step, vHeadDim], dtype: values.dtype)
            if var currentKeys = self.keys, var currentValues = self.values {
                if previous % step != 0 {
                    currentKeys = currentKeys[.ellipsis, ..<previous, 0...]
                    currentValues = currentValues[.ellipsis, ..<previous, 0...]
                }
                self.keys = concatenated([currentKeys, newK], axis: 2)
                self.values = concatenated([currentValues, newV], axis: 2)
            } else {
                self.keys = newK
                self.values = newV
            }
        }
        self.offset += keys.dim(2)
        self.keys?[.ellipsis, previous ..< self.offset, 0...] = keys
        self.values?[.ellipsis, previous ..< self.offset, 0...] = values
        return (
            self.keys![.ellipsis, ..<self.offset, 0...],
            self.values![.ellipsis, ..<self.offset, 0...]
        )
    }

    public var state: [MLXArray] {
        get {
            guard let keys = self.keys, let values = self.values else { return [] }
            if offset == keys.dim(2) {
                return [keys, values]
            }
            return [keys[.ellipsis, ..<offset, 0...], values[.ellipsis, ..<offset, 0...]]
        }
        set {
            // Defensive (no fatalError): an empty/odd snapshot just clears the buffer rather than crashing the app.
            guard newValue.count == 2 else {
                if newValue.isEmpty { self.keys = nil; self.values = nil; self.offset = 0 }
                return
            }
            self.keys = newValue[0]
            self.values = newValue[1]
            self.offset = self.keys!.dim(2)
        }
    }

    public var metaState: [String] {
        get { [String(window), String(offset), String(step)] }
        set {
            guard newValue.count == 3, let o = Int(newValue[1]), let s = Int(newValue[2]) else { return }
            self.offset = o
            self.step = s
        }
    }

    public var isTrimmable: Bool { true }

    @discardableResult
    public func trim(_ n: Int) -> Int {
        let trimmed = min(offset, n)
        offset -= trimmed
        return trimmed
    }

    public func makeMask(
        n: Int, windowSize: Int?, returnArray: Bool
    ) -> MLXFast.ScaledDotProductAttentionMaskMode {
        let w = windowSize ?? window
        // ALWAYS return the windowed ARRAY mask — even for n==1, even under-window. This is the byte-identity key:
        // the single-token greedy baseline (n==1) and the multi-token spec verify (n>1) then use the SAME masked-SDPA
        // kernel, so their bf16 reduction order matches and verify == single-token greedy token-for-token. (Returning
        // `.none` for n==1, as the stock cache does, takes the unmasked SDPA fast-path → a DIFFERENT bf16 reduction
        // than the n>1 array path → the ~1% ULP argmax flips that gave byte_identical<8/8 on Gemma. Llama is N/N
        // because, having no window, both arms already share the `.causal` kernel.) createCausalMask reduces to
        // causal-all when the window doesn't bind, so it is the correct window for every n and offset.
        return .array(createCausalMask(n: n, offset: offset, windowSize: w))
    }

    public func copy() -> any KVCache {
        let new = BASWindowMaskedCache(window: window)
        new.step = self.step
        let s = self.state
        if !s.isEmpty { new.state = s.map { $0[.ellipsis] } }
        return new
    }

    /// Build a spec-decode-safe cache for `model`: swap each sliding-window `RotatingKVCache` for an append-only
    /// window-masked cache (byte-identically trimmable); leave full-attention caches untouched, so the certified
    /// full-attention path (Llama/Qwen) is byte-unchanged. Preserves any KV-sharing (same original cache instance →
    /// same swapped instance) so shared-KV layers don't desync.
    public static func verifyCache(
        for model: any LanguageModel, parameters: GenerateParameters
    ) -> [KVCache] {
        var swapped: [ObjectIdentifier: KVCache] = [:]
        return model.newCache(parameters: parameters).map { c in
            let id = ObjectIdentifier(c as AnyObject)
            if let existing = swapped[id] { return existing }
            let replacement: KVCache
            if let rotating = c as? RotatingKVCache, let w = rotating.maxSize {
                replacement = BASWindowMaskedCache(window: w)
            } else {
                replacement = c
            }
            swapped[id] = replacement
            return replacement
        }
    }
}
#endif
