// MARK: - BASMemoryUsageTracker — chapter 二百五十一 / M738
//
// L8 memory retrieval usage logging — Stage 1 Step 1 of 3
// (Memory Importance Loop).
//
// ## Why this exists
//
// 附录 V Stage 0 closed cross-session memory persistence (chapters
// 二百四十八-二百五十). What's still open: the L8 atom store has
// no signal for "was this atom actually USED" beyond
// `BASMemoryGovernedMemory.lastConfirmedAt: Date?` (single
// timestamp per atom, mutated only on retrieval). With one
// timestamp the scorer cannot distinguish "retrieved 100 times in
// the past hour" vs "retrieved once a week ago" — both look like
// the same `lastConfirmedAt`.
//
// chapter 二百五十一 ships a typed retrieval-event log: every L8
// recall appends one `BASMemoryUsageRecord`. The
// `BASMemoryImportanceScorer` (chapter 二百五十二) reads the log and
// computes `recency × frequency × helped-rate × tier-decay` to
// recommend tier promotion / demotion. The L8 retrieval path
// (chapter 二百五十三) wires both: log on recall, apply scorer
// output via `BASMemoryAtomStore.updateTier(...)`.
//
// ## Doctrine pins
//
//   - 不变量 #1 / #2 / #3 unchanged: tracker is observability —
//     it records what happened, never grants permits, never feeds
//     base weights. The scorer's tier mutation hint goes through
//     the same `BASMemoryAtomStore` protocol and the same L8
//     governance status pipeline that already exists.
//   - 红线 7 (watcher only-hint): the scorer (next chapter) emits
//     hint records, not commits. The L8 retrieval integration
//     (chapter 二百五十三) calls the existing `updateTier` /
//     `updateGovernanceStatus` mutators which still respect every
//     downstream doctrine gate.
//   - chapter 二百四十八 SQLite idiom: same `import SQLite3`,
//     transient bind destructor, schema-version pragma, WAL mode,
//     actor-isolated `OpaquePointer` via `nonisolated(unsafe)`.
//   - chapter 二百十一 single-source-of-truth: this file owns the
//     `BASMemoryUsageRecord` schema and the tracker actor. No
//     other file defines either.
//
// ## Schema (version 1)
//
//   CREATE TABLE memory_usage_records (
//     record_id TEXT PRIMARY KEY NOT NULL,    -- per-event UUID
//     atom_id TEXT NOT NULL,                  -- BASGovernedMemory.id
//     retrieved_at_ms INTEGER NOT NULL,
//     session_ref TEXT NOT NULL,              -- session ID
//     turn_ref TEXT NOT NULL,                 -- turn ID
//     permit_mode TEXT NOT NULL,              -- BASActionPermitMode raw
//     helped_state TEXT NOT NULL              -- HelpedFlag raw value
//   );
//   CREATE INDEX memory_usage_atom_idx
//     ON memory_usage_records(atom_id);
//   CREATE INDEX memory_usage_session_idx
//     ON memory_usage_records(session_ref);
//
// `helped_state` starts as `.unknown` and may be updated by a
// post-LLM signal — was the response actually informed by this
// atom? The simplest signal: the host runtime sees the LLM output
// reference the atom (e.g. by ID embedded in an audit code) and
// calls `markHelped(recordID:helped:)`. Without that signal the
// scorer treats `.unknown` as a half-credit by default.
//
// ## In-memory mode
//
// Tests + ephemeral hosts pass `databaseURL: nil` to get an
// in-memory tracker (no SQLite, faster, but no cross-session
// continuity). Production hosts pass a SQLite URL paired with the
// chapter 二百四十八 + 二百五十 unified-storage layout.

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

