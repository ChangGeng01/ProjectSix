#if canImport(MLXLLM)
import XCTest
import MLX
import MLXLMCommon
@testable import BASMLXAdapter

/// Regression for the latent RotatingKVCache trim-desync bug (found by the Saguaro adversarial review). Both shipped
/// greedy spec decoders (`BASPromptLookupDecoder`, `BASCoreMLDraftDecoder`) rewind the target KV cache per round via
/// `trimPromptCache`; that is only sound for an UNCONDITIONALLY trimmable cache. A `RotatingKVCache` (params.maxKVSize
/// != nil) flips `isTrimmable`→false once it fills, after which the rewind silently under-trims and desyncs the cache
/// from the committed prefix — breaking byte-identity mid-run. Both init guards now reject RotatingKVCache up front
/// (`cache.allSatisfy { !($0 is RotatingKVCache) }`, fail-closed).
///
/// This pins the exact predicate the guards use. The end-to-end "generate() throws" path can't run under bare
/// `swift test` (MLX's Metal default-library isn't located outside an app bundle); the guard itself is compile-
/// certified in both decoders and exercised on-device.
final class BASSpecDecoderCacheGuardTests: XCTestCase {

    func testGuardPredicate_rejectsRotating_acceptsSimple() {
        let rotating: [KVCache] = [RotatingKVCache(maxSize: 8, keep: 4)]
        let simple: [KVCache] = [KVCacheSimple()]
        // The predicate added to both shipped decoders' init guards + BASSaguaroMLXTarget.init:
        XCTAssertFalse(rotating.allSatisfy { !($0 is RotatingKVCache) },
            "a RotatingKVCache must be rejected (its trimmability is offset-dependent → desyncs the rewind)")
        XCTAssertTrue(simple.allSatisfy { !($0 is RotatingKVCache) },
            "a KVCacheSimple must pass the RotatingKVCache check")
        XCTAssertTrue(canTrimPromptCache(simple),
            "KVCacheSimple is unconditionally trimmable (the happy path the guard preserves)")
    }

    /// P1-b (2026-07-13): the GDN/hybrid composition (ArraysCache linear layers + trimmable
    /// attention — Qwen3.5's cache shape) fails `canTrimPromptCache` (which used to throw the
    /// whole model-free family off the production quality default) but passes
    /// `BASTrunkCheckpoint.compositionSupported` — the predicate pair that now routes it to the
    /// snapshot-restore carry-forward lane instead of `DecodeError.nonTrimmableCache`.
    /// Reversal: restoring the old single-guard (`canTrimPromptCache` ⇒ throw) turns this
    /// composition back into a hard refusal — the routing asserts below red.
    func testGDNCompositionRoutesToCarryForwardNotRefusal() {
        let gdn = MambaCache()
        gdn[0] = MLXArray([Float]([1, 2, 3]))
        gdn[1] = MLXArray([Float]([4, 5, 6]))
        let hybrid: [KVCache] = [gdn, KVCacheSimple()]
        XCTAssertFalse(canTrimPromptCache(hybrid),
            "the hybrid composition is NOT trim-rewindable (ArraysCache) — pre-P1-b this threw")
        XCTAssertTrue(BASTrunkCheckpoint.compositionSupported(hybrid),
            "every layer is ArraysCache-or-trimmable — the carry-forward lane must accept it")
        XCTAssertTrue(hybrid.allSatisfy { !($0 is RotatingKVCache) },
            "the rotating exclusion still guards BOTH lanes")
        // An alien non-trimmable, non-Arrays layer stays refused (fail-closed) in both lanes.
        let alien: [KVCache] = [gdn, RotatingKVCache(maxSize: 8, keep: 4)]
        XCTAssertFalse(alien.allSatisfy { !($0 is RotatingKVCache) },
            "a rotating layer inside a hybrid composition must still be rejected up front")
    }
}
#endif
