// MARK: - BASAutoRouteRanker
// chapter 七百六 第三刀 / M2203
//
// Empirically-derived auto-routing for cosine + L2 + SHA256
// based on the chapter-七百六-第二刀 benchmark tournament
// results。 At runtime the substrate picks the fastest
// implementation per (workload × input size) cell。
//
// ## Why not always-pick-the-fastest at boot
//
// Crossover thresholds vary by hardware (M1 vs M2 vs M3,
// Intel vs Apple Silicon)。 The thresholds here are M-series
// medians;hosts running on Intel can override via the
// public init params if their own benchmark indicates a
// different crossover。
//
// ## Measured wins (M-series, see chapter-七百六-第二刀):
//
//   COSINE
//     dim ≤ ~32   : Rust scalar (SIMD overhead dominates)
//     dim ≥ ~64   : Rust SIMD   (vectorization pays off)
//
//   L2 NORM
//     all dims   : Rust SIMD (79x over Swift)
//
//   SHA256
//     ≤ ~1 KB    : Rust pure-sha2 (function-call overhead lower)
//     ≥ ~1 KB    : Swift CryptoKit (HW SHA engine amortizes)

import Foundation
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
import CryptoKit
#if canImport(Darwin)
import Darwin  // OSAtomicAdd32 — chapter 八百五十一 / M2906 fix
#endif

