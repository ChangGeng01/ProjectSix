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

    public init(
        cosineSIMDMinDim: Int = 64,
        sha256CryptoKitMinBytes: Int = 1024,
        attentionMetalMinProduct: Int = 64,
        matMulMetalMinProduct: Int = 262_144,
        layerNormSIMDMinDim: Int = 128,
        geluTanhSIMDMinDim: Int = 256,
        batchedCosineMetalMinRows: Int = 16384
    ) {
        self.cosineSIMDMinDim = max(1, cosineSIMDMinDim)
        self.sha256CryptoKitMinBytes =
            max(1, sha256CryptoKitMinBytes)
        self.attentionMetalMinProduct =
            max(1, attentionMetalMinProduct)
        self.matMulMetalMinProduct =
            max(1, matMulMetalMinProduct)
        self.layerNormSIMDMinDim =
            max(1, layerNormSIMDMinDim)
        self.geluTanhSIMDMinDim =
            max(1, geluTanhSIMDMinDim)
        self.batchedCosineMetalMinRows =
            max(1, batchedCosineMetalMinRows)
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
    /// chapter 七百七 第四刀 — HMAC routing。
    case swiftCryptoKitHMAC
    case rustHMAC
    /// chapter 七百八 第三刀 — MatMul routing。
    case rustMatMulNaive
    case rustMatMulBlocked
    case metalMatMulMPSGraph
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

    // MARK: - Softmax routing (chapter 七百九 第四刀)
    //
    // Measured M-series wins (tournament 七百九 第三刀):
    // softmax is dominated by exp() per-element cost,scalar
    // and SIMD perform within ±5%。 Always use scalar — keeps
    // the dispatch simple,zero regret in practice。
    public static func softmax(
        _ x: [Float]
    ) -> BASAutoRouteResult<[Float]> {
        guard !x.isEmpty else {
            return BASAutoRouteResult(
                value: [],
                choice: .rustSoftmaxScalar)
        }
        var out = [Float](
            repeating: 0, count: x.count)
        #if os(iOS) || os(macOS)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_softmax(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out,
                choice: .rustSoftmaxScalar)
        }
        #endif
        // Swift fallback
        var m = x[0]
        for v in x { if v > m { m = v } }
        var sum: Float = 0
        for (i, v) in x.enumerated() {
            let e = expf(v - m)
            out[i] = e
            sum += e
        }
        if sum > 0 {
            for i in 0..<out.count { out[i] /= sum }
        }
        return BASAutoRouteResult(
            value: out, choice: .swiftNaive)
    }

    // MARK: - LayerNorm routing (chapter 七百九 第四刀)
    //
    // Measured M-series wins:
    //   dim < 128 → Rust naive (no SIMD overhead)
    //   dim ≥ 128 → Rust affine SIMD (1.2-1.9x over naive)
    //
    // Affine variant takes γ + β。 For "plain" LayerNorm
    // (γ=1, β=0) the affine SIMD path still wins above the
    // threshold — only its loop structure changes,not the math。
    public static func layerNormChoice(
        dim: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteChoice {
        if dim < thresholds.layerNormSIMDMinDim {
            return .rustLayerNormNaive
        }
        return .rustLayerNormAffineSIMD
    }

    /// Plain LayerNorm (γ=1,β=0)。 Routes between Rust naive
    /// + Rust affine SIMD (with implicit γ=1, β=0)。
    public static func layerNorm(
        _ x: [Float], eps: Float = 1e-5,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        guard !x.isEmpty else {
            return BASAutoRouteResult(
                value: [],
                choice: .rustLayerNormNaive)
        }
        let choice = layerNormChoice(
            dim: x.count, thresholds: thresholds)
        var out = [Float](
            repeating: 0, count: x.count)
        #if os(iOS) || os(macOS)
        let rc: Int32
        switch choice {
        case .rustLayerNormAffineSIMD:
            let gamma = [Float](
                repeating: 1.0, count: x.count)
            let beta = [Float](
                repeating: 0.0, count: x.count)
            rc = x.withUnsafeBufferPointer { xp in
                gamma.withUnsafeBufferPointer { gp in
                    beta.withUnsafeBufferPointer { bp in
                        out.withUnsafeMutableBufferPointer
                            { op in
                            bas_ranker_layer_norm_affine_simd(
                                xp.baseAddress, x.count,
                                gp.baseAddress, gamma.count,
                                bp.baseAddress, beta.count,
                                op.baseAddress, op.count,
                                eps)
                        }
                    }
                }
            }
        default:
            rc = x.withUnsafeBufferPointer { xp in
                out.withUnsafeMutableBufferPointer { op in
                    bas_ranker_layer_norm(
                        xp.baseAddress, x.count,
                        op.baseAddress, op.count, eps)
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: choice)
        }
        #endif
        // Fallback: Swift naive
        var sum: Float = 0
        for v in x { sum += v }
        let mean = sum / Float(x.count)
        var vsum: Float = 0
        for v in x {
            let d = v - mean
            vsum += d * d
        }
        let variance = vsum / Float(x.count)
        let invStd = 1.0 / (variance + eps).squareRoot()
        for i in 0..<x.count {
            out[i] = (x[i] - mean) * invStd
        }
        return BASAutoRouteResult(
            value: out, choice: .swiftNaive)
    }

    // MARK: - Activations routing (chapter 七百十一 第四刀)
    //
    // Measured M-series wins (chapter 七百十一 第三刀):
    //   gelu_exact   : Rust scalar always (erf cost dominates;
    //                  SIMD unrolling adds <1% benefit at any
    //                  dim,scalar avoids branch)
    //   gelu_tanh    : Rust scalar < 256, Rust SIMD ≥ 256
    //                  (tanh well-vectorized in libm)
    //   silu         : Rust scalar always (sigmoid bottleneck;
    //                  SIMD parity within ±2%)

    /// GELU exact: y = 0.5*x*(1 + erf(x/√2))。 Matches
    /// torch.nn.functional.gelu (default mode)。 Returns
    /// .rustGeluExact on success,.swiftNaive on Rust fallback。
    public static func gelu(
        _ x: [Float],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        guard !x.isEmpty else {
            return BASAutoRouteResult(
                value: [], choice: .rustGeluExact)
        }
        var out = [Float](repeating: 0, count: x.count)
        #if os(iOS) || os(macOS)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_gelu_exact(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: .rustGeluExact)
        }
        #endif
        return BASAutoRouteResult(
            value: geluExactSwiftFallback(x),
            choice: .swiftNaive)
    }

    /// GELU tanh approximation: matches
    /// torch.nn.functional.gelu(approximate="tanh")。 Routes
    /// between Rust scalar + Rust SIMD per
    /// thresholds.geluTanhSIMDMinDim。
    public static func geluTanhApprox(
        _ x: [Float],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        guard !x.isEmpty else {
            return BASAutoRouteResult(
                value: [], choice: .rustGeluTanhScalar)
        }
        let useSIMD =
            x.count >= thresholds.geluTanhSIMDMinDim
        let choice: BASAutoRouteChoice = useSIMD
            ? .rustGeluTanhSIMD : .rustGeluTanhScalar
        var out = [Float](repeating: 0, count: x.count)
        #if os(iOS) || os(macOS)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                if useSIMD {
                    return bas_ranker_gelu_tanh_approx_simd(
                        xp.baseAddress, x.count,
                        op.baseAddress, op.count)
                } else {
                    return bas_ranker_gelu_tanh_approx(
                        xp.baseAddress, x.count,
                        op.baseAddress, op.count)
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: choice)
        }
        #endif
        return BASAutoRouteResult(
            value: geluTanhApproxSwiftFallback(x),
            choice: .swiftNaive)
    }

    /// SiLU (= Swish, beta=1): y = x*σ(x)。 Matches
    /// torch.nn.functional.silu。 Always uses Rust scalar
    /// (SIMD parity within ±2% — scalar saves a branch)。
    public static func silu(
        _ x: [Float],
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        guard !x.isEmpty else {
            return BASAutoRouteResult(
                value: [], choice: .rustSilu)
        }
        var out = [Float](repeating: 0, count: x.count)
        #if os(iOS) || os(macOS)
        let rc = x.withUnsafeBufferPointer { xp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_silu(
                    xp.baseAddress, x.count,
                    op.baseAddress, op.count)
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: .rustSilu)
        }
        #endif
        return BASAutoRouteResult(
            value: siluSwiftFallback(x),
            choice: .swiftNaive)
    }

    // MARK: - Swift activation fallbacks (no XCFramework)

    private static let geluInvSqrt2: Float =
        0.70710678118654752
    private static let geluSqrt2OverPi: Float =
        0.7978845608028654
    private static let geluCubicCoeff: Float = 0.044715

    /// Abramowitz & Stegun 7.1.26 erf — same coefficients as
    /// the Rust impl so the Swift fallback is bit-comparable
    /// (within fp32 rounding) with the routed path。
    private static func erfApproxFallback(_ x: Float) -> Float {
        let p: Float = 0.3275911
        let a1: Float = 0.254829592
        let a2: Float = -0.284496736
        let a3: Float = 1.421413741
        let a4: Float = -1.453152027
        let a5: Float = 1.061405429
        let sign: Float = x < 0 ? -1.0 : 1.0
        let ax = abs(x)
        let t: Float = 1.0 / (1.0 + p * ax)
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t
        let t5 = t4 * t
        let poly = a1 * t + a2 * t2 + a3 * t3
            + a4 * t4 + a5 * t5
        return sign * (1.0 - poly * expf(-(ax * ax)))
    }

    private static func geluExactSwiftFallback(
        _ x: [Float]
    ) -> [Float] {
        var out = [Float](repeating: 0, count: x.count)
        for i in 0..<x.count {
            let v = x[i]
            out[i] = 0.5 * v
                * (1.0
                    + erfApproxFallback(v * geluInvSqrt2))
        }
        return out
    }

    private static func geluTanhApproxSwiftFallback(
        _ x: [Float]
    ) -> [Float] {
        var out = [Float](repeating: 0, count: x.count)
        for i in 0..<x.count {
            let v = x[i]
            let cube = v * v * v
            let inner = geluSqrt2OverPi
                * (v + geluCubicCoeff * cube)
            out[i] = 0.5 * v * (1.0 + tanhf(inner))
        }
        return out
    }

    private static func siluSwiftFallback(
        _ x: [Float]
    ) -> [Float] {
        var out = [Float](repeating: 0, count: x.count)
        for i in 0..<x.count {
            let v = x[i]
            let sig: Float = 1.0 / (1.0 + expf(-v))
            out[i] = v * sig
        }
        return out
    }

    // MARK: - MatMul routing (chapter 七百八 第三刀)
    //
    // Measured M-series wins (BASChapter708MatMulTournamentTests):
    //   8x8x8       → Rust naive   (Metal ~250x slower)
    //   32x32x32    → Rust blocked (Metal still 14x slower)
    //   128x128x128 → Metal       (2x faster than Rust blocked)
    //   512x512x512 → Metal       (18x faster than Rust blocked)
    //
    // Crossover at M*N*K ≈ 262 144 (= 64³)。 Below uses Rust。
    // Within Rust:naive wins for tiny (≤ 8³),blocked above。
    public static func matMulChoice(
        shape: BASMatMulShape,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteChoice {
        let prod = shape.workProduct
        if prod >= thresholds.matMulMetalMinProduct {
            return .metalMatMulMPSGraph
        }
        if prod < 8_192 {
            return .rustMatMulNaive
        }
        return .rustMatMulBlocked
    }

    // MARK: - Attention routing (chapter 七百七 第三刀)
    //
    // Pure-policy helper — returns the CHOICE the router would
    // pick at this shape。 The actual Swift dispatcher lives on
    // BASCognitiveBrain because it needs the actor's memoized
    // Metal pipeline state。 Hosts compose like this:
    //
    //   let choice = BASAutoRouteRanker.attentionChoice(
    //       shape: BASAttentionShape(...), thresholds: ...)
    //   switch choice {
    //   case .swiftCPUAttention: …call CPU path…
    //   case .metalFlashAttention: …call Metal flashAttention…
    //   default: …
    //   }
    //
    // Auto-routed `brain.attentionAuto(...)` does this internally。
    public static func attentionChoice(
        shape: BASAttentionShape,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteChoice {
        // Tiny workloads → CPU wins because Metal pipeline
        // dispatch overhead (~150 μs) dominates the compute。
        if shape.workProduct
            < thresholds.attentionMetalMinProduct
        {
            return .swiftCPUAttention
        }
        // FlashAttention dominates the standard kernel at
        // every shape where Metal beats CPU,so always pick
        // it when going to GPU。 Head-dim cap (64) is enforced
        // by the dispatcher;callers exceeding it should
        // explicitly use .metalStandardAttention via the
        // standard `brain.attention(...)` entry。
        return .metalFlashAttention
    }

    /// CPU reference attention — pure-function。 Provides the
    /// fallback when Metal isn't available + the slow-but-
    /// correct ground truth for cross-impl byte-equality tests。
    public static func cpuAttention(
        q: [Float], M: Int, D: Int,
        k: [Float], N: Int,
        v: [Float], Dv: Int
    ) -> [Float] {
        let invSqrtD = 1.0 / Float(D).squareRoot()
        var out = [Float](repeating: 0, count: M * Dv)
        for i in 0..<M {
            var scaled = [Float](
                repeating: 0, count: N)
            var maxScore: Float = -.infinity
            for kk in 0..<N {
                var dot: Float = 0
                for d in 0..<D {
                    dot += q[i * D + d]
                        * k[kk * D + d]
                }
                scaled[kk] = dot * invSqrtD
                if scaled[kk] > maxScore {
                    maxScore = scaled[kk]
                }
            }
            var expSum: Float = 0
            var exps = [Float](repeating: 0, count: N)
            for kk in 0..<N {
                exps[kk] = exp(scaled[kk] - maxScore)
                expSum += exps[kk]
            }
            for j in 0..<Dv {
                var acc: Float = 0
                for kk in 0..<N {
                    acc += (exps[kk] / expSum)
                        * v[kk * Dv + j]
                }
                out[i * Dv + j] = acc
            }
        }
        return out
    }

    // MARK: - Forget cascade routing (chapter 七百十三 第四刀)
    //
    // Per matrix「Rust:forget cascade」 — set-difference
    // partition with O(N+M) HashSet membership。 Routes always
    // through Rust;Swift fallback preserved for non-Apple
    // platforms。

    /// Partition `recordIds` against `targetIds`,returning
    /// (kept,removed) index lists in input order。
    public static func forgetCascadeFilter(
        recordIds: [String],
        targetIds: [String]
    ) -> BASAutoRouteResult<(
        kept: [Int], removed: [Int]
    )> {
        #if os(iOS) || os(macOS)
        // Encode IDs as length-prefixed UTF-8 flat buffers。
        let recordBuf = encodeLengthPrefixedStrings(recordIds)
        let targetBuf = encodeLengthPrefixedStrings(targetIds)
        var kept = [Int](
            repeating: 0, count: recordIds.count)
        var removed = [Int](
            repeating: 0, count: recordIds.count)
        var keptCount: Int = 0
        var removedCount: Int = 0
        let rc = recordBuf.withUnsafeBytes { rbuf in
            targetBuf.withUnsafeBytes { tbuf in
                kept.withUnsafeMutableBufferPointer { kp in
                    removed.withUnsafeMutableBufferPointer
                        { rp in
                        bas_ranker_forget_cascade_filter(
                            recordIds.isEmpty
                                ? nil
                                : rbuf.bindMemory(
                                    to: UInt8.self)
                                    .baseAddress,
                            recordBuf.count,
                            recordIds.count,
                            targetIds.isEmpty
                                ? nil
                                : tbuf.bindMemory(
                                    to: UInt8.self)
                                    .baseAddress,
                            targetBuf.count,
                            targetIds.count,
                            kp.baseAddress,
                            rp.baseAddress,
                            &keptCount,
                            &removedCount)
                    }
                }
            }
        }
        if rc == 0 {
            let keptOut = Array(kept.prefix(keptCount))
            let removedOut = Array(
                removed.prefix(removedCount))
            return BASAutoRouteResult(
                value: (kept: keptOut, removed: removedOut),
                choice: .rustForgetCascadeFilter)
        }
        #endif
        // Swift fallback: same algorithm,no FFI hop。
        let targetSet = Set(targetIds)
        var keptSwift: [Int] = []
        var removedSwift: [Int] = []
        keptSwift.reserveCapacity(recordIds.count)
        for (i, id) in recordIds.enumerated() {
            if targetSet.contains(id) {
                removedSwift.append(i)
            } else {
                keptSwift.append(i)
            }
        }
        return BASAutoRouteResult(
            value: (kept: keptSwift, removed: removedSwift),
            choice: .swiftForgetCascadeFallback)
    }

    // MARK: - Provenance gate routing (chapter 七百十三 第四刀)
    //
    // Per matrix「Rust:provenance + integrity hash」 —
    // typed-attestation-tier filter。 Routes always through Rust;
    // Swift fallback preserves the same decision tree。

    /// Evaluate one provenance envelope。 Returns the typed
    /// decision + routing choice。
    public static func provenanceFilter(
        trainingCorpusHashHex: String,
        trainedWeightsHashHex: String,
        tier: BASProvenanceTier,
        hasAttestationSignatureRef: Bool,
        hasAttestationIssuedAt: Bool
    ) -> BASAutoRouteResult<BASProvenanceGateDecision> {
        #if os(iOS) || os(macOS)
        let tc = Array(trainingCorpusHashHex.utf8)
        let tw = Array(trainedWeightsHashHex.utf8)
        let rc = tc.withUnsafeBufferPointer { tcp in
            tw.withUnsafeBufferPointer { twp in
                bas_ranker_provenance_rejection_code(
                    tcp.baseAddress, tc.count,
                    twp.baseAddress, tw.count,
                    tier.rawValue,
                    hasAttestationSignatureRef ? 1 : 0,
                    hasAttestationIssuedAt ? 1 : 0)
            }
        }
        if rc >= 0 {
            return BASAutoRouteResult(
                value: BASProvenanceGateDecision(
                    rustExitCode: rc),
                choice: .rustProvenanceFilter)
        }
        #endif
        // Swift fallback — same decision tree as Rust。
        return BASAutoRouteResult(
            value: swiftProvenanceDecision(
                trainingCorpusHashHex:
                    trainingCorpusHashHex,
                trainedWeightsHashHex:
                    trainedWeightsHashHex,
                tier: tier,
                hasAttestationSignatureRef:
                    hasAttestationSignatureRef,
                hasAttestationIssuedAt:
                    hasAttestationIssuedAt),
            choice: .swiftProvenanceFallback)
    }

    private static func swiftProvenanceDecision(
        trainingCorpusHashHex: String,
        trainedWeightsHashHex: String,
        tier: BASProvenanceTier,
        hasAttestationSignatureRef: Bool,
        hasAttestationIssuedAt: Bool
    ) -> BASProvenanceGateDecision {
        if trainingCorpusHashHex.count != 64 {
            return .malformedHashLengthTrainingCorpus
        }
        if trainedWeightsHashHex.count != 64 {
            return .malformedHashLengthTrainedWeights
        }
        if !isAllHex(trainingCorpusHashHex) {
            return .malformedHashContentTrainingCorpus
        }
        if !isAllHex(trainedWeightsHashHex) {
            return .malformedHashContentTrainedWeights
        }
        if tier.rawValue
            < BASProvenanceTier.domainExpertReviewed.rawValue
        {
            if hasAttestationSignatureRef {
                return .nonProductionTierCarriesAttestation
            }
            return .belowProductionTier
        }
        if !hasAttestationSignatureRef
            || !hasAttestationIssuedAt
        {
            return .missingAttestationForProductionTier
        }
        return .permitted
    }

    private static func isAllHex(_ s: String) -> Bool {
        for ch in s where !ch.isHexDigit { return false }
        return true
    }

    /// Encode `[String]` as a length-prefixed UTF-8 flat
    /// buffer。 Wire format:concatenation of `[u32_be len]
    /// [utf8 bytes]` records。 Used by the C ABI bridges for
    /// forget-cascade + ledger paths。
    private static func encodeLengthPrefixedStrings(
        _ strs: [String]
    ) -> Data {
        var buf = Data()
        for s in strs {
            let bytes = Array(s.utf8)
            var lenBE = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &lenBE) {
                buf.append(contentsOf: $0)
            }
            buf.append(contentsOf: bytes)
        }
        return buf
    }

    // MARK: - Batched cosine routing (chapter 七百十五 第四刀)
    //
    // Per matrix「Metal:embedding similarity」 — but per
    // chapter 七百十五 第三刀 tournament: Rust SIMD wins at all
    // measured sizes on Apple M-series。 Routing decision
    // (Rust vs Metal) is pure-policy here;the dispatch is
    // synchronous Rust at all sizes below
    // `batchedCosineMetalMinRows`。 Metal dispatch requires an
    // async dispatcher,exposed via a separate brain helper
    // that takes the dispatcher as a parameter。

    /// Pure-policy helper returning the routing CHOICE for a
    /// given (corpus_rows × dim) shape。
    public static func batchedCosineChoice(
        corpusRows: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteChoice {
        if corpusRows >= thresholds.batchedCosineMetalMinRows
        {
            return .metalBatchedCosine
        }
        return .rustBatchedCosine
    }

    /// Synchronous Rust-SIMD batched cosine。 Returns
    /// (scores[n_rows], choice)。 Always routes to Rust here;
    /// callers wanting the Metal fallback must use the brain
    /// helper that takes a dispatcher (chapter 七百十五 第四刀
    /// `BASCognitiveBrain.batchedCosineAuto`)。
    public static func batchedCosineSimilarity(
        query: [Float],
        corpus: [Float],
        dim: Int,
        thresholds: BASAutoRouteThresholds = .mSeriesDefault
    ) -> BASAutoRouteResult<[Float]> {
        precondition(dim > 0,
            "dim must be positive")
        precondition(query.count == dim,
            "query length must equal dim")
        precondition(corpus.count % dim == 0,
            "corpus length must be multiple of dim")
        let nRows = corpus.count / dim
        guard nRows > 0 else {
            return BASAutoRouteResult(
                value: [], choice: .rustBatchedCosine)
        }
        var scores = [Float](repeating: 0, count: nRows)
        #if os(iOS) || os(macOS)
        let rc = query.withUnsafeBufferPointer { qp in
            corpus.withUnsafeBufferPointer { cp in
                scores
                    .withUnsafeMutableBufferPointer { op in
                    bas_ranker_batched_cosine_simd(
                        qp.baseAddress, query.count,
                        cp.baseAddress, corpus.count,
                        dim,
                        op.baseAddress)
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: scores,
                choice: .rustBatchedCosine)
        }
        #endif
        // Pure-Swift fallback (no FFI hop)
        return BASAutoRouteResult(
            value: swiftBatchedCosineFallback(
                query: query, corpus: corpus, dim: dim),
            choice: .swiftNaive)
    }

    private static func swiftBatchedCosineFallback(
        query: [Float], corpus: [Float], dim: Int
    ) -> [Float] {
        let nRows = corpus.count / dim
        var out = [Float](repeating: 0, count: nRows)
        var normQ: Float = 0
        for d in 0..<dim { normQ += query[d] * query[d] }
        let invNormQ: Float = normQ > 0
            ? 1.0 / normQ.squareRoot() : 0
        for r in 0..<nRows {
            var dot: Float = 0
            var normR: Float = 0
            let base = r * dim
            for d in 0..<dim {
                let rd = corpus[base + d]
                dot += query[d] * rd
                normR += rd * rd
            }
            if normR <= 0 {
                out[r] = 0
            } else {
                let invNormR: Float =
                    1.0 / normR.squareRoot()
                out[r] = dot * invNormQ * invNormR
            }
        }
        return out
    }

    // MARK: - Ledger routing (chapter 七百十二 第四刀)
    //
    // Per architectural matrix「Rust owns ledger/replay +
    // integrity hash」 + tournament 七百十二 第三刀:Rust batch
    // wins at every chain depth (5-8× over CryptoKit chain,
    // 1.3× over Rust per-entry FFI)。 No crossover threshold
    // needed — always route to Rust。 Swift CryptoKit kept as
    // a fallback for non-Apple platforms where the XCFramework
    // isn't available。

    /// Outcome of a chain-verify call。 `valid` carries the
    /// final tip hash when all entries verified;
    /// `firstMismatch` is the 0-based index of the first failed
    /// entry。
    public enum BASLedgerVerifyOutcome: Sendable, Equatable {
        case valid(tipHash: [UInt8])
        case firstMismatch(index: Int)
    }

    /// One-shot ledger seal: y = SHA256(canonical)。 Matches
    /// Swift CryptoKit byte-for-byte。 Returns the 32-byte
    /// digest + the routing choice。
    public static func ledgerSeal(
        _ canonical: [UInt8]
    ) -> BASAutoRouteResult<[UInt8]> {
        var out = [UInt8](repeating: 0, count: 32)
        #if os(iOS) || os(macOS)
        let rc = canonical.withUnsafeBufferPointer { cp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_ledger_seal(
                    cp.baseAddress, canonical.count,
                    op.baseAddress)
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: .rustLedgerSeal)
        }
        #endif
        // Fallback: Swift CryptoKit。 Bit-equal output since
        // SHA256 is fully specified by NIST FIPS 180-4。
        let d = SHA256.hash(data: Data(canonical))
        return BASAutoRouteResult(
            value: [UInt8](d),
            choice: .swiftCryptoKitLedgerSeal)
    }

    /// Batch ledger seal: for each of N records,write the
    /// 32-byte SHA256(canonical_i) into the corresponding slot
    /// of the returned [[UInt8]]。 Used by the substrate's
    /// audit-ledger append path to seal multiple entries in
    /// one FFI hop (chapter 七百十二 第三刀:1.3× over per-entry
    /// Rust at depth 256+)。
    public static func ledgerSealBatch(
        initialHash: [UInt8],
        canonicals: [[UInt8]]
    ) -> BASAutoRouteResult<[[UInt8]]> {
        precondition(initialHash.count == 32,
            "initialHash must be 32 bytes")
        guard !canonicals.isEmpty else {
            return BASAutoRouteResult(
                value: [], choice: .rustLedgerSealBatch)
        }
        #if os(iOS) || os(macOS)
        // Encode canonicals as length-prefixed flat buffer。
        var buf = Data()
        for c in canonicals {
            var lenBE = UInt32(c.count).bigEndian
            withUnsafeBytes(of: &lenBE) {
                buf.append(contentsOf: $0)
            }
            buf.append(contentsOf: c)
        }
        var outFlat = [UInt8](
            repeating: 0, count: canonicals.count * 32)
        let rc = initialHash.withUnsafeBufferPointer { ip in
            buf.withUnsafeBytes { bp in
                outFlat
                    .withUnsafeMutableBufferPointer { op in
                    bas_ranker_ledger_seal_batch(
                        ip.baseAddress,
                        bp.bindMemory(to: UInt8.self)
                            .baseAddress,
                        buf.count,
                        canonicals.count,
                        op.baseAddress)
                }
            }
        }
        if rc == 0 {
            // Slice flat buffer into [[UInt8]]。
            var hashes: [[UInt8]] = []
            hashes.reserveCapacity(canonicals.count)
            for i in 0..<canonicals.count {
                hashes.append(Array(
                    outFlat[i * 32..<(i + 1) * 32]))
            }
            return BASAutoRouteResult(
                value: hashes,
                choice: .rustLedgerSealBatch)
        }
        #endif
        // Fallback: per-entry CryptoKit
        var hashes: [[UInt8]] = []
        hashes.reserveCapacity(canonicals.count)
        for c in canonicals {
            let d = SHA256.hash(data: Data(c))
            hashes.append([UInt8](d))
        }
        return BASAutoRouteResult(
            value: hashes,
            choice: .swiftCryptoKitLedgerSeal)
    }

    /// Verify an N-entry chain。 Each record's canonical bytes
    /// are hashed and compared against the corresponding entry
    /// of `expectedSelfHashes`。 Returns the chain tip on
    /// success or the first failing index on tamper detection。
    public static func ledgerVerifyChain(
        initialHash: [UInt8],
        canonicals: [[UInt8]],
        expectedSelfHashes: [[UInt8]]
    ) -> BASAutoRouteResult<BASLedgerVerifyOutcome> {
        precondition(initialHash.count == 32,
            "initialHash must be 32 bytes")
        precondition(
            canonicals.count == expectedSelfHashes.count,
            "canonicals + expected must match length")
        guard !canonicals.isEmpty else {
            return BASAutoRouteResult(
                value: .valid(tipHash: initialHash),
                choice: .rustLedgerVerifyChain)
        }
        #if os(iOS) || os(macOS)
        var buf = Data()
        for c in canonicals {
            var lenBE = UInt32(c.count).bigEndian
            withUnsafeBytes(of: &lenBE) {
                buf.append(contentsOf: $0)
            }
            buf.append(contentsOf: c)
        }
        var expectedFlat = [UInt8]()
        expectedFlat.reserveCapacity(
            expectedSelfHashes.count * 32)
        for h in expectedSelfHashes {
            precondition(h.count == 32,
                "each expected hash must be 32 bytes")
            expectedFlat.append(contentsOf: h)
        }
        var outTip = [UInt8](repeating: 0, count: 32)
        let rc = initialHash.withUnsafeBufferPointer { ip in
            buf.withUnsafeBytes { bp in
                expectedFlat
                    .withUnsafeBufferPointer { ep in
                    outTip
                        .withUnsafeMutableBufferPointer { op in
                        bas_ranker_ledger_verify_chain(
                            ip.baseAddress,
                            bp.bindMemory(to: UInt8.self)
                                .baseAddress,
                            buf.count,
                            ep.baseAddress,
                            canonicals.count,
                            op.baseAddress)
                    }
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: .valid(tipHash: outTip),
                choice: .rustLedgerVerifyChain)
        }
        if rc > 0 {
            return BASAutoRouteResult(
                value: .firstMismatch(index: Int(rc) - 1),
                choice: .rustLedgerVerifyChain)
        }
        // rc < 0 — fall through to Swift fallback。
        #endif
        // Fallback: per-entry CryptoKit verify。
        for i in 0..<canonicals.count {
            let d = [UInt8](
                SHA256.hash(data: Data(canonicals[i])))
            if d != expectedSelfHashes[i] {
                return BASAutoRouteResult(
                    value: .firstMismatch(index: i),
                    choice: .swiftCryptoKitLedgerSeal)
            }
        }
        return BASAutoRouteResult(
            value: .valid(
                tipHash: expectedSelfHashes.last!),
            choice: .swiftCryptoKitLedgerSeal)
    }

    // MARK: - Hex encoder (chapter 七百十九 第一刀)
    //
    // Per matrix「Rust:integrity hash」 — and per chapter
    // 七百十九 measurement, Rust lookup-table hex encoder is
    // ~25× faster than Swift's `String(format: "%02x", byte)`
    // per-byte loop。 Centralized helper replaces 10+ scattered
    // Swift idiom call sites。

    /// Encode `bytes` as a lowercase hex string。 Byte-equivalent
    /// to `bytes.map { String(format: "%02x", $0) }.joined()` —
    /// pinned by BASChapter719HexEncoderTests。 Uses Rust
    /// lookup-table when the XCFramework is available;Swift
    /// fallback otherwise。
    public static func bytesToHexLower(
        _ bytes: [UInt8]
    ) -> String {
        guard !bytes.isEmpty else { return "" }
        #if os(iOS) || os(macOS)
        var out = [UInt8](
            repeating: 0, count: bytes.count * 2)
        let rc = bytes.withUnsafeBufferPointer { bp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_bytes_to_hex_lower(
                    bp.baseAddress, bytes.count,
                    op.baseAddress, op.count)
            }
        }
        if rc == 0 {
            // Output is pure ASCII so `String(decoding:as:)`
            // never fails;use `String(bytes:encoding:)` for
            // a stable failure mode just in case。
            return String(
                bytes: out, encoding: .ascii) ?? ""
        }
        #endif
        // Swift fallback — same idiom as the legacy call sites
        return bytes.map {
            String(format: "%02x", $0) }.joined()
    }

    /// Convenience overload for `Data`。
    public static func dataToHexLower(_ data: Data) -> String {
        return bytesToHexLower(Array(data))
    }

    /// chapter 七百二十一 第一刀 — Rust hex decoder。
    /// Decode lowercase or uppercase hex ASCII into bytes。
    /// Returns nil on odd length OR any non-hex character。
    /// ~40-60× faster than Swift's
    /// `hex.chunks().map { UInt8($0, radix: 16) }` idiom。
    public static func hexToBytes(_ hex: String) -> [UInt8]? {
        let hexBytes = Array(hex.utf8)
        guard !hexBytes.isEmpty else { return [] }
        #if os(iOS) || os(macOS)
        let need = hexBytes.count / 2
        var out = [UInt8](repeating: 0, count: need)
        let rc = hexBytes.withUnsafeBufferPointer { hp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_hex_to_bytes(
                    hp.baseAddress, hexBytes.count,
                    op.baseAddress, op.count)
            }
        }
        if rc >= 0 { return out }
        // rc < 0 → either malformed input OR FFI failure;
        // fall through to Swift validator so the API is
        // consistent (returns nil on malformed input)。
        #endif
        // Swift fallback — same shape as legacy idiom。
        guard hexBytes.count % 2 == 0 else { return nil }
        var fallback: [UInt8] = []
        fallback.reserveCapacity(hexBytes.count / 2)
        var i = 0
        while i < hexBytes.count {
            guard let hi = hexNibble(hexBytes[i]),
                  let lo = hexNibble(hexBytes[i + 1])
            else { return nil }
            fallback.append((hi << 4) | lo)
            i += 2
        }
        return fallback
    }

    /// Convenience overload returning `Data`。
    public static func hexToData(_ hex: String) -> Data? {
        guard let bytes = hexToBytes(hex) else { return nil }
        return Data(bytes)
    }

    private static func hexNibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 0x30...0x39: return c - 0x30  // '0'-'9'
        case 0x61...0x66: return c - 0x61 + 10  // 'a'-'f'
        case 0x41...0x46: return c - 0x41 + 10  // 'A'-'F'
        default: return nil
        }
    }

    // MARK: - BPE tokenizer (chapter 七百二十二 第二刀 / M2282)
    //
    // Substrate's first on-device tokenizer。 Routes through the
    // bas-tokenizer Rust crate via the BASRustMemoryTracker
    // XCFramework's bundled C ABI。 No Swift baseline — net-new
    // capability per the chapter 七百二十一-七百三十 aggressive
    // evolution arc (delegated to external LLM providers until now)。
    //
    // Knife 2 surface:thin pass-through helpers that take a
    // `BASBpeTokenizerHandle` (caller owns vocab loading)。
    // Knife 4 will add `BASBpeTokenizer` Swift bridge actor with
    // bundle-resource vocab loading + thread-safe convenience API。

    /// ABI version of the bundled bas-tokenizer crate。 Pinned at
    /// 1 by `TOKENIZER_ABI_VERSION` in `Cargo/bas-tokenizer/src/
    /// lib.rs`。 Drift tests assert this matches the Rust-side
    /// constant so a future ABI bump cannot silently land。
    public static let bpeTokenizerExpectedABIVersion: Int32 = 1

    /// Returns the bas-tokenizer ABI version that the XCFramework
    /// was built against。 Pure pass-through to the Rust
    /// `bas_tokenizer_abi_version()` symbol。
    public static func bpeTokenizerABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_tokenizer_abi_version()
        #else
        return 0
        #endif
    }

    /// Encode `text` into BPE token IDs using `tokenizer`。
    /// Returns `nil` only when the FFI rejects the input (invalid
    /// UTF-8 — extremely unlikely for `String.utf8` source)。
    ///
    /// Two-pass implementation:first call with capacity 0 to
    /// discover the true ID count,then a second call with the
    /// exact-sized buffer。 Mirrors how Rust returns "needed"
    /// even when output capacity is 0。 No leaks across the FFI
    /// boundary because Swift owns the output buffer。
    public static func bpeEncode(
        _ text: String,
        tokenizer: BASBpeTokenizerHandle
    ) -> [UInt32]? {
        #if os(iOS) || os(macOS)
        guard let raw = tokenizer.opaqueHandle else {
            return nil
        }
        let textBytes = Array(text.utf8)
        // Phase 1:discover required capacity。
        let needed = textBytes.withUnsafeBufferPointer { tp in
            return bas_tokenizer_encode(
                raw,
                tp.baseAddress, textBytes.count,
                nil, 0)
        }
        if needed < 0 { return nil }
        if needed == 0 { return [] }
        // Phase 2:fill the exact-sized buffer。
        var out = [UInt32](
            repeating: 0, count: Int(needed))
        let wrote = textBytes.withUnsafeBufferPointer { tp in
            return out.withUnsafeMutableBufferPointer { op in
                return bas_tokenizer_encode(
                    raw,
                    tp.baseAddress, textBytes.count,
                    op.baseAddress, op.count)
            }
        }
        guard wrote == needed else { return nil }
        return out
        #else
        return nil
        #endif
    }

    /// Decode `ids` back into a UTF-8 string via `tokenizer`。
    /// Returns `nil` when the token IDs decode to a non-UTF-8
    /// byte sequence (or the FFI signals a null pointer)。
    public static func bpeDecode(
        _ ids: [UInt32],
        tokenizer: BASBpeTokenizerHandle
    ) -> String? {
        #if os(iOS) || os(macOS)
        guard let raw = tokenizer.opaqueHandle else {
            return nil
        }
        if ids.isEmpty { return "" }
        // Phase 1:discover required byte capacity。
        let needed = ids.withUnsafeBufferPointer { ip in
            return bas_tokenizer_decode(
                raw,
                ip.baseAddress, ids.count,
                nil, 0)
        }
        if needed < 0 { return nil }
        if needed == 0 { return "" }
        // Phase 2:fill the exact-sized buffer。
        var out = [UInt8](
            repeating: 0, count: Int(needed))
        let wrote = ids.withUnsafeBufferPointer { ip in
            return out.withUnsafeMutableBufferPointer { op in
                return bas_tokenizer_decode(
                    raw,
                    ip.baseAddress, ids.count,
                    op.baseAddress, op.count)
            }
        }
        guard wrote == needed else { return nil }
        return String(decoding: out, as: UTF8.self)
        #else
        return nil
        #endif
    }

    /// Vocab size of the tokenizer handle (or -1 on null
    /// handle / FFI error)。
    public static func bpeVocabSize(
        _ tokenizer: BASBpeTokenizerHandle
    ) -> Int {
        #if os(iOS) || os(macOS)
        guard let raw = tokenizer.opaqueHandle else {
            return -1
        }
        return Int(bas_tokenizer_vocab_size(raw))
        #else
        return -1
        #endif
    }

    // MARK: - Importance scorer (chapter 七百二十三 第二刀 / M2287)
    //
    // Routes through the bas-retrieval-ranker Rust crate's
    // `bas_ranker_importance_score_all` FFI。 Wire format matches
    // the Rust-side documentation in the header (BIG-ENDIAN
    // length prefixes,LE f64 values)。
    //
    // BASRuntimeCore-local input/output types so the bridge stays
    // independent of BASMemory's `BASMemoryUsageRecord` —
    // BASMemory side adds a thin adapter when wiring through
    // BASMemoryImportanceScorer (Knife 3)。

    public enum BASImportanceTier: UInt8, Sendable, Equatable {
        case cold = 0
        case warm = 1
        case hot  = 2
    }

    public enum BASImportanceHelpedFlag: UInt8, Sendable, Equatable
    {
        case notHelped = 0
        case helped    = 1
        case unknown   = 2
    }

    public struct BASImportanceRecord: Sendable, Equatable {
        public let atomID: String
        public let retrievedAtMs: Int64
        public let helpedFlag: BASImportanceHelpedFlag
        public init(
            atomID: String,
            retrievedAtMs: Int64,
            helpedFlag: BASImportanceHelpedFlag
        ) {
            self.atomID = atomID
            self.retrievedAtMs = retrievedAtMs
            self.helpedFlag = helpedFlag
        }
    }

    public struct BASImportanceTunables: Sendable, Equatable {
        public let promoteThreshold: Double
        public let demoteThreshold: Double
        public let recencyHalfLifeSeconds: Double
        public let frequencySaturation: Double
        public let tierDecayHot: Double
        public let tierDecayWarm: Double
        public let tierDecayCold: Double
        public init(
            promoteThreshold: Double = 0.65,
            demoteThreshold: Double = 0.20,
            recencyHalfLifeSeconds: Double = 86400.0,
            frequencySaturation: Double = 50.0,
            tierDecayHot: Double = 1.0,
            tierDecayWarm: Double = 0.7,
            tierDecayCold: Double = 0.4
        ) {
            self.promoteThreshold = promoteThreshold
            self.demoteThreshold = demoteThreshold
            self.recencyHalfLifeSeconds = recencyHalfLifeSeconds
            self.frequencySaturation = frequencySaturation
            self.tierDecayHot = tierDecayHot
            self.tierDecayWarm = tierDecayWarm
            self.tierDecayCold = tierDecayCold
        }
    }

    public struct BASImportanceScore: Sendable, Equatable {
        public let atomID: String
        public let currentTier: BASImportanceTier
        public let recencyComponent: Double
        public let frequencyComponent: Double
        public let helpedComponent: Double
        public let tierDecayComponent: Double
        public let totalScore: Double
        public let recommendedTier: BASImportanceTier
        public let recordCount: Int
        public let computedAtMs: Int64
    }

    /// Rust-routed `score_all`。 Returns nil when the XCFramework
    /// is unavailable (watchOS) or the FFI rejects malformed
    /// inputs (extremely unlikely from typed Swift sources)。
    public static func importanceScoreAll(
        records: [BASImportanceRecord],
        tiers: [(atomID: String, tier: BASImportanceTier)],
        tunables: BASImportanceTunables =
            BASImportanceTunables(),
        nowMs: Int64
    ) -> [BASImportanceScore]? {
        #if os(iOS) || os(macOS)
        let recordsBuf = encodeRecordsBuffer(records)
        let tiersBuf   = encodeTiersBuffer(tiers)
        let tunablesBuf = encodeTunablesBuffer(tunables)

        return recordsBuf.withUnsafeBufferPointer { rp in
            return tiersBuf.withUnsafeBufferPointer { tp in
                return tunablesBuf.withUnsafeBufferPointer { up in
                    // Two-phase:discover then fill。
                    let needed = bas_ranker_importance_score_all(
                        rp.baseAddress, recordsBuf.count,
                        tp.baseAddress, tiersBuf.count,
                        up.baseAddress, tunablesBuf.count,
                        nowMs,
                        nil, 0)
                    if needed < 0 { return nil }
                    if needed == 0 { return [] }
                    var outBuf = [UInt8](
                        repeating: 0, count: Int(needed))
                    let wrote = outBuf
                        .withUnsafeMutableBufferPointer { op in
                            return bas_ranker_importance_score_all(
                                rp.baseAddress, recordsBuf.count,
                                tp.baseAddress, tiersBuf.count,
                                up.baseAddress, tunablesBuf.count,
                                nowMs,
                                op.baseAddress, op.count)
                        }
                    guard wrote == needed else { return nil }
                    return decodeScoresBuffer(outBuf)
                }
            }
        }
        #else
        return nil
        #endif
    }

    // MARK: - int8 cosine retrieval (chapter 七百二十七 第二刀 / M2307)

    /// Cosine between two int8-quantized vectors。 Returns nil on
    /// FFI failure or length mismatch。
    public static func cosineInt8(
        a: [Int8], scaleA: Float,
        b: [Int8], scaleB: Float
    ) -> Float? {
        #if os(iOS) || os(macOS)
        guard a.count == b.count else { return nil }
        var out: Float = 0
        let rc = a.withUnsafeBufferPointer { ap in
            return b.withUnsafeBufferPointer { bp in
                return bas_ranker_cosine_int8(
                    ap.baseAddress, ap.count, scaleA,
                    bp.baseAddress, bp.count, scaleB,
                    &out)
            }
        }
        if rc != 0 { return nil }
        return out
        #else
        return nil
        #endif
    }

    /// Batched cosine across many int8-quantized corpus rows。
    /// `corpus` is n_rows × dim contiguous;`corpusScales` has
    /// one f32 per row。 Returns one cosine per row,or nil on
    /// shape error / FFI failure。
    public static func batchedCosineInt8(
        query: [Int8], scaleQuery: Float,
        corpus: [Int8], corpusScales: [Float],
        dim: Int
    ) -> [Float]? {
        #if os(iOS) || os(macOS)
        guard dim > 0,
              query.count == dim,
              corpus.count % dim == 0
        else { return nil }
        let nRows = corpus.count / dim
        guard corpusScales.count == nRows else { return nil }
        var scores = [Float](repeating: 0, count: nRows)
        let rc = query.withUnsafeBufferPointer { qp in
            return corpus.withUnsafeBufferPointer { cp in
                return corpusScales
                    .withUnsafeBufferPointer { sp in
                        return scores
                        .withUnsafeMutableBufferPointer { op in
                            return bas_ranker_batched_cosine_int8(
                                qp.baseAddress, qp.count, scaleQuery,
                                cp.baseAddress, cp.count,
                                sp.baseAddress, sp.count,
                                dim,
                                op.baseAddress, op.count)
                        }
                }
            }
        }
        if rc != 0 { return nil }
        return scores
        #else
        return nil
        #endif
    }

    // MARK: - int8 quantization (chapter 七百二十六 第二刀 / M2302)
    //
    // Net-new capability: substrate gains symmetric int8 quantize
    // / dequantize / matmul primitives。 Foundation for chapters
    // 七百二十七 (int8 vector storage) + 七百二十八 (int8 KV cache)。

    /// Result of quantization: int8 buffer + scale。
    public struct BASQuantizeInt8Result: Sendable, Equatable {
        public let quantized: [Int8]
        public let scale: Float
        public init(quantized: [Int8], scale: Float) {
            self.quantized = quantized
            self.scale = scale
        }
    }

    /// Symmetric int8 quantize。 Returns (int8 buffer + scale)
    /// or nil on FFI failure。
    public static func quantizeInt8(
        _ x: [Float]
    ) -> BASQuantizeInt8Result? {
        #if os(iOS) || os(macOS)
        if x.isEmpty {
            return BASQuantizeInt8Result(
                quantized: [], scale: 0)
        }
        var quantized = [Int8](repeating: 0, count: x.count)
        var scale: Float = 0
        let rc = x.withUnsafeBufferPointer { xp in
            return quantized.withUnsafeMutableBufferPointer { qp in
                return bas_ranker_quantize_int8(
                    xp.baseAddress, xp.count,
                    qp.baseAddress, qp.count,
                    &scale)
            }
        }
        if rc != 0 { return nil }
        return BASQuantizeInt8Result(
            quantized: quantized, scale: scale)
        #else
        return nil
        #endif
    }

    /// Dequantize int8 + scale back to Float32。 Returns nil on
    /// FFI failure。
    public static func dequantizeInt8(
        _ q: [Int8], scale: Float
    ) -> [Float]? {
        #if os(iOS) || os(macOS)
        if q.isEmpty { return [] }
        var out = [Float](repeating: 0, count: q.count)
        let rc = q.withUnsafeBufferPointer { qp in
            return out.withUnsafeMutableBufferPointer { op in
                return bas_ranker_dequantize_int8(
                    qp.baseAddress, qp.count, scale,
                    op.baseAddress, op.count)
            }
        }
        if rc != 0 { return nil }
        return out
        #else
        return nil
        #endif
    }

    /// int8 × int8 matmul → Float32。 A (m×k) × B (k×n) = C (m×n),
    /// all row-major。 Returns nil on shape mismatch or FFI failure。
    public static func matmulInt8(
        a: [Int8], scaleA: Float,
        b: [Int8], scaleB: Float,
        m: Int, k: Int, n: Int
    ) -> [Float]? {
        #if os(iOS) || os(macOS)
        guard a.count == m * k,
              b.count == k * n
        else { return nil }
        var c = [Float](repeating: 0, count: m * n)
        let rc = a.withUnsafeBufferPointer { ap in
            return b.withUnsafeBufferPointer { bp in
                return c.withUnsafeMutableBufferPointer { cp in
                    return bas_ranker_matmul_int8(
                        ap.baseAddress, ap.count, scaleA,
                        bp.baseAddress, bp.count, scaleB,
                        m, k, n,
                        cp.baseAddress, cp.count)
                }
            }
        }
        if rc != 0 { return nil }
        return c
        #else
        return nil
        #endif
    }

    // MARK: - Aggregations (chapter 七百二十五 第二刀 / M2297)
    //
    // Routes through the chapter 七百二十五 第一刀 Rust
    // `aggregations::usage_count_for_atom`。 Reuses the chapter
    // 七百二十三 records wire format。

    /// Rust-routed `usageCount(forAtomID:)`。 Returns nil only on
    /// FFI failure (extremely unlikely from typed Swift input)。
    public static func usageCountForAtom(
        records: [BASImportanceRecord],
        atomID: String
    ) -> Int? {
        #if os(iOS) || os(macOS)
        let recordsBuf = encodeRecordsBuffer(records)
        let atomIDBytes = Array(atomID.utf8)
        return recordsBuf.withUnsafeBufferPointer { rp in
            return atomIDBytes.withUnsafeBufferPointer { ap in
                let rc = bas_ranker_usage_count_for_atom(
                    rp.baseAddress, recordsBuf.count,
                    ap.baseAddress, atomIDBytes.count)
                return rc >= 0 ? Int(rc) : nil
            }
        }
        #else
        return nil
        #endif
    }

    // MARK: - Wire format helpers (chapter 七百二十三 第二刀)

    private static func encodeRecordsBuffer(
        _ records: [BASImportanceRecord]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(4 + records.count * 40)
        appendU32BE(&buf, UInt32(records.count))
        for r in records {
            let idBytes = Array(r.atomID.utf8)
            appendU32BE(&buf, UInt32(idBytes.count))
            buf.append(contentsOf: idBytes)
            appendI64BE(&buf, r.retrievedAtMs)
            buf.append(r.helpedFlag.rawValue)
        }
        return buf
    }

    private static func encodeTiersBuffer(
        _ tiers: [(atomID: String, tier: BASImportanceTier)]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(4 + tiers.count * 24)
        appendU32BE(&buf, UInt32(tiers.count))
        for t in tiers {
            let idBytes = Array(t.atomID.utf8)
            appendU32BE(&buf, UInt32(idBytes.count))
            buf.append(contentsOf: idBytes)
            buf.append(t.tier.rawValue)
        }
        return buf
    }

    private static func encodeTunablesBuffer(
        _ t: BASImportanceTunables
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(7 * 8)
        appendF64LE(&buf, t.promoteThreshold)
        appendF64LE(&buf, t.demoteThreshold)
        appendF64LE(&buf, t.recencyHalfLifeSeconds)
        appendF64LE(&buf, t.frequencySaturation)
        appendF64LE(&buf, t.tierDecayHot)
        appendF64LE(&buf, t.tierDecayWarm)
        appendF64LE(&buf, t.tierDecayCold)
        return buf
    }

    private static func decodeScoresBuffer(
        _ buf: [UInt8]
    ) -> [BASImportanceScore]? {
        guard buf.count >= 4 else { return nil }
        var pos = 0
        let count = Int(readU32BE(buf, pos))
        pos += 4
        var out: [BASImportanceScore] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            guard pos + 4 <= buf.count else { return nil }
            let idLen = Int(readU32BE(buf, pos))
            pos += 4
            guard pos + idLen <= buf.count else { return nil }
            let atomID = String(
                decoding: buf[pos..<pos + idLen],
                as: UTF8.self)
            pos += idLen
            guard pos + 1 <= buf.count,
                  let currentTier = BASImportanceTier(
                    rawValue: buf[pos])
            else { return nil }
            pos += 1
            guard pos + 5 * 8 <= buf.count else { return nil }
            let recency = readF64LE(buf, pos);    pos += 8
            let freq    = readF64LE(buf, pos);    pos += 8
            let helped  = readF64LE(buf, pos);    pos += 8
            let tierD   = readF64LE(buf, pos);    pos += 8
            let total   = readF64LE(buf, pos);    pos += 8
            guard pos + 1 <= buf.count,
                  let recommended = BASImportanceTier(
                    rawValue: buf[pos])
            else { return nil }
            pos += 1
            guard pos + 4 + 8 <= buf.count else { return nil }
            let recordCount = Int(readU32BE(buf, pos))
            pos += 4
            let computedAt = readI64BE(buf, pos)
            pos += 8
            out.append(BASImportanceScore(
                atomID: atomID,
                currentTier: currentTier,
                recencyComponent: recency,
                frequencyComponent: freq,
                helpedComponent: helped,
                tierDecayComponent: tierD,
                totalScore: total,
                recommendedTier: recommended,
                recordCount: recordCount,
                computedAtMs: computedAt))
        }
        return out
    }

    private static func appendU32BE(
        _ buf: inout [UInt8], _ v: UInt32
    ) {
        buf.append(UInt8((v >> 24) & 0xff))
        buf.append(UInt8((v >> 16) & 0xff))
        buf.append(UInt8((v >>  8) & 0xff))
        buf.append(UInt8( v        & 0xff))
    }

    private static func appendI64BE(
        _ buf: inout [UInt8], _ v: Int64
    ) {
        let u = UInt64(bitPattern: v)
        for shift in stride(from: 56, through: 0, by: -8) {
            buf.append(UInt8((u >> shift) & 0xff))
        }
    }

    private static func appendF64LE(
        _ buf: inout [UInt8], _ v: Double
    ) {
        let bits = v.bitPattern  // host (LE on aarch64)
        for shift in stride(from: 0, through: 56, by: 8) {
            buf.append(UInt8((bits >> shift) & 0xff))
        }
    }

    private static func readU32BE(
        _ buf: [UInt8], _ pos: Int
    ) -> UInt32 {
        return  (UInt32(buf[pos    ]) << 24)
              | (UInt32(buf[pos + 1]) << 16)
              | (UInt32(buf[pos + 2]) <<  8)
              |  UInt32(buf[pos + 3])
    }

    private static func readI64BE(
        _ buf: [UInt8], _ pos: Int
    ) -> Int64 {
        var u: UInt64 = 0
        for i in 0..<8 {
            u = (u << 8) | UInt64(buf[pos + i])
        }
        return Int64(bitPattern: u)
    }

    private static func readF64LE(
        _ buf: [UInt8], _ pos: Int
    ) -> Double {
        var bits: UInt64 = 0
        for i in 0..<8 {
            bits |= UInt64(buf[pos + i]) << (i * 8)
        }
        return Double(bitPattern: bits)
    }

    // MARK: - L11 risk_plane (chapter 七百三十九 第二刀 / M2367)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L11 Wind Gate
    // state-machine port (Cargo/bas-permit-policy/src/risk_plane
    // .rs)。 Pairs with chapter 七百三十八's SQL persistence
    // layer (006_risk_observations.sql + 007_permit_escalation
    // _ledger.sql + 008_permit_escalation_steps.sql)。
    //
    // Wire encoding (single source of truth = Rust risk_plane
    // .rs C ABI):
    //   RiskBand   : 0=Low, 1=Medium, 2=High, 3=Critical
    //   RiskClimate: 0=Calm, 1=Watchful, 2=Elevated, 3=Crisis
    //   ActionPermitMode:
    //     0=Answer  1=Mirror   2=Compare 3=Delay
    //     4=DraftOnly 5=LocalOnly 6=Block 7=Replace 8=Escalate
    //
    // All functions are PURE — no FFI failure modes other than
    // out-of-range encoding → nil (Swift bridge falls back to
    // V1 Swift classifier gracefully)。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 Swift in-line classifier (EBrainRiskPlaneCore decision
    // tree) stays the live path。 Hosts must explicitly opt-in
    // via `useRoutedRiskPlane: Bool` parameter to consume these
    // helpers。 Chapter 七百三十九 第四刀 5-axis comparison
    // measures whether to flip default。

    /// L11 classifier:given a per-observation risk_band + the
    /// session's current climate + the gate's current mode,
    /// route to Rust risk_plane port and return the next mode。
    ///
    /// Encoding:band 0-3,climate 0-3,current 0-8。 Returns
    /// next ActionPermitMode encoding (0-8) or nil if any
    /// input is out of range (FFI returned -1)。 Swift bridge
    /// callers fall back to V1 in-line classifier on nil。
    public static func riskPlaneTransition(
        band: Int32,
        climate: Int32,
        currentMode: Int32
    ) -> Int32? {
        #if os(iOS) || os(macOS)
        let result =
            bas_permit_policy_risk_band_to_next_mode(
                band, climate, currentMode)
        if result < 0 { return nil }
        return result
        #else
        return nil
        #endif
    }

    /// Apply per-stratum threshold delta + clamp to [0, 1] via
    /// Rust risk_plane port。 NaN inputs → 0 (matches Swift
    /// clamp01 behavior of BASRiskCalibrationGate)。
    public static func riskPlaneEffectiveThreshold(
        base: Double,
        delta: Double
    ) -> Double {
        #if os(iOS) || os(macOS)
        return bas_permit_policy_effective_threshold(
            base, delta)
        #else
        // V1 Swift fallback (never reached on substrate's
        // supported platforms)
        let sum = base + delta
        if sum.isNaN { return 0 }
        return min(1.0, max(0.0, sum))
        #endif
    }

    /// Monotonic bundle-version comparator via Rust risk_plane
    /// port。 Returns:
    ///   .some(true)  — proposed > current (replace permitted)
    ///   .some(false) — proposed <= current (replace rejected)
    ///   nil          — either string is empty (fault)
    public static func riskPlaneMonotonicVersionCompare(
        current: String,
        proposed: String
    ) -> Bool? {
        #if os(iOS) || os(macOS)
        let currentBytes = Array(current.utf8)
        let proposedBytes = Array(proposed.utf8)
        let result = currentBytes.withUnsafeBufferPointer {
            cp -> Int32 in
            proposedBytes.withUnsafeBufferPointer {
                pp -> Int32 in
                return cp.baseAddress!.withMemoryRebound(
                    to: CChar.self,
                    capacity: currentBytes.count
                ) { ccp in
                    return pp.baseAddress!.withMemoryRebound(
                        to: CChar.self,
                        capacity: proposedBytes.count
                    ) { ppp in
                        return bas_permit_policy_monotonic_version_compare(
                            ccp, Int32(currentBytes.count),
                            ppp, Int32(proposedBytes.count))
                    }
                }
            }
        }
        switch result {
        case 1: return true
        case 0: return false
        default: return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - L10 Tribunal Court (chapter 七百四十 第二刀 / M2372)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L10 Tri-Self
    // Court pure-function derivation port
    // (Cargo/bas-tribunal-court/src/lib.rs)。 Mirrors the 4
    // derive factories from
    // Sources/BASOrchestration/BASTribunalFullBody.swift。
    //
    // Bulk-serialize FFI pattern (chapter 七百二十三 第二刀):
    // each derive takes a SINGLE JSON input blob and writes
    // a SINGLE JSON output blob。 Two-phase capacity
    // discovery (mirror of bpeEncode/bpeDecode ergonomics)。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 Swift derivations (BASTribunalFullBody.swift)
    // stay the live path。 Hosts opt in by calling these
    // helpers directly。 Chapter 七百四十 第四刀 5-axis
    // comparison decides default flip。

    /// Derive id-impulse profile via Rust bridge。 Input is
    /// the JSON-encoded `{profile_id, tri_scores, candidates}`
    /// blob;output is JSON-encoded `IdImpulseProfile`。
    /// Returns nil on FFI fault (null pointer / bad JSON)。
    public static func tribunalDeriveIdProfile(
        inputJSON: String
    ) -> String? {
        #if os(iOS) || os(macOS)
        return tribunalBulkDerive(
            inputJSON: inputJSON,
            fn: bas_tribunal_court_derive_id_profile)
        #else
        return nil
        #endif
    }

    /// Derive ego-reality assessment via Rust bridge。 Input
    /// is `{assessment_id, tri_scores, candidates, veto_marks}`
    /// JSON;output is JSON-encoded `EgoRealityAssessment`。
    public static func tribunalDeriveEgoAssessment(
        inputJSON: String
    ) -> String? {
        #if os(iOS) || os(macOS)
        return tribunalBulkDerive(
            inputJSON: inputJSON,
            fn: bas_tribunal_court_derive_ego_assessment)
        #else
        return nil
        #endif
    }

    /// Derive superego judgment via Rust bridge。 Input is
    /// `{judgment_id, veto_marks}` JSON;output is JSON-
    /// encoded `SuperegoJudgment`。
    public static func tribunalDeriveSuperegoJudgment(
        inputJSON: String
    ) -> String? {
        #if os(iOS) || os(macOS)
        return tribunalBulkDerive(
            inputJSON: inputJSON,
            fn: bas_tribunal_court_derive_superego_judgment)
        #else
        return nil
        #endif
    }

    /// Returns the bas-tribunal-court ABI version that the
    /// XCFramework was built against。 Pure pass-through to
    /// the Rust `bas_tribunal_court_abi_version()` symbol。
    public static func tribunalCourtABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_tribunal_court_abi_version()
        #else
        return 0
        #endif
    }

    #if os(iOS) || os(macOS)
    /// Shared two-phase capacity-discovery FFI driver for the
    /// 3 tribunal-court derivations。 Phase 1:invoke with
    /// out_capacity=0 to discover required size。 Phase 2:
    /// allocate + invoke with the exact size。
    private static func tribunalBulkDerive(
        inputJSON: String,
        fn: (UnsafePointer<CChar>?, Int32,
             UnsafeMutablePointer<CChar>?, Int32) -> Int32
    ) -> String? {
        let inputBytes = Array(inputJSON.utf8)
        // Phase 1:discover required output capacity
        let needed = inputBytes.withUnsafeBufferPointer {
            ip -> Int32 in
            return ip.baseAddress!.withMemoryRebound(
                to: CChar.self, capacity: inputBytes.count
            ) { ccp in
                return fn(ccp, Int32(inputBytes.count),
                          nil, 0)
            }
        }
        if needed < 0 { return nil }
        if needed == 0 { return "" }
        // Phase 2:fill the exact-sized output buffer
        var out = [CChar](
            repeating: 0, count: Int(needed))
        let wrote = inputBytes.withUnsafeBufferPointer {
            ip -> Int32 in
            return ip.baseAddress!.withMemoryRebound(
                to: CChar.self, capacity: inputBytes.count
            ) { ccp in
                return out.withUnsafeMutableBufferPointer {
                    op in
                    return fn(
                        ccp, Int32(inputBytes.count),
                        op.baseAddress, Int32(op.count))
                }
            }
        }
        guard wrote == needed else { return nil }
        // out is CChar (Int8) but holds UTF-8 bytes
        return out.withUnsafeBufferPointer { bp -> String? in
            return bp.baseAddress!.withMemoryRebound(
                to: UInt8.self, capacity: out.count
            ) { up in
                return String(
                    bytes: UnsafeBufferPointer(
                        start: up, count: out.count),
                    encoding: .utf8)
            }
        }
    }
    #endif

    // MARK: - L14 Sovereign seal/verify (chapter 七百四十一 第二刀 / M2377)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L14 Sovereign
    // audit ledger seal/verify port。 Encapsulates the Swift
    // BASSovereignAuditLedger.canonicalBytes(for:priorHash:) +
    // hash() into a SINGLE Rust call。 No CryptoKit traversal,
    // no Data concatenation in Swift。
    //
    // Builds on chapter 七百十六 routed-seal infrastructure
    // (which routed JUST the SHA256 primitive)。 This layer
    // routes the ENTIRE seal path:canonical-byte assembly +
    // hash + return next-hash + canonical bytes for persistence。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 Swift canonical-bytes-then-SHA256 path stays the live
    // default。 Hosts opt in by calling these helpers directly。
    // Chapter 七百四十一 第四刀 wires
    // BASSovereignAuditLedger.append() behind useRoutedSeal
    // flag (extends chapter 七百十六 ergonomics)。

    /// Sealed-entry output from bas_sovereign_seal_entry。
    public struct SovereignSealedEntry: Sendable {
        public let nextHash32: [UInt8]   // 32 bytes
        public let canonicalBytes: [UInt8]
    }

    /// Seal one L14 sovereign audit entry via the Rust bridge。
    /// Returns the next chain hash (32 bytes) + the canonical
    /// bytes that must be persisted alongside for replay verify。
    /// Returns nil on FFI fault (null pointer / capacity-mismatch
    /// after retry)。
    public static func sovereignSealEntry(
        priorHash32: [UInt8],
        auditID: String,
        sessionID: String,
        verdictRef: String,
        timestampMs: Int64,
        payload: [UInt8]
    ) -> SovereignSealedEntry? {
        #if os(iOS) || os(macOS)
        guard priorHash32.count == 32 else { return nil }
        let auditBytes = Array(auditID.utf8)
        let sessionBytes = Array(sessionID.utf8)
        let verdictBytes = Array(verdictRef.utf8)
        var nextHash = [UInt8](
            repeating: 0, count: 32)

        // Phase 1:capacity discovery
        let needed = priorHash32.withUnsafeBufferPointer {
            pp -> Int32 in
            auditBytes.withUnsafeBufferPointer { ap in
                sessionBytes.withUnsafeBufferPointer { sp in
                    verdictBytes.withUnsafeBufferPointer { vp in
                        payload.withUnsafeBufferPointer { plp in
                            nextHash.withUnsafeMutableBufferPointer {
                                hp in
                                return bas_sovereign_seal_entry(
                                    pp.baseAddress,
                                    ap.baseAddress, Int32(auditBytes.count),
                                    sp.baseAddress, Int32(sessionBytes.count),
                                    vp.baseAddress, Int32(verdictBytes.count),
                                    timestampMs,
                                    plp.baseAddress, Int32(payload.count),
                                    hp.baseAddress, nil, 0)
                            }
                        }
                    }
                }
            }
        }
        if needed < 0 { return nil }
        if needed == 0 {
            return SovereignSealedEntry(
                nextHash32: nextHash, canonicalBytes: [])
        }
        // Phase 2:fill exact-sized canonical buffer
        var canonical = [UInt8](
            repeating: 0, count: Int(needed))
        let wrote = priorHash32.withUnsafeBufferPointer {
            pp -> Int32 in
            auditBytes.withUnsafeBufferPointer { ap in
                sessionBytes.withUnsafeBufferPointer { sp in
                    verdictBytes.withUnsafeBufferPointer { vp in
                        payload.withUnsafeBufferPointer { plp in
                            nextHash.withUnsafeMutableBufferPointer {
                                hp in
                                canonical.withUnsafeMutableBufferPointer {
                                    cp in
                                    return bas_sovereign_seal_entry(
                                        pp.baseAddress,
                                        ap.baseAddress, Int32(auditBytes.count),
                                        sp.baseAddress, Int32(sessionBytes.count),
                                        vp.baseAddress, Int32(verdictBytes.count),
                                        timestampMs,
                                        plp.baseAddress, Int32(payload.count),
                                        hp.baseAddress,
                                        cp.baseAddress, Int32(cp.count))
                                }
                            }
                        }
                    }
                }
            }
        }
        guard wrote == needed else { return nil }
        return SovereignSealedEntry(
            nextHash32: nextHash, canonicalBytes: canonical)
        #else
        return nil
        #endif
    }

    /// Verify a sealed L14 chain via the Rust bridge。
    /// `entries` is a sequence of pre-computed canonical buffers
    /// (typically loaded from persistent storage)。
    /// Returns true if chain verifies,false if broken,nil on
    /// FFI fault。
    public static func sovereignVerifyChain(
        initialHash32: [UInt8],
        entries: [[UInt8]],
        expectedFinalHash32: [UInt8]
    ) -> Bool? {
        #if os(iOS) || os(macOS)
        guard initialHash32.count == 32,
              expectedFinalHash32.count == 32
        else { return nil }
        // Build the length-prefixed entries buffer:
        //   u32_be(count) || [u32_be(len) || bytes]*
        var totalLen = 4
        for e in entries { totalLen += 4 + e.count }
        var buffer = [UInt8](
            repeating: 0, count: totalLen)
        let count = UInt32(entries.count).bigEndian
        withUnsafeBytes(of: count) { ptr in
            buffer.replaceSubrange(0..<4, with: ptr)
        }
        var off = 4
        for e in entries {
            let len = UInt32(e.count).bigEndian
            withUnsafeBytes(of: len) { ptr in
                buffer.replaceSubrange(
                    off..<off + 4, with: ptr)
            }
            off += 4
            buffer.replaceSubrange(
                off..<off + e.count, with: e)
            off += e.count
        }
        let rc = initialHash32.withUnsafeBufferPointer {
            ip -> Int32 in
            buffer.withUnsafeBufferPointer { bp in
                expectedFinalHash32.withUnsafeBufferPointer {
                    ep in
                    return bas_sovereign_verify_chain(
                        ip.baseAddress,
                        bp.baseAddress, Int32(bp.count),
                        ep.baseAddress)
                }
            }
        }
        switch rc {
        case 1: return true
        case 0: return false
        default: return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - L14 Verdict Decisions (chapter 七百四十二 第二刀 / M2382)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L14 Sovereign
    // Verdict Engine pure-decision-tree port
    // (Cargo/bas-substrate-core/src/verdict_decisions.rs)。
    //
    // 12 hard rules encoded as a u16 bitfield + 7 soft
    // signal doubles + operation domain raw + evidence
    // sufficient flag → verdict level rank (0..7) in ONE
    // Rust call。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 BASSovereignVerdictEngine actor stays the live
    // production path。 Hosts opt in by calling these helpers
    // directly。 Chapter 七百四十二 第四刀 5-axis comparison
    // decides default flip (plan declared loss expected on
    // Axis 1 — tiny branchy workload)。

    /// 12 hard-rule observation flags packed into a u16
    /// bitfield。 Mirrors BASSovereignVerdictEngine
    /// .HardObservations。 Use the static
    /// `verdictHardBitfield(...)` helper to assemble。
    public struct VerdictHardBits {
        public let value: UInt16
        public init(value: UInt16) { self.value = value }
    }

    /// Assemble the hard-rule u16 bitfield from typed flags。
    /// LSB = BR-001 (artifactSignatureInvalid),bit 11 =
    /// BR-012 (auditAppendFailed)。
    public static func verdictHardBitfield(
        artifactSignatureInvalid: Bool = false,
        thoughtFoldChecksumBroken: Bool = false,
        externalSideEffectWithoutSCT: Bool = false,
        memoryOrHostWriteBypass: Bool = false,
        hostRemovalBypassed: Bool = false,
        policyBundleTampered: Bool = false,
        unauthorizedSelfMutation: Bool = false,
        irreversibleHighGSIWithoutEvidence: Bool = false,
        runtimeUnstableInHighRisk: Bool = false,
        riskPermitHeadConflict: Bool = false,
        hostAttemptsBaseBoundaryOverride: Bool = false,
        auditAppendFailed: Bool = false
    ) -> VerdictHardBits {
        var b: UInt16 = 0
        if artifactSignatureInvalid          { b |= 0x0001 }
        if thoughtFoldChecksumBroken         { b |= 0x0002 }
        if externalSideEffectWithoutSCT      { b |= 0x0004 }
        if memoryOrHostWriteBypass           { b |= 0x0008 }
        if hostRemovalBypassed               { b |= 0x0010 }
        if policyBundleTampered              { b |= 0x0020 }
        if unauthorizedSelfMutation          { b |= 0x0040 }
        if irreversibleHighGSIWithoutEvidence { b |= 0x0080 }
        if runtimeUnstableInHighRisk         { b |= 0x0100 }
        if riskPermitHeadConflict            { b |= 0x0200 }
        if hostAttemptsBaseBoundaryOverride  { b |= 0x0400 }
        if auditAppendFailed                 { b |= 0x0800 }
        return VerdictHardBits(value: b)
    }

    /// Operation domain raw values matching the Rust
    /// OperationDomain enum encoding。
    public enum VerdictOperationDomain: Int32 {
        case pureInference = 0
        case toolRead = 1
        case toolWrite = 2
        case hostMutate = 3
        case memoryPromote = 4
        case rulePromotion = 5
    }

    /// Derive the L14 verdict level via the Rust port。
    ///
    /// Returns verdict level rank (0..7) where:
    ///   0 = pass         1 = throttle    2 = shadowLock
    ///   3 = toolCut      4 = memoryFreeze 5 = quarantine
    ///   6 = rollback     7 = deadStop
    /// Returns nil on FFI fault (null softs / unknown domain)。
    public static func verdictDeriveLevel(
        hardBits: VerdictHardBits,
        softSignals: [Double],
        domain: VerdictOperationDomain,
        evidenceSufficient: Bool
    ) -> Int32? {
        #if os(iOS) || os(macOS)
        guard softSignals.count == 7 else { return nil }
        let result = softSignals.withUnsafeBufferPointer {
            sp -> Int32 in
            return bas_verdict_derive(
                hardBits.value,
                sp.baseAddress,
                domain.rawValue,
                evidenceSufficient ? 1 : 0)
        }
        if result < 0 { return nil }
        return result
        #else
        return nil
        #endif
    }

    /// Returns the bas-substrate-core verdict_decisions ABI
    /// version that the XCFramework was built against。
    public static func verdictDecisionsABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_verdict_decisions_abi_version()
        #else
        return 0
        #endif
    }

    // MARK: - L14 Token lifecycle (chapter 七百四十三 第一刀 / M2386)

    /// L14 token lifecycle status。 Mirrors Rust
    /// TokenLifecycleStatus enum encoding。 Keychain-bound
    /// signing/verification stays Swift permanently per
    /// user directive (Apple-glue layer)。
    public enum SovereignTokenLifecycleStatus: Int32 {
        case live = 0
        case expired = 1
        case revoked = 2
        case futureDated = 3
    }

    /// Decide a token's lifecycle status via the Rust bridge。
    /// `revokedAtMs == nil` encodes "not revoked"。
    public static func sovereignTokenLifecycleStatus(
        issuedAtMs: Int64,
        expiresAtMs: Int64,
        revokedAtMs: Int64?,
        nowMs: Int64
    ) -> SovereignTokenLifecycleStatus? {
        #if os(iOS) || os(macOS)
        let revoked = revokedAtMs ?? -1
        let rc = bas_sovereign_token_lifecycle_status(
            issuedAtMs, expiresAtMs, revoked, nowMs)
        return SovereignTokenLifecycleStatus(rawValue: rc)
        #else
        return nil
        #endif
    }

    // MARK: - L3 Knowledge Graph codec (chapter 七百四十四 第二刀 / M2392)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L3 Knowledge
    // Graph V2 binary codec (Cargo/bas-event-log-codec/src/
    // knowledge_graph_codec.rs)。 Mirrors Swift BAS
    // KnowledgeNode + BASKnowledgeEdge encode/decode。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 Swift Codable JSON path (BASSQLiteKnowledgeGraph
    // Storage.swift) stays the live production path。 Chapter
    // 七百四十四 第三刀 adds the SQL schema migration column;
    // 第四刀 measures perf;第五刀 close-out。

    /// Returns the L3 KG codec ABI version。
    public static func kgCodecABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_kg_codec_abi_version()
        #else
        return 0
        #endif
    }

    /// Encode a knowledge node via the Rust V2 binary codec。
    /// Returns the canonical bytes or nil on FFI fault。
    public static func kgCodecEncodeNode(
        nodeID: String,
        kindRaw: String,
        label: String,
        createdAtMs: Int64,
        payloadJson: String?
    ) -> [UInt8]? {
        #if os(iOS) || os(macOS)
        let nidB = Array(nodeID.utf8)
        let krB = Array(kindRaw.utf8)
        let lblB = Array(label.utf8)
        let plB: [UInt8]? = payloadJson.map { Array($0.utf8) }
        return runKgEncode { outBuf, outCap -> Int32 in
            nidB.withUnsafeBufferPointer { nidPtr in
                krB.withUnsafeBufferPointer { krPtr in
                    lblB.withUnsafeBufferPointer { lblPtr in
                        let nidC = nidPtr.baseAddress.map {
                            UnsafeRawPointer($0).assumingMemoryBound(
                                to: CChar.self) }
                        let krC = krPtr.baseAddress.map {
                            UnsafeRawPointer($0).assumingMemoryBound(
                                to: CChar.self) }
                        let lblC = lblPtr.baseAddress.map {
                            UnsafeRawPointer($0).assumingMemoryBound(
                                to: CChar.self) }
                        if let plB = plB {
                            return plB.withUnsafeBufferPointer { plPtr -> Int32 in
                                let plC = plPtr.baseAddress.map {
                                    UnsafeRawPointer($0).assumingMemoryBound(
                                        to: CChar.self) }
                                return bas_kg_codec_encode_node(
                                    nidC, Int32(nidB.count),
                                    krC, Int32(krB.count),
                                    lblC, Int32(lblB.count),
                                    createdAtMs,
                                    plC, Int32(plB.count),
                                    outBuf, outCap)
                            }
                        } else {
                            return bas_kg_codec_encode_node(
                                nidC, Int32(nidB.count),
                                krC, Int32(krB.count),
                                lblC, Int32(lblB.count),
                                createdAtMs,
                                nil, -1,
                                outBuf, outCap)
                        }
                    }
                }
            }
        }
        #else
        return nil
        #endif
    }

    /// Encode a knowledge edge via the Rust V2 binary codec。
    public static func kgCodecEncodeEdge(
        edgeID: String,
        fromNodeID: String,
        toNodeID: String,
        kindRaw: String,
        weight: Double,
        createdAtMs: Int64
    ) -> [UInt8]? {
        #if os(iOS) || os(macOS)
        let eidB = Array(edgeID.utf8)
        let frB = Array(fromNodeID.utf8)
        let toB = Array(toNodeID.utf8)
        let krB = Array(kindRaw.utf8)
        return runKgEncode { outBuf, outCap -> Int32 in
            eidB.withUnsafeBufferPointer { eidPtr in
                frB.withUnsafeBufferPointer { frPtr in
                    toB.withUnsafeBufferPointer { toPtr in
                        krB.withUnsafeBufferPointer { krPtr in
                            let eidC = eidPtr.baseAddress.map {
                                UnsafeRawPointer($0).assumingMemoryBound(
                                    to: CChar.self) }
                            let frC = frPtr.baseAddress.map {
                                UnsafeRawPointer($0).assumingMemoryBound(
                                    to: CChar.self) }
                            let toC = toPtr.baseAddress.map {
                                UnsafeRawPointer($0).assumingMemoryBound(
                                    to: CChar.self) }
                            let krC = krPtr.baseAddress.map {
                                UnsafeRawPointer($0).assumingMemoryBound(
                                    to: CChar.self) }
                            return bas_kg_codec_encode_edge(
                                eidC, Int32(eidB.count),
                                frC, Int32(frB.count),
                                toC, Int32(toB.count),
                                krC, Int32(krB.count),
                                weight, createdAtMs,
                                outBuf, outCap)
                        }
                    }
                }
            }
        }
        #else
        return nil
        #endif
    }

    #if os(iOS) || os(macOS)
    /// Shared two-phase capacity-discovery driver for kg
    /// encode operations。 Caller supplies a closure that
    /// invokes the FFI with the (out_buf, out_capacity)
    /// it receives;driver handles capacity discovery +
    /// retry with the exact-sized buffer。
    private static func runKgEncode(
        _ encodeCall: (UnsafeMutablePointer<CChar>?, Int32)
            -> Int32
    ) -> [UInt8]? {
        // Phase 1:capacity discovery
        let needed = encodeCall(nil, 0)
        if needed < 0 { return nil }
        if needed == 0 { return [] }
        // Phase 2:fill exact buffer
        var buf = [CChar](
            repeating: 0, count: Int(needed))
        let wrote = buf.withUnsafeMutableBufferPointer { bp in
            return encodeCall(bp.baseAddress, Int32(bp.count))
        }
        guard wrote == needed else { return nil }
        return buf.withUnsafeBufferPointer { bp -> [UInt8] in
            return bp.baseAddress!.withMemoryRebound(
                to: UInt8.self, capacity: buf.count
            ) { up in
                return Array(UnsafeBufferPointer(
                    start: up, count: buf.count))
            }
        }
    }
    #endif

    // MARK: - L3 Event Extractor (chapter 七百四十五 第一刀 / M2396)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L3 Event
    // Extractor per-event classification port (Cargo/bas-
    // event-log-codec/src/event_extractor.rs)。
    //
    // Full Swift orchestrator (BASKnowledgeGraphEventExtractor)
    // stays Swift。 Rust handles the per-event classification
    // hot-path:given (action, source, memory_atom_tag),
    // decide what edge to emit linking the event to its
    // project node。

    /// Edge kind classification result。 Mirrors Rust EdgeKind。
    public enum EventEdgeKind: Int32, Sendable {
        case none = 0
        case causes = 1
        case delays = 2
        case contradicts = 3
        case mentions = 4
    }

    /// Per-event classification result。
    public struct EventClassification: Sendable {
        public let edgeKind: EventEdgeKind
        public let edgeWeight: Double
        public let isMemoryAtomEvent: Bool
    }

    /// Classify one event via the Rust port。 Returns nil on
    /// FFI fault (null/invalid inputs)。
    public static func classifyEvent(
        action: String,
        source: String,
        memoryAtomEventActionTag: String
    ) -> EventClassification? {
        #if os(iOS) || os(macOS)
        let actionB = Array(action.utf8)
        let sourceB = Array(source.utf8)
        let tagB = Array(memoryAtomEventActionTag.utf8)
        var ek: Int32 = 0
        var ew: Double = 0.0
        var am: Int32 = 0
        let rc = actionB.withUnsafeBufferPointer { ap -> Int32 in
            sourceB.withUnsafeBufferPointer { sp in
                tagB.withUnsafeBufferPointer { tp in
                    let aC = ap.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(
                            to: CChar.self) }
                    let sC = sp.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(
                            to: CChar.self) }
                    let tC = tp.baseAddress.map {
                        UnsafeRawPointer($0).assumingMemoryBound(
                            to: CChar.self) }
                    return bas_event_extractor_classify(
                        aC, Int32(actionB.count),
                        sC, Int32(sourceB.count),
                        tC, Int32(tagB.count),
                        &ek, &ew, &am)
                }
            }
        }
        guard rc == 0 else { return nil }
        let kind = EventEdgeKind(rawValue: ek) ?? .none
        return EventClassification(
            edgeKind: kind,
            edgeWeight: ew,
            isMemoryAtomEvent: am != 0)
        #else
        return nil
        #endif
    }

    /// Returns the bas-event-extractor ABI version。
    public static func eventExtractorABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_event_extractor_abi_version()
        #else
        return 0
        #endif
    }

    // MARK: - Naive fallback

    private static func swiftNaiveCosine(
        _ a: [Float], _ b: [Float]
    ) -> Float {
        var dot: Float = 0
        var na:  Float = 0
        var nb:  Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na  += a[i] * a[i]
            nb  += b[i] * b[i]
        }
        if na == 0 || nb == 0 { return 0 }
        return dot
            / (na.squareRoot() * nb.squareRoot())
    }
}

