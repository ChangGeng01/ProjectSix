// MARK: - BASSQLiteEventLogStorage — chapter 三百五四 / M841
//
// Phase P1 G1 第二刀: SQLite-backed actor conformer of
// `BASEventLogStorage` (BASEventLog.swift)。Persists the
// append-only event log across process restarts。
//
// ## Mirrors `BASSQLiteMemoryAtomStore` (chapter 二百四十八 / M735)
//
// Same idiom:
//   - `actor` for serialized access
//   - `import SQLite3` system framework (no new package deps)
//   - `OpaquePointer` db handle owned by actor,closed in nonisolated
//     deinit
//   - WAL journal mode for concurrent readers
//   - Transient-destructor for Swift String binding
//   - Typed `StorageError` enum
//   - Schema-version pragma + verification on open
//   - JSON-encoded full entry in `payload_json`,structural columns
//     mirror typed fields for SQL filtering without parsing
//
// ## Schema (version 1)
//
//   CREATE TABLE event_log (
//     event_id TEXT PRIMARY KEY NOT NULL,
//     session_id TEXT NOT NULL,
//     sequence_number INTEGER NOT NULL,
//     timestamp_ms INTEGER NOT NULL,
//     kind TEXT NOT NULL,
//     risk_band TEXT NOT NULL,
//     payload_json TEXT NOT NULL
//   );
//   CREATE INDEX event_log_session_seq_idx
//     ON event_log(session_id, sequence_number);
//   CREATE INDEX event_log_timestamp_idx
//     ON event_log(timestamp_ms);
//   CREATE INDEX event_log_kind_idx
//     ON event_log(kind);
//
// `payload_json` is the source of truth on read。Indexed columns
// give fast `WHERE session_id = ?` (replay) + `WHERE timestamp_ms
// >= ?` (training extraction) queries。
//
// ## Sequence number assignment
//
// On `append`, the storage layer:
//   1. Looks up max(sequence_number) for the entry's session_id
//   2. Assigns `assigned = max + 1` (or 0 if first event for session)
//   3. Writes the row with `sequence_number = assigned`
//
// This means the caller can pass `sequenceNumber: 0` and the
// storage layer overrides it。Mirrors the in-memory conformer's
// behavior in `BASInMemoryEventLogStorage`。
//
// ## Doctrine pins held
//
// All from BASEventLog.swift apply。Additionally:
//   - chapter 二百四十八 M735: WAL + transient-destructor +
//     typed StorageError mirror exactly
//   - chapter 一百二 五级删除 doctrine: this storage layer does NOT
//     expose a `DELETE` API。Event log is append-only by contract。
//     Forget cascades operate on the L8 atom store,not the event
//     log。If host needs to wipe event log,that is a separate
//     operator-driven workflow (delete file or run a SQL script —
//     not a runtime API).

import Foundation
import SQLite3

