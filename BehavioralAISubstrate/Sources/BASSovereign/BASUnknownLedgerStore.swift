// MARK: - BASUnknownLedgerStore
// chapter 七百九十四 / M2621-M2625 — L7 unknown-ledger storage
//
// Persistence seam for the L7 「known-unknown」 records emitted
// by the chapter 七百六十四 bas-mirror-blade decomposition
// pipeline。 Pairs with SQL schema 011_unknown_ledger_records
// (chapter 七百六十五)。
//
// Two conformers ship in this chapter:
//   - BASInMemoryUnknownLedgerStore (live default reference)
//   - BASSQLiteUnknownLedgerStore (production opt-in)
//
// Same pattern as L8 atom-lifecycle stores (chapter 七百八十九
// + 七百九十二)。 「不要 删除 只能 comment」 — InMemory keeps
// being the documented default;hosts opt in to SQLite。

import Foundation
import SQLite3
import BASRuntimeCore

// MARK: - BASUnknownLedgerRecord typed record

public struct BASUnknownLedgerRecord:
    Sendable, Equatable, Hashable, Codable
{
    public let eventID: String
    public let sessionID: String
    public let turnID: String
    public let unknownText: String
    /// Classifier confidence [0, 1] at the moment the unknown
    /// was flagged。 Schema 011 enforces CHECK 0..1。
    public let confidence: Double
    public let discoveredAtMs: Int64

    public init(
        eventID: String,
        sessionID: String,
        turnID: String,
        unknownText: String,
        confidence: Double,
        discoveredAtMs: Int64
    ) {
        self.eventID = eventID
        self.sessionID = sessionID
        self.turnID = turnID
        self.unknownText = unknownText
        self.confidence = confidence
        self.discoveredAtMs = discoveredAtMs
    }
}

// MARK: - BASUnknownLedgerStore protocol

public protocol BASUnknownLedgerStore: Sendable {
    func appendRecord(
        _ record: BASUnknownLedgerRecord
    ) async throws -> BASUnknownLedgerRecord
    func records(forSession sessionID: String) async -> [BASUnknownLedgerRecord]
    func records(forTurn turnID: String) async -> [BASUnknownLedgerRecord]
    func count() async -> Int
}

// MARK: - In-memory reference impl

public actor BASInMemoryUnknownLedgerStore:
    BASUnknownLedgerStore
{
    public enum StoreError: Error, Equatable, Sendable {
        case duplicateEventID(String)
    }

    private var records: [BASUnknownLedgerRecord] = []
    private var indexByEventID: [String: Int] = [:]

    public init() {}

    public func appendRecord(
        _ record: BASUnknownLedgerRecord
    ) async throws -> BASUnknownLedgerRecord {
        if indexByEventID[record.eventID] != nil {
            throw StoreError.duplicateEventID(record.eventID)
        }
        indexByEventID[record.eventID] = records.count
        records.append(record)
        return record
    }

    public func records(
        forSession sessionID: String
    ) async -> [BASUnknownLedgerRecord] {
        records.filter { $0.sessionID == sessionID }
    }

    public func records(
        forTurn turnID: String
    ) async -> [BASUnknownLedgerRecord] {
        records.filter { $0.turnID == turnID }
    }

    public func count() async -> Int { records.count }

    // MARK: - Batch append (chapter 八百五 — API symmetry)

    /// Append many records in insertion order。 Actor isolation
    /// already serializes mutations,so no transaction is needed
    /// for the in-memory path。 API symmetry with the SQLite
    /// store's transaction-wrapped fast path。
    @discardableResult
    public func appendBatch(
        _ records: [BASUnknownLedgerRecord]
    ) async throws -> [BASUnknownLedgerRecord] {
        for record in records {
            _ = try await appendRecord(record)
        }
        return records
    }
}

// MARK: - SQLite-backed conformer

