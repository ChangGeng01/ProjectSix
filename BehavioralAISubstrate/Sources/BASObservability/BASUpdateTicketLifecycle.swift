import Foundation
import BASRuntimeCore

/// L13 — UpdateTicket lifecycle coordinator (M259).
///
/// ## Why this exists
///
/// `BASUpdateTicket` schema has been in tree since M14. Hosts
/// emit tickets each turn (proposing host-profile changes, memory
/// writes, rule candidates). `BASShadowTrialRecord` captures
/// trial outcomes. But the **state machine that takes a ticket
/// from proposal through trial through verdict to either
/// distillation queue or rejection** has only existed as ad-hoc
/// fields scattered across `BASShadowTrialRecord.completionState`
/// (a free-form string) and various `EvolutionGovernance` flags.
///
/// This file fills that gap with:
///
/// - `BASUpdateTicketLifecycleState` — typed enum for the 6
///   states a ticket can occupy
/// - `BASUpdateTicketLifecycleEntry` — Codable per-ticket record
///   (current state + history of transitions + reason codes)
/// - `BASUpdateTicketLifecycleCoordinator` — actor that owns the
///   ticket pool, enforces legal state transitions, and exposes
///   the "ready for offline distillation" queue
/// - `BASOfflineDistillationQueue` — read-only view over the
///   subset of tickets that have reached `.queuedForDistillation`
///
/// The coordinator does **not** do offline distillation itself
/// (that's a downstream ML pipeline that lives outside this SDK
/// per the plan §9.6). It exposes the ticket flow so the host
/// or an external worker can drain the queue, run distillation,
/// and signal back via `markDistilled(...)` or `markRejected(...)`.
///
/// ## Lifecycle states
///
/// ```
///                 ┌────────────┐
///                 │ proposed   │   ← initial state on submit()
///                 └─────┬──────┘
///                       │ startTrial()
///                 ┌─────▼──────┐
///                 │ trialing   │   ← shadow trial in progress
///                 └─────┬──────┘
///                       │ markTrialOutcome()
///                ┌──────┼───────────┐
///         pass   │      │           │   fail or contaminated
///         ┌──────▼┐  ┌───▼──────┐ ┌─▼──────────┐
///         │trial- │  │trial-    │ │trial-      │
///         │passed │  │failed    │ │contaminated│
///         └──┬────┘  └──────────┘ └────────────┘
///            │ approveForDistill()        │ both terminal
///         ┌──▼─────────────────┐          │
///         │queuedForDistill    │   ← visible in queue
///         └──┬─────────────────┘
///            │ markDistilled() / markRejected()
///         ┌──▼─────────────────┐
///         │ distilled OR       │ ← terminal
///         │ rejected           │
///         └────────────────────┘
/// ```
///
/// Illegal transitions throw `LifecycleError.illegalTransition`
/// — callers must respect the state machine.
///
/// ## Doctrine alignment
///
/// Invariant #3 ("宿主经验不进基础权重 / private host experience
/// stays out of base weights"): the coordinator is the **gate**
/// between L13 ticket proposal and any future weight update.
/// Tickets stuck in `.trialing` / `.trialFailed` /
/// `.trialContaminated` never reach the offline distillation
/// queue. Only `.queuedForDistillation` tickets are visible to
/// the external pipeline. Once `markDistilled(...)` records that
/// the external pipeline incorporated the ticket, the ledger
/// preserves the lineage so audit can replay.
public enum BASUpdateTicketLifecycleState:
    String, Codable, Hashable, Sendable, CaseIterable
{
    case proposed
    case trialing
    case trialPassed
    case trialFailed
    case trialContaminated
    case queuedForDistillation
    case distilled
    case rejected
}

