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

    /// M437 (chapter 一百十) — multi-trial summary capturing
    /// mean ± std across N≥2 release-build trials. Optional
    /// extension to the baseline envelope.
    ///
    /// Pre-M437 the baseline stored a single `BASBenchLatencyStats`
    /// snapshot (one trial's p50/p95/p99/mean). Single-trial
    /// regression detection has a structural floor at ~20%
    /// (chapter 一百九 codification: single-trial release-build
    /// CV is ~10-15% on outlier-heavy benches; tolerance must
    /// stay above that).
    ///
    /// M437 adds optional `trialStats` so callers running
    /// multi-trial captures can store the trial-to-trial mean +
    /// std for each compared metric. When `trialStats` is non-
    /// nil, `compareToBaseline` uses the **mean ± 2σ** check
    /// instead of percentage tolerance, enabling stat-rigorous
    /// detection of <10% regressions.
    ///
    /// Backward-compat: legacy v1 baselines (no `trialStats`)
    /// continue to work via percentage tolerance fallback.
    /// Forward-compat: new v2 baselines store both `stats`
    /// (single-trial last-snapshot) AND `trialStats` (multi-
    /// trial summary) so old readers can still parse them.
    public struct MultiTrialStats: Sendable, Equatable, Codable {
        /// Number of trials in this summary (N≥2 to be
        /// stat-meaningful; N=1 should not produce a
        /// MultiTrialStats — use single-trial path instead).
        public let trialCount: Int

        /// Mean p50 across trials.
        public let p50Mean: Double
        /// Sample standard deviation of p50 across trials.
        public let p50StdDev: Double

        /// Mean p95 across trials.
        public let p95Mean: Double
        /// Sample standard deviation of p95 across trials.
        public let p95StdDev: Double

        /// Mean of mean-latencies across trials.
        public let meanMean: Double
        /// Sample standard deviation of mean-latencies across
        /// trials.
        public let meanStdDev: Double

        public init(
            trialCount: Int,
            p50Mean: Double, p50StdDev: Double,
            p95Mean: Double, p95StdDev: Double,
            meanMean: Double, meanStdDev: Double
        ) {
            self.trialCount = trialCount
            self.p50Mean = p50Mean
            self.p50StdDev = p50StdDev
            self.p95Mean = p95Mean
            self.p95StdDev = p95StdDev
            self.meanMean = meanMean
            self.meanStdDev = meanStdDev
        }

        /// Build from an array of N single-trial stats.
        /// Returns nil for N < 2 (mean ± std from N=1 is
        /// undefined).
        public static func summarize(
            trials: [BASBenchLatencyStats]
        ) -> MultiTrialStats? {
            guard trials.count >= 2 else { return nil }
            func meanStd(_ vs: [Double]) -> (Double, Double) {
                let n = Double(vs.count)
                let m = vs.reduce(0, +) / n
                let sumSq = vs.reduce(0) {
                    $0 + ($1 - m) * ($1 - m)
                }
                // Sample std (n-1 divisor). For n=2, divisor=1;
                // for n=10, divisor=9. Use n-1 because we're
                // estimating population std from samples.
                let variance = sumSq / (n - 1)
                return (m, variance.squareRoot())
            }
            let (p50M, p50S) = meanStd(trials.map(\.p50))
            let (p95M, p95S) = meanStd(trials.map(\.p95))
            let (meanM, meanS) = meanStd(trials.map(\.mean))
            return MultiTrialStats(
                trialCount: trials.count,
                p50Mean: p50M, p50StdDev: p50S,
                p95Mean: p95M, p95StdDev: p95S,
                meanMean: meanM, meanStdDev: meanS)
        }
    }

    /// Schema-versioned envelope for a stored baseline.
    ///
    /// **M437 (chapter 一百十)**: schema bumped to v2 to carry
    /// optional `trialStats`. v1 baselines are still readable
    /// (decode treats missing `trialStats` as nil); v2 readers
    /// see both `stats` (single-trial snapshot) and `trialStats`
    /// (multi-trial summary) when both are populated.
    public struct Envelope: Sendable, Equatable, Codable {
        public let schemaVersion: String
        public let benchName: String
        public let storedAt: Date
        public let stats: BASBenchLatencyStats
        /// M437 — optional multi-trial summary. Non-nil only
        /// when capture path ran N≥2 trials. Enables stat-
        /// rigorous mean ± 2σ regression check in
        /// `compareToBaseline`.
        public let trialStats: MultiTrialStats?

        public init(
            schemaVersion: String =
                BASBenchBaselineStorage.currentSchemaVersion,
            benchName: String,
            storedAt: Date = Date(),
            stats: BASBenchLatencyStats,
            trialStats: MultiTrialStats? = nil
        ) {
            self.schemaVersion = schemaVersion
            self.benchName = benchName
            self.storedAt = storedAt
            self.stats = stats
            self.trialStats = trialStats
        }
    }

    /// Default tolerance — 25% of baseline. Measurements within
    /// this fraction count as no-regression.
    public static let defaultToleranceFraction: Double = 0.25

    /// Default schema version for new baselines.
    /// **M437 (chapter 一百十)**: bumped v1 → v2 to carry
    /// optional `MultiTrialStats`. v1 baselines still readable
    /// (treated as no-trialStats); v2 baselines emit both stats
    /// snapshot + trialStats summary when multi-trial capture
    /// ran. The `compareToBaseline` schema-mismatch guard now
    /// accepts both v1 and v2 (forward + backward compat).
    public static let currentSchemaVersion: String =
        "bas-bench-baseline.v2"

    /// **M437**: list of all schema versions this binary can
    /// read. v1 (pre-M437) and v2 (M437) are both accepted.
    /// Used by `compareToBaseline` to decide whether the stored
    /// baseline is compatible.
    public static let supportedSchemaVersions: Set<String> = [
        "bas-bench-baseline.v1",
        "bas-bench-baseline.v2",
    ]

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
        // M437 — accept both v1 and v2 (chapter 一百十 schema
        // bump for multi-trial support). v1 baselines work
        // through the percentage-tolerance fallback path below.
        if !supportedSchemaVersions.contains(
            envelope.schemaVersion)
        {
            return .incompatibleBaseline(
                reason: "expected schemaVersion in " +
                "\(supportedSchemaVersions.sorted()) got " +
                "'\(envelope.schemaVersion)'")
        }
        let baseline = envelope.stats
        var reports: [RegressionReport] = []

        // M437 (chapter 一百十) — multi-trial mean ± 2σ check
        // when baseline carries trial summary. Stat-rigorous
        // detection of <10% regressions; fires when measured >
        // (baseline-mean + 2σ). Falls through to %-tolerance
        // path below when trialStats is nil (v1 baselines or
        // single-trial captures). The 2σ threshold gives ~95%
        // confidence the regression is real (not noise) under
        // assumption of approximately-normal trial-to-trial
        // variation. Same metric set as %-tolerance path
        // (p50/p95/mean; p99 still excluded per M436.6).
        if let trial = envelope.trialStats, trial.trialCount >= 2 {
            let twoSigma: [(String, Double, Double, Double)] = [
                ("p50", trial.p50Mean,
                    trial.p50StdDev, measured.p50),
                ("p95", trial.p95Mean,
                    trial.p95StdDev, measured.p95),
                ("mean", trial.meanMean,
                    trial.meanStdDev, measured.mean),
            ]
            let absoluteFloorMs: Double = 0.005
            for (name, mean, std, measuredValue)
                in twoSigma
            {
                guard mean > 0 else { continue }
                if mean < absoluteFloorMs
                    && measuredValue < absoluteFloorMs
                {
                    continue  // sub-µs floor (M436.6)
                }
                let upper = mean + 2.0 * std
                if measuredValue > upper {
                    let regressionFraction =
                        (measuredValue - mean) / mean
                    reports.append(RegressionReport(
                        metricName: "\(name) (mean+2σ)",
                        baselineValue: mean,
                        measuredValue: measuredValue,
                        toleranceFraction:
                            (2.0 * std) / mean,
                        regressionFraction:
                            regressionFraction))
                }
            }
            if reports.isEmpty {
                return .withinTolerance
            }
            return .regression(reports: reports)
        }

        // %-tolerance fallback path (v1 baselines or v2
        // baselines without multi-trial capture).
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
