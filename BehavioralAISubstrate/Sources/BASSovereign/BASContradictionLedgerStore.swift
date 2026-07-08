// MARK: - BASContradictionLedgerStore
// chapter 七百九十四 / M2621-M2625 — L7 contradiction-ledger storage
//
// Persistence seam for L7 contradiction signals emitted by the
// chapter 七百六十四 decomposition pipeline。 Pairs with SQL
// schema 012_contradiction_ledger_records。

import Foundation
import SQLite3
import BASRuntimeCore

// MARK: - BASContradictionLedgerRecord typed record

public struct BASContradictionLedgerRecord:
    Sendable, Equatable, Hashable, Codable
{
    public let eventID: String
    public let sessionID: String
    public let turnID: String
    public let contradictionText: String
    /// Strength of the contradiction reading [0, 1]。 Schema CHECK。
    public let salience: Double
    /// Classifier confidence [0, 1]。 Schema CHECK。
    public let confidence: Double
    /// True iff a follow-up turn observed the contradiction
    /// resolved。 Stored as INTEGER 0/1 per schema CHECK。
    public let resolved: Bool
    /// UNIX epoch ms when resolved;nil when still open。
    public let resolvedAtMs: Int64?

    public init(
        eventID: String,
        sessionID: String,
        turnID: String,
        contradictionText: String,
        salience: Double,
        confidence: Double,
        resolved: Bool = false,
        resolvedAtMs: Int64? = nil
    ) {
        self.eventID = eventID
        self.sessionID = sessionID
        self.turnID = turnID
        self.contradictionText = contradictionText
        self.salience = salience
        self.confidence = confidence
        self.resolved = resolved
        self.resolvedAtMs = resolvedAtMs
    }
}

// MARK: - BASContradictionLedgerStore protocol

public protocol BASContradictionLedgerStore: Sendable {
    func appendRecord(
        _ record: BASContradictionLedgerRecord
    ) async throws -> BASContradictionLedgerRecord
    func records(forSession sessionID: String) async -> [BASContradictionLedgerRecord]
    func records(forTurn turnID: String) async -> [BASContradictionLedgerRecord]
    func count() async -> Int
}

// MARK: - In-memory reference impl

public actor BASInMemoryContradictionLedgerStore:
    BASContradictionLedgerStore
{
    public enum StoreError: Error, Equatable, Sendable {
        case duplicateEventID(String)
    }

    private var records: [BASContradictionLedgerRecord] = []
    private var indexByEventID: [String: Int] = [:]

    public init() {}

    public func appendRecord(
        _ record: BASContradictionLedgerRecord
    ) async throws -> BASContradictionLedgerRecord {
        if indexByEventID[record.eventID] != nil {
            throw StoreError.duplicateEventID(record.eventID)
        }
        indexByEventID[record.eventID] = records.count
        records.append(record)
        return record
    }

    public func records(
        forSession sessionID: String
    ) async -> [BASContradictionLedgerRecord] {
        records.filter { $0.sessionID == sessionID }
    }

    public func records(
        forTurn turnID: String
    ) async -> [BASContradictionLedgerRecord] {
        records.filter { $0.turnID == turnID }
    }

    public func count() async -> Int { records.count }

    // MARK: - Batch append (chapter 八百五 — API symmetry)

    @discardableResult
    public func appendBatch(
        _ records: [BASContradictionLedgerRecord]
    ) async throws -> [BASContradictionLedgerRecord] {
        for record in records {
            _ = try await appendRecord(record)
        }
        return records
    }
}

// MARK: - SQLite-backed conformer

public actor BASSQLiteContradictionLedgerStore:
    BASContradictionLedgerStore
{
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
        // semicolons in narrative text。
        try Self.runExec(db: handle,
            sql: ContradictionLedgerRecordsSchema.allStatementsSQL)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    public func appendRecord(
        _ record: BASContradictionLedgerRecord
    ) async throws -> BASContradictionLedgerRecord {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            INSERT INTO contradiction_ledger_records (
                event_id, session_id, turn_id, contradiction_text,
                salience, confidence, resolved, resolved_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
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
        Self.bindText(stmt, 4, record.contradictionText)
        sqlite3_bind_double(stmt, 5, record.salience)
        sqlite3_bind_double(stmt, 6, record.confidence)
        sqlite3_bind_int(stmt, 7, record.resolved ? 1 : 0)
        if let resolvedAtMs = record.resolvedAtMs {
            sqlite3_bind_int64(stmt, 8, resolvedAtMs)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
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
    ) async -> [BASContradictionLedgerRecord] {
        return (try? queryRecords(
            whereClause: "session_id = ?",
            bindings: [sessionID])) ?? []
    }

    public func records(
        forTurn turnID: String
    ) async -> [BASContradictionLedgerRecord] {
        return (try? queryRecords(
            whereClause: "turn_id = ?",
            bindings: [turnID])) ?? []
    }

    public func count() async -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM contradiction_ledger_records;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Batch append optimization (chapter 八百五)

    /// Append many records in a single SQLite transaction with a
    /// re-used prepared statement。 Mirror of chapter 八百四 L8
    /// batch pattern。 ROLLBACK on first error。
    @discardableResult
    public func appendBatch(
        _ records: [BASContradictionLedgerRecord]
    ) async throws -> [BASContradictionLedgerRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        if records.isEmpty { return [] }
        try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")
        let sql = """
            INSERT INTO contradiction_ledger_records (
                event_id, session_id, turn_id, contradiction_text,
                salience, confidence, resolved, resolved_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
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
            Self.bindText(stmt, 4, record.contradictionText)
            sqlite3_bind_double(stmt, 5, record.salience)
            sqlite3_bind_double(stmt, 6, record.confidence)
            sqlite3_bind_int(stmt, 7, record.resolved ? 1 : 0)
            if let resolvedAtMs = record.resolvedAtMs {
                sqlite3_bind_int64(stmt, 8, resolvedAtMs)
            } else {
                sqlite3_bind_null(stmt, 8)
            }
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
    ) throws -> [BASContradictionLedgerRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            SELECT event_id, session_id, turn_id, contradiction_text,
                   salience, confidence, resolved, resolved_at_ms
            FROM contradiction_ledger_records
            WHERE \(whereClause)
            ORDER BY rowid ASC
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
        var results: [BASContradictionLedgerRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let resolvedAtMs: Int64? =
                sqlite3_column_type(stmt, 7) == SQLITE_NULL
                ? nil : sqlite3_column_int64(stmt, 7)
            results.append(BASContradictionLedgerRecord(
                eventID: String(cString: sqlite3_column_text(stmt, 0)),
                sessionID: String(cString: sqlite3_column_text(stmt, 1)),
                turnID: String(cString: sqlite3_column_text(stmt, 2)),
                contradictionText: String(cString: sqlite3_column_text(stmt, 3)),
                salience: sqlite3_column_double(stmt, 4),
                confidence: sqlite3_column_double(stmt, 5),
                resolved: sqlite3_column_int(stmt, 6) != 0,
                resolvedAtMs: resolvedAtMs))
        }
        return results
    }

    // MARK: - SQLite helpers

    private static func runExec(
        db: OpaquePointer, sql: String
    ) throws {
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) }
                ?? "sqlite3_exec rc=\(rc)"
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