public struct BASUpdateTicketLifecycleTransition:
    Codable, Hashable, Sendable
{
    public let from: BASUpdateTicketLifecycleState
    public let to: BASUpdateTicketLifecycleState
    public let at: Date
    public let reasonCodes: [String]

    public init(
        from: BASUpdateTicketLifecycleState,
        to: BASUpdateTicketLifecycleState,
        at: Date = .now,
        reasonCodes: [String] = []
    ) {
        self.from = from
        self.to = to
        self.at = at
        self.reasonCodes = reasonCodes
    }
}

public struct BASUpdateTicketLifecycleEntry:
    Codable, Sendable
{
    public let ticket: BASUpdateTicket
    public var state: BASUpdateTicketLifecycleState
    public var history: [BASUpdateTicketLifecycleTransition]
    public var trialRecordRef: String?
    /// Set when the ticket reaches a verdict-bearing state
    /// (queuedForDistillation, distilled, or rejected). Pulls the
    /// L14 `BASSovereignVerdict.auditRef` so audit can correlate
    /// every promotion to a sovereign verdict ID.
    public var sovereignVerdictRef: String?

    public init(
        ticket: BASUpdateTicket,
        state: BASUpdateTicketLifecycleState = .proposed,
        history: [BASUpdateTicketLifecycleTransition] = [],
        trialRecordRef: String? = nil,
        sovereignVerdictRef: String? = nil
    ) {
        self.ticket = ticket
        self.state = state
        self.history = history
        self.trialRecordRef = trialRecordRef
        self.sovereignVerdictRef = sovereignVerdictRef
    }
}

