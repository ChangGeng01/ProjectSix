import Foundation

// MARK: - M44 — Cross-layer reconciliation verdict engine
//
// Context: M20–M43 built the observation-coverage substrate. Every
// one of the 14 cognitive layers now projects a
// `BASObservationCoverageSummary` (M42 closed the wave at 14-of-14),
// and a single turn's summaries assemble into a
// `BASObservationReconciliationReport` that is deduplicated on layer
// and enforces turn/session invariants on every construction path
// (M31 / M33). M43 proved the 14 summaries compose into one report
// without any layer being structurally silent.
//
// What was missing: a **consumer** — something that reads a report
// and turns "did each layer report healthily enough" into a
// structured, actionable decision. M44 closes that gap with a pure
// value-type verdict engine. It answers three audit questions an L14
// reconciler must answer every turn:
//
//   1. Did every layer the coordinator said would run actually
//      report? (silent-layer audit)
//   2. Did every reporting layer produce enough core signal to prove
//      the layer acted healthily? (coverage-quality audit)
//   3. Did the total wake-budget cost stay under the ceiling this
//      turn? (spend audit)
//
// Design principles:
//   1. Pure — a single top-level `evaluate(...)` with no state, no
//      I/O, no actor hops. Same inputs → same verdict, always.
//   2. Value-typed — verdict, finding, and severity are `Sendable` +
//      `Equatable` + `Codable`. They can be captured, shipped, and
//      written to the audit ledger without transport concerns.
//   3. Additive only — no existing type changes. Callers opt in by
//      handing a report (plus their expected-layer list and ceiling)
//      to the engine. Nothing in M20–M43 needs to move.

/// A single structured observation the verdict engine surfaced while
/// reading the report. The engine never invents a finding — every
/// finding corresponds 1:1 with a condition visible on
/// `BASObservationReconciliationReport` (missing layer / layer
/// without core coverage / total budget above ceiling).
///
/// The ordering the engine emits findings in is deterministic:
/// budget-overspend first (halt-tier), then missing layers in the
/// caller's `expectedLayers` order, then layers reporting without
/// core coverage in the report's first-seen order. Callers can
/// therefore rely on finding order for audit diffing.
public enum BASObservationReconciliationFinding:
    Sendable, Equatable, Codable
{
    /// A layer the caller said should report this turn, but the
    /// report contains no summary for it. Flags silent layers.
    case missingLayer(BASCognitiveLayer)

    /// A layer that did report but whose summary has
    /// `hasCoreSignalCoverage == false`. The layer spoke but did not
    /// produce enough structural signal to prove it acted healthily.
    case layerMissingCoreCoverage(BASCognitiveLayer)

    /// The sum of per-layer clamped budget costs exceeded the
    /// ceiling the caller allowed. Stores the observed total
    /// (already clamped to `[0, 1]` by the report) and the ceiling
    /// used (also clamped to `[0, 1]` before comparison).
    case budgetOverspend(observed: Double, ceiling: Double)
}

/// The final verdict severity. Severity is a simple total order:
/// `.clean < .advisory < .halt`. An L14 reconciler can compare
/// severities directly.
///
/// Semantics:
///   - `.clean` — no findings; every expected layer reported with
///     core coverage and total budget stayed at or below the
///     ceiling.
///   - `.advisory` — at least one layer was missing or produced
///     insufficient core coverage, but the overall run is
///     structurally recoverable. Not a halt.
///   - `.halt` — budget exceeded the ceiling. An L14 reconciler
///     should halt further speculative work this turn.
public enum BASObservationReconciliationSeverity:
    String, Sendable, Equatable, Codable, Comparable, CaseIterable
{
    case clean
    case advisory
    case halt

    /// Implementation of `Comparable`. Uses a small fixed table so
    /// the severity order is explicit and cannot drift if cases are
    /// reordered in source.
    public static func < (
        lhs: BASObservationReconciliationSeverity,
        rhs: BASObservationReconciliationSeverity
    ) -> Bool {
        let order: [BASObservationReconciliationSeverity] = [
            .clean, .advisory, .halt
        ]
        guard
            let l = order.firstIndex(of: lhs),
            let r = order.firstIndex(of: rhs)
        else { return false }
        return l < r
    }
}

