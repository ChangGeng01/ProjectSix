// MARK: - BASEvalRegressionDetector — chapter 三百七四 / M861
//
// C2 Auto eval harness primitive #3: typed helper that compares
// two `BASEvalRun` bundles + emits per-metric typed
// `BASEvalRegressionVerdict` values (improved / regressed /
// noChange / missing)。Future P3 G12 auto eval harness wires CI
// gates + retrain feedback on top of this output。
//
// ## What this ships
//
//   - `BASEvalRegressionVerdict` — typed enum classifying each
//     metric comparison outcome
//   - `BASEvalRegressionResult` — Codable per-metric record:
//     baseline value / candidate value / verdict / threshold used
//   - `BASEvalRegressionReport` — bundle of per-metric results +
//     convenience accessors (anyRegressed / allImproved)
//   - `BASEvalRegressionDetector` — namespace with `compare(...)`
//     factory function (mirrors M859 builder pattern)
//
// ## Doctrine pins
//
// - 不变量 #1 / #2 / #3 全保 — regression detection is
//   observation only,never mutates permits / verdicts / commit
//   token
// - 红线 7 hint-only — verdict is HINT;L11 gate decides what
//   action to take (block ship / open ticket / log only)
// - chapter 一百八十五 — every threshold tunable;named typed
//   defaults flow from `BASEvalMetric.defaultDriftTolerance`
// - chapter 二百一一 — ONE detector module,no parallel paths
// - ADR-014 OPT-IN — primitive only,no auto-CI-trigger yet
// - DAG — BASRuntimeCore leaf,Foundation only

import Foundation

// MARK: - BASEvalRegressionVerdict

/// Per-metric classification produced by the regression detector。
/// `BASEvalRegressionReport.results` keys by `BASEvalMetric` and
/// values are this enum + numeric context。
public enum BASEvalRegressionVerdict:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Candidate is meaningfully better than baseline (delta
    /// exceeds tolerance + direction matches improvement)。
    case improved = "improved"
    /// Candidate is meaningfully worse (delta exceeds tolerance
    /// + direction matches regression)。
    case regressed = "regressed"
    /// Delta is within tolerance band — no significant signal。
    case noChange = "no-change"
    /// Metric absent from one or both runs — can't compare。
    case missing = "missing"
}

// MARK: - BASEvalRegressionResult

/// Codable per-metric record holding baseline + candidate values,
/// the verdict,and the tolerance threshold used。Future eval
/// harness persists these for cross-build trend analysis。
public struct BASEvalRegressionResult:
    Sendable, Equatable, Codable, Hashable
{
    /// Which metric this result describes。
    public let metric: BASEvalMetric

    /// Baseline value (nil if missing)。
    public let baselineValue: Double?

    /// Candidate value (nil if missing)。
    public let candidateValue: Double?

    /// Verdict for this metric。
    public let verdict: BASEvalRegressionVerdict

    /// Relative delta `(candidate - baseline) / baseline` when
    /// both values present + baseline non-zero。Nil otherwise。
    /// Sign is direction-aware:positive = candidate higher。
    public let relativeDelta: Double?

    /// Tolerance threshold used for this comparison (defaults
    /// to `metric.defaultDriftTolerance` unless host overrode)。
    public let toleranceUsed: Double

    public init(
        metric: BASEvalMetric,
        baselineValue: Double?,
        candidateValue: Double?,
        verdict: BASEvalRegressionVerdict,
        relativeDelta: Double?,
        toleranceUsed: Double
    ) {
        self.metric = metric
        self.baselineValue = baselineValue
        self.candidateValue = candidateValue
        self.verdict = verdict
        self.relativeDelta = relativeDelta
        self.toleranceUsed = toleranceUsed
    }
}

// MARK: - BASEvalRegressionReport

/// Bundle of per-metric `BASEvalRegressionResult` records plus
/// convenience accessors。Hosts query this to decide CI gate
/// behavior (e.g. "any regressed → block PR")。
public struct BASEvalRegressionReport:
    Sendable, Equatable, Codable, Hashable
{
    /// Run ID of the baseline。
    public let baselineRunID: String

    /// Run ID of the candidate。
    public let candidateRunID: String

    /// Per-metric results。Keyed by `BASEvalMetric.rawValue` for
    /// JSON-friendly encoding (mirrors M861 BASEvalRun idiom)。
    public let results: [BASEvalMetric: BASEvalRegressionResult]

    public init(
        baselineRunID: String,
        candidateRunID: String,
        results: [BASEvalMetric: BASEvalRegressionResult]
    ) {
        self.baselineRunID = baselineRunID
        self.candidateRunID = candidateRunID
        self.results = results
    }

    /// True iff at least one metric regressed (CI gate signal)。
    public var anyRegressed: Bool {
        results.values.contains { $0.verdict == .regressed }
    }

    /// True iff every comparable metric improved。`missing` and
    /// `noChange` count against this (must be `.improved` for
    /// ALL metrics)。
    public var allImproved: Bool {
        guard !results.isEmpty else { return false }
        return results.values.allSatisfy {
            $0.verdict == .improved
        }
    }

    /// True iff the report contains zero regressions AND at
    /// least one improvement (typical "ship signal" semantics)。
    public var safeToShip: Bool {
        !anyRegressed && results.values.contains {
            $0.verdict == .improved
        }
    }

    /// Convenience: regressed metric subset。
    public var regressedMetrics: [BASEvalMetric] {
        results
            .filter { $0.value.verdict == .regressed }
            .keys
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Convenience: improved metric subset。
    public var improvedMetrics: [BASEvalMetric] {
        results
            .filter { $0.value.verdict == .improved }
            .keys
            .sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Codable

    /// Custom Codable encodes `results` as JSON object keyed by
    /// metric rawValue (consistent with `BASEvalRun`)。
    private enum CodingKeys: String, CodingKey {
        case baselineRunID
        case candidateRunID
        case results
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self)
        self.baselineRunID = try container.decode(
            String.self, forKey: .baselineRunID)
        self.candidateRunID = try container.decode(
            String.self, forKey: .candidateRunID)

        let stringKeyed = try container.decode(
            [String: BASEvalRegressionResult].self,
            forKey: .results)
        var typed: [BASEvalMetric: BASEvalRegressionResult] = [:]
        for (key, value) in stringKeyed {
            if let metric = BASEvalMetric(rawValue: key) {
                typed[metric] = value
            }
        }
        self.results = typed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self)
        try container.encode(
            baselineRunID, forKey: .baselineRunID)
        try container.encode(
            candidateRunID, forKey: .candidateRunID)

        var stringKeyed:
            [String: BASEvalRegressionResult] = [:]
        for (metric, result) in results {
            stringKeyed[metric.rawValue] = result
        }
        try container.encode(
            stringKeyed, forKey: .results)
    }
}

