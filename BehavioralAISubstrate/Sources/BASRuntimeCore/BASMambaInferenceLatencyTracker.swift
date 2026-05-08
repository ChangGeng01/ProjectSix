// MARK: - BASMambaInferenceLatencyTracker — chapter 四百 / M927
//
// G8 收尾 step 5:typed actor that tracks Mamba inference
// latency stratified by thermal state。Closes a feedback loop
// between G8 (training/inference) and M900 (thermal-aware
// cadence):the substrate today decides when to RUN
// extraction based on thermal state,but has no surface to
// observe how the converted Mamba head ITSELF behaves under
// the same thermal stratification。
//
// ## Why this matters
//
// 10h iPhone run revealed device spent 98.13% of events in
// `.serious` thermal。If the converted Mamba head
// (post-G11 .mlpackage) also slows under thermal load —
// likely,since ANE shares thermal envelope with GPU + CPU —
// inference latency stratified by thermal band tells us
// whether to DEMOTE Mamba inference under hot conditions
// (M900 already supports a `thermalSlowdownMultiplier` that
// could be applied here)。
//
// Without this tracker:
//   - inference latency is observed in aggregate (mean +
//     percentile) without thermal context
//   - we can't tell whether p99 spikes correlate with
//     `.serious` thermal or just bursty workload
// With this tracker:
//   - per-thermal-band p50 / p99 / count
//   - hosts surface in JSON alongside other M905 telemetry
//   - future M-number reads this to decide adaptive
//     inference cadence
//
// ## What this ships
//
//   - `BASMambaInferenceLatencyTracker` actor — owns a
//     histogram per `BASEventLogRiskBand` (mapped from
//     ProcessInfo.thermalState per M887 conventions)
//   - `BASMambaInferenceLatencyRecord` typed Sendable
//     struct: latencyMs + thermalBand + timestampMs
//   - `BASMambaInferenceLatencySnapshot` typed Codable bundle
//     of per-band p50/p99/count for serialization
//   - `record(latencyMs:thermalBand:)` typed entry point
//   - `snapshot()` typed read-only export
//
// ## Doctrine pins held
//
// - 不变量 #1/#2/#3 全保 — tracker is observation-class,
//   never mutates permits / verdicts / commit token
// - 红线 7 hint-only — latency snapshot is HINT to host /
//   future adaptive-inference decisions
// - chapter 二百一一 single-source-of-truth — ONE tracker
//   per Mamba head instance
// - chapter 一百八十五 anti-magic-number — histogram
//   percentile + bucket constants named typed
// - ADR-014 OPT-IN — substrate doesn't auto-track;hosts
//   instrument their inference call site
// - chapter 三百九〇 (M887) thermal-band-typing reused

import Foundation

// MARK: - Single-record

public struct BASMambaInferenceLatencyRecord:
    Sendable, Equatable, Hashable
{
    public let latencyMs: Double
    public let thermalBand: BASEventLogRiskBand
    public let timestampMs: Int64

    public init(
        latencyMs: Double,
        thermalBand: BASEventLogRiskBand,
        timestampMs: Int64
    ) {
        precondition(latencyMs >= 0,
            "latencyMs must be non-negative")
        self.latencyMs = latencyMs
        self.thermalBand = thermalBand
        self.timestampMs = timestampMs
    }
}

// MARK: - Snapshot

public struct BASMambaInferenceLatencyBandSummary:
    Codable, Equatable, Sendable, Hashable
{
    public let band: BASEventLogRiskBand
    public let sampleCount: Int
    public let p50Ms: Double
    public let p99Ms: Double
    public let meanMs: Double
    /// Min / max for sanity-check + outlier detection。
    public let minMs: Double
    public let maxMs: Double

    public init(
        band: BASEventLogRiskBand,
        sampleCount: Int,
        p50Ms: Double,
        p99Ms: Double,
        meanMs: Double,
        minMs: Double,
        maxMs: Double
    ) {
        self.band = band
        self.sampleCount = sampleCount
        self.p50Ms = p50Ms
        self.p99Ms = p99Ms
        self.meanMs = meanMs
        self.minMs = minMs
        self.maxMs = maxMs
    }
}

