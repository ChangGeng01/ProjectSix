// MARK: - BASShadowTrialFeedbackLedger
// ADR-018 P2 — latent plumbing for the ShadowTrial N→N+1 feedback loop。
//
// An immutable, append-only collection of `BASShadowTrialRecord` — the
// trials still PENDING across a turn boundary。 The coordinator is a
// value type with no cross-turn state, so it cannot itself hold trial
// state between turns;a host-held ledger carries it。 In ADR-018 P2 the
// host seeds the coordinator with last turn's pending trials (slot-in)
// and collects this turn's evaluated trials via a sink (sink-out)。 This
// is the trial-plane sibling of `BASEvidenceLedger` (the evidence-plane
// cross-turn carrier added in ch1042)。
//
// ## Immutability
//
// Per the repo coding-style rule:NEVER mutate。 `appending` returns a
// NEW ledger with the record added;the receiver is untouched。 This is
// what makes the type safe to share across turns + threads (it is
// `Sendable`)。
//
// ## Determinism (红线 4)
//
// The pure `evaluate(...)` evaluator delegates the legality decision to
// `BASShadowTrialStateMachineCore` (no I/O, no clock, no randomness),so
// replay is bit-identical regardless of how many times it runs。
//
// DORMANT (ADR-018 P2 Commit 1):nothing in production references this
// type yet。 Byte-equal-by-construction — no existing type is modified +
// nothing is wired into the runtime。 The N→N+1 feedback loop begins
// reading/writing this carrier in a later, explicitly-gated commit
// (Commit 2)。

import Foundation

/// An immutable, append-only carrier for the shadow trials pending
/// across turns。 Advance a prior-turn record one step via the pure
/// `evaluate(_:using:)` evaluator。 See ADR-018 P2。
public struct BASShadowTrialFeedbackLedger: Codable, Equatable, Sendable {
    /// The shadow trials still in flight, carried into the next turn,
    /// in insertion order。
    public var pendingTrials: [BASShadowTrialRecord]

    /// Creates a ledger seeded with the given pending trials (default
    /// empty)。
    public init(pendingTrials: [BASShadowTrialRecord] = []) {
        self.pendingTrials = pendingTrials
    }

    /// Return a NEW ledger with `record` appended。 Does NOT mutate the
    /// receiver (immutability — see coding-style rule + 红线 4)。
    public func appending(
        _ record: BASShadowTrialRecord
    ) -> BASShadowTrialFeedbackLedger {
        BASShadowTrialFeedbackLedger(pendingTrials: pendingTrials + [record])
    }
}

// MARK: - Pure feedback evaluator (ADR-018 P2)

extension BASShadowTrialFeedbackLedger {
    /// Evaluate a prior-turn trial one step forward via the pure state
    /// machine, returning a NEW record whose `completionState` reflects
    /// the transitioned phase。
    ///
    /// This is the N→N+1 feedback primitive:a trial that was pending
    /// last turn is advanced this turn by feeding its
    /// `completionState`-derived verdict into the state machine, then
    /// re-recording the machine's resulting phase as a new
    /// `completionState`。 The evaluator FAITHFULLY DELEGATES the
    /// legality decision to `BASShadowTrialStateMachineCore` — it never
    /// invents a transition the machine would reject。
    ///
    /// `BASShadowTrialRecord` has no `phase` field;the phase lives only
    /// in the state machine。 The completionState↔phase/verdict mapping
    /// here mirrors the vocabulary pinned by `BASShadowTrialCoordinator`
    /// (see its doc comment) and the `isPassed`/`isFailed`/`isPending`
    /// helpers on `BASShadowTrialRecord`:
    ///
    ///   - terminal records (`isPassed`/`isFailed`) carry no further
    ///     legal move → returned UNCHANGED (the machine rejects a
    ///     sealed/retracted transition)
    ///   - a pending record (`isPending`) is modeled as `.trialInFlight`
    ///     with its `completionState` as the verdict raw value:
    ///       · a terminal verdict (`"passed"`/`"failed"`/`"blocked"`)
    ///         advances to `.sealed`/`.retracted` → new completionState
    ///       · a non-terminal verdict (`"pending"`/`"observing"`/…)
    ///         maps to the no-verdict path → stays `.trialInFlight`
    ///         → record returned UNCHANGED
    ///
    /// - Note: pure + deterministic (红线 4) — no I/O, no clock, no
    ///   randomness;same input always yields the same output。 DORMANT
    ///   in this commit。
    ///
    /// - Parameters:
    ///   - record: the prior-turn trial record to advance。
    ///   - stateMachine: the pure state machine to delegate to
    ///     (default-constructed `BASShadowTrialStateMachineCore`)。
    /// - Returns: a new record with the transitioned `completionState`,
    ///   or the unchanged record when the canonical advance is not a
    ///   legal transition。
    public static func evaluate(
        _ record: BASShadowTrialRecord,
        using stateMachine: BASShadowTrialStateMachineCore = .init()
    ) -> BASShadowTrialRecord {
        // Terminal trials have no legal forward move — the machine would
        // reject from .sealed / .retracted。 Return unchanged。
        guard record.isPending else { return record }

        // A pending trial is modeled as in-flight;its completionState is
        // the verdict raw value the state machine evaluates。 A
        // non-terminal verdict ("pending" / "observing") is not a known
        // verdict → the machine's no-verdict path keeps it in flight。
        let verdictRaw = terminalVerdictRaw(for: record.completionState)
        let outcome = stateMachine.transition(
            BASShadowTrialTransitionRequest(
                currentPhase: .trialInFlight,
                verdictRaw: verdictRaw
            )
        )

        switch outcome {
        case let .advanceTo(phase):
            guard let nextState = completionState(for: phase) else {
                // .trialInFlight (still pending) → nothing to record。
                return record
            }
            var advanced = record
            advanced.completionState = nextState
            return advanced
        case .rejected:
            // Defensive:an in-flight transition with a known verdict is
            // never rejected by the Core machine, but if a custom
            // machine rejects, leave the record unchanged。
            return record
        }
    }

    /// The terminal verdict raw value the state machine recognizes for a
    /// given pending `completionState`, or nil when the state carries no
    /// terminal signal (so the machine's no-verdict path applies)。
    ///
    /// Only the terminal vocabulary (`"passed"`/`"failed"`/`"blocked"`)
    /// is a verdict the machine advances on;every other pending state
    /// (`"pending"`/`"observing"`/anything else) maps to nil。 Kept total
    /// (no `default` verdict) so a pending record can never silently
    /// advance on an unrecognized state。
    private static func terminalVerdictRaw(
        for completionState: String
    ) -> String? {
        switch completionState {
        case "passed", "completed":
            return "passed"
        case "failed":
            return "failed"
        case "blocked":
            return "blocked"
        default:
            // "pending" / "observing" / unknown → no terminal verdict。
            return nil
        }
    }

    /// The `completionState` string to record for a transitioned phase,
    /// or nil when the phase is non-terminal (still in flight) and so
    /// has nothing new to record。
    ///
    /// Mirrors the coordinator's pinned vocabulary:`.sealed` → "passed"
    /// (the trial passed + a seal issues), `.retracted` → "failed" (the
    /// trial failed + a retraction queues)。 `.nursery`/`.trialInFlight`
    /// are non-terminal → nil。
    private static func completionState(
        for phase: BASShadowTrialPhase
    ) -> String? {
        switch phase {
        case .sealed:
            return "passed"
        case .retracted:
            return "failed"
        case .nursery, .trialInFlight:
            return nil
        }
    }
}
