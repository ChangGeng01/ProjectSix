// MARK: - BASSQLiteEvalRunStorage — chapter 三百七六 / M863
//
// G12 第三刀: SQLite-backed actor conformer of `BASEvalRunStorage`。
// Persists eval runs + regression reports across process restarts。
//
// ## Mirrors `BASSQLiteEventLogStorage` (chapter 三百五四 / M841)
//
// Same idiom (chapter 二百四十八 / M735):
//   - `actor` for serialized access
//   - `import SQLite3` system framework (no new package deps)
//   - `OpaquePointer` db handle owned by actor,closed in nonisolated
//     deinit
//   - WAL journal mode for concurrent readers
//   - Transient-destructor for Swift String binding
//   - Typed `StorageError` enum
//   - Schema-version pragma + verification on open
//   - JSON-encoded full payload,structural columns mirror typed
//     fields for SQL filtering without parsing
//
// ## Schema (version 1)
//
//   CREATE TABLE eval_run (
//     run_id TEXT PRIMARY KEY NOT NULL,
//     timestamp_ms INTEGER NOT NULL,
//     build_chapter TEXT NOT NULL,
//     host_fingerprint TEXT NOT NULL,
//     sample_count INTEGER NOT NULL,
//     payload_json TEXT NOT NULL
//   );
//   CREATE INDEX eval_run_timestamp_idx
//     ON eval_run(timestamp_ms);
//   CREATE INDEX eval_run_build_chapter_idx
//     ON eval_run(build_chapter, timestamp_ms);
//   CREATE INDEX eval_run_fingerprint_idx
//     ON eval_run(host_fingerprint, timestamp_ms);
//
//   CREATE TABLE eval_regression_report (
//     baseline_run_id TEXT NOT NULL,
//     candidate_run_id TEXT NOT NULL,
//     timestamp_ms INTEGER NOT NULL,
//     payload_json TEXT NOT NULL,
//     PRIMARY KEY (baseline_run_id, candidate_run_id)
//   );
//   CREATE INDEX eval_report_candidate_idx
//     ON eval_regression_report(candidate_run_id, timestamp_ms);
//   CREATE INDEX eval_report_timestamp_idx
//     ON eval_regression_report(timestamp_ms);
//
// `payload_json` is the source of truth on read。Indexed columns
// give fast `WHERE build_chapter = ?` (baseline lookup) +
// `WHERE host_fingerprint = ?` (host segmentation) queries。
//
// ## Doctrine pins held
//
// All from BASEvalRunStorage.swift apply。Additionally:
//   - chapter 二百四十八 M735: WAL + transient-destructor + typed
//     StorageError mirror exactly
//   - chapter 一百二 五级删除 doctrine: append-only,no DELETE API

import Foundation
import SQLite3

