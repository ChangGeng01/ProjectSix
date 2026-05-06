// MARK: - SampleHostHybridBenchSettings
//
// chapter 二百二十二 / M803 — extracted from SampleHostModel.swift.
//
// Two carve-outs in one file (cohesive bench-settings surface):
//
//   1. `SampleHostHybridBenchBounds` enum: typed bound-clamping
//      pure functions for each `@Published` config flex (duration /
//      stride period / mutation count / anomaly window / drift
//      sigma / mutation prob / checkpoint every N / LLM timeout /
//      cooling every N / cooling sleep).
//
//   2. `extension SampleHostModel { ... }` block carrying the
//      11 hybrid-bench setter methods that delegate to the
//      Bounds functions. (Checkpoint lifecycle methods stay in
//      SampleHostModel.swift because they touch
//      `hybridBenchResumableCheckpoint` which is `@Published
//      private(set)` and cross-file extensions can't write to
//      private(set) properties.)
//
// Pre-this-batch: ~50 LOC of inline setters scattered with each
// duplicating its own `max(min(...))` clamp. Adding a new setting
// required typing the clamp expression by hand.
//
// Post-this-batch: setters in dedicated extension file. Bounds
// doctrine in dedicated typed enum. Each setter is a 1-liner.
// Future settings additions:
//   - Add bound function to `SampleHostHybridBenchBounds`
//   - Add 1-line setter to extension
//   - Add bounds test
// 3-step ritual instead of inline guesswork.
//
// Doctrine pins:
//   - All bounds are CLOSED ranges (max(min(..., upperBound), lowerBound))
//     so out-of-range inputs land at the nearest valid value rather
//     than crashing or being rejected.
//   - chapter 一百九十一 + 一百九十四 + 一百九十五 + 一百九十八
//     bound rationale doc-comments preserved verbatim per setter.
//   - 不变量 #1-#3 + Red line 7: ✓ pure clamping + state writes,
//     no decision-making.
//   - chapter 二百十一 single-source-of-truth: bench-settings
//     bounds invariant owned by one file.

import Foundation

/// Typed bound clamping for `@Published` hybrid-bench config flex.
/// Pure functions; each takes a raw value and returns the closest
/// in-range value. Bench loop reads the @Published values live so
/// mid-bench user adjustments take effect on next iter.
enum SampleHostHybridBenchBounds {
    /// Duration hours: [0.1, 24.0]. Lower bound prevents 0-duration
    /// (no iters); upper bound prevents accidental days-long run.
    static func durationHours(_ v: Double) -> Double {
        max(0.1, min(24.0, v))
    }

    /// Rotation-period iters: [1_000, 100_000]. Determines how often
    /// the stride rotation advances. < 1k = too churn; > 100k = stride
    /// rotation never reaches second stride during a 10h bench.
    static func rotationPeriodIter(_ v: Int) -> Int {
        max(1_000, min(100_000, v))
    }

    /// Mutation-seed count: [1, 5]. Pinned at 5 by chapter 一百七十四
    /// (5-variant alphabet); lower values shrink mutation alphabet
    /// proportionally, never go below 1.
    static func mutationSeedCount(_ v: Int) -> Int {
        max(1, min(5, v))
    }

    /// Anomaly window size: [10, 1000]. Below 10 = noise; above
    /// 1000 = stale signal (chapter 一百九十二 watcher doctrine).
    /// 100 default = chapter 一百九十二 baseline.
    static func anomalyWindowSize(_ v: Int) -> Int {
        max(10, min(1000, v))
    }

    /// Drift sigma threshold: [1.0, 10.0]. Below 1σ = false-positive
    /// flood; above 10σ = drift effectively never alarms. 3.0 default
    /// = chapter 一百九十二 baseline (Welford std-dev).
    static func driftSigmaThreshold(_ v: Double) -> Double {
        max(1.0, min(10.0, v))
    }

    /// Mutation probability: [0.0, 1.0] always. 0 = mutator off;
    /// 1 = every iter mutated. 0.05 = chapter 一百九十二 default.
    static func mutationProbability(_ v: Double) -> Double {
        max(0.0, min(1.0, v))
    }

    /// Checkpoint cadence: [100, 100_000]. < 100 = bench thrashes
    /// disk; > 100k = a crash mid-bench loses too much. 1000 default.
    static func checkpointEveryNIters(_ v: Int) -> Int {
        max(100, min(100_000, v))
    }

