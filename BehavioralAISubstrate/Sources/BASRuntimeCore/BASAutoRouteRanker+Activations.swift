// MARK: - BASAutoRouteRanker+Activations
// God-object extraction (audit ch1040): the activation-function routing
// (gelu / gelu-tanh / silu) + their Swift fallbacks, split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation — same namespace + symbols,
// call sites unchanged, byte-equal. Public funcs + their `private` fallbacks
// move together, so no access widening is needed.

import Foundation
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif

extension BASAutoRouteRanker {

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
}
