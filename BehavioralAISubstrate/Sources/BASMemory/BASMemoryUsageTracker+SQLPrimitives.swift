// MARK: - BASMemoryUsageTracker SQL primitives (statement helpers, db-parameter)
// chapter 一千〇四十 / WS-backlog-decomp — relocated extension cluster (god-object split). byte-equal.

import Foundation
import SQLite3
import BASRuntimeCore

extension BASMemoryUsageTracker {
    // MARK: - SQL primitives

    static func insertRecord(
        db: OpaquePointer,
        record: BASMemoryUsageRecord
    ) throws {
        try upsertRecord(db: db, record: record)
    }

    static func upsertRecord(
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

    static func fetchAllRecords(
        db: OpaquePointer
    ) throws -> [BASMemoryUsageRecord] {
        let sql = """
            SELECT record_id, atom_id, retrieved_at_ms,
                   session_ref, turn_ref, permit_mode,
                   helped_state
              FROM memory_usage_records
             ORDER BY retrieved_at_ms ASC,
                      CAST(turn_ref AS INTEGER) ASC
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
    ///
    /// M2440 第六刀 — the ORDER BY carries a `CAST(turn_ref AS
    /// INTEGER)` tiebreaker (matching the Swift-fold `recentRecords`
    /// path + `BASRustBrainHistoryStore`)。 `retrieved_at_ms` is
    /// MILLISECOND resolution,so two records in the same ms tie;
    /// without a deterministic secondary key the "most recent" row
    /// is ambiguous and can disagree across backends — the
    /// cross-store atomID-parity flake class。 `turn_ref` is the
    /// per-brain monotonic counter (stored as a stringified int;
    /// CAST → 0 for any non-numeric value,matching the Swift
    /// `Int(turnRef) ?? 0`),so the order is deterministic and
    /// store-identical。
    static func fetchRecentRecordsDesc(
        db: OpaquePointer,
        limit: Int
    ) throws -> [BASMemoryUsageRecord] {
        let sql = """
            SELECT record_id, atom_id, retrieved_at_ms,
                   session_ref, turn_ref, permit_mode,
                   helped_state
              FROM memory_usage_records
             ORDER BY retrieved_at_ms DESC,
                      CAST(turn_ref AS INTEGER) DESC
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
    static func fetchPermitModeDistribution(
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
    static func fetchUsageCount(
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
    static func fetchDistinctSessionCount(
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
    static func fetchRecentRecordsForAtomDesc(
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
             ORDER BY retrieved_at_ms DESC,
                      CAST(turn_ref AS INTEGER) DESC
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
    static func fetchMinRetrievedAt(
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
    static func fetchMaxRetrievedAt(
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
    static func fetchHelpedFlagDistribution(
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
    static func fetchRecordsInTimeRangeAsc(
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
             ORDER BY retrieved_at_ms ASC,
                      CAST(turn_ref AS INTEGER) ASC
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
    static func fetchEpisodeSummaries(
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

}
