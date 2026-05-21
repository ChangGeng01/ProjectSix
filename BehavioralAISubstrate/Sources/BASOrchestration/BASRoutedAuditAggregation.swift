// MARK: - BASRoutedAuditAggregation
// chapter 八百十 / M2701-M2705 — per-session audit aggregation
//
// Consumer-side helpers that roll up persisted L6/L7 audit
// records into per-session summaries。 Pure functions over
// arrays of record types — work cross-platform,no Rust dep。
//
// ## Why
//
// Chapters 七百九十八 → 八百九 shipped the recorder + replay
// loop。 Hosts that want to USE the audit trail for analysis
// (dashboards,replay-driven diagnostics,session-level metrics)
// need roll-up primitives that don't force every host to write
// the same Group-By logic by hand。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — recorders + replay helpers
// unchanged。 Aggregators are NEW pure functions。 No
// production behavior touched。
//
// All aggregators take arrays of records (caller fetches from
// store with their session/turn filter of choice) and return
// strongly-typed summary structs。 No I/O,no async — they
// can be called from any context。

import Foundation
import BASSovereign

public enum BASRoutedAuditAggregation {

    // MARK: - L6 presence summary

    /// Roll-up of multi-turn L6 presence observations。 Fed to
    /// dashboards or replay-driven diagnostics。
    public struct PresenceSessionSummary: Sendable, Equatable {
        public let sessionID: String
        /// Total observation rows in the session (across all turns)。
        public let totalObservations: Int
        /// Distinct turn count seen in the session。
        public let turnCount: Int
        /// Average salience across ALL observations,unweighted。
        public let avgSalience: Double
        /// Average confidence across ALL observations,unweighted。
        public let avgConfidence: Double
        /// Per-channel-kind observation count。 Keyed by schema-013
        /// CHECK literal (task / risk / manipulation / environment /
        /// bodyRhythm)。 Channels with zero observations are omitted。
        public let observationCountByChannel: [String: Int]

        public init(
            sessionID: String,
            totalObservations: Int,
            turnCount: Int,
            avgSalience: Double,
            avgConfidence: Double,
            observationCountByChannel: [String: Int]
        ) {
            self.sessionID = sessionID
            self.totalObservations = totalObservations
            self.turnCount = turnCount
            self.avgSalience = avgSalience
            self.avgConfidence = avgConfidence
            self.observationCountByChannel = observationCountByChannel
        }
    }

    /// Build a `PresenceSessionSummary` from previously persisted
    /// `BASPresenceObservationRecord` rows。 Caller fetches via
    /// `BASPresenceObservationStore.records(forSession:)` then
    /// hands the array to this aggregator。
    ///
    /// Empty input yields a zero-summary (totalObservations=0,
    /// turnCount=0,both averages 0)。
    public static func aggregatePresence(
        records: [BASPresenceObservationRecord],
        sessionID: String
    ) -> PresenceSessionSummary {
        if records.isEmpty {
            return PresenceSessionSummary(
                sessionID: sessionID,
                totalObservations: 0,
                turnCount: 0,
                avgSalience: 0,
                avgConfidence: 0,
                observationCountByChannel: [:])
        }
        var sumSalience = 0.0
        var sumConfidence = 0.0
        var turnSet: Set<String> = []
        var perChannel: [String: Int] = [:]
        for r in records {
            sumSalience += r.salience
            sumConfidence += r.confidence
            turnSet.insert(r.turnID)
            perChannel[r.channelKind, default: 0] += 1
        }
        let n = Double(records.count)
        return PresenceSessionSummary(
            sessionID: sessionID,
            totalObservations: records.count,
            turnCount: turnSet.count,
            avgSalience: sumSalience / n,
            avgConfidence: sumConfidence / n,
            observationCountByChannel: perChannel)
    }

    // MARK: - L7 unknown summary

    /// Roll-up of multi-turn L7 unknown records。 Categories
    /// match the chapter 七百九十九 prefix encoding (fact /
    /// role / constraint / permission / ambiguity)。
    public struct UnknownSessionSummary: Sendable, Equatable {
        public let sessionID: String
        public let totalRecords: Int
        public let turnCount: Int
        public let factCount: Int
        public let roleCount: Int
        public let constraintCount: Int
        public let permissionCount: Int
        public let ambiguityCount: Int
        /// Records whose prefix didn't match any of the 5 known
        /// kinds — defensive bucket。 Should be 0 for healthy data。
        public let unparseableCount: Int

