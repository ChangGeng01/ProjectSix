import Foundation
import BASRuntimeCore

/// M94 — `BASRetractionFurnace`: substrate-side schema for the L13
/// retraction execution queue with typed lifecycle state.
///
/// ## Why this exists
///
/// The user audit listed `BASRetractionFurnace` as one of six
/// "whitepaper-named types with zero code hits". The L13 Evolution
/// Furnace whitepaper describes the furnace as the **queue that
/// walks retraction orders from `queued` → `inFlight` →
/// (`completed` | `failed` | `skipped`) with explicit per-entry
/// audit metadata**.
///
/// Pre-M94 the substrate had `BASRetractionOrder` with a free-text
/// `executionState: String` field. That string is too weak to gate
/// on — callers can't pattern-match it without trusting the author
/// to spell `"in-flight"` vs `"inFlight"` vs `"running"` the same
/// way every time. The furnace introduces a typed enum and an
/// explicit queue container so execution walkers can reason about
/// the state machine instead of parsing strings.
///
/// ## Scope
///
/// M94 ships **schema + queue-mutation surface only** — pure
/// additive value types with Codable round-trip, enqueue /
/// mark-inFlight / mark-completed / mark-failed / mark-skipped /
/// query APIs, no runtime integration. Future milestones will wire
/// `BASShadowTrialCoordinator` / `QinaoFurnace` / the sovereign
/// verdict engine to drain the furnace on retraction approval.
/// This is the M88 discipline: land the schema clean, wire later
/// when hosts need it.
///
/// ## Relationship to `BASVersionArboretum`
///
/// When the furnace advances an entry through its lifecycle a
/// future runtime layer SHOULD append a matching
/// `BASArboretumDelta` (kind `.retractionQueued` on enqueue,
/// `.retractionCompleted` on completion). The furnace does NOT do
/// that wiring here — the two schemas are independently
/// addressable; composition lives in the coordinator layer.
///
/// ## DAG discipline
///
/// Pure Foundation + `BASRuntimeCore`-visible schema. No Qinao
/// imports. No dependencies on `BASRetractionOrder` beyond the
/// orderID string reference — the furnace stores the order
/// inline so callers don't need to resolve a separate lookup
/// table.

// MARK: - BASRetractionExecutionState

/// Typed lifecycle state for a retraction furnace entry.
///
/// Stable raw values let cross-layer consumers key on the string
/// without importing the substrate. This replaces the free-text
/// `executionState: String` on `BASRetractionOrder` when a gate
/// needs to pattern-match.
///
/// Lifecycle:
///
/// ```
/// queued ──► inFlight ──► completed
///              │
///              ├────────► failed
///              │
///              └────────► skipped
/// ```
///
/// `queued` and `inFlight` are transient; `completed`, `failed`,
/// `skipped` are terminal. The furnace refuses transitions that
/// would violate this state machine.
public enum BASRetractionExecutionState:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable {
    /// The order is on the furnace queue awaiting pickup.
    case queued = "queued"
    /// The order has been picked up and is executing. External
    /// writes may be in progress.
    case inFlight = "in-flight"
    /// The order finished successfully. All target refs are
    /// retracted and cascade refs are resolved.
    case completed = "completed"
    /// The order was picked up but could not finish. Check
    /// `failureReason` on the entry.
    case failed = "failed"
    /// The order was removed from the queue without executing —
    /// typically because it became stale (target already gone) or
    /// a supervising gate decided not to run it.
    case skipped = "skipped"

    /// Whether this state is terminal. Terminal states cannot be
    /// transitioned out of.
    public var isTerminal: Bool {
        switch self {
        case .queued, .inFlight: return false
        case .completed, .failed, .skipped: return true
        }
    }
}

// MARK: - BASRetractionFurnaceEntry

/// One entry in the furnace queue. Wraps a retraction order with
/// execution metadata: enqueue / start / finish timestamps, state,
/// and failure reason (when applicable).
///
/// The entry stores the order's fields inline (not a reference) so
/// callers don't need a separate lookup table to resolve
/// `orderID → order`. If the original `BASRetractionOrder` is also
/// held elsewhere they will agree by construction on the shared
/// fields.
public struct BASRetractionFurnaceEntry:
    BASSchemaVersioned, Hashable {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier shared with the wrapped retraction order.
    public var orderID: String
    /// Versions / artifacts to retract. Mirrors
    /// `BASRetractionOrder.targetRefs`.
    public var targetRefs: [String]
    /// Dependent refs that must also be retracted. Mirrors
    /// `BASRetractionOrder.cascadeRefs`.
    public var cascadeRefs: [String]
    /// Why the order exists. Mirrors
    /// `BASRetractionOrder.reasonCodes`.
    public var reasonCodes: [String]
    /// Current lifecycle state.
    public var state: BASRetractionExecutionState
    /// When the entry was enqueued. Always present.
    public var enqueuedAt: Date
    /// When the entry transitioned to `inFlight`. Nil while
    /// `queued`.
    public var startedAt: Date?
    /// When the entry transitioned to a terminal state. Nil for
    /// non-terminal states.
    public var finishedAt: Date?
    /// Free-text reason if `state == .failed`. Nil otherwise.
    public var failureReason: String?

    public init(
        schemaVersion: String
            = BASRetractionFurnaceEntry.currentSchemaVersion,
        orderID: String,
        targetRefs: [String] = [],
        cascadeRefs: [String] = [],
        reasonCodes: [String] = [],
        state: BASRetractionExecutionState = .queued,
        enqueuedAt: Date,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        failureReason: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.orderID = orderID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetRefs = targetRefs
        self.cascadeRefs = cascadeRefs
        self.reasonCodes = reasonCodes
        self.state = state
        self.enqueuedAt = enqueuedAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.failureReason = failureReason
    }
}

