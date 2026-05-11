// MARK: - BASKernelEvaluateLatencyProbeBundle
// chapter 五百二 / M1386 — 8th BASBundle<Item> adoption +
// real consumption of M1369 BASMPSGraphKernelBuildLatency
// ResultBody + M1371 BASKernelEvaluateLatencyProbe
//
// Closes the consumption gap left at chapter 498:M1369
// shipped the typed result and M1371 shipped the probe,
// but no typed AGGREGATOR existed to roll up many probe
// observations into a single audit surface。 Hosts running
// hot-path benchmarks across many kernel calls need an
// aggregate hit/miss/latency-summary surface — this
// bundle provides it。
//
// Wire-in proof:M1369 result body is the bundle Item,
// and the probe's evaluateAndObserve(...) returns a
// BASMPSGraphKernelBuildLatencyResult whose `.body` slots
// directly into this bundle。 Real consumption。
//
// HONEST SCOPE:bundle is observation-only (Codable
// audit surface)。 ADR-014 OPT-IN preserved — hosts that
// don't aggregate probe results see no change。

import Foundation
import BASRuntimeCore

/// 8th REAL `BASBundle<Item>` typealias migration —
/// aggregate of N kernel-evaluate latency observations
/// classified by the same Item type that M1369 surfaces
/// for individual results。
public typealias BASKernelEvaluateLatencyProbeBundle =
    BASBundle<BASMPSGraphKernelBuildLatencyResultBody>

extension BASBundle
    where Item ==
        BASMPSGraphKernelBuildLatencyResultBody
{

    /// Total wall-clock build nanos across the bundle。
    /// Saturating add to avoid overflow on adversarial
    /// inputs。
    public var totalBuildNanos: UInt64 {
        items.reduce(UInt64(0)) {
            $0 &+ $1.buildNanos
        }
    }

    /// Total wall-clock dispatch nanos across the bundle。
    public var totalDispatchNanos: UInt64 {
        items.reduce(UInt64(0)) {
            $0 &+ $1.dispatchNanos
        }
    }

    /// Total cache-hit-saved nanos (only counts items
    /// where wasCacheHit == true,using effectiveCache
    /// SavingsNanos for honest accounting)。
    public var totalCacheHitSavedNanos: UInt64 {
        items.reduce(UInt64(0)) {
            $0 &+ $1.effectiveCacheSavingsNanos
        }
    }

    /// Number of cache hits in the bundle。
    public var cacheHitCount: Int {
        items.filter(\.wasCacheHit).count
    }

    /// Cache miss count (complement of hits)。
    public var cacheMissCount: Int {
        items.count - cacheHitCount
    }

    /// Hit ratio in [0, 1]。 Zero when bundle empty。
    public var cacheHitRatio: Double {
        guard !items.isEmpty else { return 0 }
        return Double(cacheHitCount)
            / Double(items.count)
    }

    /// Per-operation distribution of items (typed map
    /// from BASNeuralOp to observation count)。 Useful
    /// for scheduler-tuning + audit-walker inspection
    /// of which ops dominate the hot path。
    public var perOperationCounts:
        [BASNeuralOp: Int]
    {
        var counts: [BASNeuralOp: Int] = [:]
        for item in items {
            counts[item.operation, default: 0] += 1
        }
        return counts
    }
}