/// SQLite-backed `BASEventLogStorage`. Events persist across
/// process restarts。
///
/// **First-run cost**: the database file + table + indices are
/// created at `init` if absent。Existing databases are opened
/// read/write。Schema-version pragma is set + verified on every
/// open。
///
/// **Failure mode**: any SQLite error throws a typed
/// `StorageError`。Per chapter 一百九十一 M91 doctrine,integrity
/// outranks availability — a corrupt store is surfaced rather
/// than silently truncated。
public actor BASSQLiteEventLogStorage: BASEventLogStorage {

    // MARK: - Errors

    public enum StorageError: Error, Equatable, Sendable {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case encodeFailed(eventID: String, message: String)
        case decodeFailed(eventID: String, message: String)
        case corruptedRow(eventID: String, reason: String)
    }

    public static let schemaVersion: Int = 1

    // MARK: - Stored state

    /// Database file URL。Surfaced for tests / observability。
    public let databaseURL: URL

    /// Owned SQLite handle。Same nonisolated(unsafe) pattern as
    /// `BASSQLiteMemoryAtomStore` — deinit closes it,all other
    /// access through actor-isolated methods。
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

        try Self.runExec(db: handle, sql: "PRAGMA journal_mode=WAL;")
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")
        try Self.runExec(
            db: handle,
            sql: "PRAGMA user_version=\(Self.schemaVersion);")
        try Self.ensureSchema(db: handle)
        try Self.verifySchemaVersion(db: handle)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Protocol — BASEventLogStorage

    @discardableResult
    public func append(
        _ entry: BASEventLogEntry
    ) async throws -> (
        wasNew: Bool, assignedSequenceNumber: Int64)
    {
        guard let db else {
            // Defensive — should be impossible if init succeeded
            throw StorageError.openFailed(
                code: -1,
                message: "db handle nil after init")
        }
        // Idempotent retry: if event_id exists,return its
        // sequenceNumber + wasNew=false
        if let existing = try Self.fetchEntry(
            db: db, eventID: entry.eventID)
        {
            return (
                wasNew: false,
                assignedSequenceNumber:
                    existing.sequenceNumber)
        }
        let assigned = try Self.nextSequenceNumber(
            db: db, sessionID: entry.sessionID)
        let stamped = BASEventLogEntry(
            eventID: entry.eventID,
            timestampMs: entry.timestampMs,
            kind: entry.kind,
            sessionID: entry.sessionID,
            sequenceNumber: assigned,
            source: entry.source,
            turnRef: entry.turnRef,
            rawInputDigest: entry.rawInputDigest,
            intent: entry.intent,
            emotion: entry.emotion,
            riskBand: entry.riskBand,
            project: entry.project,
            memoryRefs: entry.memoryRefs,
            stateBeforeID: entry.stateBeforeID,
            stateAfterID: entry.stateAfterID,
            actions: entry.actions,
            confidence: entry.confidence,
            payloadJson: entry.payloadJson)
        try Self.insertEntry(db: db, entry: stamped)
        return (wasNew: true, assignedSequenceNumber: assigned)
    }

    public func events(
        forSession sessionID: String
    ) async -> [BASEventLogEntry] {
        guard let db else { return [] }
        return (try? Self.fetchEventsForSession(
            db: db, sessionID: sessionID)) ?? []
    }

    public func events(
        sinceTimestampMs since: Int64,
        limit: Int
    ) async -> [BASEventLogEntry] {
        guard let db, limit > 0 else { return [] }
        return (try? Self.fetchEventsSinceTimestamp(
            db: db, since: since, limit: limit)) ?? []
    }

    public var totalCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countAll(db: db)) ?? 0
        }
    }

    // MARK: - Schema setup

    fileprivate static func ensureSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS event_log (
                event_id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                sequence_number INTEGER NOT NULL,
                timestamp_ms INTEGER NOT NULL,
                kind TEXT NOT NULL,
                risk_band TEXT NOT NULL,
                payload_json TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                event_log_session_seq_idx
                ON event_log(session_id, sequence_number);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                event_log_timestamp_idx
                ON event_log(timestamp_ms);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                event_log_kind_idx
                ON event_log(kind);
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

    // MARK: - CRUD primitives

    fileprivate static func insertEntry(
        db: OpaquePointer,
        entry: BASEventLogEntry
    ) throws {
        let sql = """
            INSERT INTO event_log (
                event_id, session_id, sequence_number,
                timestamp_ms, kind, risk_band, payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
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
        let payloadJson: String
        do {
            let data = try JSONEncoder().encode(entry)
            guard let s = String(data: data, encoding: .utf8)
            else {
                throw StorageError.encodeFailed(
                    eventID: entry.eventID,
                    message: "encoder produced non-UTF-8 data")
            }
            payloadJson = s
        } catch let err as StorageError {
            throw err
        } catch {
            throw StorageError.encodeFailed(
                eventID: entry.eventID,
                message: "\(error)")
        }
        bindText(stmt, 1, entry.eventID)
        bindText(stmt, 2, entry.sessionID)
        sqlite3_bind_int64(stmt, 3, entry.sequenceNumber)
        sqlite3_bind_int64(stmt, 4, entry.timestampMs)
        bindText(stmt, 5, entry.kind.rawValue)
        bindText(stmt, 6, entry.riskBand.rawValue)
        bindText(stmt, 7, payloadJson)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchEntry(
        db: OpaquePointer,
        eventID: String
    ) throws -> BASEventLogEntry? {
        let sql = """
            SELECT payload_json FROM event_log
            WHERE event_id = ?
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
        bindText(stmt, 1, eventID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let json = readText(stmt, 0)
        return try decode(eventID: eventID, json: json)
    }

    fileprivate static func nextSequenceNumber(
        db: OpaquePointer,
        sessionID: String
    ) throws -> Int64 {
        let sql = """
            SELECT COALESCE(MAX(sequence_number), -1) FROM
            event_log WHERE session_id = ?
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
        bindText(stmt, 1, sessionID)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let max = sqlite3_column_int64(stmt, 0)
        return max + 1
    }

    fileprivate static func fetchEventsForSession(
        db: OpaquePointer,
        sessionID: String
    ) throws -> [BASEventLogEntry] {
        let sql = """
            SELECT event_id, payload_json FROM event_log
            WHERE session_id = ?
            ORDER BY sequence_number ASC
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
        bindText(stmt, 1, sessionID)
        var out: [BASEventLogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = readText(stmt, 0)
            let json = readText(stmt, 1)
            let entry = try decode(eventID: id, json: json)
            out.append(entry)
        }
        return out
    }

    fileprivate static func fetchEventsSinceTimestamp(
        db: OpaquePointer,
        since: Int64,
        limit: Int
    ) throws -> [BASEventLogEntry] {
        let sql = """
            SELECT event_id, payload_json FROM event_log
            WHERE timestamp_ms >= ?
            ORDER BY timestamp_ms ASC, sequence_number ASC
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
        var out: [BASEventLogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = readText(stmt, 0)
            let json = readText(stmt, 1)
            let entry = try decode(eventID: id, json: json)
            out.append(entry)
        }
        return out
    }

    fileprivate static func countAll(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM event_log"
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

    // MARK: - Decode helper

    fileprivate static func decode(
        eventID: String,
        json: String
    ) throws -> BASEventLogEntry {
        guard let data = json.data(using: .utf8) else {
            throw StorageError.corruptedRow(
                eventID: eventID,
                reason: "payload_json not UTF-8")
        }
        do {
            return try JSONDecoder().decode(
                BASEventLogEntry.self, from: data)
        } catch {
            throw StorageError.decodeFailed(
                eventID: eventID, message: "\(error)")
        }
    }

    // MARK: - Utility (mirrors BASSQLiteMemoryAtomStore)

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
        guard let raw = sqlite3_column_text(stmt, index) else {
            return ""
        }
        return String(cString: raw)
    }
}