// MARK: - BASRetractionFurnace

/// The L13 retraction execution queue. Value-type; mutations
/// return a new furnace (functional style) so audit pipelines
/// threading the furnace don't accidentally share mutable state.
/// For actor-owned workflows, wrap the furnace in your own actor.
///
/// The furnace refuses transitions that violate the
/// `BASRetractionExecutionState` lifecycle — e.g. moving from
/// `.queued` directly to `.completed`, or transitioning out of a
/// terminal state.
public struct BASRetractionFurnace:
    BASSchemaVersioned, Hashable, Sendable {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier for the whole furnace.
    public var furnaceID: String
    /// Entries in enqueue order. Oldest first.
    public var entries: [BASRetractionFurnaceEntry]

    public init(
        schemaVersion: String
            = BASRetractionFurnace.currentSchemaVersion,
        furnaceID: String,
        entries: [BASRetractionFurnaceEntry] = []
    ) {
        self.schemaVersion = schemaVersion
        self.furnaceID = furnaceID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.entries = entries
    }

    // MARK: - Enqueue

    /// Add a new entry to the queue. Returns a new furnace with
    /// `entry` appended.
    public func enqueue(
        _ entry: BASRetractionFurnaceEntry
    ) -> BASRetractionFurnace {
        var copy = self
        copy.entries.append(entry)
        return copy
    }

    // MARK: - Transitions

    /// Move an entry from `.queued` to `.inFlight`. No-op (returns
    /// unchanged furnace) if the order isn't found or isn't in
    /// `.queued`.
    public func markInFlight(
        orderID: String,
        at timestamp: Date
    ) -> BASRetractionFurnace {
        updateEntry(orderID: orderID) { entry in
            guard entry.state == .queued else { return entry }
            var next = entry
            next.state = .inFlight
            next.startedAt = timestamp
            return next
        }
    }

    /// Move an entry from `.inFlight` to `.completed`. No-op if not
    /// found or not in `.inFlight`. Completion means the retraction was
    /// EXECUTED successfully, so it must follow `markInFlight` — the
    /// documented lifecycle is `queued → inFlight → completed`. (An
    /// order that never executes reaches a terminal state via
    /// `markSkipped`/`markFailed`, not `markCompleted`.)
    /// blindspot MED id32: the old guard `!entry.state.isTerminal`
    /// allowed `queued → completed`, skipping execution.
    public func markCompleted(
        orderID: String,
        at timestamp: Date
    ) -> BASRetractionFurnace {
        updateEntry(orderID: orderID) { entry in
            guard entry.state == .inFlight else { return entry }
            var next = entry
            next.state = .completed
            next.finishedAt = timestamp
            next.failureReason = nil
            return next
        }
    }

    /// Move an entry to `.failed` with a failure reason. No-op if
    /// not found or already terminal.
    public func markFailed(
        orderID: String,
        reason: String,
        at timestamp: Date
    ) -> BASRetractionFurnace {
        updateEntry(orderID: orderID) { entry in
            guard !entry.state.isTerminal else { return entry }
            var next = entry
            next.state = .failed
            next.finishedAt = timestamp
            next.failureReason = reason
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return next
        }
    }

    /// Move an entry to `.skipped`. No-op if not found or already
    /// terminal. Skipped entries do NOT carry a failureReason —
    /// skipping is an explicit gate decision, not an error.
    public func markSkipped(
        orderID: String,
        at timestamp: Date
    ) -> BASRetractionFurnace {
        updateEntry(orderID: orderID) { entry in
            guard !entry.state.isTerminal else { return entry }
            var next = entry
            next.state = .skipped
            next.finishedAt = timestamp
            next.failureReason = nil
            return next
        }
    }

    // MARK: - Query

    /// Entries currently in `.queued`. Preserves enqueue order.
    public var pending: [BASRetractionFurnaceEntry] {
        entries.filter { $0.state == .queued }
    }

    /// Entries currently in `.inFlight`. Preserves enqueue order.
    public var inFlight: [BASRetractionFurnaceEntry] {
        entries.filter { $0.state == .inFlight }
    }

    /// Entries in any terminal state. Preserves enqueue order.
    public var finished: [BASRetractionFurnaceEntry] {
        entries.filter { $0.state.isTerminal }
    }

    /// Entries whose `targetRefs` or `cascadeRefs` contain
    /// `versionRef`. Useful for gates asking "is this version
    /// scheduled for retraction?".
    public func entries(
        forTarget versionRef: String
    ) -> [BASRetractionFurnaceEntry] {
        entries.filter {
            $0.targetRefs.contains(versionRef)
            || $0.cascadeRefs.contains(versionRef)
        }
    }

    /// The single entry with the matching order ID, if any.
    /// Orders are expected to be unique; if duplicates somehow
    /// exist, the first in enqueue order wins.
    public func entry(
        orderID: String
    ) -> BASRetractionFurnaceEntry? {
        entries.first { $0.orderID == orderID }
    }

    /// Entries filtered by lifecycle state.
    public func entries(
        inState state: BASRetractionExecutionState
    ) -> [BASRetractionFurnaceEntry] {
        entries.filter { $0.state == state }
    }

    // MARK: - Private

    /// Apply `transform` to the first entry matching `orderID`.
    /// Returns unchanged furnace if no match.
    private func updateEntry(
        orderID: String,
        transform: (BASRetractionFurnaceEntry)
            -> BASRetractionFurnaceEntry
    ) -> BASRetractionFurnace {
        guard let idx = entries.firstIndex(
            where: { $0.orderID == orderID }
        ) else { return self }
        var copy = self
        copy.entries[idx] = transform(copy.entries[idx])
        return copy
    }
}