/// Configuration for the auto-router。 Hosts that benched on
/// non-M-series hardware can override these thresholds。
public struct BASAutoRouteThresholds:
    Sendable, Equatable, Hashable, Codable
{
    /// Cosine: use Rust scalar below this dim, SIMD at or
    /// above。 Measured M-series crossover ≈ 64。
    public let cosineSIMDMinDim: Int
    /// SHA256: use Rust below this byte count, CryptoKit at
    /// or above。 Measured M-series crossover ≈ 1024 bytes。
    public let sha256CryptoKitMinBytes: Int

    /// Attention: use CPU below this M*N product,Metal at or
    /// above。 Measured M-series crossover ≈ 64 (M=4,N=4 ⇒
    /// CPU wins;M=16,N=16 ⇒ Metal wins)。
    public let attentionMetalMinProduct: Int

    /// MatMul: use Rust below this M*N*K product,Metal at or
    /// above。 Measured M-series crossover ≈ 262 144 (32³ wins
    /// Rust, 128³ wins Metal — crossover sits between)。
    public let matMulMetalMinProduct: Int

    /// chapter 八百七十一.5 / M3025 — second crossover for matMul:
    /// at workProduct ≥ this threshold,route to true MPSGraph
    /// actor (.metalMatMulMPSGraphActor) instead of MSL kernel
    /// (.metalMatMulMPSGraph legacy enum)。 Measured M-series
    /// (Mac mini) crossover at 16M = 256³ — MPSGraph warm wins
    /// 1.07-1.38× over MSL at 256³+。 Configurable per device
    /// because iPhone A-series + iPad M-series have different
    /// MPSGraph dispatch overhead; the chapter 八百七十一 hardcoded
    /// 16M was flagged by 6th-pass review (agent A HIGH-1) as
    /// needing this configurability。
    public let matMulMPSGraphActorMinProduct: Int

    /// LayerNorm: use Rust naive below this dim,affine SIMD at
    /// or above。 Measured M-series crossover ≈ 128。
    public let layerNormSIMDMinDim: Int

    /// GELU tanh-approx: use Rust scalar below this dim,Rust
    /// SIMD at or above。 Measured M-series crossover ≈ 256
    /// (chapter 七百十一 第三刀)。 gelu_exact + silu always use
    /// scalar (SIMD unrolling gives ≤1% benefit which doesn't
    /// pay for branch cost — erf/sigmoid bottleneck dominates)。
    public let geluTanhSIMDMinDim: Int

    /// Batched cosine similarity:use Rust SIMD below this
    /// corpus-row count,Metal at or above。 Measured M-series
    /// crossover NEVER OBSERVED at the measured grid (chapter
    /// 七百十五 第三刀:Rust SIMD wins at every tested size up
    /// to 4096 × 512)。 Default set to 16384 — well above any
    /// real production workload — so Rust SIMD is effectively
    /// the production-default path。 Hosts running on hardware
    /// where the crossover shifts can lower this via calibration。
    public let batchedCosineMetalMinRows: Int

    /// chapter 八百七十二 / M3026 — batched cosine Rust→rayon
    /// parallel threshold。 Per chapter 八百七十二 第二刀 chunked
    /// v2 LIVE measurement on Mac mini:
    ///   - 1K rows × 384 dim: rayon 0.55× of seq (LOSES,
    ///     chunk-64 batch still too small at this corpus)
    ///   - 5K rows × 384 dim: rayon 1.74× of seq (WINS,
    ///     chunk count amortizes scheduling)
    /// Default 3000 sits in the conservative middle — at this
    /// threshold parallel begins winning。 Production retrieval
    /// typically operates on 1K-50K corpora so this default
    /// favors sequential at the lower end + parallel at the
    /// higher end。 Hosts with consistently large corpora can
    /// lower this via calibration。
    public let batchedCosineRayonMinRows: Int

    /// chapter 八百七十九 / M3080 — batched cosine rayon chunk
    /// granularity per parallel task。 Default 64 (matches the
    /// chapter 八百七十二 第二刀 Rust crate hardcoded value at
    /// ~64μs/task at dim=384,well above rayon ~1μs scheduling
    /// overhead)。 Configurable per chapter 871.5 lesson:device
    /// with lower core count may want larger chunks,higher
    /// core count may want smaller。
    ///
    /// chapter 八百八十 / M3085 — WIRED THROUGH (the chapter 879
    /// "future scope" promise delivered)。 Swift bridge in
    /// `batchedCosineSimilarity` now reads this field + calls
    /// `bas_ranker_batched_cosine_simd_rayon_chunked` C ABI which
    /// passes it to `batched_cosine_simd_rayon_chunked` in Rust。
    /// Default 64 → bit-identical to the chapter 872 result。
    /// Rust impl clamps: 0 → 1 (sequential-degenerate but correct),
    /// > 4096 → 4096 (sanity cap)。 Byte-equality across chunk_rows
    /// values is pinned by `BASChapter880ChunkRowsWiringTests`。
    public let batchedCosineRayonChunkRows: Int

    public init(
        cosineSIMDMinDim: Int = 64,
        sha256CryptoKitMinBytes: Int = 1024,
        attentionMetalMinProduct: Int = 64,
        matMulMetalMinProduct: Int = 262_144,
        matMulMPSGraphActorMinProduct: Int = 16_777_216,
        layerNormSIMDMinDim: Int = 128,
        geluTanhSIMDMinDim: Int = 256,
        batchedCosineMetalMinRows: Int = 16384,
        batchedCosineRayonMinRows: Int = 3000,
        batchedCosineRayonChunkRows: Int = 64
    ) {
        self.cosineSIMDMinDim = max(1, cosineSIMDMinDim)
        self.sha256CryptoKitMinBytes =
            max(1, sha256CryptoKitMinBytes)
        self.attentionMetalMinProduct =
            max(1, attentionMetalMinProduct)
        self.matMulMetalMinProduct =
            max(1, matMulMetalMinProduct)
        self.matMulMPSGraphActorMinProduct =
            max(1, matMulMPSGraphActorMinProduct)
        self.layerNormSIMDMinDim =
            max(1, layerNormSIMDMinDim)
        self.geluTanhSIMDMinDim =
            max(1, geluTanhSIMDMinDim)
        self.batchedCosineMetalMinRows =
            max(1, batchedCosineMetalMinRows)
        self.batchedCosineRayonMinRows =
            max(1, batchedCosineRayonMinRows)
        self.batchedCosineRayonChunkRows =
            max(1, batchedCosineRayonChunkRows)
    }

    /// Default measured M-series thresholds。
    public static let mSeriesDefault = BASAutoRouteThresholds()
}

