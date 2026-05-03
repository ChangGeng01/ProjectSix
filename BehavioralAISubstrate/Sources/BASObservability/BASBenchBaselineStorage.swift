import Foundation

/// M356 — typed baseline storage + regression detection for
/// `BASBenchLatencyStats`.
///
/// Pre-M356 the M179 + M334 benches output stats but had no
/// persistent baseline to compare against. A regression alarm
/// without a stored prior is just a number — the operator has to
/// remember last week's p95 by hand. M356 ships a typed primitive
/// that reads / writes / compares baselines as JSON files.
///
/// ## Doctrine
///
/// - **Regression alarm, not an SLA.** Inherits the M340 scope
///   pin. The threshold is a regression-detector, not a
///   customer-facing latency commitment.
/// - **Baselines are committable.** The intended workflow is to
///   commit `bench_baseline.json` files to git so PRs that
///   regress show up in code review. Baselines are NOT generated
///   on the fly per CI run.
/// - **Default threshold is 25%.** A new measurement that's
///   within 25% of baseline counts as "within tolerance"; beyond
///   that fires `.regression(...)`. Tunable per-bench.
public struct BASBenchBaselineStorage: Sendable {

    /// Comparison verdict between a measurement and a stored
    /// baseline.
    public enum ComparisonVerdict:
        Sendable, Equatable, Codable
    {
        /// All compared metrics are within tolerance of baseline.
        case withinTolerance

        /// At least one compared metric exceeded the tolerance
        /// threshold (regression). Includes per-metric details.
        case regression(reports: [RegressionReport])

        /// The baseline existed but used an incompatible schema
        /// (e.g., baseline file was produced by a different
        /// bench mode, or schema version mismatch).
        case incompatibleBaseline(reason: String)

        /// No baseline file exists at the given path. Caller
        /// typically writes a fresh baseline.
        case noBaseline
    }

    /// One regression report — which metric regressed, by how
    /// much.
    public struct RegressionReport:
        Sendable, Equatable, Codable
    {
        public let metricName: String
        public let baselineValue: Double
        public let measuredValue: Double
        public let toleranceFraction: Double
        public let regressionFraction: Double

        public init(
            metricName: String,
            baselineValue: Double,
            measuredValue: Double,
            toleranceFraction: Double,
            regressionFraction: Double
        ) {
            self.metricName = metricName
            self.baselineValue = baselineValue
            self.measuredValue = measuredValue
            self.toleranceFraction = toleranceFraction
            self.regressionFraction = regressionFraction
        }
    }

    /// Schema-versioned envelope for a stored baseline.
    public struct Envelope: Sendable, Equatable, Codable {
        public let schemaVersion: String
        public let benchName: String
        public let storedAt: Date
        public let stats: BASBenchLatencyStats

        public init(
            schemaVersion: String =
                "bas-bench-baseline.v1",
            benchName: String,
            storedAt: Date = Date(),
            stats: BASBenchLatencyStats
        ) {
            self.schemaVersion = schemaVersion
            self.benchName = benchName
            self.storedAt = storedAt
            self.stats = stats
        }
    }

    /// Default tolerance — 25% of baseline. Measurements within
    /// this fraction count as no-regression.
    public static let defaultToleranceFraction: Double = 0.25

    /// Default schema version for new baselines.
    public static let currentSchemaVersion: String =
        "bas-bench-baseline.v1"

    /// Write the envelope to `path` as pretty-printed JSON. The
    /// caller owns directory creation.
    public static func writeBaseline(
        envelope: Envelope, to path: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        try data.write(to: path, options: .atomic)
    }