/// SQLite-backed `BASEvalRunStorage`。Runs + reports persist
/// across process restarts。
///
/// **First-run cost**: the database file + tables + indices are
/// created at `init` if absent。Existing databases are opened
/// read/write。Schema-version pragma is set + verified on every
/// open。
///
/// **Failure mode**: any SQLite error throws a typed
/// `StorageError`。Per chapter 一百九十一 M91 doctrine,integrity
/// outranks availability — a corrupt store is surfaced rather
/// than silently truncated。
public actor BASSQLiteEvalRunStorage: BASEvalRunStorage {

    // MARK: - Errors

    public enum StorageError: Error, Equatable, Sendable {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case encodeFailed(runID: String, message: String)
        case decodeFailed(runID: String, message: String)
        case corruptedRow(runID: String, reason: String)
    }

    public static let schemaVersion: Int = 1

    // MARK: - Stored state

    /// Database file URL。Surfaced for tests / observability。
    public let databaseURL: URL

    /// Owned SQLite handle (mirror M841 nonisolated(unsafe)
    /// pattern — deinit closes it,all other access through
    /// actor-isolated methods)。
    private nonisolated(unsafe) var db: OpaquePointer?

    // MARK: - Lifecycle

    public init(databaseURL: URL) throws {
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
            throw StorageError.openFailed(
                code: openRC, message: message)
        }
        self.db = handle

        try Self.runExec(
            db: handle, sql: "PRAGMA journal_mode=WAL;")
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")

        // M882 fix (P2.5 audit):read user_version FIRST,branch
        // on:0 → write current,equal → accept,mismatch → throw。
        // Pre-M882 the unconditional pragma write made the
        // verify check a no-op。Same pattern as M866 fix.
        let existingVersion = try Self.readUserVersion(
            db: handle)
        if existingVersion == 0 {
            try Self.runExec(
                db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion != Self.schemaVersion {
            throw StorageError.schemaVersionMismatch(
                found: existingVersion,
                expected: Self.schemaVersion)
        }
        try Self.ensureSchema(db: handle)
        try Self.verifySchemaVersion(db: handle)
    }

    /// M882 helper:read `PRAGMA user_version` without setting
    /// it。Returns 0 for a freshly-created SQLite file。
    fileprivate static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "PRAGMA user_version;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Protocol — Run CRUD

    @discardableResult
    public func append(
        _ run: BASEvalRun
    ) async throws -> Bool {
        guard let db else {
            throw StorageError.openFailed(
                code: -1,
                message: "db handle nil after init")
        }
        if try Self.fetchRun(db: db, runID: run.runID) != nil {
            return false
        }
        try Self.insertRun(db: db, run: run)
        return true
    }

    public func run(forID runID: String) async -> BASEvalRun? {
        guard let db else { return nil }
        return (try? Self.fetchRun(db: db, runID: runID))
            ?? nil
    }

    public func latestRun(
        forBuildChapter buildChapter: String
    ) async -> BASEvalRun? {
        guard let db else { return nil }
        return (try? Self.fetchLatestRun(
            db: db,
            column: "build_chapter",
            value: buildChapter)) ?? nil
    }

    public func latestRun(
        forHostFingerprint hostFingerprint: String
    ) async -> BASEvalRun? {
        guard let db else { return nil }
        return (try? Self.fetchLatestRun(
            db: db,
            column: "host_fingerprint",
            value: hostFingerprint)) ?? nil
    }

    public func runs(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEvalRun] {
        guard let db, limit > 0 else { return [] }
        return (try? Self.fetchRunsSince(
            db: db, since: since, limit: limit)) ?? []
    }

    public var totalRunCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countAll(
                db: db, table: "eval_run")) ?? 0
        }
    }

    // MARK: - Protocol — Report CRUD

    @discardableResult
    public func appendReport(
        _ report: BASEvalRegressionReport,
        timestampMs: Int64
    ) async throws -> Bool {
        guard let db else {
            throw StorageError.openFailed(
                code: -1,
                message: "db handle nil after init")
        }
        if try Self.fetchReport(
            db: db,
            baselineRunID: report.baselineRunID,
            candidateRunID: report.candidateRunID) != nil
        {
            return false
        }
        try Self.insertReport(
            db: db, report: report, timestampMs: timestampMs)
        return true
    }

    public func report(
        baselineRunID: String,
        candidateRunID: String
    ) async -> BASEvalRegressionReport? {
        guard let db else { return nil }
        return (try? Self.fetchReport(
            db: db,
            baselineRunID: baselineRunID,
            candidateRunID: candidateRunID)) ?? nil
    }

    public func reportsForCandidate(
        _ candidateRunID: String
    ) async -> [BASEvalRegressionReport] {
        guard let db else { return [] }
        return (try? Self.fetchReportsForCandidate(
            db: db, candidateRunID: candidateRunID)) ?? []
    }

    public var totalReportCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countAll(
                db: db,
                table: "eval_regression_report")) ?? 0
        }
    }

    // MARK: - Schema setup

    fileprivate static func ensureSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS eval_run (
                run_id TEXT PRIMARY KEY NOT NULL,
                timestamp_ms INTEGER NOT NULL,
                build_chapter TEXT NOT NULL,
                host_fingerprint TEXT NOT NULL,
                sample_count INTEGER NOT NULL,
                payload_json TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                eval_run_timestamp_idx
                ON eval_run(timestamp_ms);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                eval_run_build_chapter_idx
                ON eval_run(build_chapter, timestamp_ms);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                eval_run_fingerprint_idx
                ON eval_run(host_fingerprint, timestamp_ms);
            """)

        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS eval_regression_report (
                baseline_run_id TEXT NOT NULL,
                candidate_run_id TEXT NOT NULL,
                timestamp_ms INTEGER NOT NULL,
                payload_json TEXT NOT NULL,
                PRIMARY KEY (baseline_run_id, candidate_run_id)
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                eval_report_candidate_idx
                ON eval_regression_report(
                    candidate_run_id, timestamp_ms);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                eval_report_timestamp_idx
                ON eval_regression_report(timestamp_ms);
            """)
    }

    fileprivate static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let sql = "PRAGMA user_version;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let found = Int(sqlite3_column_int64(stmt, 0))
        guard found == schemaVersion else {
            throw StorageError.schemaVersionMismatch(
                found: found, expected: schemaVersion)
        }
    }

    // MARK: - Run CRUD primitives

    fileprivate static func insertRun(
        db: OpaquePointer,
        run: BASEvalRun
    ) throws {
        let sql = """
            INSERT INTO eval_run (
                run_id, timestamp_ms, build_chapter,
                host_fingerprint, sample_count, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        let payloadJson = try encodeRun(run: run)

        bindText(stmt, 1, run.runID)
        sqlite3_bind_int64(stmt, 2, run.timestampMs)
        bindText(stmt, 3, run.buildChapter)
        bindText(stmt, 4, run.hostFingerprint)
        sqlite3_bind_int64(stmt, 5, Int64(run.sampleCount))
        bindText(stmt, 6, payloadJson)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchRun(
        db: OpaquePointer,
        runID: String
    ) throws -> BASEvalRun? {
        let sql = """
            SELECT payload_json FROM eval_run
            WHERE run_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, runID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let json = readText(stmt, 0)
        return try decodeRun(runID: runID, json: json)
    }

    fileprivate static func fetchLatestRun(
        db: OpaquePointer,
        column: String,
        value: String
    ) throws -> BASEvalRun? {
        // column is a controlled internal value (build_chapter
        // or host_fingerprint) — never user-supplied,so string
        // interpolation is safe here。Bind parameters are still
        // used for the value itself。
        let sql = """
            SELECT run_id, payload_json FROM eval_run
            WHERE \(column) = ?
            ORDER BY timestamp_ms DESC
            LIMIT 1
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, value)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let runID = readText(stmt, 0)
        let json = readText(stmt, 1)
        return try decodeRun(runID: runID, json: json)
    }

    fileprivate static func fetchRunsSince(
        db: OpaquePointer,
        since: Int64,
        limit: Int
    ) throws -> [BASEvalRun] {
        let sql = """
            SELECT run_id, payload_json FROM eval_run
            WHERE timestamp_ms >= ?
            ORDER BY timestamp_ms ASC
            LIMIT ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, since)
        sqlite3_bind_int64(stmt, 2, Int64(limit))
        var out: [BASEvalRun] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = readText(stmt, 0)
            let json = readText(stmt, 1)
            let run = try decodeRun(runID: id, json: json)
            out.append(run)
        }
        return out
    }

    // MARK: - Report CRUD primitives

    fileprivate static func insertReport(
        db: OpaquePointer,
        report: BASEvalRegressionReport,
        timestampMs: Int64
    ) throws {
        let sql = """
            INSERT INTO eval_regression_report (
                baseline_run_id, candidate_run_id,
                timestamp_ms, payload_json
            ) VALUES (?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        let payloadJson = try encodeReport(report: report)
        bindText(stmt, 1, report.baselineRunID)
        bindText(stmt, 2, report.candidateRunID)
        sqlite3_bind_int64(stmt, 3, timestampMs)
        bindText(stmt, 4, payloadJson)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchReport(
        db: OpaquePointer,
        baselineRunID: String,
        candidateRunID: String
    ) throws -> BASEvalRegressionReport? {
        let sql = """
            SELECT payload_json FROM eval_regression_report
            WHERE baseline_run_id = ? AND candidate_run_id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, baselineRunID)
        bindText(stmt, 2, candidateRunID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let json = readText(stmt, 0)
        return try decodeReport(
            baselineRunID: baselineRunID,
            candidateRunID: candidateRunID,
            json: json)
    }

    fileprivate static func fetchReportsForCandidate(
        db: OpaquePointer,
        candidateRunID: String
    ) throws -> [BASEvalRegressionReport] {
        let sql = """
            SELECT baseline_run_id, candidate_run_id, payload_json
            FROM eval_regression_report
            WHERE candidate_run_id = ?
            ORDER BY timestamp_ms ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, candidateRunID)
        var out: [BASEvalRegressionReport] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let baseID = readText(stmt, 0)
            let candID = readText(stmt, 1)
            let json = readText(stmt, 2)
            let report = try decodeReport(
                baselineRunID: baseID,
                candidateRunID: candID,
                json: json)
            out.append(report)
        }
        return out
    }

    fileprivate static func countAll(
        db: OpaquePointer,
        table: String
    ) throws -> Int {
        // table is internal-controlled,no SQL injection surface
        let sql = "SELECT COUNT(*) FROM \(table)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            == SQLITE_OK,
            let stmt
        else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Encode / decode helpers

    fileprivate static func encodeRun(
        run: BASEvalRun
    ) throws -> String {
        do {
            let data = try JSONEncoder().encode(run)
            guard let s = String(
                data: data, encoding: .utf8)
            else {
                throw StorageError.encodeFailed(
                    runID: run.runID,
                    message: "encoder produced non-UTF-8 data")
            }
            return s
        } catch let err as StorageError {
            throw err
        } catch {
            throw StorageError.encodeFailed(
                runID: run.runID, message: "\(error)")
        }
    }

    fileprivate static func decodeRun(
        runID: String,
        json: String
    ) throws -> BASEvalRun {
        guard let data = json.data(using: .utf8) else {
            throw StorageError.corruptedRow(
                runID: runID,
                reason: "payload_json not UTF-8")
        }
        do {
            return try JSONDecoder().decode(
                BASEvalRun.self, from: data)
        } catch {
            throw StorageError.decodeFailed(
                runID: runID, message: "\(error)")
        }
    }

    fileprivate static func encodeReport(
        report: BASEvalRegressionReport
    ) throws -> String {
        do {
            let data = try JSONEncoder().encode(report)
            guard let s = String(
                data: data, encoding: .utf8)
            else {
                throw StorageError.encodeFailed(
                    runID: report.candidateRunID,
                    message: "encoder produced non-UTF-8 data")
            }
            return s
        } catch let err as StorageError {
            throw err
        } catch {
            throw StorageError.encodeFailed(
                runID: report.candidateRunID,
                message: "\(error)")
        }
    }

    fileprivate static func decodeReport(
        baselineRunID: String,
        candidateRunID: String,
        json: String
    ) throws -> BASEvalRegressionReport {
        guard let data = json.data(using: .utf8) else {
            throw StorageError.corruptedRow(
                runID: candidateRunID,
                reason: "report payload_json not UTF-8")
        }
        do {
            return try JSONDecoder().decode(
                BASEvalRegressionReport.self, from: data)
        } catch {
            throw StorageError.decodeFailed(
                runID: candidateRunID, message: "\(error)")
        }
    }

    // MARK: - Utility (mirrors BASSQLiteEventLogStorage)

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
            throw StorageError.prepareFailed(
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
        guard let cstr = sqlite3_column_text(stmt, index)
        else { return "" }
        return String(cString: cstr)
    }
}
