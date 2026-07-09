// MARK: - BASEventSourcedMemoryAtomStore — chapter 四百二 / M943
//
// Phase 1 第三刀: event-sourced `BASMemoryAtomStore` conformer。
// Persists ONLY the event log;projects atom state on read。Hosts
// opt in via this conformer instead of `BASInMemoryMemoryAtomStore`
// or `BASSQLiteMemoryAtomStore`,both of which keep their own row
// state and violate chapter 二百一一 single-source-of-truth。
//
// ## Why this exists
//
// M941 ships the typed event payload。M942 ships the reducer。M943
// is the conformer that ties them together: every write appends a
// typed `BASEventLogEntry` to the canonical event log;every read
// projects the current atom set。No parallel state。Replay always
// reproduces the same projection (chapter 三百九二)。
//
// ## What this ships (M943)
//
//   - `BASEventSourcedMemoryAtomStore` actor conforming to
//     `BASMemoryAtomStore`
//   - `CachePolicy` enum (`.lazy` / `.warmAtInit` /
//     `.cachedWithTTL`)。`.lazy` projects on every read;
//     `.warmAtInit` keeps an in-actor cache that mutates on
//     every successful append (still serialized via actor
//     isolation,so cache and event log can never diverge
//     mid-write)
//   - Parity surface: `admit(_:)`,`count`,`allIDs`,
//     `allAtoms()`,`projectAll()`,`lastReplayedSequenceNumber`
//   - Content cache: `BASGovernedMemory.content` is host-side
//     ephemeral data NOT carried in events (privacy)。The store
//     keeps a `[String: String]` content cache populated on
//     successful `admit`/`updateX` calls so in-process callers
//     see full atoms。Cross-process replay produces empty content
//     by design (host responsibility to repopulate if needed)
//
// ## Doctrine pins held
//
//   - All M941 + M942 doctrine pins
//   - chapter 二百一一 single-source-of-truth — load-bearing。
//     Atom state lives ONLY on the event log。Cache is a derived
//     view,not a parallel source。
//   - chapter 二百四十八 storage idiom — actor isolation +
//     typed errors mirror BASSQLiteMemoryAtomStore's contract
//   - chapter 三百九二 replay-determinism — both `.lazy` and
//     `.warmAtInit` modes produce byte-equal projections (uses
//     same M942 reducer)
//   - ADR-014 OPT-IN — legacy stores untouched

import Foundation
import BASRuntimeCore

// MARK: - Cache policy

/// Cache policy for the event-sourced atom store。Trades memory
/// for read latency。
public enum BASEventSourcedMemoryAtomStoreCachePolicy:
    Sendable, Equatable, Codable
{
    /// Project the full atom set from the event log on every
    /// read。Smallest memory footprint;O(N) per read where N
    /// is the session event count。Best for low-write-volume
    /// or cross-process consistency demands。
    case lazy

    /// Project once at init,then mutate cache on every
    /// successful append。O(1) reads;O(1) writes;cache lives
    /// for actor lifetime。Best for high-read-volume hosts。
    case warmAtInit

    /// Forward-compat slot for Phase 2: TTL-bounded cache。
    /// Currently behaves like `.warmAtInit` (TTL ignored)。
    case cachedWithTTL(seconds: Int)
}

// MARK: - Store