// MARK: - BASBpeTokenizerHandle (chapter 七百二十二 第二刀 / M2282)
//
// RAII wrapper around the opaque `BasTokenizer*` returned by the
// `bas_tokenizer_new` FFI。 Owns the Rust-side heap allocation,
// calls `bas_tokenizer_free` in deinit。 Pass to
// `BASAutoRouteRanker.bpeEncode/bpeDecode` to drive the tokenizer。
//
// Vocab wire format (BIG-ENDIAN length prefixes):
//   vocab:  [u32 count][[u32 token_len][bytes][u32 id]]...
//   merges: [u32 count][[u32 ll][left][u32 rl][right][u32 rank]]...
//
// The handle is `final class` (not `actor`) because the underlying
// Rust tokenizer is read-only after construction — encode/decode
// take `&self` and never mutate state。 Concurrent reads are safe;
// the handle is `Sendable` via `nonisolated(unsafe)` on the pointer
// (single-writer-in-init, single-reader-in-encode/decode,no race)。
//
// Knife 4 will wrap this in a `BASBpeTokenizer` actor with bundle-
// resource vocab loading + a typed-error API。 This Knife 2 surface
// is the low-level building block。

public final class BASBpeTokenizerHandle: @unchecked Sendable {
    /// Underlying opaque pointer to the Rust-side
    /// `Box<bas_tokenizer::Tokenizer>`。 nil on platforms without
    /// the XCFramework (watchOS) OR when construction failed
    /// (malformed wire-format buffers)。
    ///
    /// `nonisolated(unsafe)` mirrors the chapter 七百六 / M2189
    /// BASRustMemoryUsageTrackerActor handle pattern — required
    /// because deinit must release the Rust-side `Box<Tokenizer>`
    /// and Swift 6 strict concurrency blocks non-Sendable access
    /// from nonisolated deinit otherwise。 Safe because the
    /// pointer is only mutated in init (single-writer) and
    /// dropped in deinit (no race after deinit fires)。
    fileprivate nonisolated(unsafe) var opaqueHandle:
        OpaquePointer?

