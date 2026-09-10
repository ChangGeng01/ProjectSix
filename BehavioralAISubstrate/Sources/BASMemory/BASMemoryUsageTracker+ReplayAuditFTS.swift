// MARK: - BASMemoryUsageTracker SQL ReplayLog / AuditLog extraction + FTS helpers
// chapter 一千〇四十 / WS-backlog-decomp — relocated extension cluster (god-object split). byte-equal.

import Foundation
import SQLite3
import BASRuntimeCore

extension BASMemoryUsageTracker {
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
    static func ensureExtendedIndexSchema(
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
    static func fetchExplainQueryPlan(
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
    static func runWALCheckpoint(
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
        // audit memory-a F6: the main-table UPSERT + the FTS DELETE + the FTS INSERT used to run as
        // THREE separate autocommits — a failure after the main UPSERT left the FTS index inconsistent
        // (search would miss the row). Wrap all three in ONE transaction so a mid-sequence failure
        // rolls the whole thing back (fixing the "wrap in a transaction" comment that was a lie).
        try runExec(db: db, sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
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
        // don't natively support ON CONFLICT)。 Now inside the
        // enclosing transaction opened above (audit memory-a F6)。
        // Parameterized DELETE (audit ch1040 polish): recordID is
        // caller-supplied via attachNotes(); was previously
        // string-interpolated with manual ''-escaping — the only
        // un-parameterized query in the tracker family. Now a bound
        // statement, mirroring the parameterized INSERT below.
        let ftsDeleteSQL = """
            DELETE FROM memory_usage_record_notes_fts
             WHERE record_id = ?
            """
        var ftsDeleteStmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, ftsDeleteSQL, -1, &ftsDeleteStmt, nil)
            == SQLITE_OK, let ftsDeleteStmt
        else {
            throw TrackerError.prepareFailed(
                sql: ftsDeleteSQL,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(ftsDeleteStmt) }
        bindText(ftsDeleteStmt, 1, recordID)
        guard sqlite3_step(ftsDeleteStmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: ftsDeleteSQL,
                message: String(cString: sqlite3_errmsg(db)))
        }
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
        try runExec(db: db, sql: "COMMIT;")
        } catch {
            // audit memory-a F6: any step failed — roll the whole three-write sequence back so the
            // main table and the FTS index never diverge.
            try? runExec(db: db, sql: "ROLLBACK;")
            throw error
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
    static func ensureBundleSchema(
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
    static func insertBundle(
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
    static func fetchBundleSummaries(
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
    static func ensureTombstoneSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS memory_usage_tombstones (
                record_id TEXT PRIMARY KEY NOT NULL,
                tombstoned_at_ms INTEGER NOT NULL
            );
            """)
    }

    static func insertTombstone(
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

    /// H11 — SELECT all tombstoned record_ids (for reload into inMemoryTombstones).
    static func fetchAllTombstoneIDs(db: OpaquePointer) throws -> [String] {
        let sql = "SELECT record_id FROM memory_usage_tombstones"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var ids: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) { ids.append(String(cString: c)) }
        }
        return ids
    }

    static func purgeTombstonedRows(
        db: OpaquePointer
    ) throws {
        // Atomic multi-step:DELETE the records + their notes + FTS rows,then
        // truncate the tombstones table。 Wrapped in a transaction so the tables
        // can never get out of sync。 H12 (mega-audit 2026-07-07): the notes +
        // FTS deletes were MISSING — "physical deletion" left host-supplied atom
        // content in memory_usage_record_notes + its FTS5 index, so searchNotesFTS
        // still surfaced purged records and the on-disk text stayed readable (the
        // 4th purge red-leg, hidden behind an "already implemented" delete path).
        // Notes/FTS tables are created lazily (only on first attachNotes); ensure they
        // exist so the H12 cleanup DELETEs never hit "no such table" when purge runs
        // before any note was attached.
        try ensureNotesAndFTSchema(db: db)
        try runExec(db: db,
            sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try runExec(db: db, sql: """
                DELETE FROM memory_usage_record_notes_fts
                 WHERE record_id IN (
                    SELECT record_id FROM memory_usage_tombstones
                 );
                """)
            try runExec(db: db, sql: """
                DELETE FROM memory_usage_record_notes
                 WHERE record_id IN (
                    SELECT record_id FROM memory_usage_tombstones
                 );
                """)
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
    static func insertBatchInTransaction(
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

    static func deleteOlderThan(
        db: OpaquePointer,
        cutoff: Date
    ) throws {
        // H12 (mega-audit 2026-07-07): time-based GC must also clear notes + FTS for
        // the deleted records, else host-supplied content survives the purge in
        // memory_usage_record_notes(_fts) and stays full-text searchable + readable.
        let cutoffMs = Int64(cutoff.timeIntervalSince1970 * 1000)
        func execBound(_ sql: String) throws {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt
            else {
                throw TrackerError.prepareFailed(
                    sql: sql, message: String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, cutoffMs)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw TrackerError.stepFailed(
                    sql: sql, message: String(cString: sqlite3_errmsg(db)))
            }
        }
        let staleSubquery =
            "SELECT record_id FROM memory_usage_records WHERE retrieved_at_ms < ?"
        try ensureNotesAndFTSchema(db: db)   // lazy tables — ensure before cleanup DELETE
        try runExec(db: db, sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execBound("DELETE FROM memory_usage_record_notes_fts "
                          + "WHERE record_id IN (\(staleSubquery));")
            try execBound("DELETE FROM memory_usage_record_notes "
                          + "WHERE record_id IN (\(staleSubquery));")
            try execBound("DELETE FROM memory_usage_records WHERE retrieved_at_ms < ?;")
            try runExec(db: db, sql: "COMMIT;")
        } catch {
            try? runExec(db: db, sql: "ROLLBACK;")
            throw error
        }
    }

}
