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
