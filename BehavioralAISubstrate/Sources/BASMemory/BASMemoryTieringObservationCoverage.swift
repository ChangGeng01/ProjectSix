import Foundation
import BASRuntimeCore

// MARK: - L8 hippocampal-well coverage projection
//
// M37 — additive edge projection from
// `BASMemoryTieringReconciliationOutcome` (M21) to the neutral
// `BASObservationCoverageSummary` defined in BASRuntimeCore (M31).
// Brings L8 (hippocampalWell) into the same reconciliation shape
// already used by L4/L6/L7/L9/L10/L11/L12/L13 — extending the
// M32 wave from 8-of-14 to 9-of-14 projected layers.
//
// L8's outcome shape differs from the other eight layers: a tier
// reconciliation sweep is not bound to a single turn, so the
// outcome itself does *not* carry `turnID` / `sessionID`. The
// caller — typically the governance coordinator that runs the
// sweep on behalf of a turn — must supply the turn/session keys
// when projecting. Everything else maps 1:1 with the established
// pattern.
//
// Design principles:
//   1. Additive — `BASMemoryTieringReconciliationOutcome`,
//      `BASMemoryTieringProfile`, and `BASMemoryTierTransitionLog`
//      are untouched. Callers opt in via `coverageSummary(...)`.
//   2. Pure — no actor hops; same outcome + same keys yield the
//      same summary.
//   3. Neutral shape — the L14 reconciler consumes L8 in exactly
//      the same way it consumes the other projected layers.

// MARK: - Budget

/// Pure lookup: what does each tier-transition suggestion cost the
/// L1 wake budget? Values are weights in abstract budget units
/// (0.0–1.0).
///
/// Rationale for the numbers:
///   - `hold` is the cheapest: the policy looked at a profile and
///     decided nothing should change. No mutation plan is emitted.
///   - `promote` / `demote` are symmetric single-rung moves. They
///     commit the reconciler to a planned memory-tier change, so
///     they cost more than a hold but less than the quarantine /
///     evict branches, which hand the atom to a different
///     downstream path.
///   - `quarantineSuggest` is the most expensive signal because it
///     pulls the atom out of the normal tier ladder entirely and
///     wires it to L14 contamination / sensitivity governance.
///   - `evictSuggest` sits between a move and a quarantine: it asks
///     the forget-cascade surface to delete the atom on the next
///     governance sweep.
public enum BASMemoryTieringObservationBudget {
    public static let holdCost: Double = 0.02
    public static let promoteCost: Double = 0.08
    public static let demoteCost: Double = 0.08
    public static let quarantineCost: Double = 0.15
    public static let evictCost: Double = 0.10

    /// Cost for a single transition suggestion.
    public static func cost(
        for transition: BASMemoryTierTransition
    ) -> Double {
        switch transition {
        case .hold: return holdCost
        case .promote: return promoteCost
        case .demote: return demoteCost
        case .quarantineSuggest: return quarantineCost
        case .evictSuggest: return evictCost
        }
    }

    /// Clamped total cost for a reconciliation outcome. Summing
    /// per-decision costs and clamping to [0, 1] matches the
    /// convention set by the other layers' budget tables.
    public static func totalCost(
        for outcome: BASMemoryTieringReconciliationOutcome
    ) -> Double {
        let sum = outcome.decisions.reduce(0.0) { acc, decision in
            acc + cost(for: decision.transition)
        }
        return min(1, max(0, sum))
    }
}

// MARK: - Coverage projection

extension BASMemoryTieringReconciliationOutcome {
    /// An L8 reconciliation outcome has "core signal coverage" iff
    /// it evaluated at least one profile this sweep. A pass with
    /// zero evaluations is silent — the tier reconciler ran on
    /// schedule but had no memory-atom profiles to reason over. A
    /// pass with any evaluation (even one where every decision was
    /// `.hold`) is a meaningful audit signal: the reconciler
    /// actually looked at memory state this turn.
    public var hasCoreSignalCoverage: Bool {
        evaluatedCount > 0
    }

    /// Neutral coverage summary for L8. `distinctSubjectCount`
    /// maps to the number of distinct memory atoms the reconciler
    /// reasoned over this sweep.
    ///
    /// Unlike the other layers' coverage projections, L8's outcome
    /// is not bound to a single turn; the caller supplies the
    /// turn/session keys when binding the sweep to an audit
    /// context. The projection uses `completedAt` as the
    /// `emittedAt` wall-clock stamp so the neutral summary reports
    /// when the reconciliation actually finished, not when the
    /// sweep was scheduled.
    public func coverageSummary(
        turnID: String,
        sessionID: String
    ) -> BASObservationCoverageSummary {
        let distinctAtoms = Set(
            decisions.map { $0.profile.atomID })
        return BASObservationCoverageSummary(
            layer: .hippocampalWell,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: decisions.count,
            distinctSubjectCount: distinctAtoms.count,
            hasCoreSignalCoverage: hasCoreSignalCoverage,
            budgetTotalCost:
                BASMemoryTieringObservationBudget.totalCost(
                    for: self),
            emittedAt: completedAt)
    }
}
