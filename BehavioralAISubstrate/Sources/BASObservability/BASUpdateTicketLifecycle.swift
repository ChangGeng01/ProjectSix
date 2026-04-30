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

/// M268 — durable storage for lifecycle entries.
///
/// `BASUpdateTicketLifecycleCoordinator` runs in-process in
/// memory by default. For multi-process / cross-restart
/// continuity, hosts pass a storage adapter at init. The
/// coordinator calls `load()` on `restore()` to seed entries
/// from disk and `save(_:)` after every mutation.
///
/// Mirror of M91's audit-ledger persistence pattern. The
/// storage protocol is intentionally narrow (load + save) so
/// implementations can be plain JSON files, SQLite, CloudKit,
/// or whatever the host needs. The default implementation
/// shipped here is a JSON-encoded file at a host-supplied URL.
///
/// ## M271 — concurrency contract
///
/// Implementations are responsible for cross-process safety
/// when the storage backs a file shared by multiple hosts:
///
/// - `BASUpdateTicketLifecycleJSONFileStorage`: **NOT**
///   cross-process safe. Two processes writing the same file
///   simultaneously can lose one set of changes (atomic-replace
///   races at the filesystem layer). Single-host only.
///
/// - `BASUpdateTicketLifecycleSQLiteStorage` (M270): **IS**
///   cross-process safe. SQLite's own lock manager handles
///   serialization via `SQLITE_OPEN_FULLMUTEX` + the natural
///   `BEGIN TRANSACTION` exclusive lock. Two host processes
///   pointing at the same `.sqlite` file see consistent state.
///
/// Hosts deploying multi-process scenarios (one writer + N
/// readers, or load-balanced workers) should pick the SQLite
/// implementation. The JSON file is for single-host workflows.
public protocol BASUpdateTicketLifecycleStorage: Sendable {
    /// Load every stored entry. Empty dict on first run /
    /// missing file. Throws on corrupt data so callers can
    /// decide to bail vs. start fresh.
    func load() async throws
        -> [String: BASUpdateTicketLifecycleEntry]

    /// Persist the current entry set. Called after every
    /// mutation; implementations should be atomic so partial
    /// writes don't corrupt prior state.
    func save(
        _ entries: [String: BASUpdateTicketLifecycleEntry]
    ) async throws
}

