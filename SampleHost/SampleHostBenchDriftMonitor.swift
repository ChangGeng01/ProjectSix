// MARK: - SampleHostBenchDriftMonitor
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M721 component invariant.

import Foundation

// MARK: - M721 drift threshold monitor

/// Welford std-dev tracker for residuals. Caller feeds `update(_:)`
/// per sample; queries `stdDev` / `mean` / `nSigmaAbove`. Threshold
/// crossings emit a flag that bench loop can attach to row's
/// `anomalyFlags`.
///
/// Welford recurrence:
///   M_n = M_{n-1} + (x_n - M_{n-1}) / n
///   S_n = S_{n-1} + (x_n - M_{n-1}) * (x_n - M_n)
///   var = S_n / (n - 1)  (sample variance)
final class SampleHostBenchDriftMonitor: @unchecked Sendable {
    private(set) var count: Int = 0
    private(set) var mean: Double = 0
    private var sumSquaredDiff: Double = 0
    private let lock = NSLock()

    /// Variance (sample). 0 if count < 2.
    var variance: Double {
        lock.lock(); defer { lock.unlock() }
        guard count > 1 else { return 0 }
        return sumSquaredDiff / Double(count - 1)
    }

    /// Standard deviation (sample). 0 if count < 2.
    var stdDev: Double { sqrt(variance) }

    /// Update with a new sample. NaN/Inf samples are dropped.
    func update(_ x: Double) {
        guard x.isFinite else { return }
        lock.lock(); defer { lock.unlock() }
        count += 1
        let delta = x - mean
        mean += delta / Double(count)
        let delta2 = x - mean
        sumSquaredDiff += delta * delta2
    }

    /// Returns sigma multiple of `x` above the running mean.
    /// Negative when x < mean. 0 if stdDev == 0.
    func sigmaAbove(_ x: Double) -> Double {
        let s = stdDev
        guard s > 0 else { return 0 }
        return (x - mean) / s
    }

    /// Reset counters. Call on bench Stop→Start.
    func reset() {
        lock.lock(); defer { lock.unlock() }
        count = 0
        mean = 0
        sumSquaredDiff = 0
    }
}
