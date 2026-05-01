import Foundation

/// M361 — typed warmup configuration + cold/warm split outcome.
///
/// Pre-M361 every bench mode mixed cold-start samples (first turn /
/// first append / first merge) with warm-state samples in one
/// `BASBenchLatencyStats` aggregate. This produced misleading
/// distributions:
///
///   - p99 / p99.9 dominated by cold-start spikes
///   - mean inflated by ~10-100x compared to warm-state median
///   - coefficient of variation always high (signaling bimodal
///     distribution), but no way to separate the two modes
///
/// Chapter 八十二.5 audit-ledger smoke showed this directly:
/// outlier rate 3.000% (11x normal), CV 0.36 — both red flags
/// pointing at "two distinct distributions glued together".
/// Chapter 八十二.7 full-stack smoke showed it more starkly:
/// p95 = 76.7ms (cold) but p50 = 5.3ms (warm), CV = 1.71.
///
/// M361 lets bench callers split: first N samples into a cold
/// `BASBenchLatencyStats`, remaining samples into a warm one.
/// Both are reported. Downstream tools can compare warm-only
/// across runs (apples-to-apples) while keeping cold for
/// startup-cost monitoring.
public struct BASBenchWarmupConfig:
    Sendable, Equatable, Codable
{
    /// Number of initial samples to classify as cold-start.
    /// Default 1 — first call is almost always JIT / cache /
    /// allocator warmup.
    public let coldSampleCount: Int

    /// Whether the cold samples should also be included in the
    /// warm distribution. Default false — strict separation
    /// (cold samples appear ONLY in cold stats, never in warm).
    public let includeColdInWarm: Bool

    public init(
        coldSampleCount: Int = 1,
        includeColdInWarm: Bool = false
    ) {
        // Negative cold counts make no sense; clamp to 0
        // (treat as "no warmup phase, all samples warm").
        self.coldSampleCount = Swift.max(0, coldSampleCount)
        self.includeColdInWarm = includeColdInWarm
    }

    /// Convenience — no warmup separation. All samples treated
    /// as warm.
    public static let none = BASBenchWarmupConfig(
        coldSampleCount: 0)

    /// Convenience — strict 1-sample warmup. First sample is
    /// cold; rest are warm. The most common bench pattern.
    public static let strictFirstSample =
        BASBenchWarmupConfig(coldSampleCount: 1)

    /// Convenience — 5-sample warmup for benches with longer
    /// JIT / cache priming (e.g., MLX / model adapter benches).
    public static let extended =
        BASBenchWarmupConfig(coldSampleCount: 5)
}

/// M361 — outcome of a warmup-aware bench run. Carries both
/// cold and warm latency stats, plus the original full-run
/// stats for backward-compat with M355/M356 baseline comparison.
public struct BASBenchWarmupOutcome:
    Sendable, Equatable, Codable
{
    /// Stats over the entire sample set (cold + warm), for
    /// backward-compat with pre-M361 baseline comparison.
    public let combined: BASBenchLatencyStats

    /// Stats over the first `config.coldSampleCount` samples
    /// only. Nil when `config.coldSampleCount == 0` or when
    /// the input had zero samples.
    public let cold: BASBenchLatencyStats?

    /// Stats over the warm samples only (samples beyond the
    /// cold prefix, optionally including cold per
    /// `config.includeColdInWarm`). Nil when no samples remain
    /// after the cold prefix.
    public let warm: BASBenchLatencyStats?

    /// The warmup configuration used to produce this outcome —
    /// pinned for reproducibility across baseline comparisons.
    public let config: BASBenchWarmupConfig

    public init(
        combined: BASBenchLatencyStats,
        cold: BASBenchLatencyStats?,
        warm: BASBenchLatencyStats?,
        config: BASBenchWarmupConfig
    ) {
        self.combined = combined
        self.cold = cold
        self.warm = warm
        self.config = config
    }

    /// Compute warmup-aware outcome from a list of samples and
    /// a configuration. Returns nil if the input is empty.
    public static func compute(
        samples: [Double],
        config: BASBenchWarmupConfig =
            .strictFirstSample
    ) -> BASBenchWarmupOutcome? {
        guard
            let combined = BASBenchLatencyStats.compute(
                samples: samples)
        else { return nil }

        let coldCount = Swift.min(
            config.coldSampleCount, samples.count)
        let coldSamples = Array(
            samples.prefix(coldCount))
        let warmSamples: [Double]
        if config.includeColdInWarm {
            warmSamples = samples
        } else {
            warmSamples = Array(
                samples.dropFirst(coldCount))
        }

        return BASBenchWarmupOutcome(
            combined: combined,
            cold: BASBenchLatencyStats.compute(
                samples: coldSamples),
            warm: BASBenchLatencyStats.compute(
                samples: warmSamples),
            config: config)
    }

    /// Multi-line banner output: combined first, then cold and
    /// warm if present. Mirrors `BASBenchLatencyStats.bannerLines`
    /// shape for uniformity.
    public func bannerLines(unit: String = "ms") -> [String] {
        var lines: [String] = []
        lines.append(
            "── combined (cold + warm, sample=\(combined.sampleCount)) ──")
        for line in combined.bannerLines(unit: unit) {
            lines.append("  " + line)
        }
        if let cold = cold, cold.sampleCount > 0 {
            lines.append(
                "── cold (first \(cold.sampleCount) sample(s)) ──")
            for line in cold.bannerLines(unit: unit) {
                lines.append("  " + line)
            }
        }
        if let warm = warm, warm.sampleCount > 0 {
            lines.append(
                "── warm (sample=\(warm.sampleCount)) ──")
            for line in warm.bannerLines(unit: unit) {
                lines.append("  " + line)
            }
        }
        return lines
    }
}
