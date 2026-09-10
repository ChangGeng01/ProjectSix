// MARK: - SampleHostBenchPressureMixer
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M719 component invariant.

import Foundation

// MARK: - M719 heavy-tailed pressure mixer

/// Production-realistic layer distribution. Uniform sweep (M711) is
/// great for coverage; heavy-tailed gives realistic frequency for
/// drift-detection & training-set augmentation.
///
/// Layer probabilities (informed by chapter 176 §176.19 substrate
/// distribution + heavy-tail intuition):
///   L11 risk-gate    : 25% (high-frequency in real workloads)
///   L9 candidates    : 18%
///   L8 memory        : 12%
///   L7 mirror        : 10%
///   L4 horizon       : 8%
///   L6 context       : 7%
///   L10 tribunal     : 6%
///   L5 host          : 5%
///   L1 wake          : 3%
///   L12 surface      : 2%
///   L2 breath        : 1.5%
///   L3 lung          : 1%
///   L13 evolution    : 1%
///   L14 reflection   : 0.5%
///                    ----
///                     100%
///
/// Doctrine: deterministic (seeded by iter) so replay is exact.
enum SampleHostBenchPressureMixer {
    /// Per-layer weight in ascending layer index. Sums to 100.
    static let layerWeights: [Double] = [
        3.0,   // L1 wake
        1.5,   // L2 breath
        1.0,   // L3 lung
        8.0,   // L4 horizon
        5.0,   // L5 host
        7.0,   // L6 context
        10.0,  // L7 mirror
        12.0,  // L8 memory
        18.0,  // L9 candidates
        6.0,   // L10 tribunal
        25.0,  // L11 risk-gate
        2.0,   // L12 surface
        1.0,   // L13 evolution
        0.5,   // L14 reflection
    ]

    /// Cumulative weight prefix sum (denormalized to layerWeightsTotal).
    static let cumulativeWeights: [Double] = {
        var acc: Double = 0
        var out: [Double] = []
        for w in layerWeights {
            acc += w
            out.append(acc)
        }
        return out
    }()

    /// Sum of all layer weights (used as modulus for selection).
    static let layerWeightsTotal: Double = layerWeights.reduce(0, +)

    /// Pick a layer index (1-14) by weight. Deterministic by seed.
    /// Algorithm: linear-congruential RNG seeded by iter, hash to
    /// [0, layerWeightsTotal), then binary-search cumulative weights.
    /// Exposes the picked layerIndex; caller looks up the
    /// FourteenLayerSmokeProfile.layers entry by index.
    static func pickLayerIndex(forIter iter: Int) -> Int {
        // Linear-congruential RNG. Constants from Numerical Recipes.
        // Deterministic + fast + good enough for ~5/sec sampling.
        let seed = UInt64(bitPattern: Int64(iter))
        var rng = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        // Take top 32 bits → [0, 2^32) → divide to [0, total)
        rng = rng >> 32
        let r = Double(UInt32(truncatingIfNeeded: rng))
            / Double(UInt32.max)
            * layerWeightsTotal
        // Linear scan (14 elements — binary search overkill)
        for (i, cum) in cumulativeWeights.enumerated() {
            if r < cum {
                return i + 1  // 1-indexed layer
            }
        }
        // Numerical edge — return last
        return layerWeights.count
    }
}