/// Which implementation actually executed — emitted alongside
/// the result so callers can verify the routing decision in
/// tests / telemetry。
public enum BASAutoRouteChoice:
    String, Sendable, Equatable, Hashable,
    CaseIterable, Codable
{
    case rustScalar
    case rustSIMD
    case swiftCryptoKit
    case rustPureSHA256
    case swiftNaive
    /// chapter 七百七 第三刀 — attention routing。
    case swiftCPUAttention
    case metalStandardAttention
    case metalFlashAttention
    /// chapter 八百七十 / M3016 — MPSGraph attention added as
    /// auto-router destination per chapter 八百六十九 measurement
    /// (2.31-3.09× faster than std/FA at production shapes when
    /// cache is warm)。 Routing flip from .metalFlashAttention
    /// happens at attentionChoice when shape.Dv == shape.D
    /// (MPSGraph requires Dv == D — Dv≠D shapes fall back to
    /// .metalStandardAttention which has no such constraint)。
    case metalMPSGraphAttention
    /// chapter 七百七 第四刀 — HMAC routing。
    case swiftCryptoKitHMAC
    case rustHMAC
    /// chapter 七百八 第三刀 — MatMul routing。
    ///
    /// NAMING LEGACY note (chapter 八百七十一 / M3021):
    /// `.metalMatMulMPSGraph` is misleadingly named — it routes
    /// to the MSL custom kernel `matmul_float32` via
    /// `BASMetalMatMulDispatcher`,NOT to `BASMPSGraphMatMulKernel`
    /// actor。 The enum-name implies MPSGraph but the work is
    /// done by custom MSL since chapter 七百八。 Same false-naming
    /// pattern chapter 八百六十八 caught for FlashAttention's
    /// 「1.24-1.62× faster」 claim。
    /// Renaming this case in-place would break all routing
    /// callers + tests + doctrine SQL records,so chapter 八百七十一
    /// keeps the existing case as-is + ADDS a new case
    /// `.metalMatMulMPSGraphActor` for the true MPSGraph path。
    case rustMatMulNaive
    case rustMatMulBlocked
    case metalMatMulMPSGraph
    /// chapter 八百七十一 / M3021 — TRUE MPSGraph matMul via
    /// `BASMPSGraphMatMulKernel` actor (chapter 870 attention
    /// recipe applied to matmul)。 Live measurement on Mac
    /// mini at chapter 八百七十一:
    ///   - 128³: MSL beats MPSGraph warm 1.89×
    ///   - 256³: MPSGraph warm beats MSL 1.07× (~tie)
    ///   - 512³: MPSGraph warm beats MSL 1.38×
    /// → Split-flip: stays MSL at small shapes,routes to
    /// MPSGraph actor at large (workProduct ≥ 16M)。 See
    /// `matMulChoice` for the threshold logic。
    case metalMatMulMPSGraphActor
    /// chapter 七百九 第四刀 — Softmax routing。
    case rustSoftmaxScalar
    /// chapter 七百九 第四刀 — LayerNorm routing。
    case rustLayerNormNaive
    case rustLayerNormAffineSIMD
    /// chapter 七百十一 第四刀 — Activation routing。
    case rustGeluExact
    case rustGeluTanhScalar
    case rustGeluTanhSIMD
    case rustSilu
    /// chapter 七百十二 第四刀 — Ledger seal / verify routing。
    case rustLedgerSeal
    case rustLedgerSealBatch
    case rustLedgerVerifyChain
    case swiftCryptoKitLedgerSeal
    /// chapter 七百十三 第四刀 — Forget cascade + provenance。
    case rustForgetCascadeFilter
    case swiftForgetCascadeFallback
    case rustProvenanceFilter
    case swiftProvenanceFallback
    /// chapter 七百十五 第四刀 — Batched cosine similarity。
    case rustBatchedCosine
    case metalBatchedCosine
    /// chapter 八百七十二 / M3026 — rayon-parallel batched cosine。
    /// Auto-selected at corpus rows ≥
    /// `BASAutoRouteThresholds.batchedCosineRayonMinRows` (default
    /// 3000 per chapter 八百七十二 第二刀 chunked-v2 measurement —
    /// initially set 500 in 第一刀 but raised to 3000 after live
    /// data showed v1 lost at 1K rows;chunked v2 wins at ≥3K)。
    /// Byte-equal with `.rustBatchedCosine` (par_chunks preserves
    /// collect order per chapter 八百六十三 pattern)。
    case rustBatchedCosineRayon
}

