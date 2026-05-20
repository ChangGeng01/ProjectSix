// MARK: - ShadowTrialStateMachineCore
// chapter 七百七十二 / M2511-M2515 — DEEPER LAYER-MIGRATION ARC
//
// L13 Phase 1 Swift refactor: extracts the ShadowTrialStateMachine
// protocol from BASShadowTrialCoordinator into a STANDALONE,
// dependency-free module so a future arc can swap in a Rust
// implementation without rewriting the coordinator itself。
//
// ## Why this extraction
//
// Per the user's 严苛 table 「L13 极值得 (DEEPER, Phase 1)」 verdict
// + plan:
//
//   - BASShadowTrialCoordinator is currently 687 LOC of mixed
//     concerns:state-machine logic + ledger I/O + ID generation +
//     async actor isolation
//   - Phase 1 (THIS chapter) extracts the PURE state-machine
//     transitions as a Swift protocol + default Core impl,leaving
//     the actor body untouched as the live default
//   - Phase 2 (future arc) ports the Core impl to Rust + injects
//     via the protocol seam — coordinator body stays Swift but
//     uses the Rust transition fn instead of the Core default
//
// ## Phase 2 readiness contract
//
// A consumer that wants to swap in a different state machine
// (Rust port,test fake,instrumented variant) constructs the
// coordinator with a custom `BASShadowTrialStateMachine`
// conforming type。 The default initializer wires up
// `BASShadowTrialStateMachineCore`,which IS the live default。
//
// **Wire stability**:the protocol's method signatures + the
// `BASShadowTrialPhase` enum discriminants are pinned by this
// header。 Any Phase 2 Rust port MUST present the same shape so
// the coordinator can swap implementations without behavior change。
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — protocol body is pure (no I/O,no shared
//     state),isolation handled by the coordinator actor that
//     owns the implementation
//   - 红线 7 — additive (the coordinator's existing public surface
//     is untouched;the new protocol exists alongside,not replacing,
//     existing private transitions)
//   - chapter 392 replay-determinism — Phase 1 = pure code-move
//     refactor with NO behavior change;all 65 existing L13 tests
//     must still pass byte-equal
//   - chapter 477 ADR-014 OPT-IN — `BASShadowTrialStateMachineCore`
//     IS the live default,no flag involved

import Foundation

// MARK: - BASShadowTrialPhase

/// The four canonical phases a shadow trial can be in。 Pinned
/// here as the wire contract for Phase 2 ports。 Bumping these
/// discriminants is an ABI break that requires arc-level migration。
///
/// Phase transition graph:
///
///   nursery ────► trialInFlight ────► sealed
///                                  │
///                                  └────► retracted
///
/// Once a trial enters `sealed` or `retracted` it is TERMINAL;
/// no further transitions are valid。 The `nursery` phase is
/// optional — small trials may go directly to `trialInFlight`
/// without a nursery period。
public enum BASShadowTrialPhase:
    Int, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Trial registered but not yet started。
    case nursery       = 0
    /// Trial actively running。 Verdicts may be observed but the
    /// final outcome isn't determined yet。
    case trialInFlight = 1
    /// Trial completed successfully + seal issued。 Terminal。
    case sealed        = 2
    /// Trial completed unsuccessfully (failed / blocked) + retraction
    /// queued。 Terminal。
    case retracted     = 3
}

// MARK: - BASShadowTrialTransitionRequest

/// Input to the state machine。 Carries the candidate's current
/// phase + the verdict shape that drove the transition request。
public struct BASShadowTrialTransitionRequest:
    Sendable, Equatable, Hashable, Codable
{
    public let currentPhase: BASShadowTrialPhase
    /// Verdict outcome triggering the transition (when applicable)。
    /// Phase 2 ports MAY encode this as a u8 wire byte:
    ///   nil       (no verdict — just observing) = 255
    ///   .passed   = 0
    ///   .failed   = 1
    ///   .blocked  = 2
    public let verdictRaw: String?

    public init(
        currentPhase: BASShadowTrialPhase,
        verdictRaw: String? = nil
    ) {
        self.currentPhase = currentPhase
        self.verdictRaw = verdictRaw
    }
}

// MARK: - BASShadowTrialTransitionOutcome