public struct BASMambaInferenceLatencySnapshot:
    Codable, Equatable, Sendable
{
    /// Snapshot timestamp (ms since UNIX epoch)。
    public let snapshotAtMs: Int64

    /// Total inference calls observed since tracker init。
    public let totalCalls: Int

    /// Per-band summary。Bands with zero samples are
    /// included with `sampleCount = 0` + zeroed metrics so
    /// downstream consumers get a stable shape。
    public let perBand: [BASMambaInferenceLatencyBandSummary]

    public init(
        snapshotAtMs: Int64,
        totalCalls: Int,
        perBand: [BASMambaInferenceLatencyBandSummary]
    ) {
        self.snapshotAtMs = snapshotAtMs
        self.totalCalls = totalCalls
        self.perBand = perBand
    }

    /// Convenience:lookup the per-band summary for a given
    /// risk band。
    public func summary(
        for band: BASEventLogRiskBand
    ) -> BASMambaInferenceLatencyBandSummary? {
        perBand.first { $0.band == band }
    }
}

// MARK: - Tracker actor

public actor BASMambaInferenceLatencyTracker {

    /// chapter 一百八十五:typed default percentile bounds。
    public static let p50: Double = 0.50
    public static let p99: Double = 0.99

    /// Per-band samples。Sorted on demand for percentiles
    /// (cheap at typical sample counts < 10K per band)。
    private var samplesByBand:
        [BASEventLogRiskBand: [Double]] = [:]
    private(set) var totalCalls: Int = 0

    public init() {}

    /// Record one inference latency observation。Appends to
    /// the per-band sample list。
    public func record(
        latencyMs: Double,
        thermalBand: BASEventLogRiskBand
    ) {
        precondition(latencyMs >= 0,
            "latencyMs must be non-negative")
        var samples = samplesByBand[thermalBand]
            ?? []
        samples.append(latencyMs)
        samplesByBand[thermalBand] = samples
        totalCalls += 1
    }

    /// Record a typed `BASMambaInferenceLatencyRecord`。
    /// Convenience for callers that already have the bundle。
    public func record(
        _ record: BASMambaInferenceLatencyRecord
    ) {
        self.record(
            latencyMs: record.latencyMs,
            thermalBand: record.thermalBand)
    }

    /// Produce a typed snapshot of per-band latency stats。
    /// Pure read — does not mutate samples。
    public func snapshot(
        atTimestampMs timestampMs: Int64
    ) -> BASMambaInferenceLatencySnapshot {
        var summaries:
            [BASMambaInferenceLatencyBandSummary] = []
        // Iterate ALL cases so the snapshot has stable shape
        // (zero-sample bands included as empty summaries)。
        for band in BASEventLogRiskBand.allCases {
            let samples = samplesByBand[band] ?? []
            summaries.append(
                Self.summarize(
                    band: band, samples: samples))
        }
        return BASMambaInferenceLatencySnapshot(
            snapshotAtMs: timestampMs,
            totalCalls: totalCalls,
            perBand: summaries)
    }

    /// Pure helper:summarize a sample list into the typed
    /// per-band summary。Sorts in-place on the local copy —
    /// caller's storage unchanged。
    private static func summarize(
        band: BASEventLogRiskBand,
        samples: [Double]
    ) -> BASMambaInferenceLatencyBandSummary {
        if samples.isEmpty {
            return BASMambaInferenceLatencyBandSummary(
                band: band,
                sampleCount: 0,
                p50Ms: 0,
                p99Ms: 0,
                meanMs: 0,
                minMs: 0,
                maxMs: 0)
        }
        let sorted = samples.sorted()
        let count = sorted.count
        let sum = sorted.reduce(0, +)
        let mean = sum / Double(count)
        let p50Idx = max(0, min(count - 1,
            Int(Double(count) * p50)))
        let p99Idx = max(0, min(count - 1,
            Int(Double(count) * p99)))
        return BASMambaInferenceLatencyBandSummary(
            band: band,
            sampleCount: count,
            p50Ms: sorted[p50Idx],
            p99Ms: sorted[p99Idx],
            meanMs: mean,
            minMs: sorted.first ?? 0,
            maxMs: sorted.last ?? 0)
    }

    /// Reset all samples + counter。Useful for per-session
    /// tracking where each session starts fresh。
    public func reset() {
        samplesByBand.removeAll()
        totalCalls = 0
    }
}
