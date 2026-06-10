// MARK: - BASSQLBrainHistoryStore
// SQL pilot integration:wraps BASMemoryUsageTracker
// (chapter 702 SQL pilot) for SQLite-backed history of
// brain summary() calls。
//
// Each brain.summary() call optionally writes one
// BASMemoryUsageRecord via BASMemoryUsageTracker:
//
//   - atomID:     SHA256-prefix hex of input (deterministic
//                 → same input collapses to same atomID)
//   - sessionRef: brain instance UUID
//   - turnRef:    monotonic per-brain turn counter
//   - permitMode: summary.safetyVerdict.rawValue
//                 (\"safe\" / \"warn\" / \"block\")
//
// **Why use BASMemoryUsageTracker**: this is the literal SQL
// pilot from chapter 702 (M2171-M2174). Before this commit
// it had no real consumer in the cognitive brain — just a
// pilot existence。 After this commit, real Swift→SQLite
// inserts happen on every brain.summary() call when the
// store is wired in。
//
// **Honest scope acknowledgments**:
//   - SQL pilot's schema is for *memory atom* usage tracking,
//     not arbitrary KV persistence。 The mapping
//     (input → atomID via hash) fits the schema but isn't
//     a perfect semantic match — a typed-summary table
//     would be a separate Phase D-real artifact。
//   - helpedFlag stays .unknown (no post-LLM feedback path
//     wired yet — host integration may call markHelped()
//     later via the underlying tracker)
//   - Persistence requires the host to construct the brain
//     with a non-nil databaseURL; in-memory mode loses
//     history on brain dealloc

import Foundation
import BASMemory
import CryptoKit

