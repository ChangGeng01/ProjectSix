// MARK: - BASMemoryUsageTracker SQL core (tombstone · index-driven hardcore · native query paths · schema)
// chapter 一千〇四十 / WS-backlog-decomp — relocated extension cluster (god-object split). byte-equal.

import Foundation
import SQLite3
import BASRuntimeCore

extension BASMemoryUsageTracker {
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
    /// chapter 七百二十三 第四刀 / M2289 feature flag —
    /// selects between the legacy per-row prepared-statement
    /// loop (`insertBatchInTransaction`) and the new
    /// multi-row INSERT path (`insertBatchMultiRow`)。
    ///
    /// Default flipped to TRUE per chapter 七百二十三 第四刀
    /// measurement (1.63× speedup at 500-row batch,above the
    /// 1.5× decision threshold)。 Per chapter 七百十六 byte-
    /// equality discipline both paths produce identical row
    /// state — Swift test pins this via
    /// `testLegacyAndMultiRowProduceIdenticalRows`。
    ///
    /// Hosts that prefer the legacy path can flip to false at
    /// process startup。
    public nonisolated(unsafe) static var
        useMultiRowInsertBatch: Bool = true

    @discardableResult
    public func recordBatch(
        _ entries: [BatchEntry]
    ) async throws -> [String] {
        if entries.isEmpty { return [] }
        if let db {
            if Self.useMultiRowInsertBatch {
                // chapter 七百二十三 第四刀 path
                return try Self.insertBatchMultiRow(
                    db: db,
                    entries: entries,
                    inMemoryAppender: { record in
                        inMemory[record.recordID] = record
                    })
            }
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
    static func ensureSchema(
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

}