/// A structured read of one `BASObservationReconciliationReport`.
/// Carries the turn/session keys the report was for, the overall
/// severity, every finding in deterministic order, and the emission
/// time.
///
/// Invariants:
///   - `turnID` / `sessionID` always match the report the verdict
///     was produced from — `evaluate(...)` copies them out verbatim
///     so an L14 audit can line up verdicts against reports without
///     any additional lookup.
///   - `severity == .clean` iff `findings.isEmpty`. The engine never
///     emits `.clean` with a finding, nor a non-clean severity with
///     no findings.
///   - `severity == .halt` iff at least one `.budgetOverspend`
///     finding is present. Missing-layer and missing-core-coverage
///     are advisory-tier; budget overspend is the only halt trigger
///     in M44. Future waves can add halt-tier findings additively.
public struct BASObservationReconciliationVerdict:
    Sendable, Equatable, Codable
{
    public let turnID: String
    public let sessionID: String
    public let severity: BASObservationReconciliationSeverity
    public let findings: [BASObservationReconciliationFinding]
    public let emittedAt: Date

    public init(
        turnID: String,
        sessionID: String,
        severity: BASObservationReconciliationSeverity,
        findings: [BASObservationReconciliationFinding],
        emittedAt: Date
    ) {
        self.turnID = turnID
        self.sessionID = sessionID
        self.severity = severity
        self.findings = findings
        self.emittedAt = emittedAt
    }
}

/// Pure, stateless evaluator. The caller supplies a report, the set
/// of layers they expected to hear from this turn, and a budget
/// ceiling. The engine emits a structured verdict.
///
/// The engine never throws, never mutates, never does I/O. It is
/// safe to call from any isolation domain. Two calls with the same
/// `(report, expectedLayers, budgetCeiling, emittedAt)` always
/// produce equal verdicts.
public enum BASObservationReconciliationVerdictEngine {

    /// Evaluate a report under an expected-layer list and a budget
    /// ceiling.
    ///
    /// - Parameters:
    ///   - report: the assembled 14-layer (or partial) coverage
    ///     report this turn.
    ///   - expectedLayers: the cognitive layers the caller asserts
    ///     should have reported this turn. Any layer in this list
    ///     not present in the report becomes a `.missingLayer`
    ///     finding.
    ///   - budgetCeiling: the maximum allowed total clamped budget
    ///     cost for this turn. Strict `>` comparison —
    ///     exactly-at-ceiling counts as clean. The ceiling itself is
    ///     clamped to `[0, 1]` before use (the report's
    ///     `totalBudgetCost` is already clamped, so this normalizes
    ///     caller intent).
    ///   - emittedAt: timestamp to attach to the verdict. Typically
    ///     the caller's wall clock.
    ///
    /// - Returns: a `BASObservationReconciliationVerdict` carrying
    ///   severity, findings (in deterministic order), and the
    ///   turn/session keys from the report.
    public static func evaluate(
        report: BASObservationReconciliationReport,
        expectedLayers: [BASCognitiveLayer],
        budgetCeiling: Double,
        emittedAt: Date
    ) -> BASObservationReconciliationVerdict {
        let clampedCeiling = min(1, max(0, budgetCeiling))
        var findings: [BASObservationReconciliationFinding] = []
        var severity: BASObservationReconciliationSeverity = .clean

        // Budget check first — halt-tier. Strict `>`: at-ceiling is
        // fine, only overspend trips halt.
        let observed = report.totalBudgetCost
        if observed > clampedCeiling {
            findings.append(
                .budgetOverspend(
                    observed: observed,
                    ceiling: clampedCeiling))
            severity = max(severity, .halt)
        }

        // Missing expected layers — advisory. `missingLayers` already
        // preserves caller's expectedLayers order.
        for layer in report.missingLayers(expected: expectedLayers) {
            findings.append(.missingLayer(layer))
            severity = max(severity, .advisory)
        }

        // Reporting layers without core coverage — advisory.
        // `layersWithoutCoreCoverage` preserves the report's
        // first-seen order.
        for layer in report.layersWithoutCoreCoverage {
            findings.append(.layerMissingCoreCoverage(layer))
            severity = max(severity, .advisory)
        }

        return BASObservationReconciliationVerdict(
            turnID: report.turnID,
            sessionID: report.sessionID,
            severity: severity,
            findings: findings,
            emittedAt: emittedAt)
    }
}