/// chapter 七百十三 第四刀 — provenance-gate decision codes
/// mirroring `bas_ranker_provenance_rejection_code` exit codes。
public enum BASProvenanceGateDecision:
    Sendable, Equatable, Hashable
{
    case permitted
    case malformedHashLengthTrainingCorpus
    case malformedHashLengthTrainedWeights
    case malformedHashContentTrainingCorpus
    case malformedHashContentTrainedWeights
    case belowProductionTier
    case nonProductionTierCarriesAttestation
    case missingAttestationForProductionTier
    case invalidInput

    public init(rustExitCode: Int32) {
        switch rustExitCode {
        case 0: self = .permitted
        case 1: self = .malformedHashLengthTrainingCorpus
        case 2: self = .malformedHashLengthTrainedWeights
        case 3: self = .malformedHashContentTrainingCorpus
        case 4: self = .malformedHashContentTrainedWeights
        case 5: self = .belowProductionTier
        case 6:
            self = .nonProductionTierCarriesAttestation
        case 7:
            self = .missingAttestationForProductionTier
        default: self = .invalidInput
        }
    }

    public var isPermitted: Bool {
        return self == .permitted
    }
}

/// chapter 七百十三 第四刀 — provenance tier ladder mirroring
/// Swift `BASOrganTrainedWeightProvenance.Tier`。
public enum BASProvenanceTier: Int32, Sendable {
    case illustrative = 0
    case aiAdvisory = 1
    case peerReviewed = 2
    case domainExpertReviewed = 3
}

/// chapter 七百八 第三刀 — MatMul shape input。
public struct BASMatMulShape:
    Sendable, Equatable, Hashable, Codable
{
    public let M: Int
    public let N: Int
    public let K: Int
    public init(M: Int, N: Int, K: Int) {
        self.M = M
        self.N = N
        self.K = K
    }
    /// Used by the auto-router to gate Rust vs Metal。
    public var workProduct: Int { return M * N * K }
}

/// chapter 七百七 第三刀 — attention shape input。
public struct BASAttentionShape:
    Sendable, Equatable, Hashable, Codable
{
    public let M: Int
    public let N: Int
    public let D: Int
    public let Dv: Int
    public init(M: Int, N: Int, D: Int, Dv: Int) {
        self.M = M
        self.N = N
        self.D = D
        self.Dv = Dv
    }
    /// Used by the auto-router to gate CPU vs Metal。
    public var workProduct: Int { return M * N }
}

/// Typed result struct emitted by every auto-route call。
public struct BASAutoRouteResult<Value>: Sendable
    where Value: Sendable
{
    public let value: Value
    public let choice: BASAutoRouteChoice
    public init(value: Value, choice: BASAutoRouteChoice) {
        self.value = value
        self.choice = choice
    }
}

/// Stateless auto-router。 Picks the fastest implementation per
/// workload + input size。 No actor isolation needed because all
/// routing decisions are pure functions of (input size,
/// thresholds)。
public enum BASAutoRouteRanker {