/// Default implementation: atomic JSON file. Writes go to a
/// `.tmp` sibling first, then `replaceItem` rotates it into
/// place — a partial write or crash mid-save leaves the prior
/// state intact.
public final class BASUpdateTicketLifecycleJSONFileStorage:
    BASUpdateTicketLifecycleStorage
{
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() async throws
    -> [String: BASUpdateTicketLifecycleEntry] {
        guard FileManager.default.fileExists(
            atPath: url.path)
        else { return [:] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(
            [String: BASUpdateTicketLifecycleEntry].self,
            from: data)
    }

    public func save(
        _ entries: [String: BASUpdateTicketLifecycleEntry]
    ) async throws {
        let data = try JSONEncoder().encode(entries)
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        // Use replaceItem so the swap is atomic at FS level.
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(
                url, withItemAt: tmpURL)
        } else {
            try FileManager.default.moveItem(
                at: tmpURL, to: url)
        }
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

    /// M265 — terminal-transition audit hook. When a ticket
    /// reaches `.distilled` or `.rejected`, the coordinator
    /// invokes this closure with a synthesized
    /// `BASSovereignAuditEntry` so hosts can pipe terminal
    /// lifecycle events into `BASSovereignAuditLedger` without
    /// `BASObservability` having to import `BASSovereign`.
    /// Hosts wire it as `{ try await ledger.append($0) }`.
    /// Errors thrown by the sink are absorbed (audit failures
    /// must not crash the lifecycle path); callers that want
    /// strict failure can log inside the closure.
    public typealias AuditSink =
        @Sendable (BASSovereignAuditEntry) async throws -> Void

    private var entries: [String: BASUpdateTicketLifecycleEntry] = [:]
    private let clock: @Sendable () -> Date
    private let auditSink: AuditSink?
    /// M268 — optional durable storage for entries.
    private let storage: BASUpdateTicketLifecycleStorage?

    /// M273 — chain link for serialized auto-saves. Each
    /// `persistQuietly()` invocation captures the current snapshot
    /// of `entries` then awaits the prior save chain link before
    /// invoking `storage.save(_:)`. This guarantees in-flight
    /// saves complete in the same order their snapshots were
    /// taken — the latest snapshot writes last, so the on-disk
    /// state always converges to the actor's current entries map.
    ///
    /// Without this, two concurrent submits could capture
    /// different snapshots, race to disk, and the LATER snapshot
    /// (with more entries) could land BEFORE the EARLIER one,
    /// leaving the file in a stale state.
    private var saveChain: Task<Void, Never>?

    public init(
        clock: @escaping @Sendable () -> Date = { .now },
        auditSink: AuditSink? = nil,
        storage: BASUpdateTicketLifecycleStorage? = nil
    ) {
        self.clock = clock
        self.auditSink = auditSink
        self.storage = storage
    }

    // MARK: - M268 durable-state lifecycle

    /// Load entries from durable storage. Idempotent: calling
    /// twice replays the file's current contents into the
    /// actor's entries map (overwriting any prior in-memory
    /// state). Hosts call this once at startup before any
    /// mutating operation.
    public func restore() async throws {
        guard let storage = storage else { return }
        let loaded = try await storage.load()
        entries = loaded
    }

    /// Persist current entries to storage. Called automatically
    /// after every mutation; exposed publicly for hosts that
    /// want to force a flush at known checkpoints. Errors are
    /// absorbed inside the auto-call path so persistence
    /// failures don't crash the lifecycle. Manual callers see
    /// the throw.
    public func persist() async throws {
        guard let storage = storage else { return }
        try await storage.save(entries)
    }

    private func persistQuietly() async {
        guard let storage = storage else { return }
        // M273 — chain saves so they execute in the order their
        // snapshots were taken. Capture the current snapshot
        // synchronously (still on the actor's executor), then
        // schedule a Task that awaits the prior save before
        // running ours. We then await the new task inline so
        // callers see the storage at the latest snapshot
        // synchronously after the mutation returns. The chain
        // prevents misordering between in-flight saves; the
        // inline await prevents stale reads downstream.
        let snapshot = entries
        let prior = saveChain
        let task = Task { [storage, snapshot, prior] in
            await prior?.value
            do {
                try await storage.save(snapshot)
            } catch {
                // absorbed — persistence failures don't crash
                // lifecycle (mutation already completed in
                // memory; chain advances regardless)
            }
        }
        saveChain = task
        await task.value
    }

    /// Wait for any in-flight auto-save chain to drain. Hosts
    /// running stress workloads (or tests) call this before
    /// reading the storage from a fresh handle to ensure the
    /// latest mutation has reached disk.
    public func drainPersistChain() async {
        await saveChain?.value
    }

    // MARK: - Submission

    /// Register a fresh ticket. Initial state is `.proposed`.
    @discardableResult
    public func submit(
        _ ticket: BASUpdateTicket
    ) async throws -> BASUpdateTicketLifecycleEntry {
        if entries[ticket.ticketID] != nil {
            throw LifecycleError.duplicateTicket(
                id: ticket.ticketID)
        }
        let entry = BASUpdateTicketLifecycleEntry(
            ticket: ticket,
            state: .proposed)
        entries[ticket.ticketID] = entry
        await persistQuietly()
        return entry
    }

    // MARK: - State transitions

    /// `proposed` → `trialing`. Records the trial ID for audit.
    public func startTrial(
        ticketID: String,
        trialRecordRef: String
    ) async throws {
        try mutate(ticketID: ticketID, to: .trialing,
                   reasonCodes: [
                    "trial-record-ref:\(trialRecordRef)"]) {
            entry in entry.trialRecordRef = trialRecordRef
        }
        await persistQuietly()
    }

    /// `trialing` → `trialPassed` / `trialFailed` /
    /// `trialContaminated` based on the outcome.
    public func markTrialOutcome(
        ticketID: String,
        outcome: TrialOutcome
    ) async throws {
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
        await persistQuietly()
    }

    /// `trialPassed` → `queuedForDistillation`. Requires a
    /// sovereign verdict ref so the lineage is auditable.
    public func approveForDistillation(
        ticketID: String,
        sovereignVerdictRef: String
    ) async throws {
        try mutate(
            ticketID: ticketID,
            to: .queuedForDistillation,
            reasonCodes: [
                "sovereign-verdict:\(sovereignVerdictRef)"]
        ) { entry in
            entry.sovereignVerdictRef = sovereignVerdictRef
        }
        await persistQuietly()
    }

    /// `queuedForDistillation` → `distilled`. Called by the
    /// external offline pipeline once it has incorporated the
    /// ticket into a model checkpoint. Terminal.
    public func markDistilled(
        ticketID: String,
        reasonCodes: [String] = []
    ) async throws {
        try mutate(ticketID: ticketID, to: .distilled,
                   reasonCodes: reasonCodes)
        await persistQuietly()
        await emitTerminalAudit(
            ticketID: ticketID,
            terminal: .distilled,
            reasonCodes: reasonCodes)
    }

    /// Any pre-terminal state → `rejected`. The reject path is
    /// reachable from any non-terminal state so an L14 sovereign
    /// override or contamination guard can stop a ticket at any
    /// point. Terminal.
    public func markRejected(
        ticketID: String,
        reasonCodes: [String]
    ) async throws {
        try mutate(ticketID: ticketID, to: .rejected,
                   reasonCodes: reasonCodes)
        await persistQuietly()
        await emitTerminalAudit(
            ticketID: ticketID,
            terminal: .rejected,
            reasonCodes: reasonCodes)
    }

    /// Build + emit a `BASSovereignAuditEntry` for a terminal
    /// lifecycle transition. Errors from the sink are absorbed
    /// because audit failures must not crash the lifecycle path
    /// (a failed write to the ledger is a sovereign-layer
    /// concern; the lifecycle state machine has already mutated
    /// successfully and that record stays in `entries`).
    private func emitTerminalAudit(
        ticketID: String,
        terminal: BASUpdateTicketLifecycleState,
        reasonCodes: [String]
    ) async {
        guard let sink = auditSink,
              let entry = entries[ticketID]
        else { return }
        // synthesize an audit entry. verdictRef must be non-
        // empty per ledger validation — fall back to a
        // synthetic ID derived from the lifecycle state so the
        // entry passes ledger.append's contract.
        let verdictRef = entry.sovereignVerdictRef
            ?? "lifecycle.\(terminal.rawValue).\(ticketID)"
        let auditEntry = BASSovereignAuditEntry(
            auditID: "lifecycle.\(terminal.rawValue)." +
                "\(ticketID)",
            sessionID: entry.ticket.sessionRef.isEmpty
                ? "lifecycle"
                : entry.ticket.sessionRef,
            turnID: "lifecycle-terminal",
            verdictRef: verdictRef,
            ruleIDs: ["L13.lifecycle.\(terminal.rawValue)"],
            signalRefs: reasonCodes,
            actionRefs: [
                "ticket:\(ticketID)",
                "state:\(terminal.rawValue)",
            ],
            snapshotRef: entry.trialRecordRef ?? "",
            actor: .system,
            signature: "",
            appendedAt: clock())
        do {
            try await sink(auditEntry)
        } catch {
            // absorbed — audit failures must not crash lifecycle
        }
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

    // MARK: - M261 auto-flow ingestion

    /// Ingest every ticket produced by a turn (typically
    /// `BASEBrainTurnResult.updateTickets`). Duplicates are
    /// silently skipped so this is safe to call after every
    /// turn even if the host occasionally re-presents an old
    /// ticket. Returns the number of newly-registered tickets
    /// (those that weren't already in the coordinator).
    ///
    /// All other errors are silently absorbed too — the
    /// auto-flow path must never crash a host runtime, and
    /// `submit` only throws `duplicateTicket` today. Hosts that
    /// want stricter handling should iterate manually.
    @discardableResult
    public func ingestTurn(
        _ tickets: [BASUpdateTicket]
    ) async -> Int {
        var newCount = 0
        for ticket in tickets {
            do {
                _ = try await submit(ticket)
                newCount += 1
            } catch {
                // duplicateTicket etc. — auto-flow is forgiving
                continue
            }
        }
        return newCount
    }
}
