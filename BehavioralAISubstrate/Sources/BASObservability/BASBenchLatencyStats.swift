import Foundation

/// M355 — typed benchmark latency statistics primitive.
///
/// Generalises the M334 `ThroughputBenchDemo.LatencyStats` (which
/// shipped with min/max/mean/p50/p95/p99) into a reusable BAS-side
/// type with extended statistics:
///
///   - p99.9 (one-in-a-thousand tail)
///   - sample count
///   - variance + standard deviation
///   - outlier count (samples beyond 3 standard deviations from mean)
///
/// All bench modes (M357 audit-ledger / M358 multi-host-merge / M359
/// full-stack) use this primitive so their stats output is uniform
/// and can be diffed against baselines via M356
/// `BASBenchBaselineStorage`.
///
/// ## Doctrine — REGRESSION ALARM, NOT AN SLA
///
/// Inherits the M340 scope statement: numbers from this primitive
/// measure substrate-internal cycle latency or in-process
/// computation only. They are NOT customer-facing latency
/// commitments. Real-session latency adds AFM inference + audit
/// ledger I/O + actor hops which can be 100x to 10000x larger than
/// what a focused bench shows.
///
/// ## Algorithm
///
/// - Percentiles use the **nearest-rank** method (same as M179 +
///   M334): `index = ceil(p × N) - 1` over the sorted samples.
///   No interpolation. Reproducible across runs given the same
///   input.
/// - Variance uses the **population formula** (`Σ(x - μ)² / N`),
///   not the sample formula (`Σ(x - μ)² / (N-1)`). Bench data is
///   the entire population for the run, not a sample of a larger
///   distribution.
/// - Outlier count is the number of samples with `|x - μ| > 3σ`.
///   For a normal distribution this is ~0.27% of samples; sharply
///   higher counts indicate a multi-modal distribution (cold-start
///   spikes / GC pauses / actor handoff jitter).
public struct BASBenchLatencyStats:
    Sendable, Equatable, Codable
{

    // MARK: - Required core stats

    /// Number of samples that fed into the stats. Always > 0
    /// for valid stats.
    public let sampleCount: Int

    /// Smallest sample value.
    public let min: Double

    /// Largest sample value.
    public let max: Double

    /// Arithmetic mean of all samples.
    public let mean: Double

    /// Median (50th percentile).
    public let p50: Double

    /// 95th percentile.
    public let p95: Double

    /// 99th percentile.
    public let p99: Double

    /// 99.9th percentile (one-in-a-thousand tail).
    public let p999: Double

    /// Population standard deviation (`sqrt(variance)`).
    public let standardDeviation: Double

    /// Number of samples beyond 3 standard deviations from the
    /// mean. For a unimodal normal distribution this is ~0.27% of
    /// `sampleCount`; sharply higher indicates non-normal
    /// distribution.
    public let outlierCount: Int

    public init(
        sampleCount: Int,
        min: Double,
        max: Double,
        mean: Double,
        p50: Double,
        p95: Double,
        p99: Double,
        p999: Double,
        standardDeviation: Double,
        outlierCount: Int
    ) {
        self.sampleCount = sampleCount
        self.min = min
        self.max = max
        self.mean = mean
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
        self.p999 = p999
        self.standardDeviation = standardDeviation
        self.outlierCount = outlierCount
    }

    // MARK: - Derived

    /// Population variance — `standardDeviation²`.
    public var variance: Double {
        standardDeviation * standardDeviation
    }

    /// Outlier rate as a fraction of sample count. Returns 0
    /// when `sampleCount == 0`.
    public var outlierRate: Double {
        guard sampleCount > 0 else { return 0 }
        return Double(outlierCount) / Double(sampleCount)
    }

    /// Coefficient of variation — `stddev / mean`. Returns 0
    /// when `mean == 0`. Useful for cross-mean comparison
    /// (smaller = tighter distribution).
    public var coefficientOfVariation: Double {
        guard mean != 0 else { return 0 }
        return standardDeviation / mean
    }

    // MARK: - Construction

    /// Compute stats from a list of samples (any order; internally
    /// sorted). Returns nil for empty input. All input samples
    /// expected to be non-negative latencies in a uniform unit
    /// (ms, µs, ns — the primitive is unit-agnostic; consumers
    /// pick their unit and stick to it).
    public static func compute(
        samples: [Double]
    ) -> BASBenchLatencyStats? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let n = sorted.count
        let sum = sorted.reduce(0, +)
        let mean = sum / Double(n)

        // Population variance.
        var sumSquaredDeviations = 0.0
        for sample in sorted {
            let delta = sample - mean
            sumSquaredDeviations += delta * delta
        }
        let variance = sumSquaredDeviations / Double(n)
        let stddev = variance.squareRoot()

        // Outliers — samples beyond ±3σ from mean.
        let threshold = 3.0 * stddev
        var outliers = 0
        if threshold > 0 {
            for sample in sorted where
                Swift.abs(sample - mean) > threshold
            {
                outliers += 1
            }
        }

        return BASBenchLatencyStats(
            sampleCount: n,
            min: sorted.first!,
            max: sorted.last!,
            mean: mean,
            p50: percentile(sorted: sorted, p: 0.50),
            p95: percentile(sorted: sorted, p: 0.95),
            p99: percentile(sorted: sorted, p: 0.99),
            p999: percentile(sorted: sorted, p: 0.999),
            standardDeviation: stddev,
            outlierCount: outliers)
    }

    /// Nearest-rank percentile. Same algorithm as M179 / M334 —
    /// `index = ceil(p × N) - 1`, clamped to `[0, N-1]`.
    public static func percentile(
        sorted: [Double], p: Double
    ) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let n = sorted.count
        let rawIndex =
            Int((p * Double(n)).rounded(.up)) - 1
        let clamped = Swift.min(
            Swift.max(0, rawIndex), n - 1)
        return sorted[clamped]
    }

    // MARK: - Human-readable formatting

    /// Returns a multi-line string suitable for sample-host banner
    /// output. Format mirrors M334's existing banner shape but
    /// adds p99.9 + stddev + outliers.
    public func bannerLines(
        unit: String = "ms",
        labelWidth: Int = 14
    ) -> [String] {
        func pad(_ label: String) -> String {
            let target = Swift.max(labelWidth, label.count + 1)
            let extra = target - label.count
            return label + String(repeating: " ", count: extra)
        }
        func fmt(_ value: Double) -> String {
            String(format: "%.4f", value) + " " + unit
        }
        return [
            pad("samples:") + "\(sampleCount)",
            pad("min:") + fmt(min),
            pad("p50:") + fmt(p50),
            pad("p95:") + fmt(p95),
            pad("p99:") + fmt(p99),
            pad("p99.9:") + fmt(p999),
            pad("max:") + fmt(max),
            pad("mean:") + fmt(mean),
            pad("stddev:") + fmt(standardDeviation),
            pad("outliers:")
                + "\(outlierCount) "
                + "(" + String(format: "%.3f%%",
                               outlierRate * 100.0) + ")",
            pad("CV:")
                + String(format: "%.4f", coefficientOfVariation),
        ]
    }
}