// MARK: - BASEvalRegressionDetector

/// Factory namespace for regression detection。Mirror of the M859
/// `BASCognitiveOSBuilder` pattern — pure factory, no hidden
/// state。
public enum BASEvalRegressionDetector {

    /// Compare a candidate run against a baseline run + emit a
    /// per-metric verdict report。
    ///
    /// **Empty-run handling** (chapter 三百七四 doctrine pin):
    ///   - If either run is empty (sampleCount == 0 OR no metrics)
    ///     → return all-`noChange` report (avoid false signals
    ///     when the baseline is uninitialized)
    ///
    /// **Missing-metric handling**:
    ///   - Metric in baseline but not candidate → `.missing`
    ///   - Metric in candidate but not baseline → `.missing`
    ///   - Both present → relative delta + tolerance check
    ///
    /// **Tolerance overrides**:
    ///   - `customTolerances` lets host override the default
    ///     drift tolerance per-metric (chapter 一百八十五 pin)
    ///   - Unspecified metrics fall through to
    ///     `metric.defaultDriftTolerance`
    ///
    /// - Parameters:
    ///   - baseline: prior run (e.g. last green CI build)
    ///   - candidate: new run (e.g. PR build)
    ///   - customTolerances: optional per-metric tolerance
    ///     overrides;defaults to empty
    /// - Returns: typed report keyed by metric
    public static func compare(
        baseline: BASEvalRun,
        candidate: BASEvalRun,
        customTolerances: [BASEvalMetric: Double] = [:]
    ) -> BASEvalRegressionReport {

        // Empty-run defensive pin: emit all-noChange when either
        // side is uninitialized
        if baseline.isEmpty || candidate.isEmpty {
            let unionKeys =
                Set(baseline.metrics.keys)
                    .union(candidate.metrics.keys)
            var results:
                [BASEvalMetric: BASEvalRegressionResult] = [:]
            for metric in unionKeys {
                let tolerance =
                    customTolerances[metric]
                    ?? metric.defaultDriftTolerance
                results[metric] = BASEvalRegressionResult(
                    metric: metric,
                    baselineValue: baseline.metrics[metric],
                    candidateValue: candidate.metrics[metric],
                    verdict: .noChange,
                    relativeDelta: nil,
                    toleranceUsed: tolerance)
            }
            return BASEvalRegressionReport(
                baselineRunID: baseline.runID,
                candidateRunID: candidate.runID,
                results: results)
        }

        // Standard comparison: walk union of metric keys
        let unionKeys =
            Set(baseline.metrics.keys)
                .union(candidate.metrics.keys)

        var results:
            [BASEvalMetric: BASEvalRegressionResult] = [:]
        for metric in unionKeys {
            let baselineValue = baseline.metrics[metric]
            let candidateValue = candidate.metrics[metric]
            let tolerance =
                customTolerances[metric]
                ?? metric.defaultDriftTolerance

            // Missing-metric short-circuit
            guard let bv = baselineValue,
                  let cv = candidateValue else {
                results[metric] = BASEvalRegressionResult(
                    metric: metric,
                    baselineValue: baselineValue,
                    candidateValue: candidateValue,
                    verdict: .missing,
                    relativeDelta: nil,
                    toleranceUsed: tolerance)
                continue
            }

            // Both present → compute delta + classify
            let absoluteDelta = cv - bv
            let relativeDelta: Double? =
                bv != 0 ? absoluteDelta / abs(bv) : nil

            // Within tolerance band → noChange (use absolute
            // when baseline is zero, else relative)
            let comparisonMagnitude: Double =
                bv != 0 ? abs(absoluteDelta / bv) :
                          abs(absoluteDelta)

            if comparisonMagnitude <= tolerance {
                results[metric] = BASEvalRegressionResult(
                    metric: metric,
                    baselineValue: bv,
                    candidateValue: cv,
                    verdict: .noChange,
                    relativeDelta: relativeDelta,
                    toleranceUsed: tolerance)
                continue
            }

            // Outside tolerance → direction-aware classify
            let candidateHigher = cv > bv
            let verdict: BASEvalRegressionVerdict
            switch metric.direction {
            case .higherIsBetter:
                verdict = candidateHigher
                    ? .improved : .regressed
            case .lowerIsBetter:
                verdict = candidateHigher
                    ? .regressed : .improved
            }

            results[metric] = BASEvalRegressionResult(
                metric: metric,
                baselineValue: bv,
                candidateValue: cv,
                verdict: verdict,
                relativeDelta: relativeDelta,
                toleranceUsed: tolerance)
        }

        return BASEvalRegressionReport(
            baselineRunID: baseline.runID,
            candidateRunID: candidate.runID,
            results: results)
    }
}