/// Event-sourced `BASMemoryAtomStore` conformer。Persists ONLY
/// the typed event log;projects atom state on read。
public actor BASEventSourcedMemoryAtomStore: BASMemoryAtomStore {

    // MARK: - Dependencies

    private let eventLog: any BASEventLogStorage
    private let sessionID: String
    private let eventIDFactory: @Sendable () -> String
    private let clockMs: @Sendable () -> Int64
    private let source: String
    private let cachePolicy:
        BASEventSourcedMemoryAtomStoreCachePolicy

    // MARK: - Mutable cache (actor-isolated)

    private var stateCache: [String: BASGovernedMemory] = [:]
    private var contentCache: [String: String] = [:]
    private var hasWarmedCache: Bool = false
    private var lastSeq: Int64? = nil

    /// audit memory-b F4 — surfaced when a mutation (updateTier /
    /// updateGovernanceStatus / remove) FAILS on an EXISTING atom. The Bool/nil
    /// returns can't distinguish "atom not found" from "store write errored"
    /// (both false/nil), so a real write failure was silently fail-open (counted
    /// downstream as not-found). A host wires this to observe the real error.
    /// nil ⇒ unobserved (default).
    public var onSilentFailure: (@Sendable (Error) -> Void)?
    public func setOnSilentFailure(_ handler: (@Sendable (Error) -> Void)?) {
        self.onSilentFailure = handler
    }

    // MARK: - Init

    public init(
        eventLog: any BASEventLogStorage,
        sessionID: String,
        eventIDFactory: @escaping @Sendable () -> String =
            { UUID().uuidString },
        clockMs: @escaping @Sendable () -> Int64 =
            { Int64(Date().timeIntervalSince1970 * 1000) },
        source: String = "memory-atom-store",
        cachePolicy:
            BASEventSourcedMemoryAtomStoreCachePolicy = .lazy
    ) {
        self.eventLog = eventLog
        self.sessionID = sessionID
        self.eventIDFactory = eventIDFactory
        self.clockMs = clockMs
        self.source = source
        self.cachePolicy = cachePolicy
    }

    // MARK: - Cache helpers

    private func warmCacheIfNeeded() async {
        switch cachePolicy {
        case .lazy:
            return
        case .warmAtInit, .cachedWithTTL:
            if hasWarmedCache {
                return
            }
            hasWarmedCache = true
            stateCache = await BASMemoryAtomReducer.project(
                from: eventLog,
                sessionID: sessionID)
            // lastSeq from latest projected event
            let events = await eventLog.events(
                forSession: sessionID)
            lastSeq = events.last?.sequenceNumber
        }
    }

    private func currentProjection() async
        -> [String: BASGovernedMemory]
    {
        switch cachePolicy {
        case .lazy:
            return await BASMemoryAtomReducer.project(
                from: eventLog,
                sessionID: sessionID)
        case .warmAtInit, .cachedWithTTL:
            await warmCacheIfNeeded()
            return stateCache
        }
    }

    /// Hydrate `BASGovernedMemory.content` from the local
    /// content cache。Replayed atoms have empty content;hosts
    /// that admitted atoms in-process see full content via the
    /// cache。
    private func hydrateContent(
        _ atom: BASGovernedMemory
    ) -> BASGovernedMemory {
        guard let cached = contentCache[atom.id.uuidString],
              !cached.isEmpty else {
            return atom
        }
        var hydrated = atom
        hydrated.content = cached
        return hydrated
    }

    // MARK: - Append + cache update (single-mutex region)

    private func appendEventAndUpdateCache(
        payload: BASMemoryAtomEventPayload
    ) async throws -> Bool {
        let entry = BASEventLogEntry.memoryAtomEvent(
            eventID: eventIDFactory(),
            timestampMs: clockMs(),
            sessionID: sessionID,
            sequenceNumber: 0,
            payload: payload,
            source: source)
        let result = try await eventLog.append(entry)
        if !result.wasNew {
            return false
        }
        lastSeq = result.assignedSequenceNumber
        switch cachePolicy {
        case .lazy:
            return true
        case .warmAtInit, .cachedWithTTL:
            await warmCacheIfNeeded()
            stateCache = BASMemoryAtomReducer.reduce(
                priorAtoms: stateCache,
                event: BASEventLogEntry(
                    eventID: entry.eventID,
                    timestampMs: entry.timestampMs,
                    kind: entry.kind,
                    sessionID: entry.sessionID,
                    sequenceNumber:
                        result.assignedSequenceNumber,
                    source: entry.source,
                    turnRef: entry.turnRef,
                    rawInputDigest: entry.rawInputDigest,
                    intent: entry.intent,
                    emotion: entry.emotion,
                    riskBand: entry.riskBand,
                    project: entry.project,
                    memoryRefs: entry.memoryRefs,
                    stateBeforeID: entry.stateBeforeID,
                    stateAfterID: entry.stateAfterID,
                    actions: entry.actions,
                    confidence: entry.confidence,
                    payloadJson: entry.payloadJson))
            return true
        }
    }

    // MARK: - BASMemoryAtomStore conformance

    public func atom(
        forID id: String
    ) async -> BASGovernedMemory? {
        let projection = await currentProjection()
        guard let atom = projection[id] else { return nil }
        return hydrateContent(atom)
    }

    @discardableResult
    public func updateTier(
        forID id: String,
        to newTier: BASMemoryTier
    ) async -> Bool {
        // No-op if atom is not present (matches in-memory store)
        let projection = await currentProjection()
        guard projection[id] != nil else { return false }
        let payload = BASMemoryAtomEventPayload(
            tierChange: id, newTier: newTier)
        do {
            return try await appendEventAndUpdateCache(
                payload: payload)
        } catch {
            // audit memory-b F4: the atom EXISTS (guard passed) — a false here is
            // a store WRITE error, not "not found". Surface it, don't fail-open.
            onSilentFailure?(error)
            return false
        }
    }

    @discardableResult
    public func updateGovernanceStatus(
        forID id: String,
        to newStatus: BASMemoryGovernanceStatus
    ) async -> Bool {
        let projection = await currentProjection()
        guard projection[id] != nil else { return false }
        let payload = BASMemoryAtomEventPayload(
            governanceChange: id, newStatus: newStatus)
        do {
            return try await appendEventAndUpdateCache(
                payload: payload)
        } catch {
            onSilentFailure?(error)   // audit memory-b F4: surface the write error
            return false
        }
    }

    @discardableResult
    public func remove(
        forID id: String
    ) async -> BASGovernedMemory? {
        let projection = await currentProjection()
        guard let existing = projection[id] else {
            return nil
        }
        let removed = hydrateContent(existing)
        let payload = BASMemoryAtomEventPayload(remove: id)
        do {
            _ = try await appendEventAndUpdateCache(
                payload: payload)
            contentCache.removeValue(forKey: id)
            return removed
        } catch {
            onSilentFailure?(error)   // audit memory-b F4: surface the write error (atom existed)
            return nil
        }
    }

    // MARK: - Parity surface (matches BASSQLiteMemoryAtomStore)

    /// Admit a new atom into the store。Returns true if the admit
    /// event was appended (the normal path);false only if the
    /// underlying event log reports the event was not new — i.e. its
    /// eventID already existed (idempotent-retry dedup)。Because each
    /// admit mints a fresh `UUID().uuidString` eventID, false is
    /// effectively unreachable in normal use and never signals a
    /// content/atom conflict。The M942 reducer's confidence tiebreak
    /// (BASMemoryAtomReducer) runs only inside the projection and does
    /// not influence this Bool。
    @discardableResult
    public func admit(
        _ atom: BASGovernedMemory
    ) async throws -> Bool {
        let key = atom.id.uuidString
        // audit memory-b F3: capture the CURRENT winner's confidence BEFORE the append. The M942
        // reducer keeps the HIGHER-confidence entry (ties go to the existing one). If this atom
        // does NOT strictly win, its content must NOT overwrite the winner's cached content —
        // otherwise atom(forID:) returns a winner-metadata + loser-content HYBRID.
        let priorConfidence = await currentProjection()[key]?.confidence
        let payload = BASMemoryAtomEventPayload(admitted: atom)
        let appended = try await appendEventAndUpdateCache(
            payload: payload)
        if appended, !atom.content.isEmpty {
            // Cache content for in-process content fidelity — ONLY when this atom won the reducer's
            // confidence tiebreak (no prior, or strictly higher confidence than the prior winner).
            if priorConfidence == nil || atom.confidence > priorConfidence! {
                contentCache[key] = atom.content
            }
        }
        return appended
    }

    /// Total atom count in the current projection。
    public var count: Int {
        get async {
            await currentProjection().count
        }
    }

    /// All atom IDs in the current projection。
    public var allIDs: Set<String> {
        get async {
            Set(await currentProjection().keys)
        }
    }

    /// All atoms in the current projection (with content
    /// hydrated from the in-process content cache where
    /// available)。
    public func allAtoms() async -> [BASGovernedMemory] {
        let projection = await currentProjection()
        return projection.values.map { hydrateContent($0) }
    }

    /// Diagnostic surface — full projection mapped by ID。
    public func projectAll() async
        -> [String: BASGovernedMemory]
    {
        let projection = await currentProjection()
        var hydrated: [String: BASGovernedMemory] = [:]
        for (id, atom) in projection {
            hydrated[id] = hydrateContent(atom)
        }
        return hydrated
    }

    /// Last sequence number this store observed。Used by
    /// tests + audit to verify monotonic progression。
    public var lastReplayedSequenceNumber: Int64? {
        lastSeq
    }
}
