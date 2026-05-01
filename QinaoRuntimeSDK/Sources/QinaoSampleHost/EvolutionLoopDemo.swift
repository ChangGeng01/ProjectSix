import Foundation
import BASMemory

/// M333 — L13 self-evolution lifecycle loop demo.
///
/// Drives `BASEvolutionLifecycleSession` (chapter 五十六) through
/// the full 8-stage state machine so hosts on first-day
/// integration see the L13 self-evolution doctrine end-to-end.
/// Pre-M333 the session was production-shipped + audit-wired
/// (M305) but had **0 sample/demo path**; the L13 self-evolution
/// promise was reachable only via XCTests.
///
/// What the demo proves
///
///   1. Happy path: a ticket walks `proposed → candidateRegistered
///      → shadowTrialing → trialFinalized → promoted` via the 4
///      typed-allowed actions (registerCandidate / startShadowTrial
///      / finalizeTrial / promote).
///   2. **Promoted is NOT terminal** — retraction is a real path:
///      `promoted → retracted` via `retract` action. This is the
///      doctrine-pinned non-trivial fact the demo exists to
///      demonstrate.
///   3. Failure path: a separate ticket walks `proposed →
///      candidateRegistered → shadowTrialing → rejected` via
///      `fail` from shadowTrialing.
///   4. Withdrawal path: a third ticket walks `proposed →
///      withdrawn` via `withdraw` from proposed (host explicitly
///      withdraws before promotion).
///   5. Withdraw is BLOCKED from promoted — once promoted, the
///      only way out is retraction (chapter 五十六.3 doctrine
///      pin: `tmpl-relationship-direct-confrontation`'s sibling
///      L13 invariant). Demo verifies `applying(.withdraw)`
///      returns nil when stage is `.promoted`.
///
/// ## Doctrine
///
/// - **Pure value-type lifecycle.** No actors, no IO, no
///   side effects. Every transition is `session.applying(action)
///   -> Session?` — returns nil when transition is illegal.
/// - **History accumulates monotonically.** `session.history` is
///   the typed lineage; audit walkers grep it.
/// - **Stages visited list is grep-friendly.** Demo prints the
///   distinct stages each ticket visited so the doctrine ("no
///   stage skipping") is visible without parsing transitions.
/// - **Doctrine invariant #3 unchanged.** Demo walks lifecycle
///   metadata only — does NOT update host weights or L2 training
///   pipeline.
public struct EvolutionLoopDemo {

    public struct TicketRecord: Sendable, Equatable {
        public let candidateID: String
        public let pathName: String
        public let finalStage: String
        public let isTerminal: Bool
        public let hasReachedPromotion: Bool
        public let stagesVisited: [String]
        public let transitions: [String]

        public init(
            candidateID: String,
            pathName: String,
            finalStage: String,
            isTerminal: Bool,
            hasReachedPromotion: Bool,
            stagesVisited: [String],
            transitions: [String]
        ) {
            self.candidateID = candidateID
            self.pathName = pathName
            self.finalStage = finalStage
            self.isTerminal = isTerminal
            self.hasReachedPromotion = hasReachedPromotion
            self.stagesVisited = stagesVisited
            self.transitions = transitions
        }
    }

    public struct InvariantPin: Sendable, Equatable {
        public let pinName: String
        public let assertionResult: Bool
        public let detail: String

        public init(
            pinName: String,
            assertionResult: Bool,
            detail: String
        ) {
            self.pinName = pinName
            self.assertionResult = assertionResult
            self.detail = detail
        }
    }

    public struct Outcome: Sendable, Equatable {
        public let promotedThenRetracted: TicketRecord
        public let trialFailed: TicketRecord
        public let earlyWithdrawn: TicketRecord
        public let invariantPins: [InvariantPin]

        public init(
            promotedThenRetracted: TicketRecord,
            trialFailed: TicketRecord,
            earlyWithdrawn: TicketRecord,
            invariantPins: [InvariantPin]
        ) {
            self.promotedThenRetracted = promotedThenRetracted
            self.trialFailed = trialFailed
            self.earlyWithdrawn = earlyWithdrawn
            self.invariantPins = invariantPins
        }

        public var allInvariantsHold: Bool {
            invariantPins.allSatisfy(\.assertionResult)
        }
    }