    /// Construct a tokenizer from already-serialized vocab +
    /// merges buffers in the documented BIG-ENDIAN wire format。
    /// Returns nil when:
    ///   - platform has no XCFramework support (watchOS)
    ///   - Rust FFI rejects the wire format (length-prefix
    ///     underrun)
    public init?(
        vocabBuffer: [UInt8],
        mergesBuffer: [UInt8],
        unknownTokenID: UInt32
    ) {
        #if os(iOS) || os(macOS)
        // Empty vocab + empty merges is a degenerate-but-legal
        // tokenizer (every byte → <unk>)。 Rust side accepts it。
        let raw: OpaquePointer? =
            vocabBuffer.withUnsafeBufferPointer { vp in
                mergesBuffer.withUnsafeBufferPointer { mp in
                    return bas_tokenizer_new(
                        vp.baseAddress, vocabBuffer.count,
                        mp.baseAddress, mergesBuffer.count,
                        unknownTokenID)
                }
            }
        guard let nonNil = raw else { return nil }
        self.opaqueHandle = nonNil
        #else
        self.opaqueHandle = nil
        return nil
        #endif
    }

    deinit {
        #if os(iOS) || os(macOS)
        if let h = opaqueHandle {
            // Safe to call from deinit;Rust side just drops
            // the `Box<Tokenizer>` allocation。
            bas_tokenizer_free(h)
        }
        #endif
    }

