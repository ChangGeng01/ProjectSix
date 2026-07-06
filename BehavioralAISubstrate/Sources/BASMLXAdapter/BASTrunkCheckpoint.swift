import Foundation
import MLX
import MLXLMCommon

/// 案1 (2026-07-06 decode-OS audit) — ONE owner for the in-decode trunk snapshot/restore idiom
/// that existed as SIX verbatim copies across the spec decoders (fused chain, K=1 reference,
/// sampling, sequential deep-K, DFlash). MECHANISM only: byte-for-byte the same MLX operations
/// (retain the GDN slot references at capture — MLX arrays are immutable so this is FREE;
/// reassign them on restore; trim the attention layers) — adopting lanes stay numerically
/// identical by construction. Per-lane NUMERICS are deliberately NOT unified (the fat-mtpForward
/// vs lean-fusedLink coupling is load-bearing — the 0.72→0.59 sampling-acceptance regression
/// pinned that lesson).
///
/// Generalizes the hardcoded `(m, m[0], m[1])` 2-slot capture to n slots, walking them the way
/// BASSessionKVStore.save does — the two state owners can no longer drift on slot semantics.
/// ArraysCache.offset is deliberately NOT captured: the vendored Qwen3.5 forward never reads nor
/// advances it (pinned by BASTrunkCheckpointPinTests — a vendor bump that changes either fact
/// breaks loudly there, not silently here).
///
/// PRECONDITION: capture on a WARM cache (post-prefill). `ArraysCache.state` compacts nil slots,
/// so a fresh cache exposes zero slots; every production site snapshots after the prefill wrote
/// the GDN state, and the debug assert below pins the expectation.
struct BASTrunkCheckpoint {

    private let slots: [(cache: ArraysCache, saved: [MLXArray?])]

    /// Retain every ArraysCache layer's slot references (2 for GDN/Mamba; n-generic).
    init(cache: [KVCache]) {
        slots = cache.compactMap { c in
            guard let ac = c as? ArraysCache else { return nil }
            let n = ac.state.count
            assert(n > 0, "BASTrunkCheckpoint captured a COLD ArraysCache — snapshot after prefill")
            return (ac, (0 ..< n).map { ac[$0] })
        }
    }

    /// Entry-time composition guard (the fail-closed check the prompt-lookup/tree lanes carry
    /// and the MTP lanes lacked): every layer must be either an ArraysCache (snapshot-restore)
    /// or a trimmable attention cache. A vendor/model change that introduces anything else must
    /// refuse speculation instead of corrupting state mid-generation.
    static func compositionSupported(_ cache: [KVCache]) -> Bool {
        cache.allSatisfy { $0 is ArraysCache || $0.isTrimmable }
    }

    /// Reassign the captured slot references and trim every non-Arrays layer by `tokens`.
    /// Returns `false` when a trim under-returned (cache inconsistent — the old idiom silently
    /// discarded `trim`'s return; callers must FAIL-CLOSE their loop on false: everything already
    /// emitted is a trunk argmax, so stopping early is safe, continuing on corrupt state is not).
    @discardableResult
    func restore(cache: [KVCache], trimming tokens: Int) -> Bool {
        for (ac, saved) in slots {
            for (j, a) in saved.enumerated() { ac[j] = a }
        }
        var ok = true
        for c in cache where !(c is ArraysCache) {
            if c.trim(tokens) != tokens { ok = false }
        }
        return ok
    }
}
