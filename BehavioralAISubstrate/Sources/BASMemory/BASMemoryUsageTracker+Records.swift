// MARK: - BASMemoryUsageTracker value types (usage record · replay/audit log · WAL · summaries)
// chapter 一千〇四十 / WS-backlog-decomp — relocated from BASMemoryUsageTracker.swift (god-object split).
// Pure top-level value types; same module + names ⇒ byte-equal, call sites unchanged.

import Foundation
import SQLite3
import BASRuntimeCore

/// One retrieval event. Append-only log row produced by the L8
/// recall path; consumed by `BASMemoryImportanceScorer` (chapter
/// 二百五十二) when computing per-atom importance scores.
public struct BASMemoryUsageRecord: BASSchemaVersioned,
    Sendable, Equatable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public enum HelpedFlag: String, Codable, Sendable, Hashable {
        /// Default — recall logged, no post-LLM signal yet.
        case unknown
        /// Post-LLM signal: the response did reference / depend
        /// on this atom.
        case helped
        /// Post-LLM signal: the response did not use this atom
        /// (or actively flagged it as unhelpful).
        case notHelped
    }

    public var schemaVersion: String
    public let recordID: String
    public let atomID: String
    public let retrievedAt: Date
    public let sessionRef: String
    public let turnRef: String
    public let permitMode: String
    public var helpedFlag: HelpedFlag

    public init(
        schemaVersion: String =
            BASMemoryUsageRecord.currentSchemaVersion,
        recordID: String? = nil,
        atomID: String,
        retrievedAt: Date = Date(),
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        helpedFlag: HelpedFlag = .unknown
    ) {
        self.schemaVersion = schemaVersion
        self.recordID = recordID ?? UUID().uuidString
        self.atomID = atomID
        self.retrievedAt = retrievedAt
        self.sessionRef = sessionRef
        self.turnRef = turnRef
        self.permitMode = permitMode
        self.helpedFlag = helpedFlag
    }
}

/// 主线 SQL ReplayLog 抽取 — Codable append-only event。
/// Stored in `memory_usage_replay_log` table。 Each
/// entry captures an input event suitable for
/// deterministic replay。
public struct BASReplayLogEntry: Codable, Equatable,
    Sendable, Hashable
{
    public let eventID: String
    public let eventType: String
    public let payload: String
    public let recordedAtMs: Int64

    public init(
        eventID: String,
        eventType: String,
        payload: String,
        recordedAtMs: Int64
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.payload = payload
        self.recordedAtMs = recordedAtMs
    }
}

/// 主线 SQL AuditLog 抽取 — Codable append-only audit
/// entry。 Stored in `memory_usage_audit_log` table。
/// Distinct from replay log — captures observability /
/// compliance events,not user-input events。
public struct BASAuditLogEntry: Codable, Equatable,
    Sendable, Hashable
{
    public let entryID: String
    public let actor: String
    public let action: String
    public let detail: String
    public let recordedAtMs: Int64

    public init(
        entryID: String,
        actor: String,
        action: String,
        detail: String,
        recordedAtMs: Int64
    ) {
        self.entryID = entryID
        self.actor = actor
        self.action = action
        self.detail = detail
        self.recordedAtMs = recordedAtMs
    }
}

/// 主线 SQL 硬核 — Codable WAL checkpoint result as
/// produced by `BASMemoryUsageTracker.checkpointWAL()`。
/// Three integers per `PRAGMA wal_checkpoint(TRUNCATE)`
/// row。
public struct BASWALCheckpointResult: Codable,
    Equatable, Sendable, Hashable
{
    /// 1 if the checkpoint was blocked by another reader,
    /// 0 otherwise。
    public let busy: Int

    /// Size of the WAL log in pages BEFORE the
    /// checkpoint。 Hosts use this to size dashboards
    /// for WAL growth。
    public let logPages: Int

    /// Pages successfully checkpointed (i.e. flushed
    /// from WAL to main DB)。
    public let checkpointed: Int

    public init(
        busy: Int, logPages: Int, checkpointed: Int
    ) {
        self.busy = busy
        self.logPages = logPages
        self.checkpointed = checkpointed
    }

    /// True when every page in the WAL was successfully
    /// flushed during this checkpoint (busy == 0 AND
    /// checkpointed == logPages)。
    public var isFullyFlushed: Bool {
        return busy == 0
            && checkpointed == logPages
    }
}

/// 主线 SQL Bundle 抽取 — Codable summary of one
/// memory_usage_bundles group。 Returned by
/// `BASMemoryUsageTracker.bundleSummariesViaSQL()`。
public struct BASBundleSummary: Codable, Equatable,
    Sendable, Hashable
{
    /// UUID-style bundle identifier。
    public let bundleID: String

    /// Number of records contained in this bundle。
    public let recordCount: Int

    /// Epoch milliseconds of bundle creation。 Bundles
    /// are immutable once created — this stamp doesn't
    /// move。
    public let createdAtMs: Int64

    public init(
        bundleID: String,
        recordCount: Int,
        createdAtMs: Int64
    ) {
        self.bundleID = bundleID
        self.recordCount = recordCount
        self.createdAtMs = createdAtMs
    }
}

/// 主线 SQL Episode 抽取 — Codable summary of one
/// distinct session's record sequence as produced by
/// `BASMemoryUsageTracker.episodeSummariesViaSQL()`。
/// Each row corresponds to one `GROUP BY session_ref`
/// row from native SQL。
public struct BASEpisodeSummary: Codable, Equatable,
    Sendable, Hashable
{
    /// Session identifier — same value across all
    /// records belonging to this episode。
    public let sessionRef: String

    /// Number of records in this session。
    public let recordCount: Int

    /// Epoch milliseconds of the FIRST retrieval in
    /// this session (= MIN(retrieved_at_ms))。
    public let startMs: Int64

    /// Epoch milliseconds of the LAST retrieval in
    /// this session (= MAX(retrieved_at_ms))。
    public let endMs: Int64

    public init(
        sessionRef: String,
        recordCount: Int,
        startMs: Int64,
        endMs: Int64
    ) {
        self.sessionRef = sessionRef
        self.recordCount = recordCount
        self.startMs = startMs
        self.endMs = endMs
    }

    /// Convenience:duration of this episode in
    /// seconds。 0 for single-record episodes (start
    /// == end)。
    public var durationSeconds: Double {
        return Double(endMs - startMs) / 1000.0
    }
}