    /// Compute cosine similarity using the best implementation
    /// for the input size。 Returns the result + which path was
    /// chosen。 On non-iOS/macOS platforms (no Rust binary)
    /// falls back to Swift naive。
    public static func cosineSimilarity(
        _ a: [Float], _ b: [Float],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<Float> {
        guard a.count == b.count, !a.isEmpty else {
            return BASAutoRouteResult(
                value: 0, choice: .swiftNaive)
        }
        #if os(iOS) || os(macOS)
        let useSIMD = a.count >= thresholds.cosineSIMDMinDim
        var score: Float = 0
        let rc: Int32 = a.withUnsafeBufferPointer { ap in
            b.withUnsafeBufferPointer { bp in
                if useSIMD {
                    return bas_ranker_cosine_similarity_simd(
                        ap.baseAddress, a.count,
                        bp.baseAddress, b.count, &score)
                } else {
                    return bas_ranker_cosine_similarity(
                        ap.baseAddress, a.count,
                        bp.baseAddress, b.count, &score)
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: score,
                choice: useSIMD ? .rustSIMD : .rustScalar)
        }
        // Rust FFI error fallthrough → Swift naive
        #endif
        // Swift naive fallback (also the watchOS / Linux path)
        return BASAutoRouteResult(
            value: swiftNaiveCosine(a, b),
            choice: .swiftNaive)
    }

    /// Auto-routed L2 norm。 Measured M-series:Rust SIMD wins
    /// at every dim,so always use it when available。
    public static func l2Norm(
        _ v: [Float]
    ) -> BASAutoRouteResult<Float> {
        guard !v.isEmpty else {
            return BASAutoRouteResult(
                value: 0, choice: .swiftNaive)
        }
        #if os(iOS) || os(macOS)
        var n: Float = 0
        let rc = v.withUnsafeBufferPointer { vp in
            bas_ranker_l2_norm_simd(
                vp.baseAddress, v.count, &n)
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: n, choice: .rustSIMD)
        }
        #endif
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        return BASAutoRouteResult(
            value: sumSq.squareRoot(),
            choice: .swiftNaive)
    }

    /// chapter 七百七 第四刀 — auto-routed HMAC-SHA256。
    ///
    /// Same crossover heuristic as SHA256:CryptoKit's HMAC
    /// uses the same hardware SHA engine,so its win amortizes
    /// at the same payload sizes。 Rust pure-HMAC wins for
    /// small payloads where function-call overhead dominates。
    public static func hmacSHA256(
        key: [UInt8], payload: [UInt8],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[UInt8]> {
        #if os(iOS) || os(macOS)
        let useCryptoKit =
            payload.count >= thresholds.sha256CryptoKitMinBytes
        if useCryptoKit {
            let keyD = SymmetricKey(data: Data(key))
            let mac = HMAC<SHA256>.authenticationCode(
                for: Data(payload), using: keyD)
            return BASAutoRouteResult(
                value: Array(mac),
                choice: .swiftCryptoKitHMAC)
        }
        var out = [UInt8](repeating: 0, count: 32)
        let rc = out.withUnsafeMutableBufferPointer { ob in
            key.withUnsafeBufferPointer { kp in
                payload.withUnsafeBufferPointer { pp in
                    bas_substrate_hmac_sha256(
                        kp.baseAddress, key.count,
                        pp.baseAddress, payload.count,
                        ob.baseAddress)
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: .rustHMAC)
        }
        #endif
        // Fallback: CryptoKit
        let keyD = SymmetricKey(data: Data(key))
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(payload), using: keyD)
        return BASAutoRouteResult(
            value: Array(mac),
            choice: .swiftCryptoKitHMAC)
    }

    /// Auto-routed SHA256。 Switch crossover at ~1 KB based on
    /// measured M-series tournament results。
    public static func sha256(
        _ payload: [UInt8],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[UInt8]> {
        #if os(iOS) || os(macOS)
        let useCryptoKit =
            payload.count >= thresholds.sha256CryptoKitMinBytes
        if useCryptoKit {
            let digest = SHA256.hash(data: Data(payload))
            return BASAutoRouteResult(
                value: Array(digest),
                choice: .swiftCryptoKit)
        }
        // Small-payload path: Rust pure-sha2
        var out = [UInt8](repeating: 0, count: 32)
        let rc = out.withUnsafeMutableBufferPointer { ob in
            payload.withUnsafeBufferPointer { pb in
                bas_substrate_sha256(
                    pb.baseAddress,
                    payload.count,
                    ob.baseAddress)
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: .rustPureSHA256)
        }
        #endif
        // Fallback: Swift CryptoKit (always available on Apple)
        let digest = SHA256.hash(data: Data(payload))
        return BASAutoRouteResult(
            value: Array(digest),
            choice: .swiftCryptoKit)
    }

}
