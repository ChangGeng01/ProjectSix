// MARK: - BASPresenceObservationStore
// chapter 七百九十五 / M2626-M2630 — L6 presence-observations storage
//
// Persistence seam for the L6 multi-channel presence signals
// (chapter 七百六十六 bas-presence-eye)。 Pairs with SQL schema
// 013_presence_observations (chapter 七百六十七)。

import Foundation
import SQLite3

// MARK: - BASPresenceObservationRecord typed record

public struct BASPresenceObservationRecord:
    Sendable, Equatable, Hashable, Codable
{
    public let eventID: String
    public let sessionID: String
    public let turnID: String
    /// Channel name (matches SQL 013 CHECK):
    /// task / risk / manipulation / environment / bodyRhythm
    public let channelKind: String
    public let salience: Double
    public let confidence: Double
    public let observedAtMs: Int64

    public init(
        eventID: String,
        sessionID: String,
        turnID: String,
        channelKind: String,
        salience: Double,
        confidence: Double,
        observedAtMs: Int64
    ) {
        self.eventID = eventID
        self.sessionID = sessionID
        self.turnID = turnID
        self.channelKind = channelKind
        self.salience = salience
        self.confidence = confidence
        self.observedAtMs = observedAtMs
    }
}

// MARK: - BASPresenceObservationStore protocol

public protocol BASPresenceObservationStore: Sendable {
    func appendRecord(
        _ record: BASPresenceObservationRecord
    ) async throws -> BASPresenceObservationRecord
    func records(forSession sessionID: String) async -> [BASPresenceObservationRecord]
    func records(forChannel channelKind: String) async -> [BASPresenceObservationRecord]
    func count() async -> Int
}

// MARK: - In-memory reference impl

public actor BASInMemoryPresenceObservationStore:
    BASPresenceObservationStore
{
    public enum StoreError: Error, Equatable, Sendable {
        case duplicateEventID(String)
    }

    private var records: [BASPresenceObservationRecord] = []
    private var indexByEventID: [String: Int] = [:]

    public init() {}

    public func appendRecord(
        _ record: BASPresenceObservationRecord
    ) async throws -> BASPresenceObservationRecord {
        if indexByEventID[record.eventID] != nil {
            throw StoreError.duplicateEventID(record.eventID)
        }
        indexByEventID[record.eventID] = records.count
        records.append(record)
        return record
    }

    public func records(
        forSession sessionID: String
    ) async -> [BASPresenceObservationRecord] {
        records.filter { $0.sessionID == sessionID }
    }

    public func records(
        forChannel channelKind: String
    ) async -> [BASPresenceObservationRecord] {
        records.filter { $0.channelKind == channelKind }
    }

    public func count() async -> Int { records.count }

    // MARK: - Batch append (chapter 八百六 — API symmetry)

    @discardableResult
    public func appendBatch(
        _ records: [BASPresenceObservationRecord]
    ) async throws -> [BASPresenceObservationRecord] {
        for record in records {
            _ = try await appendRecord(record)
        }
        return records
    }
}

// MARK: - SQLite-backed conformer

public actor BASSQLitePresenceObservationStore:
    BASPresenceObservationStore
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
        try Self.runExec(db: handle,
            sql: PresenceObservationsSchema.allStatementsSQL)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    public func appendRecord(
        _ record: BASPresenceObservationRecord
    ) async throws -> BASPresenceObservationRecord {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            INSERT INTO presence_observations (
                event_id, session_id, turn_id, channel_kind,
                salience, confidence, observed_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
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
        Self.bindText(stmt, 4, record.channelKind)
        sqlite3_bind_double(stmt, 5, record.salience)
        sqlite3_bind_double(stmt, 6, record.confidence)
        sqlite3_bind_int64(stmt, 7, record.observedAtMs)
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
    ) async -> [BASPresenceObservationRecord] {
        return (try? queryRecords(
            whereClause: "session_id = ?",
            bindings: [sessionID])) ?? []
    }

    public func records(
        forChannel channelKind: String
    ) async -> [BASPresenceObservationRecord] {
        return (try? queryRecords(
            whereClause: "channel_kind = ?",
            bindings: [channelKind])) ?? []
    }

    public func count() async -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM presence_observations;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Batch append (chapter 八百六)

    @discardableResult
    public func appendBatch(
        _ records: [BASPresenceObservationRecord]
    ) async throws -> [BASPresenceObservationRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        if records.isEmpty { return [] }
        try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")
        let sql = """
            INSERT INTO presence_observations (
                event_id, session_id, turn_id, channel_kind,
                salience, confidence, observed_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
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
            Self.bindText(stmt, 4, record.channelKind)
            sqlite3_bind_double(stmt, 5, record.salience)
            sqlite3_bind_double(stmt, 6, record.confidence)
            sqlite3_bind_int64(stmt, 7, record.observedAtMs)
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
    ) throws -> [BASPresenceObservationRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            SELECT event_id, session_id, turn_id, channel_kind,
                   salience, confidence, observed_at_ms
            FROM presence_observations
            WHERE \(whereClause)
            ORDER BY observed_at_ms ASC, rowid ASC
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
        var results: [BASPresenceObservationRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(BASPresenceObservationRecord(
                eventID: String(cString: sqlite3_column_text(stmt, 0)),
                sessionID: String(cString: sqlite3_column_text(stmt, 1)),
                turnID: String(cString: sqlite3_column_text(stmt, 2)),
                channelKind: String(cString: sqlite3_column_text(stmt, 3)),
                salience: sqlite3_column_double(stmt, 4),
                confidence: sqlite3_column_double(stmt, 5),
                observedAtMs: sqlite3_column_int64(stmt, 6)))
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
