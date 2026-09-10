// MARK: - BASMemoryUsageTracker chapter 723 helpers + utility
// chapter 一千〇四十 / WS-backlog-decomp — relocated extension cluster (god-object split). byte-equal.

import Foundation
import SQLite3
import BASRuntimeCore

extension BASMemoryUsageTracker {
    // MARK: - chapter 七百二十三 第四刀 / M2289
    //         Multi-row INSERT optimization (recordBatch hot path)
    //
    // Same outcome as `insertBatchInTransaction` (single fsync +
    // identical row state) but collapses N prepared-statement
    // prepares into ONE multi-row INSERT statement per chunk。
    //
    // Why this is faster:
    //   - SQLite parses + compiles the INSERT once,binds the
    //     parameters for ALL rows,steps once。 N prepare/finalize
    //     pairs collapse to 1。
    //   - Network/disk round-trips amortize across the whole chunk。
    //
    // Chunking:SQLite's SQLITE_LIMIT_VARIABLE_NUMBER defaults to
    // 999 (modern SQLite raised it to 32766,but conservative
    // default to keep portable)。 7 params × 142 = 994。 We pick
    // 100 rows per chunk to leave headroom + simplify the test
    // matrix。 Larger chunks save more on parse cost,smaller
    // chunks bound peak memory。

    /// Maximum rows per multi-row INSERT chunk。 7 params/row ×
    /// 142 rows = 994 < 999 default SQLite param limit。 100 is
    /// the conservative choice。
    fileprivate static let multiRowInsertChunkSize = 100

    /// 千万不要 删除 只能 commented 代码 — legacy
    /// `insertBatchInTransaction` is preserved verbatim above
    /// (lines 2427-2475)。 This new path opts in via
    /// `useMultiRowInsertBatch` feature flag。
    ///
    /// Builds one (or more,for large batches) multi-row INSERT
    /// statement under a single transaction。 Same fsync count as
    /// the legacy path (1 per batch),but parse/prepare count
    /// drops from N to ceil(N / chunkSize)。
    static func insertBatchMultiRow(
        db: OpaquePointer,
        entries: [BatchEntry],
        inMemoryAppender: (BASMemoryUsageRecord) -> Void
    ) throws -> [String] {
        if entries.isEmpty { return [] }
        try runExec(db: db,
            sql: "BEGIN IMMEDIATE TRANSACTION;")

        var ids: [String] = []
        ids.reserveCapacity(entries.count)

        // Materialize records first so recordIDs are deterministic
        // and in-memory append happens AFTER successful commit。
        let records: [BASMemoryUsageRecord] =
            entries.map { e in
                BASMemoryUsageRecord(
                    atomID: e.atomID,
                    retrievedAt: e.retrievedAt,
                    sessionRef: e.sessionRef,
                    turnRef: e.turnRef,
                    permitMode: e.permitMode)
            }

        do {
            var idx = 0
            while idx < records.count {
                let end = min(
                    idx + multiRowInsertChunkSize,
                    records.count)
                let chunk = records[idx..<end]
                try multiRowInsertChunk(
                    db: db, chunk: Array(chunk))
                idx = end
            }
        } catch {
            try? runExec(db: db, sql: "ROLLBACK;")
            throw error
        }

        try runExec(db: db, sql: "COMMIT;")

        // Post-commit:append to in-memory cache + return IDs in
        // insertion order (matches the legacy contract)。
        for r in records {
            inMemoryAppender(r)
            ids.append(r.recordID)
        }
        return ids
    }

    private static func multiRowInsertChunk(
        db: OpaquePointer,
        chunk: [BASMemoryUsageRecord]
    ) throws {
        if chunk.isEmpty { return }
        // Build "(?, ?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ?, ?, ?), ..."
        let rowPlaceholder = "(?, ?, ?, ?, ?, ?, ?)"
        let valuesClause = Array(
            repeating: rowPlaceholder, count: chunk.count
        ).joined(separator: ", ")
        let sql = """
            INSERT INTO memory_usage_records (
                record_id, atom_id, retrieved_at_ms,
                session_ref, turn_ref, permit_mode, helped_state
            ) VALUES \(valuesClause)
            ON CONFLICT(record_id) DO UPDATE SET
                helped_state = excluded.helped_state
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, sql, -1, &stmt, nil) == SQLITE_OK,
            let stmt
        else {
            throw TrackerError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var bindIdx: Int32 = 1
        for record in chunk {
            bindText(stmt, bindIdx, record.recordID)
            bindIdx += 1
            bindText(stmt, bindIdx, record.atomID)
            bindIdx += 1
            sqlite3_bind_int64(
                stmt, bindIdx,
                Int64(record.retrievedAt
                    .timeIntervalSince1970 * 1000))
            bindIdx += 1
            bindText(stmt, bindIdx, record.sessionRef)
            bindIdx += 1
            bindText(stmt, bindIdx, record.turnRef)
            bindIdx += 1
            bindText(stmt, bindIdx, record.permitMode)
            bindIdx += 1
            bindText(stmt, bindIdx, record.helpedFlag.rawValue)
            bindIdx += 1
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TrackerError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Utility

    static func runExec(
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

    static func bindText(
        _ stmt: OpaquePointer,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(
            stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    static func readText(
        _ stmt: OpaquePointer,
        _ index: Int32
    ) -> String {
        guard let raw = sqlite3_column_text(stmt, index) else {
            return ""
        }
        return String(cString: raw)
    }
}