        public init(
            sessionID: String,
            totalRecords: Int,
            turnCount: Int,
            factCount: Int,
            roleCount: Int,
            constraintCount: Int,
            permissionCount: Int,
            ambiguityCount: Int,
            unparseableCount: Int
        ) {
            self.sessionID = sessionID
            self.totalRecords = totalRecords
            self.turnCount = turnCount
            self.factCount = factCount
            self.roleCount = roleCount
            self.constraintCount = constraintCount
            self.permissionCount = permissionCount
            self.ambiguityCount = ambiguityCount
            self.unparseableCount = unparseableCount
        }
    }

    /// Count L7 unknown records by prefix kind across the session。
    public static func aggregateUnknowns(
        records: [BASUnknownLedgerRecord],
        sessionID: String
    ) -> UnknownSessionSummary {
        var counts = [
            "fact": 0, "role": 0, "constraint": 0,
            "permission": 0, "ambiguity": 0,
        ]
        var unparseable = 0
        var turnSet: Set<String> = []
        for r in records {
            turnSet.insert(r.turnID)
            if let kind = prefixKind(of: r.unknownText) {
                counts[kind, default: 0] += 1
            } else {
                unparseable += 1
            }
        }
        return UnknownSessionSummary(
            sessionID: sessionID,
            totalRecords: records.count,
            turnCount: turnSet.count,
            factCount: counts["fact"] ?? 0,
            roleCount: counts["role"] ?? 0,
            constraintCount: counts["constraint"] ?? 0,
            permissionCount: counts["permission"] ?? 0,
            ambiguityCount: counts["ambiguity"] ?? 0,
            unparseableCount: unparseable)
    }

    /// Extract the prefix kind from an `unknownText` field。
    /// Returns nil for unparseable rows (defensive)。
    private static func prefixKind(of text: String) -> String? {
        for kind in ["fact", "role", "constraint",
                     "permission", "ambiguity"] {
            if text.hasPrefix("\(kind): ") {
                return kind
            }
        }
        return nil
    }

    // MARK: - L7 contradiction summary

    /// Roll-up of multi-turn L7 contradiction records。
    public struct ContradictionSessionSummary:
        Sendable, Equatable
    {
        public let sessionID: String
        public let totalRecords: Int
        public let resolvedCount: Int
        public let unresolvedCount: Int
        /// Max salience observed in the session (0 if empty)。
        public let maxSalience: Double
        /// Mean salience across all rows (0 if empty)。
        public let avgSalience: Double

        public init(
            sessionID: String,
            totalRecords: Int,
            resolvedCount: Int,
            unresolvedCount: Int,
            maxSalience: Double,
            avgSalience: Double
        ) {
            self.sessionID = sessionID
            self.totalRecords = totalRecords
            self.resolvedCount = resolvedCount
            self.unresolvedCount = unresolvedCount
            self.maxSalience = maxSalience
            self.avgSalience = avgSalience
        }
    }

    public static func aggregateContradictions(
        records: [BASContradictionLedgerRecord],
        sessionID: String
    ) -> ContradictionSessionSummary {
        if records.isEmpty {
            return ContradictionSessionSummary(
                sessionID: sessionID,
                totalRecords: 0,
                resolvedCount: 0,
                unresolvedCount: 0,
                maxSalience: 0,
                avgSalience: 0)
        }
        var sumSalience = 0.0
        var maxSalience = 0.0
        var resolved = 0
        var unresolved = 0
        for r in records {
            sumSalience += r.salience
            maxSalience = max(maxSalience, r.salience)
            if r.resolved { resolved += 1 } else { unresolved += 1 }
        }
        return ContradictionSessionSummary(
            sessionID: sessionID,
            totalRecords: records.count,
            resolvedCount: resolved,
            unresolvedCount: unresolved,
            maxSalience: maxSalience,
            avgSalience: sumSalience / Double(records.count))
    }
}
