// MARK: - BASAutoRouteRanker+RankFuse — 全面进化 T2.1
//
// Swift bridge for the bas-retrieval-ranker crate's batched
// decayed-fusion entry (`bas_ranker_decayed_fuse_batch`,ranker ABI
// v2 — the FIRST C-ABI exposure of the crate's decay/fuser modules,
// which shipped at chapter 七百三 with zero callers)。
//
// ## Semantics (mirrors the Rust contract exactly)
//
//   fused[i] = wPrimary × decay(primary[i], agesMs[i], policy)
//            + wSecondary × (secondary?[i] ?? 0)
//
// Scores ONLY:membership and the pinned (score DESC, atomID ASC)
// tie-break stay the L8 seam's job — the ADR-036 "membership-only
// divergence" contract is preserved by construction。
//
// ## Swift-inline fallback (BASRoutedPresenceFusion pattern)
//
// `decayedFuseInline` is the pure Swift twin。 It is (a) the
// fallback when the FFI is unavailable,(b) the cross-language
// parity reference the gate tests pin (Rust == Swift on every
// vector),and (c) the honest baseline for any future 5-axis flip
// measurement。

import Foundation
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif

@_silgen_name("bas_ranker_decayed_fuse_batch")
private func _bas_ranker_decayed_fuse_batch(
    _ primaryScores: UnsafePointer<Double>?,
    _ agesMs: UnsafePointer<Int64>?,
    _ count: Int,
    _ policyTag: Int32,
    _ policyA: Double,
    _ policyB: Double,
    _ secondaryScores: UnsafePointer<Double>?,
    _ wPrimary: Double,
    _ wSecondary: Double,
    _ outFused: UnsafeMutablePointer<Double>?
) -> Int32

extension BASAutoRouteRanker {

    /// Typed decay policy — mirrors the Rust `DecayPolicy` enum
    /// (and its FFI tag encoding) exactly。
    public enum BASRankDecayPolicy: Sendable, Equatable {
        case none
        /// `score × exp(-rate × ageSeconds)`;`rate` is per-second。
        case exponential(rate: Double)
        /// `score × max(0, 1 - ageMs / horizonMs)`。
        case linear(horizonMs: Int64)
        /// `score × (1 if ageMs < thresholdMs else floorFactor)`。
        case step(thresholdMs: Int64, floorFactor: Double)

        var ffiTag: (tag: Int32, a: Double, b: Double) {
            switch self {
            case .none:
                return (0, 0, 0)
            case .exponential(let rate):
                return (1, rate, 0)
            case .linear(let horizonMs):
                return (2, Double(horizonMs), 0)
            case .step(let thresholdMs, let floorFactor):
                return (3, Double(thresholdMs), floorFactor)
            }
        }
    }

    /// Batched decayed weighted-linear fusion via the Rust kernel。
    /// Returns nil on FFI failure or input-shape mismatch — callers
    /// (the seam closure, the gate harness) fall back to
    /// `decayedFuseInline` or to the undecayed scores;absence is
    /// honest,never guessed at。
    public static func decayedFuseBatch(
        primaryScores: [Double],
        agesMs: [Int64],
        policy: BASRankDecayPolicy,
        secondaryScores: [Double]? = nil,
        wPrimary: Double = 1.0,
        wSecondary: Double = 0.0
    ) -> [Double]? {
        let count = primaryScores.count
        guard agesMs.count == count else { return nil }
        if let secondary = secondaryScores,
           secondary.count != count { return nil }
        if count == 0 { return [] }
        let (tag, a, b) = policy.ffiTag
        var out = [Double](repeating: 0, count: count)
        let rc = primaryScores.withUnsafeBufferPointer { p in
            agesMs.withUnsafeBufferPointer { ages in
                out.withUnsafeMutableBufferPointer { o in
                    if let secondary = secondaryScores {
                        return secondary.withUnsafeBufferPointer { s in
                            _bas_ranker_decayed_fuse_batch(
                                p.baseAddress, ages.baseAddress, count,
                                tag, a, b,
                                s.baseAddress,
                                wPrimary, wSecondary,
                                o.baseAddress)
                        }
                    }
                    return _bas_ranker_decayed_fuse_batch(
                        p.baseAddress, ages.baseAddress, count,
                        tag, a, b,
                        nil,
                        wPrimary, wSecondary,
                        o.baseAddress)
                }
            }
        }
        guard rc == 0 else { return nil }
        return out
    }

    /// Pure Swift twin of `decayedFuseBatch` — the parity reference
    /// + FFI-unavailable fallback。 Sequential scalar loop,same
    /// shapes,same clamps (negative ages clamp to 0;non-positive
    /// linear horizon zeroes the term)。
    public static func decayedFuseInline(
        primaryScores: [Double],
        agesMs: [Int64],
        policy: BASRankDecayPolicy,
        secondaryScores: [Double]? = nil,
        wPrimary: Double = 1.0,
        wSecondary: Double = 0.0
    ) -> [Double]? {
        let count = primaryScores.count
        guard agesMs.count == count else { return nil }
        if let secondary = secondaryScores,
           secondary.count != count { return nil }
        var out = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let age = max(0, agesMs[i])
            let decayed: Double
            switch policy {
            case .none:
                decayed = primaryScores[i]
            case .exponential(let rate):
                let ageSeconds = Double(age) / 1000.0
                decayed = primaryScores[i] * exp(-rate * ageSeconds)
            case .linear(let horizonMs):
                if horizonMs <= 0 {
                    decayed = 0
                } else {
                    let factor = 1.0
                        - Double(age) / Double(horizonMs)
                    decayed = primaryScores[i] * max(0, factor)
                }
            case .step(let thresholdMs, let floorFactor):
                decayed = age < thresholdMs
                    ? primaryScores[i]
                    : primaryScores[i] * floorFactor
            }
            let second = secondaryScores?[i] ?? 0
            out[i] = wPrimary * decayed + wSecondary * second
        }
        return out
    }
}