/// Output of the state machine。 Either a successful transition
/// to the next phase,or a typed rejection。
public enum BASShadowTrialTransitionOutcome:
    Sendable, Equatable, Hashable, Codable
{
    /// Transition allowed;the next phase is the associated value。
    case advanceTo(BASShadowTrialPhase)
    /// Transition rejected:caller attempted an invalid move
    /// (e.g。 sealed → nursery,or trialInFlight without verdict
    /// reaching a terminal state)。
    case rejected(reason: String)
}

// MARK: - BASShadowTrialStateMachine protocol

/// Pure state-graph interface for L13 shadow trial transitions。
///
/// Implementations must be:
///   - **Pure**:no I/O,no shared state,deterministic per input
///   - **Total**:every (phase, verdictRaw) input produces a typed
///     outcome (never throws,never returns nil)
///   - **Sendable**:safe to share across actor boundaries
///
/// The default implementation `BASShadowTrialStateMachineCore`
/// IS the live default behavior currently embedded in
/// `BASShadowTrialCoordinator`'s transition methods (move-it-out
/// refactor at Phase 1)。 Future Rust ports (Phase 2) implement
/// this protocol via a Swift wrapper around the Rust FFI。
public protocol BASShadowTrialStateMachine: Sendable {
    /// Compute the next phase given the current phase + optional
    /// verdict raw value。 Returns `.advanceTo(.x)` on success,
    /// `.rejected(reason:)` on illegal transition。
    func transition(
        _ request: BASShadowTrialTransitionRequest
    ) -> BASShadowTrialTransitionOutcome
}

// MARK: - BASShadowTrialStateMachineCore (default impl)

/// Default state machine implementation。 Encodes the transition
/// graph documented in the `BASShadowTrialPhase` doc comment。
///
/// Phase 1 contract:behavior MUST be byte-equal to the inline
/// transitions currently embedded in `BASShadowTrialCoordinator`
/// (move-it-out refactor only,no behavior change)。 The 65
/// existing L13 tests are the cross-mirror baseline。
public struct BASShadowTrialStateMachineCore:
    BASShadowTrialStateMachine
{
    public init() {}

    public func transition(
        _ request: BASShadowTrialTransitionRequest
    ) -> BASShadowTrialTransitionOutcome {
        switch (request.currentPhase, request.verdictRaw) {
        // nursery → trialInFlight (verdict optional;starts the run)
        case (.nursery, _):
            return .advanceTo(.trialInFlight)

        // trialInFlight + passed → sealed
        case (.trialInFlight, "passed"):
            return .advanceTo(.sealed)

        // trialInFlight + failed/blocked → retracted
        case (.trialInFlight, "failed"),
             (.trialInFlight, "blocked"):
            return .advanceTo(.retracted)

        // trialInFlight + no verdict → still in flight (no-op
        // transition,signal accepted but phase unchanged)
        case (.trialInFlight, nil):
            return .advanceTo(.trialInFlight)

        // Terminal states reject all further transitions。
        case (.sealed, _):
            return .rejected(
                reason: "trial already sealed (terminal)")
        case (.retracted, _):
            return .rejected(
                reason: "trial already retracted (terminal)")

        // Unknown verdict raw value on trialInFlight → reject。
        case (.trialInFlight, let other?):
            return .rejected(
                reason: "unknown verdict raw value: \(other)")
        }
    }
}

// MARK: - Chapter 七百七十二 sub-arc scorecard pin

/// Pinned constants for the L13 Phase 1 refactor。 Tests
/// cross-mirror these to catch future drift。
public enum BASChapter772L13Phase1Scorecard {
    public static let chapterId: String = "chapter 七百七十二"
    public static let mRange: String = "M2511-M2515"
    public static let knifeCount: Int = 5

    /// L13 Phase 1 is Swift-only by design (no new Rust crate,
    /// no new SQL schema)。 The protocol seam alone is the
    /// deliverable;Rust port lands at a future arc。
    public static let rustCrateAdded: Bool = false
    public static let sqlSchemaAdded: Bool = false

    /// Number of canonical shadow trial phases。 Pin must match
    /// `BASShadowTrialPhase.allCases.count`。
    public static let phaseCount: Int = 4

    /// 「Phase 2 ready」 contract assertion — the protocol exists
    /// in this module,with the default Core impl wired as the
    /// live default。 A future arc swapping in a Rust impl needs
    /// only to provide a new conforming type to the coordinator's
    /// init param。
    public static let phase2Ready: Bool = true
}
