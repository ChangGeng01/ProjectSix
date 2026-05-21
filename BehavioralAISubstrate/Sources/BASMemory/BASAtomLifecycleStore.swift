// MARK: - BASAtomLifecycleStore
// chapter 七百八十九 / M2596-M2600 — L8 storage adapter scaffold
//
// Persistence protocol + in-memory reference implementation for
// the L8 atom-lifecycle event log。 Pairs with:
//   - bas-atom-lifecycle Rust crate (chapter 七百八十二):state-
//     machine transition decisions
//   - SQL schema 023_atom_lifecycle_events (chapter 七百八十四):
//     append-only event log shape
//   - BASAtomLifecycleBridge (chapter 七百八十三):Swift bridge
//     to the Rust transition fn
//
// ## Why a protocol + in-memory impl in this chapter (not the
// ## SQLite-backed store)
//
// 「依旧 不删除 只 comment」 + ADR-014 OPT-IN. The in-memory
// reference impl is the LIVE default — hosts that want
// SQLite persistence opt in by passing a custom
// `BASAtomLifecycleStore` conformer (e.g。 a future
// BASSQLiteAtomLifecycleStore that writes to schema 023)。
// Same pattern as BASShadowTrialLedger:protocol seam + leaf-
// module-shipped reference impl + composition-layer opt-in。
//
// SQLite-backed conformer deferred to a future arc that ships
// the actor adapter (cross-actor + retain-cycle review needed
// for a real SQLite-backed actor that holds the schema 023
// statement-prepared cursors)。

import Foundation

// MARK: - Typed event record

/// One atom-lifecycle event。 Mirrors SQL schema 023 column
/// shape (chapter 七百八十四)。
public struct BASAtomLifecycleEvent:
    Sendable, Equatable, Hashable, Codable
{
    public let eventID: String
    public let atomID: String
    public let sessionID: String
    /// Phase BEFORE the transition (0..4 per Rust AtomPhase)。
    public let fromPhaseByte: UInt8
    /// Phase AFTER the transition (0..4)。
    public let toPhaseByte: UInt8
    /// Action driving the transition (0..3 per Rust AtomAction)。
    public let actionByte: UInt8
    /// Outcome (0=advanced / 1=rejected_illegal / 2=rejected_terminal)。
    public let outcome: Int32
    /// UNIX epoch ms timestamp。
    public let recordedAtMs: Int64
    /// Optional FK to the actor that drove this transition
    /// (sovereign / reducer / GC)。 Maps to SQL `actor_ref`。
    public let actorRef: String?

    public init(
        eventID: String,
        atomID: String,
        sessionID: String,
        fromPhaseByte: UInt8,
        toPhaseByte: UInt8,
        actionByte: UInt8,
        outcome: Int32,
        recordedAtMs: Int64,
        actorRef: String? = nil
    ) {
        self.eventID = eventID
        self.atomID = atomID
        self.sessionID = sessionID
        self.fromPhaseByte = fromPhaseByte
        self.toPhaseByte = toPhaseByte
        self.actionByte = actionByte
        self.outcome = outcome
        self.recordedAtMs = recordedAtMs
        self.actorRef = actorRef
    }

    /// Convenience:was the transition successful?
    public var advanced: Bool { outcome == 0 }
}

// MARK: - BASAtomLifecycleStore protocol

/// Persistence seam for atom lifecycle events。 Conformers may
/// be in-memory (this chapter) or SQLite-backed (future arc)。
///
/// Implementations:
///   - MUST be append-only at the event level (chapter 一百八十五
///     anti-magic-number + chapter 392 replay-determinism)
///   - MUST return events in insertion order from queries
///   - MAY throw on backing-store I/O failure
public protocol BASAtomLifecycleStore: Sendable {
    /// Append a new event。 Returns the persisted event (typically
    /// identical to the input,but conformers may decorate with
    /// store-side metadata)。
    func appendEvent(_ event: BASAtomLifecycleEvent) async throws -> BASAtomLifecycleEvent

    /// Replay all events for a specific atom in insertion order。
    /// Used for cold-restart state reconstruction。
    func events(forAtom atomID: String) async -> [BASAtomLifecycleEvent]

    /// Replay all events across all atoms for a session in
    /// insertion order。 Used for cross-session audit。
    func events(forSession sessionID: String) async -> [BASAtomLifecycleEvent]

    /// Total event count。 Useful for stress-test + scorecard。
    func count() async -> Int
}

// MARK: - BASInMemoryAtomLifecycleStore reference impl

/// In-memory `BASAtomLifecycleStore` reference impl。 Useful for
/// unit tests + as the live default for hosts that don't want
/// SQLite。 Deterministic insertion order;single-process only。
public actor BASInMemoryAtomLifecycleStore: BASAtomLifecycleStore {

    public enum StoreError: Error, Equatable, Sendable {
        case duplicateEventID(String)
    }

    private var events: [BASAtomLifecycleEvent] = []
    private var indexByEventID: [String: Int] = [:]

    public init() {}

    public func appendEvent(
        _ event: BASAtomLifecycleEvent
    ) async throws -> BASAtomLifecycleEvent {
        if indexByEventID[event.eventID] != nil {
            throw StoreError.duplicateEventID(event.eventID)
        }
        indexByEventID[event.eventID] = events.count
        events.append(event)
        return event
    }

    public func events(
        forAtom atomID: String
    ) async -> [BASAtomLifecycleEvent] {
        events.filter { $0.atomID == atomID }
    }

    public func events(
        forSession sessionID: String
    ) async -> [BASAtomLifecycleEvent] {
        events.filter { $0.sessionID == sessionID }
    }

    public func count() async -> Int {
        events.count
    }

    /// Test-only:bulk-import events (cold-restart simulation
    /// from SQLite-backed conformer)。
    public func bulkImport(
        _ batch: [BASAtomLifecycleEvent]
    ) async throws {
        for event in batch {
            _ = try await appendEvent(event)
        }
    }
}

// MARK: - Reconstruction helpers (cold-restart support)

extension BASAtomLifecycleStore {

    /// Reconstruct the current phase of an atom by replaying its
    /// events in insertion order。 Returns the LATEST observed
    /// to_phase byte from the most recent `advanced=true` event,
    /// or nil if the atom has no successful events。
    ///
    /// Pure replay logic — no I/O beyond the store query。
    /// chapter 392 replay-determinism preserved。
    public func reconstructCurrentPhaseByte(
        forAtom atomID: String
    ) async -> UInt8? {
        let history = await events(forAtom: atomID)
        var latestPhase: UInt8? = nil
        for event in history where event.advanced {
            latestPhase = event.toPhaseByte
        }
        return latestPhase
    }
}
