// MARK: - BASAuditTrailArchive
// chapter 八百十八 / M2741-M2745 — audit trail archival / compaction
//
// Pure-fn helpers that compress a `SessionAuditTrail` (chapter
// 八百十六) into a compact `ArchivedSlice` — one row per
// (sessionID,turnID) carrying aggregate-level information for
// long-running hosts that need to bound on-device storage。
//
// ## Why
//
// Production hosts running 1000+ sessions/day on watchOS or
// iOS have a real budget for SQLite ledger size。 The chapter
// 八百三 measurement showed:
//
//   - L8 atom-lifecycle:   ~140 bytes/event raw
//   - L7 unknown-ledger:   ~150 bytes/record raw
//   - L7 contradiction:    ~180 bytes/record raw
//   - L6 presence:         ~120 bytes/observation raw
//   - L5 version:          ~200 bytes/version + 32-byte BLOB
//
// A 100-turn × 9-record/turn session (chapter 八百十三 stress)
// is ~900 records × ~150 bytes ≈ 135 KB on disk。 Reasonable
// for one session,not reasonable for 1000+。
//
// Archival reduces this to ONE summary row per turn (or even
// per session) for trails older than a configurable cutoff。
//
// ## What's preserved vs lost
//
// PRESERVED in archive:
//   - turnID identity (caller can replay per-turn at coarse grain)
//   - per-channel observation count + avg salience+confidence
//   - unknown-kind counts (fact/role/etc.)
//   - resolved/unresolved contradiction split + max severity
//   - atom transition count + count by outcome
//   - first / last timestamp in the turn
//
// LOST in archive:
//   - individual event_ids (gone — replay-to-exact-state no
//     longer possible from archive alone)
//   - specific unknown texts (gone)
//   - specific contradiction summaries (gone)
//
// Hosts wanting full fidelity must retain the raw audit trail
// for the desired retention window (TTL = host policy)。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — no store touched。 Archive is
// PURE — produces a new typed `ArchivedTrail` value;does NOT
// mutate any underlying store。 Hosts that want to actually
// DELETE archived rows must implement their own purge against
// the stores (out of scope for this chapter — chapter 七百六十九
// deletion-manifest pattern applies)。

import Foundation
import BASMemory
import BASSovereign

public enum BASAuditTrailArchive {

    // MARK: - ArchivedTurn record

    /// Compressed summary for one turn — replaces N raw records
    /// with one aggregate row per dimension。
    public struct ArchivedTurn: Sendable, Equatable {
        public let sessionID: String
        public let turnID: String
        public let firstTimestampMs: Int64
        public let lastTimestampMs: Int64

        // L6 presence summary for the turn
        public let presenceObservationCount: Int
        public let presenceAvgSalience: Double
        public let presenceAvgConfidence: Double
        public let presenceCountByChannel: [String: Int]

        // L7 unknown summary for the turn
        public let unknownFactCount: Int
        public let unknownRoleCount: Int
        public let unknownConstraintCount: Int
        public let unknownPermissionCount: Int
        public let unknownAmbiguityCount: Int

        // L7 contradiction summary for the turn
        public let contradictionTotal: Int
        public let contradictionResolved: Int
        public let contradictionMaxSalience: Double

        // L8 atom summary for the turn (NOTE: L8 events don't
        // carry a turnID column;they are summarized SEPARATELY
        // at the session level in `ArchivedTrail`)。

        public init(
            sessionID: String,
            turnID: String,
            firstTimestampMs: Int64,
            lastTimestampMs: Int64,
            presenceObservationCount: Int,
            presenceAvgSalience: Double,
            presenceAvgConfidence: Double,
            presenceCountByChannel: [String: Int],
            unknownFactCount: Int,
            unknownRoleCount: Int,
            unknownConstraintCount: Int,
            unknownPermissionCount: Int,
            unknownAmbiguityCount: Int,
            contradictionTotal: Int,
            contradictionResolved: Int,
            contradictionMaxSalience: Double
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.firstTimestampMs = firstTimestampMs
            self.lastTimestampMs = lastTimestampMs
            self.presenceObservationCount = presenceObservationCount
            self.presenceAvgSalience = presenceAvgSalience
            self.presenceAvgConfidence = presenceAvgConfidence
            self.presenceCountByChannel = presenceCountByChannel
            self.unknownFactCount = unknownFactCount
            self.unknownRoleCount = unknownRoleCount
            self.unknownConstraintCount = unknownConstraintCount
            self.unknownPermissionCount = unknownPermissionCount
            self.unknownAmbiguityCount = unknownAmbiguityCount
            self.contradictionTotal = contradictionTotal
            self.contradictionResolved = contradictionResolved
            self.contradictionMaxSalience = contradictionMaxSalience
        }
    }

    // MARK: - ArchivedTrail (session-scoped wrapper)

    /// Whole-session archive。 Contains per-turn rows + session-
    /// level L8 atom + L5 version summaries (which aren't
    /// turn-keyed)。
    public struct ArchivedTrail: Sendable, Equatable {
        public let sessionID: String
        public let turns: [ArchivedTurn]
        public let atomEventCount: Int
        /// Count by outcome: 0=advanced / 1=rejected_illegal /
        /// 2=rejected_terminal
        public let atomOutcomeCounts: [Int32: Int]
        public let versionCount: Int
        public let rollbackVersionCount: Int