    /// Read the envelope from `path`. Returns nil if file
    /// doesn't exist; throws if file exists but cannot be
    /// decoded as a baseline envelope.
    public static func readBaseline(
        from path: URL
    ) throws -> Envelope? {
        guard FileManager.default.fileExists(
            atPath: path.path)
        else { return nil }
        let data = try Data(contentsOf: path)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            Envelope.self, from: data)
    }

    /// Compare `measured` stats against baseline stored at
    /// `baselinePath`. Compares 3 most-relevant metrics for
    /// regression alarm: p50, p95, mean.
    ///
    /// **M436.6 (chapter 一百九)**: dropped p99 from the
    /// regression check. p99 is the single 10th-worst sample of
    /// the run (for N=1000, 1-of-1000); it swings 50-150% on
    /// single-trial spikes from OS scheduler jitter alone. After
    /// the 5µs absolute floor was added, p99 was still firing
    /// false-positive alarms on benches with high outlier rates
    /// (audit-ledger has ~2% outlier rate; one outlier moves p99
    /// 60-100%). p99 stays in the JSON baseline for diagnosis +
    /// in the markdown report for visibility, but is no longer
    /// an alarm threshold. Real regressions show in p50 + p95 +
    /// mean simultaneously; tail-only regressions are diagnosed
    /// by hand rather than auto-alarmed.
    ///
    /// Other metrics in the envelope (min, max, p99.9, stddev,
    /// outliers) are stored but not compared — they're for
    /// diagnosis, not regression alarms.
    public static func compareToBaseline(
        measured: BASBenchLatencyStats,
        benchName: String,
        baselinePath: URL,
        toleranceFraction: Double =
            BASBenchBaselineStorage
                .defaultToleranceFraction
    ) throws -> ComparisonVerdict {
        guard
            let envelope = try readBaseline(
                from: baselinePath)
        else {
            return .noBaseline
        }
        if envelope.benchName != benchName {
            return .incompatibleBaseline(
                reason: "expected benchName " +
                "'\(benchName)' got " +
                "'\(envelope.benchName)'")
        }
        if envelope.schemaVersion
            != currentSchemaVersion
        {
            return .incompatibleBaseline(
                reason: "expected schemaVersion " +
                "'\(currentSchemaVersion)' got " +
                "'\(envelope.schemaVersion)'")
        }
        let baseline = envelope.stats
        var reports: [RegressionReport] = []
        // M436.6 — p99 dropped from regression check. Single-
        // trial p99 = single 10th-worst-of-N sample, which swings
        // 50-150% on OS-jitter outliers alone. Real regressions
        // show in p50 + p95 + mean together; tail-only regressions
        // are diagnosed by hand. p99 still appears in the markdown
        // report for visibility.
        let metrics: [(String, Double, Double)] = [
            ("p50", baseline.p50, measured.p50),
            ("p95", baseline.p95, measured.p95),
            ("mean", baseline.mean, measured.mean),
        ]
        // M436.6 (chapter 一百九) — absolute-µs floor for sub-µs
        // benches. At sub-5µs scales (lifecycle / throughput
        // benches) timer jitter dominates: a 1µs jump from
        // baseline 0.7µs to measured 1.7µs is +143% but is
        // pure jitter, not a regression. Without this floor
        // every other run of the suite fires false-positive
        // alarms on sub-µs benches no matter what % tolerance.
        // 5µs floor is empirical: above 5µs the OS scheduler
        // jitter becomes a small fraction; below 5µs it's the
        // dominant signal. ContinuousClock sub-µs measurements
        // are not stat-rigorous in single-trial.
        let absoluteFloorMs: Double = 0.005  // 5µs
        for (name, baselineValue, measuredValue) in metrics {
            // Skip metrics where baseline is 0 (we can't compute
            // a meaningful percentage regression from 0).
            guard baselineValue > 0 else { continue }
            // Skip metrics where both baseline AND measured are
            // below the 5µs absolute floor — sub-µs scale is
            // timer-jitter-dominated and unreliable for single-
            // trial regression detection.
            if baselineValue < absoluteFloorMs
                && measuredValue < absoluteFloorMs
            {
                continue
            }
            let regressionFraction =
                (measuredValue - baselineValue)
                / baselineValue
            if regressionFraction > toleranceFraction {
                reports.append(RegressionReport(
                    metricName: name,
                    baselineValue: baselineValue,
                    measuredValue: measuredValue,
                    toleranceFraction:
                        toleranceFraction,
                    regressionFraction:
                        regressionFraction))
            }
        }
        if reports.isEmpty {
            return .withinTolerance
        }
        return .regression(reports: reports)
    }
}