    /// True iff the handle holds a valid Rust-side allocation。
    /// False on watchOS and on construction failure。
    public var isValid: Bool {
        return opaqueHandle != nil
    }

    /// Vocab size。 -1 on invalid handle。
    public var vocabSize: Int {
        return BASAutoRouteRanker.bpeVocabSize(self)
    }

    // MARK: - Convenience wire-format builders
    //
    // Static helpers that emit the BIG-ENDIAN length-prefixed
    // buffers that `bas_tokenizer_new` consumes。 Used by tests
    // (and by knife 4's BASBpeTokenizer actor) to avoid hand-
    // rolling the byte layout at every call site。

    /// Build the BIG-ENDIAN vocab wire buffer。 Entries are emitted
    /// in caller-provided order — order does not affect tokenizer
    /// behavior since the Rust side stores entries in a HashMap。
    public static func encodeVocabBuffer(
        _ entries: [(token: [UInt8], id: UInt32)]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(
            4 + entries.reduce(0) {
                $0 + 4 + $1.token.count + 4
            })
        appendU32BE(&buf, UInt32(entries.count))
        for (token, id) in entries {
            appendU32BE(&buf, UInt32(token.count))
            buf.append(contentsOf: token)
            appendU32BE(&buf, id)
        }
        return buf
    }

    /// Build the BIG-ENDIAN merges wire buffer。 Merges are
    /// applied lowest-rank-first by the Rust BPE engine,so the
    /// caller controls order via the `rank` field (NOT array
    /// position)。
    public static func encodeMergesBuffer(
        _ merges: [(
            left: [UInt8],
            right: [UInt8],
            rank: UInt32)]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(
            4 + merges.reduce(0) {
                $0 + 4 + $1.left.count + 4
                + $1.right.count + 4
            })
        appendU32BE(&buf, UInt32(merges.count))
        for (l, r, rank) in merges {
            appendU32BE(&buf, UInt32(l.count))
            buf.append(contentsOf: l)
            appendU32BE(&buf, UInt32(r.count))
            buf.append(contentsOf: r)
            appendU32BE(&buf, rank)
        }
        return buf
    }

    private static func appendU32BE(
        _ buf: inout [UInt8], _ value: UInt32
    ) {
        buf.append(UInt8((value >> 24) & 0xff))
        buf.append(UInt8((value >> 16) & 0xff))
        buf.append(UInt8((value >>  8) & 0xff))
        buf.append(UInt8( value        & 0xff))
    }
}