        public init(
            sessionID: String,
            turns: [ArchivedTurn],
            atomEventCount: Int,
            atomOutcomeCounts: [Int32: Int],
            versionCount: Int,
            rollbackVersionCount: Int
        ) {
            self.sessionID = sessionID
            self.turns = turns
            self.atomEventCount = atomEventCount
            self.atomOutcomeCounts = atomOutcomeCounts
            self.versionCount = versionCount
            self.rollbackVersionCount = rollbackVersionCount
        }

        /// Total turn count in the archive。
        public var turnCount: Int { turns.count }
    }

    // MARK: - Archive function

    /// Compress a `SessionAuditTrail` (chapter 八百十六) into
    /// an `ArchivedTrail`。 Pure function — does not touch any
    /// underlying store。
    public static func archive(
        trail: BASAuditReplayEngine.SessionAuditTrail
    ) -> ArchivedTrail {
        // Group L6/L7 records by turnID
        var turnsByID: [String: TurnAccumulator] = [:]
        for r in trail.presence {
            turnsByID[r.turnID, default: .init(
                sessionID: trail.sessionID,
                turnID: r.turnID)
            ].addPresence(r)
        }
        for r in trail.unknowns {
            turnsByID[r.turnID, default: .init(
                sessionID: trail.sessionID,
                turnID: r.turnID)
            ].addUnknown(r)
        }
        for r in trail.contradictions {
            turnsByID[r.turnID, default: .init(
                sessionID: trail.sessionID,
                turnID: r.turnID)
            ].addContradiction(r)
        }
        let turns = turnsByID.values
            .map { $0.snapshot() }
            .sorted { lhs, rhs in
                if lhs.firstTimestampMs != rhs.firstTimestampMs {
                    return lhs.firstTimestampMs < rhs.firstTimestampMs
                }
                return lhs.turnID < rhs.turnID
            }

        // Atom summary (session-scoped)
        var outcomeCounts: [Int32: Int] = [:]
        for e in trail.atomEvents {
            outcomeCounts[e.outcome, default: 0] += 1
        }

        // Version summary
        let rollbackCount = trail.versions
            .filter { $0.isRollbackPoint }.count

        return ArchivedTrail(
            sessionID: trail.sessionID,
            turns: turns,
            atomEventCount: trail.atomEvents.count,
            atomOutcomeCounts: outcomeCounts,
            versionCount: trail.versions.count,
            rollbackVersionCount: rollbackCount)
    }

    // MARK: - Accumulator (private)

    private struct TurnAccumulator {
        let sessionID: String
        let turnID: String
        var firstMs: Int64 = .max
        var lastMs: Int64 = .min

        var presenceCount: Int = 0
        var presenceSalienceSum: Double = 0
        var presenceConfidenceSum: Double = 0
        var perChannel: [String: Int] = [:]

        var factCount: Int = 0
        var roleCount: Int = 0
        var constraintCount: Int = 0
        var permissionCount: Int = 0
        var ambiguityCount: Int = 0

        var contradictionTotal: Int = 0
        var contradictionResolved: Int = 0
        var contradictionMaxSalience: Double = 0

        mutating func addPresence(
            _ r: BASPresenceObservationRecord
        ) {
            presenceCount += 1
            presenceSalienceSum += r.salience
            presenceConfidenceSum += r.confidence
            perChannel[r.channelKind, default: 0] += 1
            updateTimestamps(r.observedAtMs)
        }

        mutating func addUnknown(
            _ r: BASUnknownLedgerRecord
        ) {
            if r.unknownText.hasPrefix("fact: ") {
                factCount += 1
            } else if r.unknownText.hasPrefix("role: ") {
                roleCount += 1
            } else if r.unknownText.hasPrefix("constraint: ") {
                constraintCount += 1
            } else if r.unknownText.hasPrefix("permission: ") {
                permissionCount += 1
            } else if r.unknownText.hasPrefix("ambiguity: ") {
                ambiguityCount += 1
            }
            updateTimestamps(r.discoveredAtMs)
        }

        mutating func addContradiction(
            _ r: BASContradictionLedgerRecord
        ) {
            contradictionTotal += 1
            if r.resolved { contradictionResolved += 1 }
            if r.salience > contradictionMaxSalience {
                contradictionMaxSalience = r.salience
            }
            if let resolved = r.resolvedAtMs {
                updateTimestamps(resolved)
            }
        }

        private mutating func updateTimestamps(_ ms: Int64) {
            firstMs = min(firstMs, ms)
            lastMs = max(lastMs, ms)
        }

        func snapshot() -> ArchivedTurn {
            let n = max(presenceCount, 1)
            let avgSal = presenceSalienceSum / Double(n)
            let avgCon = presenceConfidenceSum / Double(n)
            // If NO presence rows,zero avg
            let finalAvgSal = presenceCount > 0 ? avgSal : 0
            let finalAvgCon = presenceCount > 0 ? avgCon : 0
            return ArchivedTurn(
                sessionID: sessionID,
                turnID: turnID,
                firstTimestampMs: firstMs == .max ? 0 : firstMs,
                lastTimestampMs: lastMs == .min ? 0 : lastMs,
                presenceObservationCount: presenceCount,
                presenceAvgSalience: finalAvgSal,
                presenceAvgConfidence: finalAvgCon,
                presenceCountByChannel: perChannel,
                unknownFactCount: factCount,
                unknownRoleCount: roleCount,
                unknownConstraintCount: constraintCount,
                unknownPermissionCount: permissionCount,
                unknownAmbiguityCount: ambiguityCount,
                contradictionTotal: contradictionTotal,
                contradictionResolved: contradictionResolved,
                contradictionMaxSalience: contradictionMaxSalience)
        }
    }
}
