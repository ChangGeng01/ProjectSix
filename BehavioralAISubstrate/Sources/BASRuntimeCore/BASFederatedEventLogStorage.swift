// MARK: - BASFederatedEventLogStorage
// chapter 四百四十五 / M1157 — POST-RADICAL Wave 16
//
// Typed `BASEventLogStorage` conformer that wraps N
// backend storage conformers (in-memory + SQLite +
// remote sync + future federated peers) and presents
// them as ONE unified event log。 Sibling of chapter
// 442's `BASInMemoryEventLogStorage` (single-backend
// in-memory) and chapter 三百九五 `BASSQLiteEventLog
// Storage` (single-backend SQLite);this is the typed
// composition over N backends。
//
// ## Why this exists (system entropy framing)
//
// chapter 443 (Wave 14) shipped
// `BASEventLogProjectors.projectAcrossAllSessions(
// from:)` for cross-SESSION replay aggregation within
// ONE storage backend。 But replay consumers (G8 SSM
// training,distributed audit,multi-host federation)
// often live across multiple storage backends:
//
//   - Local in-memory (test runs,one-shot CLI)
//   - SQLite-backed (chapter 三百九五 production
//     persistence)
//   - Remote-replicated (future federated peers)
//
// chapter 443 future-cut #4:typed protocol for replay
// consumers to pull from N storage backends in one
// call。 Without it,every consumer rolls its own
// loop:fetch-from-A,fetch-from-B,fetch-from-C,
// concat,sort by (timestampMs,sequenceNumber)。
// chapter 445 closes that gap。
//
// ## What this ships (M1157)
//
//   - `BASFederatedEventLogStorage` actor implementing
//     the `BASEventLogStorage` protocol over an array
//     of backend conformers。 Append routes to the
//     designated PRIMARY backend (idx 0 by default);
//     reads aggregate across ALL backends with proper
//     global ordering。
//   - `events(forSession:)` aggregates per-session events
//     from all backends + sorts by sequenceNumber。
//   - `events(sinceTimestampMs:limit:)` aggregates from
//     all backends + sorts by (timestampMs ASC,
//     sequenceNumber ASC) + caps at limit (chapter 三百
//     九七 retention semantics preserved)。
//   - `totalCount` async sums across all backends。
//   - `pruneEventsBefore(...)` propagates to all
//     backends + sums removed counts。
//   - Empty-backends-array case:`append` throws
//     `BASFederatedEventLogStorageError.noBackends`;
//     reads return empty。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — anti-magic-number (typed
//     actor + typed error;not a generic dispatcher)
//   - chapter 二百一一 — single source-of-truth (the
//     federation IS a `BASEventLogStorage` conformer;
//     consumers don't need a parallel API)
//   - chapter 三百九二 — replay-determinism (global
//     ordering preserved across backends via
//     timestampMs + sequenceNumber composite key)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive actor;no existing storage conformer
//     touched)
//   - 红线 7 — hint-only (federated storage is
//     observation/audit plumbing,not commitment
//     authority)
//   - ADR-014 OPT-IN — purely additive

import Foundation

// MARK: - Error

/// Typed errors thrown by `BASFederatedEventLogStorage`。
public enum BASFederatedEventLogStorageError:
    Error, Equatable, Sendable
{
    /// Caller tried to `append(_:)` but no backends
    /// were registered。 Hosts must construct the actor
    /// with at least one backend。
    case noBackends
}

// MARK: - Federated storage actor

/// Typed `BASEventLogStorage` conformer that wraps N
/// backend conformers and presents them as ONE
/// federated event log with proper cross-backend
/// ordering for reads。
public actor BASFederatedEventLogStorage:
    BASEventLogStorage
{

    // MARK: - State

    /// Ordered array of backend conformers。 Backend at
    /// index `primaryBackendIndex` receives all
    /// `append(_:)` calls;all backends contribute to
    /// reads。
    private let backends: [any BASEventLogStorage]

    /// Index into `backends` where new appends route。
    /// Defaults to `0` (first backend)。 Hosts can
    /// designate a different primary at construction
    /// time (e.g. SQLite primary,in-memory secondary)。
    /// `nonisolated` since it's set once at init and
    /// never mutates;callers can read without await。
    public nonisolated let primaryBackendIndex: Int

    // MARK: - Init

    /// Construct the federated storage over `backends`
    /// with the primary at `primaryBackendIndex`
    /// (defaults to 0)。 Empty backend list is allowed
    /// — `append` will throw `.noBackends`,reads
    /// return empty。
    public init(
        backends: [any BASEventLogStorage],
        primaryBackendIndex: Int = 0
    ) {
        self.backends = backends
        if backends.isEmpty {
            self.primaryBackendIndex = 0
        } else {
            self.primaryBackendIndex = max(
                0, min(primaryBackendIndex,
                       backends.count - 1))
        }
    }

    // MARK: - Public accessors

    /// Number of backends registered。 Useful for
    /// audit + tests verifying federation shape。
    public var backendCount: Int {
        return backends.count
    }

    // MARK: - BASEventLogStorage conformance

    @discardableResult
    public func append(
        _ entry: BASEventLogEntry
    ) async throws -> (
        wasNew: Bool, assignedSequenceNumber: Int64)
    {
        guard !backends.isEmpty else {
            throw BASFederatedEventLogStorageError
                .noBackends
        }
        return try await backends[primaryBackendIndex]
            .append(entry)
    }

    public func events(
        forSession sessionID: String
    ) async -> [BASEventLogEntry] {
        var collected: [BASEventLogEntry] = []
        for backend in backends {
            let slice = await backend.events(
                forSession: sessionID)
            collected.append(contentsOf: slice)
        }
        // Backend slices were already sequenceNumber-
        // sorted within each backend;but cross-backend
        // ordering needs explicit sort to honor the
        // protocol contract。 sequenceNumber is per-
        // session-monotonic so sorting by it is the
        // right global key here。
        collected.sort {
            $0.sequenceNumber < $1.sequenceNumber
        }
        return collected
    }

    public func events(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEventLogEntry] {
        let safeLimit = max(0, limit)
        guard safeLimit > 0 else { return [] }
        var collected: [BASEventLogEntry] = []
        for backend in backends {
            let slice = await backend.events(
                sinceTimestampMs: since,
                limit: safeLimit)
            collected.append(contentsOf: slice)
        }
        // Global ordering across backends:
        // (timestampMs ASC, sequenceNumber ASC) per
        // protocol contract。 Cap at limit AFTER sort
        // so the limit reflects the global earliest-
        // first window,not per-backend。
        collected.sort { lhs, rhs in
            if lhs.timestampMs != rhs.timestampMs {
                return lhs.timestampMs < rhs.timestampMs
            }
            return lhs.sequenceNumber < rhs.sequenceNumber
        }
        return Array(collected.prefix(safeLimit))
    }

    public var totalCount: Int {
        get async {
            var sum = 0
            for backend in backends {
                let n = await backend.totalCount
                sum += n
            }
            return sum
        }
    }

    @discardableResult
    public func pruneEventsBefore(
        timestampMs cutoff: Int64
    ) async throws -> Int {
        var totalRemoved = 0
        for backend in backends {
            let removed = try await backend
                .pruneEventsBefore(timestampMs: cutoff)
            totalRemoved += removed
        }
        return totalRemoved
    }
}
