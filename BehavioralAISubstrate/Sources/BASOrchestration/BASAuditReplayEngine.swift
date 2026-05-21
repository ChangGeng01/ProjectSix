// MARK: - BASAuditReplayEngine
// chapter 八百十六 / M2731-M2735 — audit replay loader
//
// Read-side counterpart to `BASAuditPipeline` (chapter 八百十五)。
// Where the pipeline writes records to 5 stores per turn,the
// replay engine reads ALL stores for a given session and bundles
// the results into one typed `SessionAuditTrail`。
//
// ## Why
//
// Hosts that want to:
//   - Resume audit state after process restart
//   - Build dashboards / debugging UIs over historical trails
//   - Diff two sessions (chapter 八百十七)
//   - Compact / archive older trails (chapter 八百十八)
//
// …all start by loading a `SessionAuditTrail`。 Centralizing the
// load + aggregate step here means hosts don't write the same
// per-store fetch + zip dance by hand。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — stores are unmodified;the engine
// just fetches via existing `records(forSession:)` APIs。
// ADR-014 OPT-IN — hosts call `loadSession(_:)` explicitly。
// Substrate default behavior unchanged。
//
// ## Layering
//
// L8 atom-lifecycle is fetched by sessionID (the store has a
// dedicated `events(forSession:)` query)。 L5 version tree
// fetched by vaultID (host must supply vaultID separately since
// versions are vault-scoped,not session-scoped)。

import Foundation
import BASMemory
import BASSovereign

public struct BASAuditReplayEngine: Sendable {

    public let presenceStore: BASPresenceObservationStore
    public let unknownStore: BASUnknownLedgerStore
    public let contradictionStore: BASContradictionLedgerStore
    public let atomLifecycleStore: BASAtomLifecycleStore
    public let versionTreeStore: BASHostConstitutionVersionTreeStore

    public init(
        presenceStore: BASPresenceObservationStore,
        unknownStore: BASUnknownLedgerStore,
        contradictionStore: BASContradictionLedgerStore,
        atomLifecycleStore: BASAtomLifecycleStore,
        versionTreeStore: BASHostConstitutionVersionTreeStore
    ) {
        self.presenceStore = presenceStore
        self.unknownStore = unknownStore
        self.contradictionStore = contradictionStore
        self.atomLifecycleStore = atomLifecycleStore
        self.versionTreeStore = versionTreeStore
    }

    // MARK: - SessionAuditTrail

    /// Snapshot of a session's full audit trail across all 5
    /// storage stores at the moment `loadSession` was called。
    /// Records arrive in insertion order per the underlying store
    /// query contract (ORDER BY timestamp ASC,rowid ASC)。
    public struct SessionAuditTrail: Sendable, Equatable, Codable {
        public let sessionID: String
        /// Optional vault ID (only populated when versions are loaded)。
        public let vaultID: String?
        public let presence: [BASPresenceObservationRecord]
        public let unknowns: [BASUnknownLedgerRecord]
        public let contradictions: [BASContradictionLedgerRecord]
        public let atomEvents: [BASAtomLifecycleEvent]
        public let versions: [BASHostConstitutionVersionRecord]

        public init(
            sessionID: String,
            vaultID: String?,
            presence: [BASPresenceObservationRecord],
            unknowns: [BASUnknownLedgerRecord],
            contradictions: [BASContradictionLedgerRecord],
            atomEvents: [BASAtomLifecycleEvent],
            versions: [BASHostConstitutionVersionRecord]
        ) {
            self.sessionID = sessionID
            self.vaultID = vaultID
            self.presence = presence
            self.unknowns = unknowns
            self.contradictions = contradictions
            self.atomEvents = atomEvents
            self.versions = versions
        }

        /// Total record count across all 5 stores。
        public var totalRecords: Int {
            presence.count + unknowns.count + contradictions.count
                + atomEvents.count + versions.count
        }

        /// Distinct turnIDs seen across L6/L7/L8 records。 L5
        /// versions are vault-scoped (no turnID) so excluded。
        public var distinctTurnIDs: Set<String> {
            var s: Set<String> = []
            for r in presence { s.insert(r.turnID) }
            for r in unknowns { s.insert(r.turnID) }
            for r in contradictions { s.insert(r.turnID) }
            for e in atomEvents {
                // L8 events don't carry a turnID column per
                // schema 023 — atoms can span turns。 Skipped。
                _ = e
            }
            return s
        }
    }

    // MARK: - loadSession

    /// Load the complete audit trail for a session。 Each store
    /// is queried via its existing `records(forSession:)` API。
    /// Returns a typed `SessionAuditTrail` snapshot。
    ///
    /// - Parameters:
    ///   - sessionID: foreign key shared across L6/L7/L8 stores
    ///   - vaultID: optional vault for L5 versions (versions are
    ///     vault-scoped,not session-scoped)。 When nil,the
    ///     returned trail's `versions` array is empty
    ///
    /// - Returns: `SessionAuditTrail` carrying every record
    ///   currently persisted under the given session/vault
    public func loadSession(
        sessionID: String,
        vaultID: String? = nil
    ) async -> SessionAuditTrail {
        let presence = await presenceStore.records(
            forSession: sessionID)
        let unknowns = await unknownStore.records(
            forSession: sessionID)
        let contradictions = await contradictionStore.records(
            forSession: sessionID)
        let atomEvents = await atomLifecycleStore.events(
            forSession: sessionID)
        var versions: [BASHostConstitutionVersionRecord] = []
        if let vault = vaultID {
            versions = await versionTreeStore.versions(
                forVault: vault)
        }
        return SessionAuditTrail(
            sessionID: sessionID,
            vaultID: vaultID,
            presence: presence,
            unknowns: unknowns,
            contradictions: contradictions,
            atomEvents: atomEvents,
            versions: versions)
    }

    /// Convenience that loads + immediately aggregates。 Bundles
    /// the chapter 八百十 summary primitives so hosts that just
    /// want「what happened in session X」 can get all 3 summaries
    /// in one call。
    public func loadAndSummarize(
        sessionID: String,
        vaultID: String? = nil
    ) async -> SessionAuditSummary {
        let trail = await loadSession(
            sessionID: sessionID, vaultID: vaultID)
        return SessionAuditSummary(
            trail: trail,
            presence: BASRoutedAuditAggregation.aggregatePresence(
                records: trail.presence, sessionID: sessionID),
            unknowns: BASRoutedAuditAggregation.aggregateUnknowns(
                records: trail.unknowns, sessionID: sessionID),
            contradictions: BASRoutedAuditAggregation
                .aggregateContradictions(
                    records: trail.contradictions,
                    sessionID: sessionID))
    }

    /// Bundle:trail + the 3 aggregation summaries。
    public struct SessionAuditSummary: Sendable, Equatable, Codable {
        public let trail: SessionAuditTrail
        public let presence: BASRoutedAuditAggregation.PresenceSessionSummary
        public let unknowns: BASRoutedAuditAggregation.UnknownSessionSummary
        public let contradictions: BASRoutedAuditAggregation.ContradictionSessionSummary

        public init(
            trail: SessionAuditTrail,
            presence: BASRoutedAuditAggregation.PresenceSessionSummary,
            unknowns: BASRoutedAuditAggregation.UnknownSessionSummary,
            contradictions: BASRoutedAuditAggregation.ContradictionSessionSummary
        ) {
            self.trail = trail
            self.presence = presence
            self.unknowns = unknowns
            self.contradictions = contradictions
        }
    }
}
