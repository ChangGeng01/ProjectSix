// MARK: - BASEvalMetric — chapter 三百七四 / M861
//
// C2 Auto eval harness primitive #1: typed enum naming the metric
// dimensions a host can record per eval run。Future P3 G12 auto
// eval harness will compose `BASEvalRun` + `BASEvalRegressionDetector`
// on top of this enum to drive CI regression gates + retrain feedback。
//
// ## Why this exists (M840 roadmap G12)
//
// Pre-M861 hosts had NO typed shape for "what eval metrics did this
// build score on". Each host home-rolled its own dictionary keys,
// drifting between runs。Without a typed enum the regression
// detector cannot perform compile-time-checked metric selection —
// e.g. "compare latencyP95 between baseline + candidate" requires
// the metric name to be a typed value, not a free-form string。
//
// ## What this ships
//
//   - `BASEvalMetric` — typed enum with 7 baseline dimensions
//     (accuracy / latencyP50 / latencyP95 / latencyP99 /
//      hallucinationRate / failureRate / driftScore)
//   - `direction` — typed `BASEvalMetricDirection` indicating
//     whether higher or lower values are "better" (drives
//     regression detector improved/regressed classification)
//   - `defaultDriftTolerance` — typed Double per metric (named
//     constants per chapter 一百八十五 anti-magic-number)
//
// ## Doctrine pins
//
// - 不变量 #1 / #2 / #3 全保 — eval is observation only,never
//   mutates permits / verdicts / commit token
// - 红线 7 hint-only — regression detection result is a hint;
//   the gate at L11 still owns the decision
// - chapter 一百八十五 anti-magic-number — every drift tolerance
//   named typed constant,no inline literals
// - chapter 二百一一 single-source-of-truth — ONE enum module
//   owns metric vocabulary,every consumer imports it
// - ADR-014 OPT-IN → PROD — primitive only,no auto-trigger;
//   hosts opt in by recording runs themselves
// - DAG discipline — BASRuntimeCore leaf,Foundation only

import Foundation

// MARK: - BASEvalMetricDirection

/// Whether a higher or lower numeric value of a metric is
/// considered "better" by the regression detector。Latency metrics
/// are `lowerIsBetter`;accuracy is `higherIsBetter`。
public enum BASEvalMetricDirection:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Higher numeric value = better (e.g. accuracy)。
    case higherIsBetter = "higher-is-better"
    /// Lower numeric value = better (e.g. latencyP95)。
    case lowerIsBetter = "lower-is-better"
}

// MARK: - BASEvalMetric

/// Typed enum naming an eval metric dimension。`BASEvalRun.metrics`
/// keys this enum;`BASEvalRegressionDetector` switches on it。
///
/// Hosts adding a new dimension extend the enum + provide
/// `direction` + `defaultDriftTolerance` — these are mandatory per
/// the `CaseIterable` lint guard test (`testEveryMetricHasDirection`
/// + `testEveryMetricHasDriftTolerance`)。
public enum BASEvalMetric:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// Fraction of correct predictions in the eval set,0…1。
    case accuracy = "accuracy"
    /// p50 latency in milliseconds (median)。
    case latencyP50 = "latency-p50-ms"
    /// p95 latency in milliseconds。
    case latencyP95 = "latency-p95-ms"
    /// p99 latency in milliseconds。
    case latencyP99 = "latency-p99-ms"
    /// Fraction of outputs flagged hallucinatory by the verifier
    /// composer,0…1。
    case hallucinationRate = "hallucination-rate"
    /// Fraction of eval samples that errored out (exception /
    /// timeout / verdict.deny),0…1。
    case failureRate = "failure-rate"
    /// Drift signal scalar (e.g. KL divergence between baseline +
    /// candidate output distributions)。
    case driftScore = "drift-score"

    /// Direction that counts as "improvement" for the regression
    /// detector。
    public var direction: BASEvalMetricDirection {
        switch self {
        case .accuracy:
            return .higherIsBetter
        case .latencyP50,
             .latencyP95,
             .latencyP99,
             .hallucinationRate,
             .failureRate,
             .driftScore:
            return .lowerIsBetter
        }
    }

    /// Default per-metric drift tolerance (relative,0…1)。Below
    /// this delta a change is classified `noChange` by the
    /// regression detector。Per chapter 一百八十五 each value is
    /// a named typed constant tunable at the call site。
    ///
    /// Defaults reflect realistic noise floors:
    ///   - accuracy: 0.5% — high precision required
    ///   - latency p50/p95/p99: 5% — measurement noise tolerated
    ///   - hallucinationRate: 1% — semi-tight
    ///   - failureRate: 1% — semi-tight
    ///   - driftScore: 5% — exploratory
    public var defaultDriftTolerance: Double {
        switch self {
        case .accuracy:
            return BASEvalMetricThresholds.accuracyDriftTolerance
        case .latencyP50,
             .latencyP95,
             .latencyP99:
            return BASEvalMetricThresholds.latencyDriftTolerance
        case .hallucinationRate:
            return BASEvalMetricThresholds
                .hallucinationDriftTolerance
        case .failureRate:
            return BASEvalMetricThresholds
                .failureDriftTolerance
        case .driftScore:
            return BASEvalMetricThresholds
                .driftScoreDriftTolerance
        }
    }

    /// Stable typed reason code prefix that appears in regression
    /// signalRefs (e.g. "eval-metric:accuracy" identifies which
    /// metric triggered a regression hint)。
    public var auditCodePrefix: String {
        "eval-metric:\(rawValue)"
    }
}

// MARK: - BASEvalMetricThresholds

/// Typed named constants for default drift tolerances per chapter
/// 一百八十五 anti-magic-number。Hosts override at the regression
/// detector call site;these are the `defaultDriftTolerance`
/// fall-throughs。
public enum BASEvalMetricThresholds {

    /// 0.5% — accuracy demands high precision。
    public static let accuracyDriftTolerance: Double = 0.005

    /// 5% — latency measurement is inherently noisy across
    /// thermal / battery / scheduler conditions。
    public static let latencyDriftTolerance: Double = 0.05

    /// 1% — hallucination rate semi-tight。
    public static let hallucinationDriftTolerance: Double = 0.01

    /// 1% — failure rate semi-tight。
    public static let failureDriftTolerance: Double = 0.01

    /// 5% — drift score is exploratory by definition。
    public static let driftScoreDriftTolerance: Double = 0.05
}