    /// Drive the 3 lifecycle paths + verify 2 doctrine invariants.
    public static func run() -> Outcome {
        // Path 1: full promotion + retraction.
        var session1 = BASEvolutionLifecycleSession(
            candidateID: "ticket-promotion-001")
        session1 = session1
            .applying(.registerCandidate)!
            .applying(.startShadowTrial)!
            .applying(.finalizeTrial)!
            .applying(.promote)!
            .applying(.retract)!
        let path1 = Self.makeRecord(
            session: session1,
            pathName: "promoted → retracted")

        // Path 2: trial failure.
        var session2 = BASEvolutionLifecycleSession(
            candidateID: "ticket-failure-002")
        session2 = session2
            .applying(.registerCandidate)!
            .applying(.startShadowTrial)!
            .applying(.fail)!
        let path2 = Self.makeRecord(
            session: session2,
            pathName: "shadowTrialing → rejected (fail)")

        // Path 3: early withdrawal.
        var session3 = BASEvolutionLifecycleSession(
            candidateID: "ticket-withdrawn-003")
        session3 = session3
            .applying(.withdraw)!
        let path3 = Self.makeRecord(
            session: session3,
            pathName: "proposed → withdrawn (host withdrew)")

        // Invariant pins.
        var pins: [InvariantPin] = []

        // Pin 1: withdraw is BLOCKED from .promoted.
        let promoted = BASEvolutionLifecycleSession(
            candidateID: "promoted-pin",
            currentStage: .promoted,
            history: [])
        let withdrawAttempt = promoted.applying(.withdraw)
        pins.append(
            InvariantPin(
                pinName:
                    "withdraw blocked from .promoted",
                assertionResult: withdrawAttempt == nil,
                detail:
                    "applying(.withdraw) on .promoted → \(withdrawAttempt == nil ? "nil ✓" : "non-nil ⚠")"))

        // Pin 2: hasReachedPromotion remains true after retract.
        pins.append(
            InvariantPin(
                pinName:
                    ".retracted retains hasReachedPromotion",
                assertionResult:
                    session1.hasReachedPromotion,
                detail:
                    "session1.hasReachedPromotion = \(session1.hasReachedPromotion) (final stage = .retracted)"))

        // Pin 3: terminal stages return empty validTransitions.
        let terminalStages: [
            BASEvolutionLifecycleStage
        ] = [.retracted, .rejected, .withdrawn]
        let allTerminalEmpty = terminalStages.allSatisfy {
            BASEvolutionLifecyclePolicy.validTransitions(
                from: $0)
                .isEmpty
        }
        pins.append(
            InvariantPin(
                pinName:
                    "terminal stages have empty validTransitions",
                assertionResult: allTerminalEmpty,
                detail:
                    ".retracted / .rejected / .withdrawn → []"))

        // Pin 4: aggregate over the 3 paths produces non-nil + correct counts.
        let agg = BASEvolutionLifecycleSession.aggregate([
            session1, session2, session3,
        ])
        let aggOK = agg != nil
            && agg?.count == 3
            && agg?.terminalCount == 3
            && agg?.promotedCount == 1
        pins.append(
            InvariantPin(
                pinName:
                    "M305 aggregate over 3 sessions correct",
                assertionResult: aggOK,
                detail:
                    "count=\(agg?.count ?? -1) / terminalCount=\(agg?.terminalCount ?? -1) / promotedCount=\(agg?.promotedCount ?? -1)"))

        return Outcome(
            promotedThenRetracted: path1,
            trialFailed: path2,
            earlyWithdrawn: path3,
            invariantPins: pins)
    }

    private static func makeRecord(
        session: BASEvolutionLifecycleSession,
        pathName: String
    ) -> TicketRecord {
        TicketRecord(
            candidateID: session.candidateID,
            pathName: pathName,
            finalStage: session.currentStage.rawValue,
            isTerminal: session.isTerminal,
            hasReachedPromotion:
                session.hasReachedPromotion,
            stagesVisited: session.stagesVisited.map(\.rawValue),
            transitions: session.history.map { t in
                "\(t.action.rawValue) (\(t.from.rawValue)→\(t.to.rawValue))"
            })
    }
}
