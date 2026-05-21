// MARK: - BASAuditTrailDiff
// chapter 八百十七 / M2736-M2740 — cross-session audit diff
//
// Pure-fn helpers that compute typed delta between two
// `BASAuditReplayEngine.SessionAuditTrail` snapshots。 Per-store
// added / removed sets keyed by event/version ID。
//
// ## Use cases
//
// - Diagnose「what changed between session A and session B」 in
//   audit dashboards / debug UIs
// - Verify post-replay state matches pre-replay state (round-
//   trip identity check at the audit-trail level)
// - Detect dropped or duplicated rows during sync between
//   on-device and cloud replicas
//
// ## Semantics
//
// All diffs are SET-BASED keyed by the record's primary ID:
//   - L6 presence:eventID
//   - L7 unknown:eventID
//   - L7 contradiction:eventID
//   - L8 atom:eventID
//   - L5 version:versionID
//
// A record present in BOTH trails counts as unchanged regardless
// of payload identity。 Hosts that want byte-identity comparison
// can iterate `unchanged` IDs and compare records directly。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — no store touched。 Pure functions
// over already-loaded trails。 ADR-014 OPT-IN — hosts opt into
// diff by calling these helpers。

import Foundation
import BASMemory
import BASSovereign

public enum BASAuditTrailDiff {

    // MARK: - Per-store ID delta

    /// Set-based ID delta:`added` IDs are in `current` but not
    /// `baseline`,`removed` IDs are in `baseline` but not
    /// `current`,`unchanged` IDs are in BOTH。
    public struct IDDelta: Sendable, Equatable {
        public let added: Set<String>
        public let removed: Set<String>
        public let unchanged: Set<String>

        public init(
            added: Set<String>,
            removed: Set<String>,
            unchanged: Set<String>
        ) {
            self.added = added
            self.removed = removed
            self.unchanged = unchanged
        }

        /// True iff added + removed are both empty (regardless
        /// of payload diffs within unchanged IDs)。
        public var isIdentitySet: Bool {
            added.isEmpty && removed.isEmpty
        }
    }

    /// Per-store ID deltas wrapped together for a full
    /// `SessionAuditTrail` diff。
    public struct SessionDelta: Sendable, Equatable {
        public let baselineSessionID: String
        public let currentSessionID: String
        public let presence: IDDelta
        public let unknowns: IDDelta
        public let contradictions: IDDelta
        public let atomEvents: IDDelta
        public let versions: IDDelta

        public init(
            baselineSessionID: String,
            currentSessionID: String,
            presence: IDDelta,
            unknowns: IDDelta,
            contradictions: IDDelta,
            atomEvents: IDDelta,
            versions: IDDelta
        ) {
            self.baselineSessionID = baselineSessionID
            self.currentSessionID = currentSessionID
            self.presence = presence
            self.unknowns = unknowns
            self.contradictions = contradictions
            self.atomEvents = atomEvents
            self.versions = versions
        }

        /// True iff every per-store delta has empty added +
        /// removed (i.e。 trails carry the SAME set of IDs across
        /// every store)。
        public var trailsHaveIdenticalIDSets: Bool {
            return presence.isIdentitySet
                && unknowns.isIdentitySet
                && contradictions.isIdentitySet
                && atomEvents.isIdentitySet
                && versions.isIdentitySet
        }

        /// Total IDs added across all 5 stores。
        public var totalAdded: Int {
            presence.added.count + unknowns.added.count
                + contradictions.added.count
                + atomEvents.added.count + versions.added.count
        }

        /// Total IDs removed across all 5 stores。
        public var totalRemoved: Int {
            presence.removed.count + unknowns.removed.count
                + contradictions.removed.count
                + atomEvents.removed.count + versions.removed.count
        }
    }

    // MARK: - Diff functions

    /// Diff two `SessionAuditTrail` snapshots。 Returns a typed
    /// `SessionDelta` carrying per-store added/removed/unchanged
    /// ID sets。
    public static func diff(
        baseline: BASAuditReplayEngine.SessionAuditTrail,
        current: BASAuditReplayEngine.SessionAuditTrail
    ) -> SessionDelta {
        return SessionDelta(
            baselineSessionID: baseline.sessionID,
            currentSessionID: current.sessionID,
            presence: diffIDs(
                baseline: baseline.presence.map { $0.eventID },
                current: current.presence.map { $0.eventID }),
            unknowns: diffIDs(
                baseline: baseline.unknowns.map { $0.eventID },
                current: current.unknowns.map { $0.eventID }),
            contradictions: diffIDs(
                baseline: baseline.contradictions.map { $0.eventID },
                current: current.contradictions.map { $0.eventID }),
            atomEvents: diffIDs(
                baseline: baseline.atomEvents.map { $0.eventID },
                current: current.atomEvents.map { $0.eventID }),
            versions: diffIDs(
                baseline: baseline.versions.map { $0.versionID },
                current: current.versions.map { $0.versionID }))
    }

    /// Compute set-based delta between two ID lists。 Order-
    /// insensitive。 Duplicates within an input collapse to one
    /// entry per Set semantics。
    public static func diffIDs(
        baseline: [String],
        current: [String]
    ) -> IDDelta {
        let bSet = Set(baseline)
        let cSet = Set(current)
        return IDDelta(
            added: cSet.subtracting(bSet),
            removed: bSet.subtracting(cSet),
            unchanged: bSet.intersection(cSet))
    }

    /// Convenience:given a `SessionDelta`,return a flat array
    /// of human-readable change lines。 Useful for log output。
    /// Order:presence → unknowns → contradictions → atom → version。
    public static func summaryLines(
        _ delta: SessionDelta
    ) -> [String] {
        var lines: [String] = []
        func addBlock(name: String, ids: IDDelta) {
            if ids.isIdentitySet { return }
            if !ids.added.isEmpty {
                lines.append("[\(name)] added \(ids.added.count): " +
                    ids.added.sorted().joined(separator: ", "))
            }
            if !ids.removed.isEmpty {
                lines.append("[\(name)] removed \(ids.removed.count): " +
                    ids.removed.sorted().joined(separator: ", "))
            }
        }
        addBlock(name: "presence", ids: delta.presence)
        addBlock(name: "unknowns", ids: delta.unknowns)
        addBlock(name: "contradictions", ids: delta.contradictions)
        addBlock(name: "atomEvents", ids: delta.atomEvents)
        addBlock(name: "versions", ids: delta.versions)
        return lines
    }
}