/// SQL-backed brain summary history store。 Wraps the
/// chapter 702 SQL pilot (BASMemoryUsageTracker)。
public actor BASSQLBrainHistoryStore {

    /// Stable session identifier for all records appended
    /// during this brain instance's lifetime。 New UUID
    /// per init so cross-instance queries can separate
    /// runs。
    public let sessionRef: String

    /// Monotonic turn counter。 Starts at 0,increments on
    /// every `recordSummary(_:)` call。
    private var turnCounter: Int = 0

    private let tracker: BASMemoryUsageTracker

    /// Sentinel value for permitMode when no safety
    /// verdict is available (defensive default — should
    /// not occur on the brain summary path)。
    public static let unknownPermitMode: String = "unknown"

    /// Deterministic hash function for atomID derivation。
    /// SHA256-prefix hex (first 16 chars = first 8 bytes
    /// of SHA256)。 Same input → same atomID,enabling
    /// `usageCount(forAtomID:)` queries from the underlying
    /// tracker。
    ///
    /// 主线 解构:delegates to `BASBrainHistoryAtomID.derive`
    /// — the canonical single source of truth shared with
    /// the Rust history store。 Cross-store joins on
    /// atomID remain byte-equal by construction。
    public static func atomID(forInput input: String)
        -> String
    {
        return BASBrainHistoryAtomID.derive(
            forInput: input)
    }

    public init(tracker: BASMemoryUsageTracker) {
        self.tracker = tracker
        self.sessionRef = UUID().uuidString
    }

    /// Persist one brain summary as a memory-atom usage
    /// record。 Returns the underlying tracker's recordID
    /// for later `markHelped()` calls。
    ///
    /// `retrievedAt` allows the caller to thread a single
    /// timestamp into BOTH the SQL store + Rust store (chapter
    /// 七百五十七 第四刀 / M2440) so that cross-store
    /// `recentRecords(limit:)` ordering matches by construction
    /// — without this,SQL.tracker stamps a Swift `Date()` and
    /// Rust.tracker stamps a Rust `SystemTime` for the SAME
    /// summary,which can disagree under clock skew,causing
    /// the atomID-parity smoke test to flake。 Default keeps
    /// V1 callers (single-store hosts) on auto-stamped Date()。
    @discardableResult
    public func recordSummary(
        _ summary: BASCognitiveBrainSummary,
        retrievedAt: Date = Date()
    ) async throws -> String {
        turnCounter += 1
        let atomID = Self.atomID(
            forInput: summary.input)
        return try await tracker.record(
            atomID: atomID,
            sessionRef: sessionRef,
            turnRef: String(turnCounter),
            permitMode: summary.safetyVerdict.rawValue,
            retrievedAt: retrievedAt)
    }

    /// Total persisted records (any session) seen by the
    /// underlying tracker。
    public var recordCount: Int {
        get async { await tracker.recordCount }
    }

    /// Number of distinct turns recorded by THIS brain
    /// instance (i.e. since `init`)。 Differs from
    /// `recordCount` when the host pre-populated the
    /// tracker with prior-session data。
    public var turnsThisSession: Int {
        return turnCounter
    }

    /// Read the N most-recent records from the tracker
    /// (across all sessions)。 Newest first by retrievedAt
    /// timestamp,with `turnRef` as a DETERMINISTIC tiebreaker。
    ///
    /// The tiebreaker (M2440 第五刀 / cross-store flake fix)
    /// MUST match `BASRustBrainHistoryStore.recentRecords` so
    /// the two backends agree on "most recent" for the same
    /// summary set。 Both store `retrieved_at_ms` at
    /// MILLISECOND resolution,so two summaries in the same
    /// millisecond tie; the bare `retrievedAt`-only sort is
    /// unstable on the tie and can disagree across stores —
    /// the intermittent `atomID`-parity smoke-test flake。
    /// `turnRef` is the per-brain monotonic counter threaded
    /// identically into both stores,so `(retrievedAt, turnRef)`
    /// is deterministic and store-identical。
    public func recentRecords(
        limit: Int
    ) async -> [BASMemoryUsageRecord] {
        let all = await tracker.allRecords()
        let sorted = all.sorted {
            $0.retrievedAt != $1.retrievedAt
                ? $0.retrievedAt > $1.retrievedAt
                : (Int($0.turnRef) ?? 0) > (Int($1.turnRef) ?? 0)
        }
        let take = min(max(0, limit), sorted.count)
        return Array(sorted.prefix(take))
    }

    /// Count how many times a given input has been seen
    /// (across all sessions) per the SQL pilot's
    /// usageCount API。 Useful for deduplication +
    /// "how often does this manipulation attempt repeat"
    /// telemetry。
    public func usageCount(
        forInput input: String
    ) async -> Int {
        let atomID = Self.atomID(forInput: input)
        return await tracker
            .usageCount(forAtomID: atomID)
    }

    // MARK: - 主线 全面 提升: native SQL query surfaces

    /// True when the underlying tracker has a SQLite database
    /// handle。 Hosts can use this to decide whether queries via
    /// `recentRecordsViaSQL` / `permitModeDistribution` will hit
    /// the storage engine (true) or fall back to a Swift fold
    /// over the in-memory cache (false)。
    public var isSQLBacked: Bool {
        get async { await tracker.isSQLBacked }
    }

    /// Read the N most-recent records via a native SQLite
    /// `ORDER BY retrieved_at_ms DESC LIMIT ?` query when the
    /// tracker is SQLite-backed。 Falls back to Swift fold when
    /// the tracker is in-memory only。 Both paths return
    /// logically identical results。
    ///
    /// Differs from `recentRecords(limit:)` (the legacy Swift-
    /// fold path) by pushing the ordering + limit into the
    /// storage engine。 Use this when running against large
    /// SQLite-backed corpora where you don't want the full
    /// record set materialized in Swift。
    public func recentRecordsViaSQL(
        limit: Int
    ) async throws -> [BASMemoryUsageRecord] {
        return try await tracker.recentRecordsViaSQL(
            limit: limit)
    }

    /// Record counts grouped by permit mode (safety verdict)。
    /// When SQLite-backed,uses a native `GROUP BY permit_mode`
    /// aggregation query。 When in-memory,folds over the cache。
    ///
    /// Hosts use this for safety-dashboard rollups。 Mirrors the
    /// equivalent surface on BASRustBrainHistoryStore so dashboards
    /// can switch between SQL and Rust history backends without
    /// rewriting consumer code。
    public func permitModeDistribution() async throws
        -> [String: Int]
    {
        return try await tracker.permitModeDistribution()
    }

    /// Codable aggregation snapshot bundling the count + permit-
    /// mode distribution + this-session turn count into one
    /// dashboard-shaped payload。 Mirrors
    /// `BASRustBrainHistoryStoreAggregation` semantics across
    /// the two history backends。
    public func aggregationSnapshot() async throws
        -> BASSQLBrainHistoryStoreAggregation
    {
        let count = await tracker.recordCount
        let dist = try await tracker.permitModeDistribution()
        let backed = await tracker.isSQLBacked
        let distinctSessions = try await tracker
            .distinctSessionCountViaSQL()
        // 严查 修复 — surface MIN/MAX(retrieved_at_ms)
        // through the aggregation snapshot so the Round-3
        // SQL native aggregates actually flow into
        // brain.healthSnapshot()。
        let oldest = try await tracker
            .oldestRecordTimestampViaSQL()
        let newest = try await tracker
            .newestRecordTimestampViaSQL()
        let helpedDist = try await tracker
            .helpedFlagDistributionViaSQL()
        return BASSQLBrainHistoryStoreAggregation(
            totalRecords: count,
            recordsByPermitMode: dist,
            turnsThisSession: turnCounter,
            isSQLBacked: backed,
            distinctSessions: distinctSessions,
            oldestRecordAt: oldest,
            newestRecordAt: newest,
            recordsByHelpedFlag: helpedDist)
    }

    // MARK: - 主线 解构 重构 — atom-scoped native queries

    /// Atom-scoped usage count via native `SELECT COUNT(*)
    /// WHERE atom_id = ?` SQL query (engine-side count when
    /// SQLite-backed,Swift fallback in-memory)。 Replaces
    /// the legacy `usageCount(forInput:)` Swift-fold path for
    /// hosts running large corpora。
    public func usageCountViaSQL(
        forInput input: String
    ) async throws -> Int {
        let atomID = Self.atomID(forInput: input)
        return try await tracker.usageCountViaSQL(
            forAtomID: atomID)
    }

    /// Atom-scoped recent-records via native `SELECT ...
    /// WHERE atom_id = ? ORDER BY retrieved_at_ms DESC
    /// LIMIT ?` SQL query。 Returns at most `limit` rows
    /// for the input,newest first。
    public func recentRecordsForInputViaSQL(
        forInput input: String,
        limit: Int
    ) async throws -> [BASMemoryUsageRecord] {
        let atomID = Self.atomID(forInput: input)
        return try await tracker.recentRecordsForAtomViaSQL(
            atomID: atomID, limit: limit)
    }

    /// Distinct-session count via native `SELECT COUNT
    /// (DISTINCT session_ref)` SQL query。 Returns the
    /// number of distinct sessions that have ever written
    /// to the underlying database (across all brain
    /// instances using this tracker)。
    public func distinctSessionCountViaSQL() async throws
        -> Int
    {
        return try await tracker
            .distinctSessionCountViaSQL()
    }

    // MARK: - 主线 解构 重构 Round 3 — engine-side aggregates

    /// Oldest record timestamp via native `SELECT MIN
    /// (retrieved_at_ms)`。 Nil when the database is empty。
    public func oldestRecordTimestampViaSQL() async throws
        -> Date?
    {
        return try await tracker
            .oldestRecordTimestampViaSQL()
    }

    /// Newest record timestamp via native `SELECT MAX
    /// (retrieved_at_ms)`。 Nil when the database is empty。
    public func newestRecordTimestampViaSQL() async throws
        -> Date?
    {
        return try await tracker
            .newestRecordTimestampViaSQL()
    }

    /// Helped-flag distribution via native `SELECT
    /// helped_state, COUNT(*) GROUP BY helped_state`。
    /// Returns map from helpedFlag raw value ("unknown" /
    /// "helped" / "notHelped") to count。
    public func helpedFlagDistributionViaSQL() async throws
        -> [String: Int]
    {
        return try await tracker
            .helpedFlagDistributionViaSQL()
    }

    /// Records in a time window via native `WHERE
    /// retrieved_at_ms BETWEEN ? AND ?`。 Returns rows
    /// ascending by retrieved_at_ms (oldest first)。
    public func recordsInTimeRangeViaSQL(
        from: Date,
        to: Date
    ) async throws -> [BASMemoryUsageRecord] {
        return try await tracker
            .recordsInTimeRangeViaSQL(
                from: from, to: to)
    }

    /// 持续性 发展 — mark a recorded summary as helped /
    /// notHelped。 Delegates to the underlying
    /// BASMemoryUsageTracker's `markHelped` path (which
    /// updates the SQL row's helped_state column when
    /// the tracker is SQLite-backed,or just the in-
    /// memory cache when it isn't)。
    ///
    /// Throws BASMemoryUsageTracker.TrackerError when the
    /// recordID is unknown。 Hosts pass the recordID
    /// returned by a prior `recordSummary(_:)` call。
    public func markHelped(
        recordID: String, helped: Bool
    ) async throws {
        try await tracker.markHelped(
            recordID: recordID, helped: helped)
    }

    /// 全面 开发 — atomic batch summary insert via SQLite
    /// `BEGIN TRANSACTION ... COMMIT`。 Either all
    /// summaries commit or none。 Returns the minted
    /// recordIDs in insertion order。
    ///
    /// Use case:host has a batch of N summaries (e.g.
    /// from a queue / file replay) and wants them
    /// inserted with one fsync,not N。 SQL transaction
    /// is the right primitive here。
    @discardableResult
    public func recordSummaryBatch(
        _ summaries: [BASCognitiveBrainSummary]
    ) async throws -> [String] {
        if summaries.isEmpty { return [] }
        var entries: [BASMemoryUsageTracker.BatchEntry] =
            []
        entries.reserveCapacity(summaries.count)
        for s in summaries {
            turnCounter += 1
            entries.append(
                BASMemoryUsageTracker.BatchEntry(
                    atomID: Self.atomID(
                        forInput: s.input),
                    sessionRef: sessionRef,
                    turnRef: String(turnCounter),
                    permitMode:
                        s.safetyVerdict.rawValue))
        }
        return try await tracker.recordBatch(entries)
    }
}