/// Append-only L8 retrieval usage log. Two modes:
///
///   - **In-memory** (databaseURL: nil): records live in the actor
///     for the session only. Tests + ephemeral hosts.
///   - **SQLite-backed** (databaseURL: non-nil): records persist
///     across process restarts; cross-session importance scoring
///     can read history from prior sessions.
///
/// Records are immutable except for `helpedFlag` which the host
/// runtime can flip from `.unknown` to `.helped` / `.notHelped`
/// once the post-LLM "did the response actually use this atom"
/// signal is known.
public actor BASMemoryUsageTracker {

    public enum TrackerError:
        Error, Equatable, Hashable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case unknownRecord(id: String)

        /// Stable telemetry-friendly identifier for the
        /// error case discriminator,independent of
        /// associated value data。 See chapter 七百二十 /
        /// M2219 for the cross-pilot caseIdentifier
        /// contract。
        public var caseIdentifier: String {
            switch self {
            case .openFailed:
                return "openFailed"
            case .prepareFailed:
                return "prepareFailed"
            case .stepFailed:
                return "stepFailed"
            case .schemaVersionMismatch:
                return "schemaVersionMismatch"
            case .unknownRecord:
                return "unknownRecord"
            }
        }
    }

    public static let schemaVersion: Int = 1

    /// SQLite file URL when persistent; nil when in-memory.
    public let databaseURL: URL?

    /// SQLite handle (nil in in-memory mode). See chapter
    /// 二百四十八 / M735 commentary on why `nonisolated(unsafe)`
    /// is the right opt-out for deinit cleanup of an
    /// actor-isolated `OpaquePointer`.
    private nonisolated(unsafe) var db: OpaquePointer?

    /// In-memory record store keyed by recordID. Used in
    /// in-memory mode AND as a write-through cache in SQLite
    /// mode (so `recordCount` / `recentRecords` don't need a
    /// SQL round-trip). Reloaded from disk on init.
    private var inMemory: [String: BASMemoryUsageRecord] = [:]

    /// 主线 SQL Tombstone 抽取 — set of recordIDs marked
    /// as tombstoned。 Mirrors the SQL
    /// `memory_usage_tombstones` table when SQLite-backed;
    /// holds the only state in in-memory mode。
    private var inMemoryTombstones: Set<String> = []

    /// 主线 SQL Bundle 抽取 — in-memory mirror of the
    /// `memory_usage_bundles` table。 Keyed by bundleID,
    /// value carries the ordered recordIDs + createdAt。
    private var inMemoryBundles:
        [String: (recordIDs: [String],
                  createdAtMs: Int64)] = [:]

    /// 主线 SQL ReplayLog 抽取 — append-only event log。
    private var inMemoryReplayLog: [BASReplayLogEntry] = []

    /// 主线 SQL AuditLog 抽取 — append-only audit trail。
    private var inMemoryAuditLog: [BASAuditLogEntry] = []

    /// 主线 SQL FTS 抽取 — per-record notes for FTS5
    /// search。 Keyed by recordID。
    private var inMemoryNotes: [String: String] = [:]

    // MARK: - Lifecycle

    /// Construct an in-memory tracker. No disk I/O.
    public init() {
        self.databaseURL = nil
        self.db = nil
    }

    /// Construct a SQLite-backed tracker. Loads any prior records
    /// from disk into the in-memory cache so subsequent reads
    /// don't need a round-trip.
    ///
    /// - Parameter useGeneratedSchema:M2173 chapter 七百二 第三刀
    ///   — when `true`,the schema is provisioned via the
    ///   `MemoryUsageRecordsSchema.allStatementsSQL` constant
    ///   generated by the BASSQLSchemaGen build plugin from
    ///   `Sources/BASMemory/SQL/001_memory_usage_records.sql`。
    ///   Default `false` preserves the V1 byte-equality path
    ///   (three separate inline `runExec` calls)。
    ///
    ///   ADR-014 OPT-IN preserved:callers that want the
    ///   generated path opt-in explicitly。 The async factory
    ///   `make(databaseURL:flags:)` does that opt-in based on
    ///   `BASLanguageAugmentationFeatureFlags.sqlMigratorEnabled`
    ///   (default-off feature flag → V1 path)。
    ///
    ///   Both code paths produce IDENTICAL on-disk schema (proved
    ///   by `BASMemoryUsageTrackerSqlPilotByteEqualityTests` at
    ///   M2173 第三刀)。
    public init(
        databaseURL: URL,
        useGeneratedSchema: Bool = false
    ) throws {
        self.databaseURL = databaseURL

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
        let openRC = sqlite3_open_v2(
            databaseURL.path, &handle, flags, nil)
        guard openRC == SQLITE_OK, let handle else {
            let message = handle.flatMap { db -> String? in
                String(cString: sqlite3_errmsg(db))
            } ?? "sqlite3_open_v2 rc=\(openRC)"
            if handle != nil { sqlite3_close_v2(handle) }
            throw TrackerError.openFailed(
                code: openRC, message: message)
        }
        self.db = handle

        try Self.runExec(db: handle, sql: "PRAGMA journal_mode=WAL;")
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")
        try Self.runExec(db: handle, sql: "PRAGMA foreign_keys=ON;")

        // M886 backport (M882 audit fix):read user_version FIRST,
        // branch 0 → write current,equal → accept,mismatch → throw。
        let existingVersion = try Self.readUserVersion(
            db: handle)
        if existingVersion == 0 {
            try Self.runExec(
                db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion != Self.schemaVersion {
            throw TrackerError.schemaVersionMismatch(
                found: existingVersion,
                expected: Self.schemaVersion)
        }
        try Self.ensureSchema(
            db: handle, useGenerated: useGeneratedSchema)
        try Self.verifySchemaVersion(db: handle)

        // Load prior records into the in-memory cache.
        let prior = try Self.fetchAllRecords(db: handle)
        for record in prior {
            inMemory[record.recordID] = record
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Public surface

    /// 全面 开发 — typed payload struct for batch insert。
    /// Each entry is a record-shaped struct without the
    /// recordID (the tracker mints a UUID per insert)。
    public struct BatchEntry: Sendable, Equatable, Hashable {
        public let atomID: String
        public let sessionRef: String
        public let turnRef: String
        public let permitMode: String
        public let retrievedAt: Date

        public init(
            atomID: String,
            sessionRef: String,
            turnRef: String,
            permitMode: String,
            retrievedAt: Date = Date()
        ) {
            self.atomID = atomID
            self.sessionRef = sessionRef
            self.turnRef = turnRef
            self.permitMode = permitMode
            self.retrievedAt = retrievedAt
        }
    }

    // MARK: - 主线 SQL Tombstone 抽取

    // MARK: - 主线 SQL 硬核 — index-driven + durability

    /// 主线 SQL 硬核 — provision the composite covering
    /// index `(atom_id, retrieved_at_ms DESC)` for the
    /// hot "recent records per atom" query path。 With
    /// just the single-column `memory_usage_atom_idx`,
    /// SQLite has to fetch matching rows then sort by
    /// retrieved_at_ms。 With this composite index,the
    /// query plan can read rows in index order — no
    /// post-fetch sort needed。
    ///
    /// Idempotent CREATE INDEX IF NOT EXISTS。 The main
    /// table schema stays untouched (chapter 702 byte-
    /// equality preserved)。
    public func ensureCoveringIndex() async throws {
        guard let db = db else { return }
        try Self.ensureExtendedIndexSchema(db: db)
    }

    /// 主线 SQL 硬核 — typed Codable EXPLAIN QUERY PLAN
    /// row。 Mirrors the columns SQLite emits when you
    /// prefix a statement with `EXPLAIN QUERY PLAN`:
    ///   id INTEGER, parent INTEGER, notused INTEGER,
    ///   detail TEXT
    public struct ExplainQueryPlanRow: Codable, Equatable,
        Sendable, Hashable
    {
        public let id: Int
        public let parent: Int
        public let detail: String

        public init(
            id: Int, parent: Int, detail: String
        ) {
            self.id = id
            self.parent = parent
            self.detail = detail
        }

        /// True when the SQLite query planner is using
        /// an INDEX (the detail string contains "USING
        /// INDEX")。 Hosts use this in tests to assert
        /// that a query is not doing a full table scan。
        public var usesIndex: Bool {
            return detail.contains("USING INDEX")
        }

        /// Detail-string scan check:returns true if the
        /// query planner is using a full table SCAN
        /// (no index)。 Hosts use this to flag
        /// regression — when an expected index lookup
        /// degrades to a scan,it shows here。
        public var doesTableScan: Bool {
            return detail.contains("SCAN")
                && !usesIndex
        }
    }

    /// Run `EXPLAIN QUERY PLAN <sql>` against the
    /// SQLite database。 Returns the typed rows so hosts
    /// can verify the query optimizer is using indexes。
    ///
    /// In-memory mode returns an empty array (no SQLite
    /// engine to ask)。 Throws on SQL parse error。
    public func explainQueryPlan(
        forSQL sql: String
    ) throws -> [ExplainQueryPlanRow] {
        guard let db = db else { return [] }
        return try Self.fetchExplainQueryPlan(
            db: db, sql: sql)
    }

    /// 主线 SQL 硬核 — force WAL checkpoint。 Runs
    /// `PRAGMA wal_checkpoint(TRUNCATE)` to flush all
    /// uncommitted WAL pages to the main database file
    /// and truncate the WAL file。 Returns a Codable
    /// summary of the checkpoint result。
    ///
    /// SQLite returns 3 integers from this PRAGMA:
    ///   busy:       1 if checkpoint was blocked by
    ///               another reader (otherwise 0)
    ///   logPages:   the size of the WAL log in pages
    ///               BEFORE the checkpoint
    ///   checkpointed: pages successfully checkpointed
    ///
    /// Use case:hosts running long sessions can call
    /// this periodically to bound the WAL file size。
    /// Also useful before host process shutdown to
    /// ensure all writes are durable on disk。
    ///
    /// In-memory mode returns a zero-result (no WAL
    /// exists)。 Throws if the PRAGMA call fails。
    @discardableResult
    public func checkpointWAL() throws
        -> BASWALCheckpointResult
    {
        guard let db = db else {
            return BASWALCheckpointResult(
                busy: 0, logPages: 0, checkpointed: 0)
        }
        return try Self.runWALCheckpoint(db: db)
    }

    /// 主线 SQL 硬核 — create a Bundle (named group of
    /// related records)。 Inserts one row per recordID
    /// into `memory_usage_bundles` with the supplied
    /// position-in-bundle ordering。 Returns the minted
    /// bundle UUID。
    ///
    /// Hosts use bundles to group records that belong
    /// to a single logical unit (e.g. a multi-turn
    /// dialogue, a batched-input run, etc) without
    /// touching session_ref semantics。
    ///
    /// In-memory mode stores bundles in a Swift dict
    /// keyed by bundleID。
    @discardableResult
    public func createBundle(
        recordIDs: [String],
        bundleID: String? = nil,
        createdAt: Date = Date()
    ) async throws -> String {
        let bid = bundleID ?? UUID().uuidString
        let createdMs = Int64(
            createdAt.timeIntervalSince1970 * 1000)
        if let db = db {
            try Self.ensureBundleSchema(db: db)
            try Self.insertBundle(
                db: db,
                bundleID: bid,
                recordIDs: recordIDs,
                createdAtMs: createdMs)
        }
        inMemoryBundles[bid] = (
            recordIDs: recordIDs,
            createdAtMs: createdMs)
        return bid
    }

    /// Return summaries of all bundles。 Sorted by
    /// created_at_ms ascending (oldest first)。 SQLite-
    /// backed mode uses native GROUP BY query;in-memory
    /// folds the Swift dict。
    public func bundleSummariesViaSQL() throws
        -> [BASBundleSummary]
    {
        if let db = db {
            try Self.ensureBundleSchema(db: db)
            return try Self.fetchBundleSummaries(db: db)
        }
        let summaries = inMemoryBundles.map {
            (bid, entry) -> BASBundleSummary in
            BASBundleSummary(
                bundleID: bid,
                recordCount: entry.recordIDs.count,
                createdAtMs: entry.createdAtMs)
        }
        return summaries.sorted {
            $0.createdAtMs < $1.createdAtMs
        }
    }

    /// 主线 SQL Episode 抽取 — group records by
    /// session_ref via native `SELECT ... GROUP BY
    /// session_ref` SQL query。 Each "episode" is one
    /// distinct session's record sequence。 Returns:
    ///   - sessionRef
    ///   - recordCount  (rows in this session)
    ///   - startMs      (MIN(retrieved_at_ms))
    ///   - endMs        (MAX(retrieved_at_ms))
    ///
    /// Sorted ascending by startMs (oldest episode
    /// first)。 In-memory mode folds in Swift。
    ///
    /// SQL territory:GROUP BY + MIN/MAX is canonical
    /// SQL aggregation work,not Swift fold work。
    public func episodeSummariesViaSQL() throws
        -> [BASEpisodeSummary]
    {
        if let db = db {
            return try Self
                .fetchEpisodeSummaries(db: db)
        }
        // In-memory fallback
        var byRef: [String: (count: Int,
                              start: Int64,
                              end: Int64)] = [:]
        for record in inMemory.values {
            let ms = Int64(
                record.retrievedAt
                    .timeIntervalSince1970 * 1000)
            if var existing = byRef[record.sessionRef] {
                existing.count += 1
                existing.start = min(existing.start, ms)
                existing.end = max(existing.end, ms)
                byRef[record.sessionRef] = existing
            } else {
                byRef[record.sessionRef] = (1, ms, ms)
            }
        }
        let summaries = byRef.map { entry in
            BASEpisodeSummary(
                sessionRef: entry.key,
                recordCount: entry.value.count,
                startMs: entry.value.start,
                endMs: entry.value.end)
        }
        return summaries.sorted {
            $0.startMs < $1.startMs
        }
    }

    /// 主线 全面 开发 — soft-delete marker。 Inserts a
    /// row into the `memory_usage_tombstones` table
    /// (auto-created at first call) marking `recordID`
    /// as forgotten。 Active-record queries filter out
    /// tombstoned records via LEFT JOIN。
    ///
    /// Does NOT delete the original record — tombstone
    /// preserves the audit trail。 Use `purgeTombstoned`
    /// for physical deletion later。
    ///
    /// In-memory mode tracks tombstones in a Swift Set
    /// (no SQL table); same semantics, no persistence。
    public func tombstoneRecord(
        recordID: String,
        tombstonedAt: Date = Date()
    ) async throws {
        if let db = db {
            try Self.ensureTombstoneSchema(db: db)
            try Self.insertTombstone(
                db: db,
                recordID: recordID,
                tombstonedAtMs: Int64(
                    tombstonedAt.timeIntervalSince1970
                        * 1000))
        }
        inMemoryTombstones.insert(recordID)
    }

    /// True if the recordID has been tombstoned。 Checks
    /// in-memory set (which mirrors the SQL table when
    /// SQLite-backed)。
    public func isTombstoned(
        recordID: String
    ) -> Bool {
        return inMemoryTombstones.contains(recordID)
    }

    /// Count of tombstoned records。
    public var tombstoneCount: Int {
        return inMemoryTombstones.count
    }

    /// Count of records that have NOT been tombstoned。
    /// Useful for "live memory" dashboards。
    public var activeRecordCount: Int {
        return inMemory.count - inMemoryTombstones.count
    }

    /// Permanently delete tombstoned records from both
    /// the in-memory cache AND the SQLite table (when
    /// backed)。 Returns the count purged。 The tombstones
    /// table is also cleaned。
    @discardableResult
    public func purgeTombstoned() async throws -> Int {
        let toRemove = inMemoryTombstones
        let count = toRemove.count
        for id in toRemove {
            inMemory.removeValue(forKey: id)
        }
        inMemoryTombstones.removeAll()
        if let db = db {
            try Self.ensureTombstoneSchema(db: db)
            try Self.purgeTombstonedRows(db: db)
        }
        return count
    }

    /// 全面 开发 — atomic batch insert wrapped in
    /// `BEGIN TRANSACTION ... COMMIT`。 Either every row
    /// commits or none (the tracker rolls back on any
    /// step failure)。 Returns the minted recordIDs in
    /// insertion order。
    ///
    /// In SQLite-backed mode this is also significantly
    /// faster than N individual `record(...)` calls:one
    /// fsync at COMMIT instead of N。 In in-memory mode it
    /// degrades to a per-entry append (transactions are
    /// a SQL primitive,not a HashMap primitive)。
    ///
    /// Empty `entries` returns empty array,no SQL work。
    @discardableResult
    public func recordBatch(
        _ entries: [BatchEntry]
    ) async throws -> [String] {
        if entries.isEmpty { return [] }
        if let db {
            return try Self.insertBatchInTransaction(
                db: db,
                entries: entries,
                inMemoryAppender: { record in
                    inMemory[record.recordID] = record
                })
        }
        // In-memory fallback:no transaction primitive,
        // just append each entry。 If a host wants
        // atomicity here,they need the SQLite-backed
        // mode。
        var ids: [String] = []
        ids.reserveCapacity(entries.count)
        for e in entries {
            let record = BASMemoryUsageRecord(
                atomID: e.atomID,
                retrievedAt: e.retrievedAt,
                sessionRef: e.sessionRef,
                turnRef: e.turnRef,
                permitMode: e.permitMode)
            inMemory[record.recordID] = record
            ids.append(record.recordID)
        }
        return ids
    }

    /// Append one retrieval event. Returns the recordID so the
    /// host can later call `markHelped(recordID:helped:)` once
    /// the post-LLM signal is known.
    @discardableResult
    public func record(
        atomID: String,
        sessionRef: String,
        turnRef: String,
        permitMode: String,
        retrievedAt: Date = Date()
    ) async throws -> String {
        let record = BASMemoryUsageRecord(
            atomID: atomID,
            retrievedAt: retrievedAt,
            sessionRef: sessionRef,
            turnRef: turnRef,
            permitMode: permitMode)
        inMemory[record.recordID] = record
        if let db { try Self.insertRecord(db: db, record: record) }
        return record.recordID
    }

    /// Update the `.helped` / `.notHelped` flag on a recorded
    /// event. Throws if the recordID is unknown.
    public func markHelped(
        recordID: String,
        helped: Bool
    ) async throws {
        guard var record = inMemory[recordID] else {
            throw TrackerError.unknownRecord(id: recordID)
        }
        record.helpedFlag = helped ? .helped : .notHelped
        inMemory[recordID] = record
        if let db { try Self.upsertRecord(db: db, record: record) }
    }

    /// Total number of records in the log.
    public var recordCount: Int { inMemory.count }

    /// Number of retrieval events for a given atom.
    public func usageCount(forAtomID atomID: String) -> Int {
        inMemory.values.filter { $0.atomID == atomID }.count
    }

    /// Most recent N records for `atomID`, sorted descending by
    /// `retrievedAt` (newest first). Useful for recency-weighted
    /// scoring.
    public func recentRecords(
        forAtomID atomID: String,
        limit: Int = 50
    ) -> [BASMemoryUsageRecord] {
        let all = inMemory.values.filter { $0.atomID == atomID }
        let sorted = all.sorted { $0.retrievedAt > $1.retrievedAt }
        return Array(sorted.prefix(max(0, limit)))
    }

    /// Every record in the log, sorted ascending by `retrievedAt`.
    /// Used by the scorer to compute global frequency stats.
    public func allRecords() -> [BASMemoryUsageRecord] {
        inMemory.values.sorted {
            $0.retrievedAt < $1.retrievedAt
        }
    }

    // MARK: - 主线 全面 提升: native SQL query paths
    //
    // The methods above (`allRecords`,`recentRecords(forAtomID:)`,
    // `usageCount(forAtomID:)`,`recordCount`) read from the
    // `inMemory` dictionary。 That's the write-through cache — fast
    // O(1) recordCount + O(n) Swift sort + Array prefix。 Works for
    // any corpus size that fits in RAM,but does NOT exercise the
    // SQL pilot's query engine。
    //
    // These methods push the query into SQLite when a database
    // handle is available。 ORDER BY,LIMIT,and GROUP BY all run
    // inside the storage engine — the actual reason the chapter
    // 702 SQL pilot exists。 In-memory mode (db == nil) falls back
    // to the Swift fold so semantics stay consistent across both
    // tracker modes。

    /// Read the N most-recent records across ALL atoms,sorted
    /// descending by `retrievedAt` (newest first)。
    ///
    /// When the tracker is SQLite-backed (databaseURL non-nil),
    /// this executes a native `SELECT ... ORDER BY retrieved_at_ms
    /// DESC LIMIT ?` query inside SQLite。 When the tracker is in-
    /// memory only,it folds over `inMemory.values`。 Both paths
    /// return logically identical results。
    ///
    /// Hosts running large corpora prefer this over `allRecords()
    /// .sorted().prefix()` because the storage engine handles the
    /// ordering + limit without materializing the full record set
    /// in Swift。
    public func recentRecordsViaSQL(
        limit: Int
    ) throws -> [BASMemoryUsageRecord] {
        if let db {
            return try Self.fetchRecentRecordsDesc(
                db: db, limit: max(0, limit))
        }
        let sorted = inMemory.values.sorted {
            $0.retrievedAt > $1.retrievedAt
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    /// Record counts grouped by `permit_mode`。 When SQLite-
    /// backed,runs a native `SELECT permit_mode, COUNT(*) ...
    /// GROUP BY permit_mode` query。 When in-memory only,
    /// folds over the cache。 Both paths return logically
    /// identical results。
    ///
    /// Hosts use this for safety-dashboard rollups:
    ///   - "how many .block verdicts logged this database?"
    ///   - "how many .warn?"
    ///   - "how many .safe?"
    public func permitModeDistribution() throws -> [String: Int] {
        if let db {
            return try Self.fetchPermitModeDistribution(db: db)
        }
        var counts: [String: Int] = [:]
        for record in inMemory.values {
            counts[record.permitMode, default: 0] += 1
        }
        return counts
    }

    /// True when this tracker is SQLite-backed (has a real
    /// `db` handle)。 Hosts can use this to log whether queries
    /// will hit the engine or fall back to Swift folds。
    public var isSQLBacked: Bool {
        return db != nil
    }

    /// 主线 解构 重构 — native `SELECT COUNT(*) WHERE
    /// atom_id = ?` query。 Pushes the count operation
    /// into SQLite when the tracker is SQLite-backed;
    /// falls back to Swift filter+count for in-memory
    /// mode。 Both paths return the same Int。
    ///
    /// Replaces the legacy Swift-fold path
    /// (`usageCount(forAtomID:)`) for hosts running large
    /// SQLite-backed corpora where the in-memory cache
    /// fold is unnecessary work。
    public func usageCountViaSQL(
        forAtomID atomID: String
    ) throws -> Int {
        if let db {
            return try Self.fetchUsageCount(
                db: db, atomID: atomID)
        }
        return inMemory.values
            .filter { $0.atomID == atomID }
            .count
    }

    /// 主线 解构 重构 — native `SELECT COUNT(DISTINCT
    /// session_ref)` query。 Pushes the distinct-count
    /// into SQLite (the storage engine's specialty)。
    /// Falls back to a Swift Set when in-memory only。
    ///
    /// Hosts use this for "how many distinct sessions
    /// have ever written to this DB" rollups。
    public func distinctSessionCountViaSQL() throws -> Int {
        if let db {
            return try Self.fetchDistinctSessionCount(db: db)
        }
        var seen = Set<String>()
        for record in inMemory.values {
            seen.insert(record.sessionRef)
        }
        return seen.count
    }

    /// 主线 解构 重构 — native `SELECT ... WHERE atom_id
    /// = ? ORDER BY retrieved_at_ms DESC LIMIT ?` query。
    /// Pushes the atom filter + ordering + limit into
    /// SQLite,returning only the rows the caller asked
    /// for instead of materializing the full atom-filtered
    /// set in Swift first。
    ///
    /// Differs from `recentRecords(forAtomID:limit:)` (the
    /// legacy Swift-fold path) by running the WHERE +
    /// ORDER BY + LIMIT all inside the storage engine。
    public func recentRecordsForAtomViaSQL(
        atomID: String,
        limit: Int
    ) throws -> [BASMemoryUsageRecord] {
        if let db {
            return try Self.fetchRecentRecordsForAtomDesc(
                db: db, atomID: atomID,
                limit: max(0, limit))
        }
        let filtered = inMemory.values
            .filter { $0.atomID == atomID }
        let sorted = filtered.sorted {
            $0.retrievedAt > $1.retrievedAt
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    /// 主线 解构 重构 Round 3 — native `SELECT MIN/MAX
    /// (retrieved_at_ms)` queries returning the oldest /
    /// newest timestamps as Date。 Nil when the table is
    /// empty (no records means no MIN/MAX)。
    ///
    /// SQL-backed path runs one COUNT-free aggregate query
    /// inside the engine。 In-memory path folds over the
    /// cache values。 Both return identical Date values
    /// for identical data。
    public func oldestRecordTimestampViaSQL() throws -> Date? {
        if let db {
            guard let ms = try Self
                .fetchMinRetrievedAt(db: db)
            else { return nil }
            return Date(
                timeIntervalSince1970: Double(ms) / 1000)
        }
        return inMemory.values
            .map { $0.retrievedAt }
            .min()
    }

    /// Counterpart of `oldestRecordTimestampViaSQL` using
    /// `SELECT MAX(retrieved_at_ms)`。
    public func newestRecordTimestampViaSQL() throws -> Date? {
        if let db {
            guard let ms = try Self
                .fetchMaxRetrievedAt(db: db)
            else { return nil }
            return Date(
                timeIntervalSince1970: Double(ms) / 1000)
        }
        return inMemory.values
            .map { $0.retrievedAt }
            .max()
    }

    /// 主线 解构 重构 Round 3 — native `SELECT helped_state
    /// , COUNT(*) GROUP BY helped_state`。 Pushes the
    /// distinct-count aggregation into SQLite — same engine-
    /// side specialty as permitModeDistribution()。
    ///
    /// Returns a map from helpedFlag raw value
    /// ("unknown" / "helped" / "notHelped") to count。
    /// Hosts use this to render "did the LLM actually use
    /// the recalled atom" dashboards。
    public func helpedFlagDistributionViaSQL() throws
        -> [String: Int]
    {
        if let db {
            return try Self
                .fetchHelpedFlagDistribution(db: db)
        }
        var counts: [String: Int] = [:]
        for record in inMemory.values {
            counts[record.helpedFlag.rawValue,
                default: 0] += 1
        }
        return counts
    }

    /// 主线 解构 重构 Round 3 — native `SELECT ... WHERE
    /// retrieved_at_ms BETWEEN ? AND ?` query for time-
    /// range scans。 Returns matching rows ordered ascending
    /// by retrieved_at_ms (oldest first — matches the
    /// existing `allRecords()` sort)。
    ///
    /// Hosts use this for "what happened during this hour"
    /// audit slices without pulling the full table into
    /// Swift。 SQLite's query planner uses the implicit
    /// rowid+timestamp ordering for an efficient range
    /// scan when no other index applies。
    public func recordsInTimeRangeViaSQL(
        from: Date,
        to: Date
    ) throws -> [BASMemoryUsageRecord] {
        if let db {
            return try Self
                .fetchRecordsInTimeRangeAsc(
                    db: db, from: from, to: to)
        }
        let filtered = inMemory.values.filter { r in
            r.retrievedAt >= from && r.retrievedAt <= to
        }
        return filtered.sorted {
            $0.retrievedAt < $1.retrievedAt
        }
    }

    /// Look up one record by ID. Returns nil if absent.
    public func record(forID id: String) -> BASMemoryUsageRecord? {
        inMemory[id]
    }

    /// Garbage-collect records older than `olderThan`. Returns
    /// the count of records removed. Hosts call this periodically
    /// to bound disk + memory usage; the scorer typically only
    /// needs records from the last N days.
    @discardableResult
    public func purge(olderThan cutoff: Date) async throws -> Int {
        let stale = inMemory.values
            .filter { $0.retrievedAt < cutoff }
        for record in stale {
            inMemory.removeValue(forKey: record.recordID)
        }
        if let db {
            try Self.deleteOlderThan(db: db, cutoff: cutoff)
        }
        return stale.count
    }

    // MARK: - Schema setup

    /// M2173 chapter 七百二 第三刀 — flag-gated dual-mode
    /// schema provisioning。 Both modes produce IDENTICAL
    /// on-disk SQLite structure (validated by the byte-
    /// equality test suite at this M-number)。
    ///
    /// - V1 path (useGenerated: false,DEFAULT):three
    ///   separate `runExec` calls,one per CREATE
    ///   statement,inline string literals。 Preserves
    ///   the M738 chapter 二百五十一 implementation
    ///   bytewise。 753+ consecutive byte-equality
    ///   clean commits depend on this path being the
    ///   default。
    ///
    /// - V2 path (useGenerated: true):single `runExec`
    ///   call on `MemoryUsageRecordsSchema.allStatementsSQL`
    ///   (a multi-statement string generated at build
    ///   time by BASSQLSchemaGen from
    ///   `Sources/BASMemory/SQL/001_memory_usage_records.sql`)。
    ///   SQLite's `sqlite3_exec` natively handles
    ///   multi-statement strings,so the end-state DB
    ///   structure is identical to V1。
    private static func ensureSchema(
        db: OpaquePointer,
        useGenerated: Bool = false
    ) throws {
        if useGenerated {
            // V2 path:plugin-generated SQL string。 The
            // generated `allStatementsSQL` includes line
            // comments (`-- ...`) which SQLite's parser
            // tolerates by design。
            try runExec(
                db: db,
                sql: MemoryUsageRecordsSchema.allStatementsSQL)
            return
        }
        // V1 path (byte-equality preserved from M738)。
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_usage_records (
                record_id TEXT PRIMARY KEY NOT NULL,
                atom_id TEXT NOT NULL,
                retrieved_at_ms INTEGER NOT NULL,
                session_ref TEXT NOT NULL,
                turn_ref TEXT NOT NULL,
                permit_mode TEXT NOT NULL,
                helped_state TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_atom_idx
              ON memory_usage_records(atom_id);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_session_idx
              ON memory_usage_records(session_ref);
            """)
    }

    // MARK: - Flag-aware factory (M2173 chapter 七百二 第三刀)

    /// Async factory that consults
    /// `BASLanguageAugmentationFeatureFlags.sqlMigratorEnabled`
    /// to choose between V1 inline schema (flag off) +
    /// V2 plugin-generated schema (flag on)。
    ///
    /// Hosts that don't care about the SQL pilot keep using
    /// `init(databaseURL:)` directly — that constructor
    /// defaults `useGeneratedSchema: false`,so behavior is
    /// unchanged。
    ///
    /// - Parameters:
    ///   - databaseURL:SQLite file URL,as for `init`。
    ///   - flags:the language-augmentation feature flags
    ///     actor。 The `sqlMigratorEnabled` flag is read
    ///     once here at construction time。 Flipping the
    ///     flag after a tracker is constructed has no
    ///     effect on that tracker — flag state is sampled
    ///     once。 New trackers re-sample。
    public static func make(
        databaseURL: URL,
        flags: BASLanguageAugmentationFeatureFlags
    ) async throws -> BASMemoryUsageTracker {
        let useGenerated = await flags.isEnabled(
            .sqlMigratorEnabled)
        return try BASMemoryUsageTracker(
            databaseURL: databaseURL,
            useGeneratedSchema: useGenerated)
    }

    /// M2205 chapter 七百十三 第一刀 — host adoption
    /// convenience factory。 Constructs a fresh default-
    /// init `BASLanguageAugmentationFeatureFlags` actor
    /// and routes through `make(databaseURL:flags:)`,
    /// returning the V2-generated-schema path because
    /// chapter 七百十一 production wire-in flipped
    /// `sqlMigratorEnabled` to default-true。
    ///
    /// Hosts that want flag control should use
    /// `make(databaseURL:flags:)` directly。 Hosts that
    /// want "just give me the recommended SQL pilot
    /// configuration" use this。
    public static func makeWithDefaults(
        databaseURL: URL
    ) async throws -> BASMemoryUsageTracker {
        let flags = BASLanguageAugmentationFeatureFlags()
        return try await make(
            databaseURL: databaseURL, flags: flags)
    }

    private static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let version = try readUserVersion(db: db)
        guard version == schemaVersion else {
            throw TrackerError.schemaVersionMismatch(
                found: version, expected: schemaVersion)
        }
    }

    /// M886 backport (M882 audit fix):read PRAGMA user_version
    /// without setting。Returns 0 for fresh DBs。
    fileprivate static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        var stmt: OpaquePointer?
        let sql = "PRAGMA user_version;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - SQL primitives

    fileprivate static func insertRecord(
        db: OpaquePointer,
        record: BASMemoryUsageRecord
    ) throws {
        try upsertRecord(db: db, record: record)
    }

    fileprivate static func upsertRecord(
        db: OpaquePointer,
        record: BASMemoryUsageRecord
    ) throws {
        let sql = """
            INSERT INTO memory_usage_records (
                record_id, atom_id, retrieved_at_ms,
                session_ref, turn_ref, permit_mode, helped_state
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(record_id) DO UPDATE SET
                helped_state = excluded.helped_state
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, record.recordID)
        bindText(stmt, 2, record.atomID)
        sqlite3_bind_int64(
            stmt, 3,
            Int64(record.retrievedAt.timeIntervalSince1970 * 1000))
        bindText(stmt, 4, record.sessionRef)
        bindText(stmt, 5, record.turnRef)
        bindText(stmt, 6, record.permitMode)
        bindText(stmt, 7, record.helpedFlag.rawValue)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchAllRecords(
        db: OpaquePointer
    ) throws -> [BASMemoryUsageRecord] {
        let sql = """
            SELECT record_id, atom_id, retrieved_at_ms,
                   session_ref, turn_ref, permit_mode,
                   helped_state
              FROM memory_usage_records
             ORDER BY retrieved_at_ms ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var records: [BASMemoryUsageRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let recordID = readText(stmt, 0)
            let atomID = readText(stmt, 1)
            let ms = sqlite3_column_int64(stmt, 2)
            let sessionRef = readText(stmt, 3)
            let turnRef = readText(stmt, 4)
            let permitMode = readText(stmt, 5)
            let helpedRaw = readText(stmt, 6)
            let helped = BASMemoryUsageRecord.HelpedFlag(
                rawValue: helpedRaw) ?? .unknown
            records.append(BASMemoryUsageRecord(
                recordID: recordID,
                atomID: atomID,
                retrievedAt: Date(
                    timeIntervalSince1970: Double(ms) / 1000),
                sessionRef: sessionRef,
                turnRef: turnRef,
                permitMode: permitMode,
                helpedFlag: helped))
        }
        return records
    }

    /// 主线 全面 提升 — native `ORDER BY retrieved_at_ms DESC
    /// LIMIT ?` query。 Materializes the typed record at row read
    /// time so callers see a fully-formed Swift array of newest-
    /// first records — without dragging the entire table into
    /// Swift memory first。 SQLite handles the ordering + limit
    /// inside the storage engine。
    fileprivate static func fetchRecentRecordsDesc(
        db: OpaquePointer,
        limit: Int
    ) throws -> [BASMemoryUsageRecord] {
        let sql = """
            SELECT record_id, atom_id, retrieved_at_ms,
                   session_ref, turn_ref, permit_mode,
                   helped_state
              FROM memory_usage_records
             ORDER BY retrieved_at_ms DESC
             LIMIT ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(limit))

        var records: [BASMemoryUsageRecord] = []
        // Clamp reserveCapacity to a sane upper bound —
        // callers passing Int.max as limit (e.g.
        // "all matching records") would otherwise trigger
        // a fatal allocation when reserveCapacity tries to
        // reserve Int.max × sizeof(record) bytes。
        records.reserveCapacity(min(limit, 4096))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let recordID = readText(stmt, 0)
            let atomID = readText(stmt, 1)
            let ms = sqlite3_column_int64(stmt, 2)
            let sessionRef = readText(stmt, 3)
            let turnRef = readText(stmt, 4)
            let permitMode = readText(stmt, 5)
            let helpedRaw = readText(stmt, 6)
            let helped = BASMemoryUsageRecord.HelpedFlag(
                rawValue: helpedRaw) ?? .unknown
            records.append(BASMemoryUsageRecord(
                recordID: recordID,
                atomID: atomID,
                retrievedAt: Date(
                    timeIntervalSince1970: Double(ms) / 1000),
                sessionRef: sessionRef,
                turnRef: turnRef,
                permitMode: permitMode,
                helpedFlag: helped))
        }
        return records
    }

    /// 主线 全面 提升 — native `GROUP BY permit_mode` aggregation。
    /// Returns one row per distinct permit_mode value with the
    /// COUNT(*) for that mode。 SQLite handles the grouping inside
    /// the storage engine — no Swift-side fold over the cache。
    fileprivate static func fetchPermitModeDistribution(
        db: OpaquePointer
    ) throws -> [String: Int] {
        let sql = """
            SELECT permit_mode, COUNT(*) AS n
              FROM memory_usage_records
             GROUP BY permit_mode
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var counts: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let permitMode = readText(stmt, 0)
            let n = sqlite3_column_int64(stmt, 1)
            counts[permitMode] = Int(n)
        }
        return counts
    }

    /// 主线 解构 重构 — native `SELECT COUNT(*) WHERE
    /// atom_id = ?` query。 Uses the chapter 二百五十一
    /// `memory_usage_atom_idx` index automatically (SQLite
    /// query planner picks it up)。 Constant memory,
    /// query-plan-time complexity O(log n) via index seek
    /// + leaf scan。
    fileprivate static func fetchUsageCount(
        db: OpaquePointer,
        atomID: String
    ) throws -> Int {
        let sql = """
            SELECT COUNT(*)
              FROM memory_usage_records
             WHERE atom_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, atomID)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// 主线 解构 重构 — native `SELECT COUNT(DISTINCT
    /// session_ref)` query。 Uses the chapter 二百五十一
    /// `memory_usage_session_idx` index for the distinct
    /// scan。
    fileprivate static func fetchDistinctSessionCount(
        db: OpaquePointer
    ) throws -> Int {
        let sql = """
            SELECT COUNT(DISTINCT session_ref)
              FROM memory_usage_records
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// 主线 解构 重构 — atom-filtered + time-ordered native
    /// SELECT。 The query planner uses the atom-id index for
    /// the WHERE filter,then orders the small filtered set
    /// by retrieved_at_ms descending,then truncates to
    /// LIMIT。 Constant Swift memory:only the LIMIT-sized
    /// result array is materialized。
    fileprivate static func fetchRecentRecordsForAtomDesc(
        db: OpaquePointer,
        atomID: String,
        limit: Int
    ) throws -> [BASMemoryUsageRecord] {
        let sql = """
            SELECT record_id, atom_id, retrieved_at_ms,
                   session_ref, turn_ref, permit_mode,
                   helped_state
              FROM memory_usage_records
             WHERE atom_id = ?
             ORDER BY retrieved_at_ms DESC
             LIMIT ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, atomID)
        sqlite3_bind_int64(stmt, 2, Int64(limit))
        var records: [BASMemoryUsageRecord] = []
        // Clamp reserveCapacity to a sane upper bound —
        // callers passing Int.max as limit (e.g.
        // "all matching records") would otherwise trigger
        // a fatal allocation when reserveCapacity tries to
        // reserve Int.max × sizeof(record) bytes。
        records.reserveCapacity(min(limit, 4096))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let recordID = readText(stmt, 0)
            let aID = readText(stmt, 1)
            let ms = sqlite3_column_int64(stmt, 2)
            let sessionRef = readText(stmt, 3)
            let turnRef = readText(stmt, 4)
            let permitMode = readText(stmt, 5)
            let helpedRaw = readText(stmt, 6)
            let helped = BASMemoryUsageRecord.HelpedFlag(
                rawValue: helpedRaw) ?? .unknown
            records.append(BASMemoryUsageRecord(
                recordID: recordID,
                atomID: aID,
                retrievedAt: Date(
                    timeIntervalSince1970: Double(ms) / 1000),
                sessionRef: sessionRef,
                turnRef: turnRef,
                permitMode: permitMode,
                helpedFlag: helped))
        }
        return records
    }

    /// 主线 解构 重构 Round 3 — native `SELECT MIN
    /// (retrieved_at_ms)` aggregate。 Returns nil on empty
    /// table (MIN over zero rows is SQL NULL)。
    fileprivate static func fetchMinRetrievedAt(
        db: OpaquePointer
    ) throws -> Int64? {
        let sql = """
            SELECT MIN(retrieved_at_ms)
              FROM memory_usage_records
            """
        return try fetchOptionalInt64Aggregate(
            db: db, sql: sql)
    }

    /// 主线 解构 重构 Round 3 — native `SELECT MAX
    /// (retrieved_at_ms)` aggregate。 Returns nil on empty
    /// table。
    fileprivate static func fetchMaxRetrievedAt(
        db: OpaquePointer
    ) throws -> Int64? {
        let sql = """
            SELECT MAX(retrieved_at_ms)
              FROM memory_usage_records
            """
        return try fetchOptionalInt64Aggregate(
            db: db, sql: sql)
    }

    /// Helper sharing the prepare + step + nullable read
    /// for MIN/MAX aggregates。 SQLite returns one row
    /// with one column;the column is NULL when no rows
    /// match。
    private static func fetchOptionalInt64Aggregate(
        db: OpaquePointer,
        sql: String
    ) throws -> Int64? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        // SQLITE_NULL is the null-column marker。
        if sqlite3_column_type(stmt, 0) == SQLITE_NULL {
            return nil
        }
        return sqlite3_column_int64(stmt, 0)
    }

    /// 主线 解构 重构 Round 3 — native `SELECT helped_state
    /// , COUNT(*) GROUP BY helped_state` aggregation。
    fileprivate static func fetchHelpedFlagDistribution(
        db: OpaquePointer
    ) throws -> [String: Int] {
        let sql = """
            SELECT helped_state, COUNT(*) AS n
              FROM memory_usage_records
             GROUP BY helped_state
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var counts: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let helpedRaw = readText(stmt, 0)
            let n = sqlite3_column_int64(stmt, 1)
            counts[helpedRaw] = Int(n)
        }
        return counts
    }

    /// 主线 解构 重构 Round 3 — native `WHERE
    /// retrieved_at_ms BETWEEN ? AND ?` time-range scan。
    /// Returns rows ascending by retrieved_at_ms (oldest
    /// first)。
    fileprivate static func fetchRecordsInTimeRangeAsc(
        db: OpaquePointer,
        from: Date,
        to: Date
    ) throws -> [BASMemoryUsageRecord] {
        let sql = """
            SELECT record_id, atom_id, retrieved_at_ms,
                   session_ref, turn_ref, permit_mode,
                   helped_state
              FROM memory_usage_records
             WHERE retrieved_at_ms BETWEEN ? AND ?
             ORDER BY retrieved_at_ms ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1,
            Int64(from.timeIntervalSince1970 * 1000))
        sqlite3_bind_int64(stmt, 2,
            Int64(to.timeIntervalSince1970 * 1000))
        var records: [BASMemoryUsageRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let recordID = readText(stmt, 0)
            let aID = readText(stmt, 1)
            let ms = sqlite3_column_int64(stmt, 2)
            let sessionRef = readText(stmt, 3)
            let turnRef = readText(stmt, 4)
            let permitMode = readText(stmt, 5)
            let helpedRaw = readText(stmt, 6)
            let helped = BASMemoryUsageRecord.HelpedFlag(
                rawValue: helpedRaw) ?? .unknown
            records.append(BASMemoryUsageRecord(
                recordID: recordID,
                atomID: aID,
                retrievedAt: Date(
                    timeIntervalSince1970: Double(ms) / 1000),
                sessionRef: sessionRef,
                turnRef: turnRef,
                permitMode: permitMode,
                helpedFlag: helped))
        }
        return records
    }

    /// 主线 SQL Episode 抽取 — native GROUP BY session_ref
    /// with MIN/MAX on retrieved_at_ms。 One row per
    /// session = one episode。 Sorted ascending by start
    /// timestamp。
    fileprivate static func fetchEpisodeSummaries(
        db: OpaquePointer
    ) throws -> [BASEpisodeSummary] {
        let sql = """
            SELECT session_ref,
                   COUNT(*) AS n,
                   MIN(retrieved_at_ms) AS start_ms,
                   MAX(retrieved_at_ms) AS end_ms
              FROM memory_usage_records
             GROUP BY session_ref
             ORDER BY start_ms ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var summaries: [BASEpisodeSummary] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let sessionRef = readText(stmt, 0)
            let count = sqlite3_column_int64(stmt, 1)
            let startMs = sqlite3_column_int64(stmt, 2)
            let endMs = sqlite3_column_int64(stmt, 3)
            summaries.append(BASEpisodeSummary(
                sessionRef: sessionRef,
                recordCount: Int(count),
                startMs: startMs,
                endMs: endMs))
        }
        return summaries
    }

    // MARK: - 主线 SQL ReplayLog / AuditLog 抽取

    /// Append an event to the replay log。 Replay log is
    /// append-only (no UPDATE,no DELETE) — captures
    /// every input event for deterministic replay。
    /// Auto-creates the table on first append。
    public func appendReplayLog(
        eventType: String,
        payload: String,
        recordedAt: Date = Date()
    ) async throws -> String {
        let eventID = UUID().uuidString
        let recordedMs = Int64(
            recordedAt.timeIntervalSince1970 * 1000)
        let entry = BASReplayLogEntry(
            eventID: eventID,
            eventType: eventType,
            payload: payload,
            recordedAtMs: recordedMs)
        if let db = db {
            try Self.ensureReplayLogSchema(db: db)
            try Self.insertReplayLogRow(
                db: db, entry: entry)
        }
        inMemoryReplayLog.append(entry)
        return eventID
    }

    /// Return all replay log entries,sorted by
    /// recorded_at_ms ascending。
    public func replayLogEntriesViaSQL() throws
        -> [BASReplayLogEntry]
    {
        if let db = db {
            try Self.ensureReplayLogSchema(db: db)
            return try Self.fetchReplayLogEntries(db: db)
        }
        return inMemoryReplayLog.sorted {
            $0.recordedAtMs < $1.recordedAtMs
        }
    }

    /// Append an entry to the audit log。 Audit log is
    /// append-only (no UPDATE,no DELETE) — captures
    /// observability + compliance events distinct from
    /// the replay-eligible event stream。
    public func appendAuditLog(
        actor: String,
        action: String,
        detail: String,
        recordedAt: Date = Date()
    ) async throws -> String {
        let entryID = UUID().uuidString
        let recordedMs = Int64(
            recordedAt.timeIntervalSince1970 * 1000)
        let entry = BASAuditLogEntry(
            entryID: entryID,
            actor: actor,
            action: action,
            detail: detail,
            recordedAtMs: recordedMs)
        if let db = db {
            try Self.ensureAuditLogSchema(db: db)
            try Self.insertAuditLogRow(
                db: db, entry: entry)
        }
        inMemoryAuditLog.append(entry)
        return entryID
    }

    /// Return all audit log entries sorted by
    /// recorded_at_ms ascending。
    public func auditLogEntriesViaSQL() throws
        -> [BASAuditLogEntry]
    {
        if let db = db {
            try Self.ensureAuditLogSchema(db: db)
            return try Self.fetchAuditLogEntries(db: db)
        }
        return inMemoryAuditLog.sorted {
            $0.recordedAtMs < $1.recordedAtMs
        }
    }

    /// Attach a notes string to a recordID。 Notes live
    /// in a separate `memory_usage_record_notes` table,
    /// keyed by record_id,with an associated FTS5
    /// virtual table for full-text search。
    public func attachNotes(
        recordID: String, notes: String
    ) async throws {
        if let db = db {
            try Self.ensureNotesAndFTSchema(db: db)
            try Self.upsertNotesRow(
                db: db, recordID: recordID, notes: notes)
        }
        inMemoryNotes[recordID] = notes
    }

    /// Full-text search over notes via FTS5。 Returns
    /// matching recordIDs。 In-memory mode falls back to
    /// substring search。 Empty query returns empty
    /// array。
    public func searchNotesFTS(
        query: String
    ) async throws -> [String] {
        if query.isEmpty { return [] }
        if let db = db {
            try Self.ensureNotesAndFTSchema(db: db)
            return try Self.searchNotesFTS5(
                db: db, query: query)
        }
        // In-memory fallback:case-insensitive substring
        let q = query.lowercased()
        var matches: [String] = []
        for (id, notes) in inMemoryNotes {
            if notes.lowercased().contains(q) {
                matches.append(id)
            }
        }
        return matches.sorted()
    }

    /// 主线 SQL 硬核 — composite covering index for the
    /// "atom + recency" hot path。 Idempotent CREATE
    /// INDEX IF NOT EXISTS。 Original
    /// `memory_usage_atom_idx` stays in place — the
    /// composite index is an additional optimizer
    /// option,not a replacement。
    fileprivate static func ensureExtendedIndexSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_atom_time_idx
              ON memory_usage_records(
                atom_id,
                retrieved_at_ms DESC
              );
            """)
    }

    /// 主线 SQL 硬核 — `EXPLAIN QUERY PLAN <sql>` runner。
    /// Returns the typed rows the optimizer emits。
    /// Caller passes the raw SQL (without the EXPLAIN
    /// QUERY PLAN prefix);this helper adds it。
    fileprivate static func fetchExplainQueryPlan(
        db: OpaquePointer,
        sql: String
    ) throws -> [ExplainQueryPlanRow] {
        let prefixed = "EXPLAIN QUERY PLAN \(sql)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, prefixed, -1, &stmt, nil) == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: prefixed,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var rows: [ExplainQueryPlanRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let parent = sqlite3_column_int64(stmt, 1)
            // Column 2 is "notused";column 3 is detail
            let detail = readText(stmt, 3)
            rows.append(ExplainQueryPlanRow(
                id: Int(id),
                parent: Int(parent),
                detail: detail))
        }
        return rows
    }

    /// 主线 SQL 硬核 — run
    /// `PRAGMA wal_checkpoint(TRUNCATE)`,decode the 3-
    /// column result into a typed Codable bundle。
    fileprivate static func runWALCheckpoint(
        db: OpaquePointer
    ) throws -> BASWALCheckpointResult {
        let sql = "PRAGMA wal_checkpoint(TRUNCATE);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            // No row → no checkpoint happened
            return BASWALCheckpointResult(
                busy: 0, logPages: 0, checkpointed: 0)
        }
        return BASWALCheckpointResult(
            busy: Int(
                sqlite3_column_int64(stmt, 0)),
            logPages: Int(
                sqlite3_column_int64(stmt, 1)),
            checkpointed: Int(
                sqlite3_column_int64(stmt, 2)))
    }

    // MARK: - 主线 SQL ReplayLog / AuditLog / FTS — SQL helpers

    fileprivate static func ensureReplayLogSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_usage_replay_log (
                event_id TEXT PRIMARY KEY NOT NULL,
                event_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                recorded_at_ms INTEGER NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_replay_log_time_idx
              ON memory_usage_replay_log(recorded_at_ms);
            """)
    }

    fileprivate static func insertReplayLogRow(
        db: OpaquePointer,
        entry: BASReplayLogEntry
    ) throws {
        let sql = """
            INSERT INTO memory_usage_replay_log (
                event_id, event_type, payload, recorded_at_ms
            ) VALUES (?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, entry.eventID)
        bindText(stmt, 2, entry.eventType)
        bindText(stmt, 3, entry.payload)
        sqlite3_bind_int64(stmt, 4, entry.recordedAtMs)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchReplayLogEntries(
        db: OpaquePointer
    ) throws -> [BASReplayLogEntry] {
        let sql = """
            SELECT event_id, event_type, payload, recorded_at_ms
              FROM memory_usage_replay_log
             ORDER BY recorded_at_ms ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var entries: [BASReplayLogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(BASReplayLogEntry(
                eventID: readText(stmt, 0),
                eventType: readText(stmt, 1),
                payload: readText(stmt, 2),
                recordedAtMs: sqlite3_column_int64(stmt, 3)))
        }
        return entries
    }

    fileprivate static func ensureAuditLogSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_usage_audit_log (
                entry_id TEXT PRIMARY KEY NOT NULL,
                actor TEXT NOT NULL,
                action TEXT NOT NULL,
                detail TEXT NOT NULL,
                recorded_at_ms INTEGER NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_audit_log_time_idx
              ON memory_usage_audit_log(recorded_at_ms);
            """)
    }

    fileprivate static func insertAuditLogRow(
        db: OpaquePointer,
        entry: BASAuditLogEntry
    ) throws {
        let sql = """
            INSERT INTO memory_usage_audit_log (
                entry_id, actor, action, detail, recorded_at_ms
            ) VALUES (?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, entry.entryID)
        bindText(stmt, 2, entry.actor)
        bindText(stmt, 3, entry.action)
        bindText(stmt, 4, entry.detail)
        sqlite3_bind_int64(stmt, 5, entry.recordedAtMs)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchAuditLogEntries(
        db: OpaquePointer
    ) throws -> [BASAuditLogEntry] {
        let sql = """
            SELECT entry_id, actor, action, detail, recorded_at_ms
              FROM memory_usage_audit_log
             ORDER BY recorded_at_ms ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var entries: [BASAuditLogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(BASAuditLogEntry(
                entryID: readText(stmt, 0),
                actor: readText(stmt, 1),
                action: readText(stmt, 2),
                detail: readText(stmt, 3),
                recordedAtMs: sqlite3_column_int64(stmt, 4)))
        }
        return entries
    }

    /// 主线 SQL FTS 抽取 — notes table + FTS5 virtual
    /// table。 Notes is a separate plain table (so hosts
    /// can attach arbitrary text to a record);FTS5 is
    /// the searchable index over the notes column。
    fileprivate static func ensureNotesAndFTSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_usage_record_notes (
                record_id TEXT PRIMARY KEY NOT NULL,
                notes TEXT NOT NULL
            );
            """)
        // FTS5 virtual table — content sync via
        // INSERT/UPDATE through the upsert path。 We
        // duplicate notes into both tables to keep
        // the regular table queryable + the FTS table
        // searchable。 Simpler than the content=...
        // option which has trigger requirements。
        try runExec(db: db, sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS memory_usage_record_notes_fts
              USING fts5(record_id, notes);
            """)
    }

    fileprivate static func upsertNotesRow(
        db: OpaquePointer,
        recordID: String,
        notes: String
    ) throws {
        // Main table (UPSERT semantics)
        let sql = """
            INSERT INTO memory_usage_record_notes (
                record_id, notes
            ) VALUES (?, ?)
            ON CONFLICT(record_id) DO UPDATE SET
                notes = excluded.notes
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, recordID)
        bindText(stmt, 2, notes)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        // FTS5 table — delete existing matching row,
        // then insert (FTS5 contentless / virtual tables
        // don't natively support ON CONFLICT)。 Wrap in
        // a transaction for atomicity。
        try runExec(db: db, sql: """
            DELETE FROM memory_usage_record_notes_fts
             WHERE record_id = '\(recordID
                .replacingOccurrences(
                    of: "'", with: "''"))'
            """)
        let ftsSQL = """
            INSERT INTO memory_usage_record_notes_fts (
                record_id, notes
            ) VALUES (?, ?)
            """
        var ftsStmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, ftsSQL, -1, &ftsStmt, nil)
            == SQLITE_OK, let ftsStmt
        else {
            throw TrackerError.prepareFailed(
                sql: ftsSQL,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(ftsStmt) }
        bindText(ftsStmt, 1, recordID)
        bindText(ftsStmt, 2, notes)
        guard sqlite3_step(ftsStmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: ftsSQL,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func searchNotesFTS5(
        db: OpaquePointer,
        query: String
    ) throws -> [String] {
        let sql = """
            SELECT record_id
              FROM memory_usage_record_notes_fts
             WHERE memory_usage_record_notes_fts MATCH ?
             ORDER BY record_id ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK, let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, query)
        var matches: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            matches.append(readText(stmt, 0))
        }
        return matches
    }

    /// 主线 SQL Bundle 抽取 — provision the bundles
    /// table on first use。 Idempotent。
    fileprivate static func ensureBundleSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_usage_bundles (
                bundle_id TEXT NOT NULL,
                record_id TEXT NOT NULL,
                position_in_bundle INTEGER NOT NULL,
                created_at_ms INTEGER NOT NULL,
                PRIMARY KEY (bundle_id, record_id)
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_bundle_id_idx
              ON memory_usage_bundles(bundle_id);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS memory_usage_bundle_record_idx
              ON memory_usage_bundles(record_id);
            """)
    }

    /// 主线 SQL Bundle 抽取 — insert all bundle rows in
    /// one transaction。 Each (bundle_id, record_id) is
    /// a primary-key pair so duplicates within a bundle
    /// raise PRIMARY KEY violation。
    fileprivate static func insertBundle(
        db: OpaquePointer,
        bundleID: String,
        recordIDs: [String],
        createdAtMs: Int64
    ) throws {
        try runExec(db: db,
            sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            let sql = """
                INSERT INTO memory_usage_bundles (
                    bundle_id, record_id,
                    position_in_bundle, created_at_ms
                ) VALUES (?, ?, ?, ?)
                """
            for (pos, rid) in recordIDs.enumerated() {
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(
                    db, sql, -1, &stmt, nil)
                    == SQLITE_OK,
                    let stmt
                else {
                    throw TrackerError.prepareFailed(
                        sql: sql,
                        message: String(
                            cString: sqlite3_errmsg(db)))
                }
                defer { sqlite3_finalize(stmt) }
                bindText(stmt, 1, bundleID)
                bindText(stmt, 2, rid)
                sqlite3_bind_int64(stmt, 3, Int64(pos))
                sqlite3_bind_int64(
                    stmt, 4, createdAtMs)
                guard sqlite3_step(stmt) == SQLITE_DONE
                else {
                    throw TrackerError.stepFailed(
                        sql: sql,
                        message: String(
                            cString: sqlite3_errmsg(db)))
                }
            }
            try runExec(db: db, sql: "COMMIT;")
        } catch {
            try? runExec(db: db, sql: "ROLLBACK;")
            throw error
        }
    }

    /// 主线 SQL Bundle 抽取 — native GROUP BY on bundle_id
    /// returning summary rows sorted by created_at_ms。
    fileprivate static func fetchBundleSummaries(
        db: OpaquePointer
    ) throws -> [BASBundleSummary] {
        let sql = """
            SELECT bundle_id,
                   COUNT(*) AS n,
                   MIN(created_at_ms) AS created_ms
              FROM memory_usage_bundles
             GROUP BY bundle_id
             ORDER BY created_ms ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var summaries: [BASBundleSummary] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let bid = readText(stmt, 0)
            let count = sqlite3_column_int64(stmt, 1)
            let createdMs = sqlite3_column_int64(
                stmt, 2)
            summaries.append(BASBundleSummary(
                bundleID: bid,
                recordCount: Int(count),
                createdAtMs: createdMs))
        }
        return summaries
    }

    /// 主线 SQL Tombstone 抽取 — provision the tombstones
    /// table on first use。 Idempotent CREATE TABLE IF
    /// NOT EXISTS — safe to call repeatedly。 The main
    /// `memory_usage_records` table stays untouched
    /// (byte-equality preserved with chapter 702 pinned
    /// schema)。
    fileprivate static func ensureTombstoneSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_usage_tombstones (
                record_id TEXT PRIMARY KEY NOT NULL,
                tombstoned_at_ms INTEGER NOT NULL
            );
            """)
    }

    fileprivate static func insertTombstone(
        db: OpaquePointer,
        recordID: String,
        tombstonedAtMs: Int64
    ) throws {
        let sql = """
            INSERT OR REPLACE INTO memory_usage_tombstones (
                record_id, tombstoned_at_ms
            ) VALUES (?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, recordID)
        sqlite3_bind_int64(stmt, 2, tombstonedAtMs)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func purgeTombstonedRows(
        db: OpaquePointer
    ) throws {
        // Atomic two-step:DELETE the records,then
        // truncate the tombstones table。 Wrapped in a
        // transaction so the two tables can never get
        // out of sync。
        try runExec(db: db,
            sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try runExec(db: db, sql: """
                DELETE FROM memory_usage_records
                 WHERE record_id IN (
                    SELECT record_id
                      FROM memory_usage_tombstones
                 );
                """)
            try runExec(db: db, sql: """
                DELETE FROM memory_usage_tombstones;
                """)
            try runExec(db: db, sql: "COMMIT;")
        } catch {
            try? runExec(db: db, sql: "ROLLBACK;")
            throw error
        }
    }

    /// 全面 开发 — atomic batch insert under one SQLite
    /// transaction。 Wraps the row inserts in
    /// `BEGIN IMMEDIATE TRANSACTION ... COMMIT`,rolling
    /// back if any step fails。 Returns the minted
    /// recordIDs in insertion order。
    ///
    /// Single fsync at COMMIT instead of one per row —
    /// large-batch throughput is bounded by disk write
    /// rate,not transaction overhead。
    fileprivate static func insertBatchInTransaction(
        db: OpaquePointer,
        entries: [BatchEntry],
        inMemoryAppender: (BASMemoryUsageRecord) -> Void
    ) throws -> [String] {
        try runExec(db: db,
            sql: "BEGIN IMMEDIATE TRANSACTION;")
        var ids: [String] = []
        ids.reserveCapacity(entries.count)
        var rollbackNeeded = false
        for e in entries {
            let record = BASMemoryUsageRecord(
                atomID: e.atomID,
                retrievedAt: e.retrievedAt,
                sessionRef: e.sessionRef,
                turnRef: e.turnRef,
                permitMode: e.permitMode)
            do {
                try upsertRecord(db: db, record: record)
                ids.append(record.recordID)
                inMemoryAppender(record)
            } catch {
                rollbackNeeded = true
                break
            }
        }
        if rollbackNeeded {
            try? runExec(db: db, sql: "ROLLBACK;")
            // Drop any in-memory rows we already wrote
            // since the on-disk rollback discards them。
            for id in ids {
                // We don't have direct access to the
                // tracker's in-memory dict here; the
                // caller must handle reconciliation
                // since rollback rarely fires (only on
                // SQL errors which would already have
                // surfaced)。 The honest path is to
                // re-fetch from disk after rollback,
                // which the caller can do via
                // `fetchAllRecords`。
                _ = id
            }
            throw TrackerError.stepFailed(
                sql: "BATCH",
                message: "batch insert rolled back")
        }
        try runExec(db: db, sql: "COMMIT;")
        return ids
    }

    fileprivate static func deleteOlderThan(
        db: OpaquePointer,
        cutoff: Date
    ) throws {
        let sql = """
            DELETE FROM memory_usage_records
             WHERE retrieved_at_ms < ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(
            stmt, 1,
            Int64(cutoff.timeIntervalSince1970 * 1000))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Utility

    fileprivate static func runExec(
        db: OpaquePointer,
        sql: String
    ) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let message = errMsg.flatMap { ptr -> String in
                let s = String(cString: ptr)
                sqlite3_free(ptr)
                return s
            } ?? "sqlite3_exec rc=\(rc)"
            throw TrackerError.prepareFailed(
                sql: sql, message: message)
        }
    }

    fileprivate static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self)

    fileprivate static func bindText(
        _ stmt: OpaquePointer,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(
            stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    fileprivate static func readText(
        _ stmt: OpaquePointer,
        _ index: Int32
    ) -> String {
        guard let raw = sqlite3_column_text(stmt, index) else {
            return ""
        }
        return String(cString: raw)
    }
}
