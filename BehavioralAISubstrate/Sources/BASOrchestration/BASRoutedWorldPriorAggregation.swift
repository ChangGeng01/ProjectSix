// MARK: - BASRoutedWorldPriorAggregation
// chapter 七百八十 / M2551-M2555 — STRONG-FLIP execution
//
// Production-default Rust-routed entry points for L4 world-prior
// aggregations:evidence propagation,latency aggregation,
// reversibility worst-case。
//
// ## Justification for default flip
//
// Chapter 七百七十九 5-axis measurement reported **5.12×
// speedup** for propagate_evidence vs the inline Swift baseline。
// Verdict:**STRONG-FLIP**。 The Swift baseline allocated array
// state per call;Rust uses stack-only iteration over the
// caller-supplied slice。
//
// ## ADR-014 OPT-IN preserved
//
// Hosts that want the V1 Swift inline path call the
// `propagateEvidenceViaSwiftInline(...)` (etc.) variants
// explicitly。 Default routes through Rust on Apple platforms。

import Foundation
import BASRuntimeCore

/// Production-default L4 world-prior aggregation entry points。
public enum BASRoutedWorldPriorAggregation {

    // MARK: - propagate_evidence

    /// Weakest-link aggregation across a list of evidence levels。
    /// Returns the minimum level encountered (most-cautious
    /// strategy);empty input → 0 (Anecdotal,weakest)。
    ///
    /// EvidenceLevel discriminants:
    ///   0 = Anecdotal / 1 = Observed /
    ///   2 = PeerReviewed / 3 = Mechanistic
    public static func propagateEvidence(
        levels: [UInt8]
    ) -> Int32 {
        #if os(iOS) || os(macOS)
        return propagateEvidenceViaRust(levels: levels)
        #else
        return propagateEvidenceViaSwiftInline(levels: levels)
        #endif
    }

    internal static func propagateEvidenceViaRust(
        levels: [UInt8]
    ) -> Int32 {
        return BASWorldPriorBridge.propagateEvidence(levels: levels)
    }

    /// V1 Swift inline fallback。 Mirrors Rust propagate_evidence
    /// semantics:weakest level wins;empty input → 0;invalid
    /// byte (>3) → -1。
    public static func propagateEvidenceViaSwiftInline(
        levels: [UInt8]
    ) -> Int32 {
        if levels.isEmpty { return 0 }
        var min: UInt8 = 3
        for l in levels {
            if l > 3 { return -1 }
            if l < min { min = l }
        }
        return Int32(min)
    }

    // MARK: - aggregate_latency

    /// Integer mean of latency_ms values。 Empty input → 0;
    /// negative-len wire fault → -1 (Rust path only)。
    public static func aggregateLatency(
        latencies: [Int64]
    ) -> Int64 {
        #if os(iOS) || os(macOS)
        return aggregateLatencyViaRust(latencies: latencies)
        #else
        return aggregateLatencyViaSwiftInline(latencies: latencies)
        #endif
    }

    internal static func aggregateLatencyViaRust(
        latencies: [Int64]
    ) -> Int64 {
        return BASWorldPriorBridge.aggregateLatency(
            latencies: latencies)
    }

    public static func aggregateLatencyViaSwiftInline(
        latencies: [Int64]
    ) -> Int64 {
        if latencies.isEmpty { return 0 }
        var sum: Int64 = 0
        for l in latencies { sum += l }
        return sum / Int64(latencies.count)
    }

    // MARK: - worst_reversibility

    /// Worst-case (most dangerous) reversibility — minimum
    /// discriminant per the Rust enum semantics。 Empty → 3 (Easy)。
    ///
    /// Reversibility discriminants:
    ///   0 = Irreversible / 1 = Hard / 2 = Medium / 3 = Easy
    public static func worstReversibility(
        values: [UInt8]
    ) -> Int32 {
        #if os(iOS) || os(macOS)
        return worstReversibilityViaRust(values: values)
        #else
        return worstReversibilityViaSwiftInline(values: values)
        #endif
    }

    internal static func worstReversibilityViaRust(
        values: [UInt8]
    ) -> Int32 {
        return BASWorldPriorBridge.worstReversibility(values: values)
    }

    public static func worstReversibilityViaSwiftInline(
        values: [UInt8]
    ) -> Int32 {
        if values.isEmpty { return 3 }
        var worst: UInt8 = 3
        for v in values {
            if v > 3 { return -1 }
            if v < worst { worst = v }
        }
        return Int32(worst)
    }
}
