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
    Sendable, Equatable, Codable
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

    public init(
        cosineSIMDMinDim: Int = 64,
        sha256CryptoKitMinBytes: Int = 1024,
        attentionMetalMinProduct: Int = 64,
        matMulMetalMinProduct: Int = 262_144
    ) {
        self.cosineSIMDMinDim = max(1, cosineSIMDMinDim)
        self.sha256CryptoKitMinBytes =
            max(1, sha256CryptoKitMinBytes)
        self.attentionMetalMinProduct =
            max(1, attentionMetalMinProduct)
        self.matMulMetalMinProduct =
            max(1, matMulMetalMinProduct)
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