public actor BASSQLiteUnknownLedgerStore: BASUnknownLedgerStore {

    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case duplicateEventID(String)
    }

    public static let schemaVersion: Int = 1
    public let databaseURL: URL
    private nonisolated(unsafe) var db: OpaquePointer?

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
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
        // #16 删除教义 (mega-audit, 2026-07-08): secure_delete zeroes freed pages
        // at delete time — default-on, BAS_SECURE_DELETE=0 kill-switch.
        if let sdSQL = BASSQLiteSecureDelete.openPragmaSQL {
            try Self.runExec(db: handle, sql: sdSQL)
        }
        try Self.runExec(db: handle, sql: "PRAGMA synchronous=NORMAL;")
        let existingVersion = try Self.readUserVersion(db: handle)
        if existingVersion == 0 {
            try Self.runExec(db: handle,
                sql: "PRAGMA user_version=\(Self.schemaVersion);")
        } else if existingVersion != Self.schemaVersion {
            throw StorageError.schemaVersionMismatch(
                found: existingVersion,
                expected: Self.schemaVersion)
        }
        // sqlite3_exec handles multi-statement SQL natively;don't
        // split on `;` because schema comment headers may embed
        // semicolons in narrative text (e.g。 "default 0;flipped to
        // 1 when...")。
        try Self.runExec(db: handle,
            sql: UnknownLedgerRecordsSchema.allStatementsSQL)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    public func appendRecord(
        _ record: BASUnknownLedgerRecord
    ) async throws -> BASUnknownLedgerRecord {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            INSERT INTO unknown_ledger_records (
                event_id, session_id, turn_id, unknown_text,
                confidence, discovered_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        Self.bindText(stmt, 1, record.eventID)
        Self.bindText(stmt, 2, record.sessionID)
        Self.bindText(stmt, 3, record.turnID)
        Self.bindText(stmt, 4, record.unknownText)
        sqlite3_bind_double(stmt, 5, record.confidence)
        sqlite3_bind_int64(stmt, 6, record.discoveredAtMs)
        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE {
            if rc == SQLITE_CONSTRAINT {
                throw StorageError.duplicateEventID(record.eventID)
            }
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return record
    }

    public func records(
        forSession sessionID: String
    ) async -> [BASUnknownLedgerRecord] {
        return (try? queryRecords(
            whereClause: "session_id = ?",
            bindings: [sessionID])) ?? []
    }

    public func records(
        forTurn turnID: String
    ) async -> [BASUnknownLedgerRecord] {
        return (try? queryRecords(
            whereClause: "turn_id = ?",
            bindings: [turnID])) ?? []
    }

    public func count() async -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM unknown_ledger_records;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Batch append optimization (chapter 八百五)

    /// Append many records in a single SQLite transaction with a
    /// re-used prepared statement。 Mirrors chapter 八百四's L8
    /// batch pattern。 On the first error the whole batch ROLLS
    /// BACK — no partial writes leak。
    ///
    /// Empty input is a no-op (returns []),no transaction opened。
    @discardableResult
    public func appendBatch(
        _ records: [BASUnknownLedgerRecord]
    ) async throws -> [BASUnknownLedgerRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        if records.isEmpty { return [] }
        try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")
        let sql = """
            INSERT INTO unknown_ledger_records (
                event_id, session_id, turn_id, unknown_text,
                confidence, discovered_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else {
            try? Self.runExec(db: db, sql: "ROLLBACK;")
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        for record in records {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            Self.bindText(stmt, 1, record.eventID)
            Self.bindText(stmt, 2, record.sessionID)
            Self.bindText(stmt, 3, record.turnID)
            Self.bindText(stmt, 4, record.unknownText)
            sqlite3_bind_double(stmt, 5, record.confidence)
            sqlite3_bind_int64(stmt, 6, record.discoveredAtMs)
            let rc = sqlite3_step(stmt)
            if rc != SQLITE_DONE {
                try? Self.runExec(db: db, sql: "ROLLBACK;")
                if rc == SQLITE_CONSTRAINT {
                    throw StorageError.duplicateEventID(
                        record.eventID)
                }
                throw StorageError.stepFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
            }
        }
        try Self.runExec(db: db, sql: "COMMIT;")
        return records
    }

    private func queryRecords(
        whereClause: String, bindings: [String]
    ) throws -> [BASUnknownLedgerRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            SELECT event_id, session_id, turn_id, unknown_text,
                   confidence, discovered_at_ms
            FROM unknown_ledger_records
            WHERE \(whereClause)
            ORDER BY discovered_at_ms ASC, rowid ASC
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else {
            throw StorageError.prepareFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        for (i, val) in bindings.enumerated() {
            Self.bindText(stmt, Int32(i + 1), val)
        }
        var results: [BASUnknownLedgerRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(BASUnknownLedgerRecord(
                eventID: String(cString: sqlite3_column_text(stmt, 0)),
                sessionID: String(cString: sqlite3_column_text(stmt, 1)),
                turnID: String(cString: sqlite3_column_text(stmt, 2)),
                unknownText: String(cString: sqlite3_column_text(stmt, 3)),
                confidence: sqlite3_column_double(stmt, 4),
                discoveredAtMs: sqlite3_column_int64(stmt, 5)))
        }
        return results
    }

    // MARK: - SQLite helpers (mirror BASSQLiteAtomLifecycleStore)

    private static func runExec(
        db: OpaquePointer, sql: String
    ) throws {
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map {
                String(cString: $0)
            } ?? "sqlite3_exec rc=\(rc)"
            if err != nil { sqlite3_free(err) }
            throw StorageError.stepFailed(sql: sql, message: msg)
        }
    }

    private static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        var stmt: OpaquePointer?
        let sql = "PRAGMA user_version;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else {
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

    private static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self)

    private static func bindText(
        _ stmt: OpaquePointer?,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }
}
