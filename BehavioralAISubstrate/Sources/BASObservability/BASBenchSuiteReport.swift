import Foundation

/// M362 — typed aggregator for multi-bench suite runs.
///
/// Pre-M362 each bench mode emitted its own banner; running multiple
/// benches required parsing each banner separately. M362 ships a
/// typed primitive that aggregates per-bench measurements into a
/// single Codable record + emits both a machine-readable JSON
/// payload and a human-readable markdown table for sample-host
/// banner output.
///
/// ## Doctrine
///
/// Inherits the M340 scope statement: numbers in the report are
/// regression alarms, not customer-facing latency commitments. The
/// markdown table format is for human review (PR descriptions,
/// release notes); the JSON format is for downstream tooling
/// (CI dashboards, baseline diff scripts).
public struct BASBenchSuiteReport:
    Sendable, Equatable, Codable
{

    // MARK: - Per-bench result

    /// One row in the suite report. Carries the bench identifier
    /// + warmup-aware latency outcome + optional notes.
    public struct BenchResult:
        Sendable, Equatable, Codable
    {
        public let benchName: String

        /// Optional sub-label for benches that produce multiple
        /// rows (e.g., M358 multi-host-merge runs at 4 frame
        /// counts). Nil for single-row benches.
        public let scenarioLabel: String?

        /// Warmup-aware outcome (M361). For benches that don't
        /// distinguish cold/warm (e.g., M334 pure value-type
        /// state machine), this can be a no-warmup outcome.
        public let outcome: BASBenchWarmupOutcome

        /// Number of seconds the bench's wall-clock took
        /// end-to-end (sum of all sample latencies plus
        /// per-sample bookkeeping).
        public let elapsedSeconds: Double

        /// Optional free-form notes (e.g., "10K entries
        /// appended to in-memory ledger").
        public let notes: String?

        public init(
            benchName: String,
            scenarioLabel: String? = nil,
            outcome: BASBenchWarmupOutcome,
            elapsedSeconds: Double,
            notes: String? = nil
        ) {
            self.benchName = benchName
            self.scenarioLabel = scenarioLabel
            self.outcome = outcome
            self.elapsedSeconds = elapsedSeconds
            self.notes = notes
        }
    }

    // MARK: - Top-level fields

    public let schemaVersion: String
    public let suiteName: String
    public let runStartedAt: Date
    public let runCompletedAt: Date
    public let totalElapsedSeconds: Double
    public let benches: [BenchResult]

    public init(
        schemaVersion: String =
            "bas-bench-suite-report.v1",
        suiteName: String,
        runStartedAt: Date,
        runCompletedAt: Date,
        totalElapsedSeconds: Double,
        benches: [BenchResult]
    ) {
        self.schemaVersion = schemaVersion
        self.suiteName = suiteName
        self.runStartedAt = runStartedAt
        self.runCompletedAt = runCompletedAt
        self.totalElapsedSeconds = totalElapsedSeconds
        self.benches = benches
    }

    // MARK: - Output formats

    /// Pretty-printed JSON suitable for downstream tools.
    /// Pair with `decodeJSON(from:)` for symmetric round-trip.
    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Pretty-printed JSON as String (UTF-8). Caller-friendly
    /// alias when the JSON is going straight to stdout.
    public func encodedJSONString() throws -> String {
        let data = try encodedJSON()
        return String(
            data: data, encoding: .utf8) ?? ""
    }

    /// Decode a `BASBenchSuiteReport` from JSON. Symmetric with
    /// `encodedJSON()` — uses the matching ISO8601 date
    /// strategy. Default `JSONDecoder()` would expect Double
    /// timestamps and fail to round-trip.
    public static func decodeJSON(
        from data: Data
    ) throws -> BASBenchSuiteReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            BASBenchSuiteReport.self, from: data)
    }

    /// Markdown table suitable for embedding in PR descriptions
    /// or release notes. Columns: bench / scenario / samples /
    /// p50 / p95 / p99 / mean / max / wall (sec).
    /// Uses the warm distribution (or combined when warm is
    /// nil) so cold-start spikes don't dominate the table.
    public func markdownTable(unit: String = "ms") -> String {
        var lines: [String] = []
        lines.append(
            "| bench | scenario | samples | p50 | p95 " +
            "| p99 | mean | max | wall (sec) |")
        lines.append(
            "|---|---|---:|---:|---:|---:|---:|---:|---:|")
        for bench in benches {
            let stats = bench.outcome.warm
                ?? bench.outcome.combined
            let scenario = bench.scenarioLabel ?? "—"
            func fmt(_ v: Double) -> String {
                String(format: "%.4f", v) + unit
            }
            lines.append(
                "| \(bench.benchName) | \(scenario) " +
                "| \(stats.sampleCount) " +
                "| \(fmt(stats.p50)) " +
                "| \(fmt(stats.p95)) " +
                "| \(fmt(stats.p99)) " +
                "| \(fmt(stats.mean)) " +
                "| \(fmt(stats.max)) " +
                "| \(String(format: "%.4f", bench.elapsedSeconds)) |")
        }
        return lines.joined(separator: "\n")
    }

    /// M372 chapter 八十四 — markdown table extended with a
    /// "vs baseline" delta column on p50 / mean. Loads baselines
    /// from `baselineDirectory` (one file per bench:
    /// `<benchName>.json`). Missing baseline → "n/a". Same
    /// shape as `markdownTable(unit:)` plus 2 extra columns.
    /// Quality-of-life upgrade for tracking improvements made
    /// via M369/M370 etc. — see CHANGELOG / chapter 八十四.
    public func markdownTableWithBaselineDelta(
        unit: String = "ms",
        baselineDirectory: URL
    ) -> String {
        var lines: [String] = []
        lines.append(
            "| bench | scenario | samples | p50 | Δp50 " +
            "| p95 | p99 | mean | Δmean | max | wall (sec) |")
        lines.append(
            "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for bench in benches {
            let stats = bench.outcome.warm
                ?? bench.outcome.combined
            let scenario = bench.scenarioLabel ?? "—"
            let baselinePath = baselineDirectory
                .appendingPathComponent(
                    "\(bench.benchName).json")
            let baseline = (try? BASBenchBaselineStorage
                .readBaseline(from: baselinePath)) ?? nil
            func fmt(_ v: Double) -> String {
                String(format: "%.4f", v) + unit
            }
            func deltaCell(
                baseline baselineValue: Double,
                measured: Double
            ) -> String {
                guard baselineValue > 0 else { return "n/a" }
                let pct = (measured - baselineValue)
                    / baselineValue * 100.0
                let sign = pct >= 0 ? "+" : ""
                return String(format: "%@%.1f%%", sign, pct)
            }
            let p50Delta = baseline.map {
                deltaCell(
                    baseline: $0.stats.p50,
                    measured: stats.p50)
            } ?? "n/a"
            let meanDelta = baseline.map {
                deltaCell(
                    baseline: $0.stats.mean,
                    measured: stats.mean)
            } ?? "n/a"
            lines.append(
                "| \(bench.benchName) | \(scenario) " +
                "| \(stats.sampleCount) " +
                "| \(fmt(stats.p50)) " +
                "| \(p50Delta) " +
                "| \(fmt(stats.p95)) " +
                "| \(fmt(stats.p99)) " +
                "| \(fmt(stats.mean)) " +
                "| \(meanDelta) " +
                "| \(fmt(stats.max)) " +
                "| \(String(format: "%.4f", bench.elapsedSeconds)) |")
        }
        return lines.joined(separator: "\n")
    }

    /// Multi-line banner suitable for sample-host stdout. One
    /// section per bench, then a summary footer.
    public func bannerLines(unit: String = "ms") -> [String] {
        var lines: [String] = []
        lines.append("══ Bench Suite: \(suiteName) ══")
        lines.append(
            "  total wall: \(String(format: "%.2f", totalElapsedSeconds)) sec")
        lines.append(
            "  benches:    \(benches.count)")
        lines.append("")
        for bench in benches {
            let scenario = bench.scenarioLabel
                .map { " (\($0))" } ?? ""
            lines.append(
                "── \(bench.benchName)\(scenario) ──")
            lines.append(
                "  wall:  \(String(format: "%.4f", bench.elapsedSeconds)) sec")
            if let notes = bench.notes {
                lines.append("  notes: \(notes)")
            }
            for line in bench.outcome.bannerLines(
                unit: unit)
            {
                lines.append("  " + line)
            }
            lines.append("")
        }
        lines.append(
            "══ Suite complete — \(benches.count) benches ══")
        return lines
    }
}
