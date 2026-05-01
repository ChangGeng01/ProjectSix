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
    /// `baselinePath`. Compares the 4 most-relevant metrics:
    /// p50, p95, p99, mean. Other metrics in the envelope (min,
    /// max, p99.9, stddev, outliers) are stored but not compared
    /// — they're for diagnosis, not regression alarms (max alone
    /// is too noisy).
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
        let metrics: [(String, Double, Double)] = [
            ("p50", baseline.p50, measured.p50),
            ("p95", baseline.p95, measured.p95),
            ("p99", baseline.p99, measured.p99),
            ("mean", baseline.mean, measured.mean),
        ]
        for (name, baselineValue, measuredValue) in metrics {
            // Skip metrics where baseline is 0 (we can't compute
            // a meaningful percentage regression from 0).
            guard baselineValue > 0 else { continue }
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