    /// M735 chapter 一百九十五 — per-iter LLM timeout (seconds).
    /// Bounds: [5s, 300s = 5min]. Lower bound prevents pathological
    /// always-timeout; upper bound prevents defeating timeout's
    /// purpose (60s default).
    static func llmTimeoutSeconds(_ v: Double) -> Double {
        max(5.0, min(300.0, v))
    }

    /// M744 chapter 一百九十八 — cooling cadence (every N iters).
    /// Bounds: [0, 100_000]. 0 = disabled. 1000 ≈ every 55s on
    /// 18-iter/s iPhone. Disabled by default (operator opts in
    /// for hot-device 10h runs).
    static func coolingEveryNIters(_ v: Int) -> Int {
        max(0, min(100_000, v))
    }

    /// M744 chapter 一百九十八 — cooling sleep duration (seconds).
    /// Bounds: [5, 60]. < 5s = ineffective; > 60s = bench stalls.
    /// 10s default lets thermal recover slowly across iter clusters.
    static func coolingSleepSeconds(_ v: Double) -> Double {
        max(5.0, min(60.0, v))
    }
}

// MARK: - Hybrid bench setters (1-line delegates to Bounds)

extension SampleHostModel {
    func updateHybridBenchDurationHours(_ newValue: Double) {
        hybridBenchDurationHours =
            SampleHostHybridBenchBounds.durationHours(newValue)
    }

    func updateHybridBenchStrideCSV(_ newValue: String) {
        hybridBenchStrideRotationCSV = newValue
    }

    func updateHybridBenchRotationPeriod(_ newValue: Int) {
        hybridBenchRotationPeriodIter =
            SampleHostHybridBenchBounds.rotationPeriodIter(newValue)
    }

    func updateHybridBenchMutationCount(_ newValue: Int) {
        hybridBenchMutationSeedCount =
            SampleHostHybridBenchBounds.mutationSeedCount(newValue)
    }

    // M731 chapter 一百九十四 — bound-enforcing setters for the
    // chapter-192 safety-kit flex constants. Doctrine: bench
    // loop reads the @Published value live but ranges must stay
    // within sane operating envelope so mid-bench adjustments
    // don't break invariants (e.g. windowSize = 0 → infinite loop).
    func updateAnomalyWindowSize(_ v: Int) {
        hybridBenchAnomalyWindowSize =
            SampleHostHybridBenchBounds.anomalyWindowSize(v)
    }
    func updateDriftSigmaThreshold(_ v: Double) {
        hybridBenchDriftSigmaThreshold =
            SampleHostHybridBenchBounds.driftSigmaThreshold(v)
    }
    func updateMutationProbability(_ v: Double) {
        hybridBenchMutationProbability =
            SampleHostHybridBenchBounds.mutationProbability(v)
    }
    func updateCheckpointEveryNIters(_ v: Int) {
        hybridBenchCheckpointEveryNIters =
            SampleHostHybridBenchBounds.checkpointEveryNIters(v)
    }
    /// M735 chapter 一百九十五 — per-iter LLM timeout setter.
    /// Bounds: [5s, 300s = 5min]. 60s default. Bounds protect
    /// against pathological 0-second (always timeout) and
    /// unreasonably-long (defeats purpose) settings.
    func updateLLMTimeoutSeconds(_ v: Double) {
        hybridBenchLLMTimeoutSeconds =
            SampleHostHybridBenchBounds.llmTimeoutSeconds(v)
    }
    /// M744 chapter 一百九十八 — cooling-every-N-iters setter.
    /// Bounds: [0, 100_000]. 0 = disabled. 1000 = every ~55s on
    /// 18 iter/sec iPhone.
    func updateCoolingEveryNIters(_ v: Int) {
        hybridBenchCoolingEveryNIters =
            SampleHostHybridBenchBounds.coolingEveryNIters(v)
    }
    /// M744 chapter 一百九十八 — cooling sleep seconds setter.
    /// Bounds: [5, 60]. 10s default lets thermal recover slowly.
    func updateCoolingSleepSeconds(_ v: Double) {
        hybridBenchCoolingSleepSeconds =
            SampleHostHybridBenchBounds.coolingSleepSeconds(v)
    }
}
