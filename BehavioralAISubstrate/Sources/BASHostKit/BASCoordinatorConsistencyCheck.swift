// MARK: - BASCoordinatorConsistencyCheck
// ch1044 (a) — the REAL coordinator-regression detector.
//
// Engine-vs-coordinator parity (ADR-023 §8) CANNOT detect a coordinator
// regression: the engine is always the deliberately-stricter independent
// backstop, so a `coordinatorLaxer` only ever means "the engine's finer model is
// stricter here, by design". The meaningful fail-closed signal is the coordinator
// vs ITS OWN baseline — re-derive what the coordinator's rules
// (`computeVerdictDecision`) SHOULD produce for a completed turn's settled state,
// and compare against the verdict the turn actually stored. A stored verdict
// STRICTLY LAXER than the re-derived one is a genuine regression: stale inputs, a
// post-hoc mutation, or a rule change that no longer reproduces. THAT is what a
// real Phase-2 halt should act on.
//
// WIRING (honest — ch1044 audit M2): this is OBSERVATION-ONLY today. The endurance
// runner emits a `🚨 coordinator_regression` log line on `.regression`; NO
// production path in Sources/ consumes `.isRegression` to halt anything. It is the
// signal a FUTURE Phase-2 gate would act on — not an active fail-closed halt yet.

import Foundation
import BASRuntimeCore
import BASPolicy

/// Result of a coordinator self-consistency check.
public enum BASCoordinatorConsistency: Sendable, Equatable {
    /// The turn carried no coordinator verdict to check.
    case noVerdict
    /// The stored verdict is at least as strict as the coordinator's own rules
    /// re-applied to the turn's settled state — the safe case.
    case consistent
    /// The stored verdict is STRICTLY LAXER than the coordinator's rules
    /// re-derived from the same state — a genuine regression. `atLeast` is the
    /// (conservative lower-bound) level the verdict SHOULD have carried.
    case regression(
        stored: BASSovereignVerdictLevel,
        atLeast: BASSovereignVerdictLevel)

    /// True only for `.regression`. NOTE (ch1044 audit M2): observation-only today —
    /// no production path halts on this yet (see the header); it is the signal a
    /// future Phase-2 gate would consume.
    public var isRegression: Bool {
        if case .regression = self { return true }
        return false
    }
}

public enum BASCoordinatorConsistencyCheck {

    /// Re-derive the coordinator verdict LEVEL from a completed turn's settled
    /// state and compare against the stored verdict.
    ///
    /// Flags ONLY a stored verdict strictly laxer than the re-derived
    /// (lower-bound) level, so it can NEVER false-alarm:
    ///   - the request-only kill-switch term of `needsProtectedWriteLane` is not
    ///     on the result; omitting it only UNDER-sets the re-derived level → a
    ///     conservative lower bound;
    ///   - quarantine/rollback refs are opaque to the level decision, so
    ///     placeholders are used.
    /// Pure + deterministic.
    public static func check(
        _ result: BASEBrainTurnResult
    ) -> BASCoordinatorConsistency {
        guard let stored = result.sovereignVerdict else { return .noVerdict }
        let needsProtectedWriteLane =
            result.actionPermit.mode == .delay
            || result.actionPermit.mode == .replace
            || result.updateTickets.contains { $0.requiresReview || $0.conflictFlag }
        let reDerived = BASEBrainRuntimeCoordinator.computeVerdictDecision(
            policyLineagePresent: result.policyLineage != nil,
            budgetFrame: result.budgetFrame,
            riskCard: result.riskCard,
            actionPermit: result.actionPermit,
            emergencyBrake: result.emergencyBrake,
            activeKillSwitches: [],
            needsProtectedWriteLane: needsProtectedWriteLane,
            quarantineSources: [],
            rollbackSource: nil)
        if stored.verdictLevel < reDerived.level {
            return .regression(
                stored: stored.verdictLevel, atLeast: reDerived.level)
        }
        return .consistent
    }
}