/// Codable aggregation snapshot from
/// BASSQLBrainHistoryStore.aggregationSnapshot()。 Hosts use
/// this for dashboard / audit rollups。 Mirrors
/// BASRustBrainHistoryStoreAggregation so dashboards can switch
/// between SQL and Rust history backends without rewriting
/// consumer code。
public struct BASSQLBrainHistoryStoreAggregation: Codable,
    Equatable, Sendable, Hashable
{
    /// Total records across all sessions / permit modes。
    public let totalRecords: Int

    /// Record count grouped by permit mode
    /// ("safe" / "warn" / "block")。 Computed via native
    /// `GROUP BY permit_mode` SQL query when the underlying
    /// tracker is SQLite-backed。
    public let recordsByPermitMode: [String: Int]

    /// Turn counter for this brain instance (matches
    /// `BASSQLBrainHistoryStore.turnsThisSession`)。
    public let turnsThisSession: Int

    /// True if the underlying tracker has a SQLite database
    /// handle (queries hit the storage engine)。
    public let isSQLBacked: Bool

    /// 主线 解构 重构 — distinct session count via native
    /// `SELECT COUNT(DISTINCT session_ref)` SQL。 0 by
    /// default for backward-compat with snapshots produced
    /// before this field landed。
    public let distinctSessions: Int

    /// 严查 修复 — oldest record timestamp via native
    /// `SELECT MIN(retrieved_at_ms)`。 Nil when the
    /// database is empty。 Default nil for backward-compat。
    public let oldestRecordAt: Date?

    /// Newest record timestamp via native `SELECT MAX
    /// (retrieved_at_ms)`。 Nil when the database is
    /// empty。
    public let newestRecordAt: Date?

    /// Records grouped by helped_state ("unknown" /
    /// "helped" / "notHelped") via native `GROUP BY
    /// helped_state` SQL query。 Empty map when no
    /// records。 Default empty for backward-compat。
    public let recordsByHelpedFlag: [String: Int]

    public init(
        totalRecords: Int,
        recordsByPermitMode: [String: Int],
        turnsThisSession: Int,
        isSQLBacked: Bool,
        distinctSessions: Int = 0,
        oldestRecordAt: Date? = nil,
        newestRecordAt: Date? = nil,
        recordsByHelpedFlag: [String: Int] = [:]
    ) {
        self.totalRecords = totalRecords
        self.recordsByPermitMode = recordsByPermitMode
        self.turnsThisSession = turnsThisSession
        self.isSQLBacked = isSQLBacked
        self.distinctSessions = distinctSessions
        self.oldestRecordAt = oldestRecordAt
        self.newestRecordAt = newestRecordAt
        self.recordsByHelpedFlag = recordsByHelpedFlag
    }

    /// 严查 修复 — convenience time-span derived from
    /// MIN/MAX timestamps。 Nil when either bound is nil。
    public var recordsTimeSpanSeconds: TimeInterval? {
        guard let oldest = oldestRecordAt,
              let newest = newestRecordAt
        else { return nil }
        return newest.timeIntervalSince(oldest)
    }
}