public actor BASUpdateTicketLifecycleCoordinator {
    public enum LifecycleError: Error, Equatable, Sendable {
        case unknownTicket(id: String)
        case duplicateTicket(id: String)
        case illegalTransition(
            from: BASUpdateTicketLifecycleState,
            to: BASUpdateTicketLifecycleState)
    }

    public enum TrialOutcome: Sendable, Equatable {
        case passed(reasonCodes: [String])
        case failed(reasonCodes: [String])
        case contaminated(reasonCodes: [String])
    }

    private var entries: [String: BASUpdateTicketLifecycleEntry] = [:]
    private let clock: @Sendable () -> Date

    public init(
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.clock = clock
    }

    // MARK: - Submission

    /// Register a fresh ticket. Initial state is `.proposed`.
    @discardableResult
    public func submit(
        _ ticket: BASUpdateTicket
    ) throws -> BASUpdateTicketLifecycleEntry {
        if entries[ticket.ticketID] != nil {
            throw LifecycleError.duplicateTicket(
                id: ticket.ticketID)
        }
        let entry = BASUpdateTicketLifecycleEntry(
            ticket: ticket,
            state: .proposed)
        entries[ticket.ticketID] = entry
        return entry
    }

    // MARK: - State transitions

    /// `proposed` → `trialing`. Records the trial ID for audit.
    public func startTrial(
        ticketID: String,
        trialRecordRef: String
    ) throws {
        try mutate(ticketID: ticketID, to: .trialing,
                   reasonCodes: [
                    "trial-record-ref:\(trialRecordRef)"]) {
            entry in entry.trialRecordRef = trialRecordRef
        }
    }

    /// `trialing` → `trialPassed` / `trialFailed` /
    /// `trialContaminated` based on the outcome.
    public func markTrialOutcome(
        ticketID: String,
        outcome: TrialOutcome
    ) throws {
        let target: BASUpdateTicketLifecycleState
        let reasonCodes: [String]
        switch outcome {
        case .passed(let codes):
            target = .trialPassed
            reasonCodes = codes
        case .failed(let codes):
            target = .trialFailed
            reasonCodes = codes
        case .contaminated(let codes):
            target = .trialContaminated
            reasonCodes = codes
        }
        try mutate(ticketID: ticketID, to: target,
                   reasonCodes: reasonCodes)
    }

    /// `trialPassed` → `queuedForDistillation`. Requires a
    /// sovereign verdict ref so the lineage is auditable.
    public func approveForDistillation(
        ticketID: String,
        sovereignVerdictRef: String
    ) throws {
        try mutate(
            ticketID: ticketID,
            to: .queuedForDistillation,
            reasonCodes: [
                "sovereign-verdict:\(sovereignVerdictRef)"]
        ) { entry in
            entry.sovereignVerdictRef = sovereignVerdictRef
        }
    }

    /// `queuedForDistillation` → `distilled`. Called by the
    /// external offline pipeline once it has incorporated the
    /// ticket into a model checkpoint. Terminal.
    public func markDistilled(
        ticketID: String,
        reasonCodes: [String] = []
    ) throws {
        try mutate(ticketID: ticketID, to: .distilled,
                   reasonCodes: reasonCodes)
    }

    /// Any pre-terminal state → `rejected`. The reject path is
    /// reachable from any non-terminal state so an L14 sovereign
    /// override or contamination guard can stop a ticket at any
    /// point. Terminal.
    public func markRejected(
        ticketID: String,
        reasonCodes: [String]
    ) throws {
        try mutate(ticketID: ticketID, to: .rejected,
                   reasonCodes: reasonCodes)
    }

    // MARK: - Read-only views

    public func entry(
        ticketID: String
    ) -> BASUpdateTicketLifecycleEntry? {
        entries[ticketID]
    }

    public func count() -> Int { entries.count }

    public func count(
        in state: BASUpdateTicketLifecycleState
    ) -> Int {
        entries.values.lazy.filter { $0.state == state }.count
    }

    /// Snapshot of every entry; sort order = ticket ID for
    /// determinism in tests and audit logs.
    public func allEntries()
    -> [BASUpdateTicketLifecycleEntry]
    {
        entries.values.sorted { $0.ticket.ticketID
            < $1.ticket.ticketID }
    }

    /// The "offline distillation queue": entries currently in
    /// `.queuedForDistillation`. External pipelines pull from
    /// here. Order is FIFO by the most recent
    /// `queuedForDistillation` transition timestamp.
    public func distillationQueue()
    -> [BASUpdateTicketLifecycleEntry]
    {
        entries.values
            .filter { $0.state == .queuedForDistillation }
            .sorted { lhs, rhs in
                let lt = lhs.history.last(where: {
                    $0.to == .queuedForDistillation
                })?.at ?? .distantFuture
                let rt = rhs.history.last(where: {
                    $0.to == .queuedForDistillation
                })?.at ?? .distantFuture
                return lt < rt
            }
    }

    // MARK: - Private

    private static let legalTransitions:
        [BASUpdateTicketLifecycleState:
            Set<BASUpdateTicketLifecycleState>]
        = [
            .proposed: [.trialing, .rejected],
            .trialing: [
                .trialPassed,
                .trialFailed,
                .trialContaminated,
                .rejected],
            .trialPassed: [
                .queuedForDistillation,
                .rejected],
            .trialFailed: [.rejected],
            .trialContaminated: [.rejected],
            .queuedForDistillation: [
                .distilled,
                .rejected],
            // Terminal states: nothing leaves them
            .distilled: [],
            .rejected: [],
        ]

    private func mutate(
        ticketID: String,
        to target: BASUpdateTicketLifecycleState,
        reasonCodes: [String],
        sideEffect: (
            inout BASUpdateTicketLifecycleEntry
        ) -> Void = { _ in }
    ) throws {
        guard var entry = entries[ticketID] else {
            throw LifecycleError.unknownTicket(id: ticketID)
        }
        let allowed = Self.legalTransitions[entry.state]
            ?? []
        guard allowed.contains(target) else {
            throw LifecycleError.illegalTransition(
                from: entry.state, to: target)
        }
        let transition = BASUpdateTicketLifecycleTransition(
            from: entry.state,
            to: target,
            at: clock(),
            reasonCodes: reasonCodes)
        entry.state = target
        entry.history.append(transition)
        sideEffect(&entry)
        entries[ticketID] = entry
    }
}
