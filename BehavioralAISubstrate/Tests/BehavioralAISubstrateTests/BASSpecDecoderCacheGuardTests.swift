#if canImport(MLXLLM)
import XCTest
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
}
#endif
