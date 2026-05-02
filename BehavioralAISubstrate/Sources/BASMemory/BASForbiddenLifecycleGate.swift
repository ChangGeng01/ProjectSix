// SPDX-License-Identifier: Apache-2.0
// M386 — `BASForbiddenKnowledgeCandidate` → `BASEvolutionLifecycleAction`
// gate. Closes附录 K.2.3 third runtime-decision wire for the
// Cthulhu doctrine: when an L13 candidate has been parked in the
// forbidden-knowledge reserve (M321), any attempt to advance the
// candidate's lifecycle is filtered through this typed gate. The
// shadow-trial policy and sovereign-review state both gate
// independently; either can refuse a particular action.
//
// Doctrine pins:
//
//   - **Single commit mouth**: this helper never mutates lifecycle
//     state; it returns `nil` to refuse an action and a reason code
//     so the lifecycle coordinator (single commit mouth) makes the
//     final no-op decision.
//   - **Pure value type**: no actor, no I/O. Co-resides with the
//     existing L13 evolution types in BASMemory.
//   - **Default-safe**: when `candidate` is `nil` (no forbidden
//     parking record), `gate(action:candidate:)` returns the action
//     unchanged. The gate only narrows; it never expands.
//   - **Audit-visible**: every refusal returns a typed reason code
//     in the `GateDecision` so the audit trail records why.

import Foundation

// MARK: - BASForbiddenLifecycleGateDecision

/// Pure result type carrying the gated action (or `nil` when
/// refused) and the typed reason code that motivated the refusal.
public struct BASForbiddenLifecycleGateDecision:
    Sendable, Equatable, Hashable
{
    /// The action allowed by the gate, or `nil` when the gate
    /// refuses. The caller (lifecycle coordinator) is expected to
    /// no-op when `nil`.
    public let action: BASEvolutionLifecycleAction?
    /// Stable reason code documenting the gate decision. Empty
    /// when the action passes through unchanged.
    /// Format: `"lifecycle.gated:forbidden:<reason>"`.
    public let reasonCodes: [String]
    /// `true` when the action was refused (`action == nil`).
    public let refused: Bool

    public init(
        action: BASEvolutionLifecycleAction?,
        reasonCodes: [String],
        refused: Bool
    ) {
        self.action = action
        self.reasonCodes = reasonCodes
        self.refused = refused
    }
}

// MARK: - BASForbiddenLifecycleGate

/// Pure-function helper translating a forbidden-knowledge candidate
/// readout into a lifecycle-action refusal decision.
public enum BASForbiddenLifecycleGate {

    /// Decide a gate filter for one (action, candidate) pair. Pure
    /// function.
    ///
    /// - Parameters:
    ///   - action: the lifecycle action a coordinator wants to
    ///     apply.
    ///   - candidate: the M321 forbidden-knowledge candidate
    ///     parked alongside the lifecycle session. May be `nil`
    ///     when no forbidden parking record exists.
    /// - Returns: a value-typed decision. `decision.action == nil`
    ///   when the gate refuses; otherwise the action is allowed.
    public static func gate(
        action: BASEvolutionLifecycleAction,
        candidate: BASForbiddenKnowledgeCandidate?
    ) -> BASForbiddenLifecycleGateDecision {
        // No forbidden record → action passes unchanged.
        guard let candidate else {
            return BASForbiddenLifecycleGateDecision(
                action: action,
                reasonCodes: [],
                refused: false)
        }

        // Sovereign review states.
        switch candidate.sovereignReviewState {
        case .rejected:
            // Sovereign permanently bars — every action that
            // would *advance* the candidate is refused. Three
            // exit-bound actions are still allowed because they
            // take the candidate OUT of the active path:
            //
            //   - `.withdraw` (any active → `.withdrawn`)
            //   - `.fail`     (pre-promotion → `.rejected`)
            //   - `.retract`  (`.promoted` → `.retracted`)
            //
            // `.retract` is the only path out of `.promoted` per
            // `BASEvolutionLifecyclePolicy.validTransitions(from:
            // .promoted) = [.retract: .retracted]`. If sovereign
            // rejects a candidate that has somehow reached
            // `.promoted` (e.g. via a different path that pre-
            // dated the gate), refusing `.retract` would strand
            // the candidate in `.promoted` with no exit. Doctrine
            // fix from chapter 九十一 deep review #2: allow
            // `.retract` alongside `.withdraw`/`.fail` so the
            // sovereign-rejected verdict can always reach a
            // terminal stage.
            switch action {
            case .withdraw, .fail, .retract:
                return BASForbiddenLifecycleGateDecision(
                    action: action,
                    reasonCodes: [
                        "lifecycle.gated:forbidden:sovereign-rejected:terminal-action-allowed"
                    ],
                    refused: false)
            case .registerCandidate, .startShadowTrial,
                .finalizeTrial, .promote:
                return BASForbiddenLifecycleGateDecision(
                    action: nil,
                    reasonCodes: [
                        "lifecycle.gated:forbidden:sovereign-rejected"
                    ],
                    refused: true)
            }
        case .held:
            // Sovereign deferred — refuse trial start until the
            // sovereign verdict is in. Other actions remain valid.
            if action == .startShadowTrial {
                return BASForbiddenLifecycleGateDecision(
                    action: nil,
                    reasonCodes: [
                        "lifecycle.gated:forbidden:sovereign-held:trial-start-refused"
                    ],
                    refused: true)
            }
        case .pending, .cleared, .notReferred:
            // No sovereign refusal at this state. Continue to
            // policy check.
            break
        }

        // Shadow-trial policy.
        switch candidate.shadowTrialPolicy {
        case .none:
            // No shadow trial allowed — refuse `startShadowTrial`.
            if action == .startShadowTrial {
                return BASForbiddenLifecycleGateDecision(
                    action: nil,
                    reasonCodes: [
                        "lifecycle.gated:forbidden:shadow-trial-policy-none"
                    ],
                    refused: true)
            }
        case .manualOnly, .restricted, .standard, .escalated:
            // Allowed; no refusal. The audit trail records the
            // policy via the candidate's audit signalRefs (M321);
            // this gate intentionally does not double-emit codes
            // when the action passes through.
            break
        }

        return BASForbiddenLifecycleGateDecision(
            action: action,
            reasonCodes: [],
            refused: false)
    }
}
