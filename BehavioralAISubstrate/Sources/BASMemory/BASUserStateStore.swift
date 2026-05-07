// MARK: - BASUserStateStore — chapter 三百五五 / M842
//
// Phase P1 G2 第三刀: persistence for the state vector S_t produced
// by `BASUserStateReducer`。
//
// ## What this is
//
// Append-history typed state store with two retrieval modes:
//   1. By `stateID` (for event log cross-references — G1 events
//      carry `stateBeforeID` / `stateAfterID` which point here)
//   2. Latest-for-session (for the next reducer call — fetch
//      `S_{t-1}` to fold next event into)
//
// Mirrors `BASEventLogStorage` protocol pattern + provides both
// in-memory + SQLite-backed conformers。
//
// ## Storage shape (SQLite version 1)
//
//   CREATE TABLE user_states (
//     state_id TEXT PRIMARY KEY NOT NULL,
//     session_id TEXT NOT NULL,
//     generated_at_ms INTEGER NOT NULL,
//     payload_json TEXT NOT NULL
//   );
//   CREATE INDEX user_states_session_time_idx
//     ON user_states(session_id, generated_at_ms DESC);
//
// **Append-history doctrine**: states are NEVER updated;each
// reducer call produces a new state_id row。Old states are kept
// for replay correctness (S_{t-1} pointer stability)。Pruning is
// a separate operator workflow (chapter 一百二 五级删除 mirror)。
//
// ## Doctrine pins held
//
//   - All BASUserState.swift / BASUserStateReducer.swift pins apply
//   - 单提交口 (L11/L14) 不变 — store is observation-only
//   - chapter 二百四十八 M735 idiom — same SQLite pattern as event
//     log storage + memory atom store
//   - chapter 二百一一 single-source-of-truth — ONE protocol,
//     two conformers (in-memory + SQLite) byte-equal
//   - ADR-014 OPT-IN → PROD — store is opt-in,wired only by
//     hosts that want continuous-state observability

import Foundation
import SQLite3
import BASRuntimeCore

// MARK: - Storage protocol

/// Append-history typed user state storage。Sendable;all methods
/// async per existing storage idiom。
public protocol BASUserStateStorage: Sendable {

    /// Append a new state snapshot。Idempotent on duplicate
    /// `stateID` — re-appending returns `false` and does not
    /// mutate。
    @discardableResult
    func append(
        _ state: BASUserState,
        sessionID: String
    ) async throws -> Bool

    /// Read state by stateID。Returns nil if not found。
    func state(forID stateID: String) async -> BASUserState?

    /// Read most-recent state for `sessionID` ordered by
    /// `generatedAtMs DESC`。Returns nil if session has no states。
    func latestState(
        forSession sessionID: String
    ) async -> BASUserState?

    /// Total state count (all sessions)。
    var totalCount: Int { get async }
}

// MARK: - In-memory conformer

public actor BASInMemoryUserStateStorage: BASUserStateStorage {

    private var states: [String: BASUserState] = [:]
    private var sessionIndex: [String: [String]] = [:]
        // sessionID → [stateID] insertion order

    public init() {}

    @discardableResult
    public func append(
        _ state: BASUserState,
        sessionID: String
    ) async throws -> Bool {
        if states[state.stateID] != nil { return false }
        states[state.stateID] = state
        sessionIndex[sessionID, default: []]
            .append(state.stateID)
        return true
    }

    public func state(
        forID stateID: String
    ) async -> BASUserState? {
        states[stateID]
    }

    public func latestState(
        forSession sessionID: String
    ) async -> BASUserState? {
        guard let ids = sessionIndex[sessionID],
              !ids.isEmpty
        else { return nil }
        // Latest = highest generatedAtMs among the session's states
        var latest: BASUserState? = nil
        for id in ids {
            guard let s = states[id] else { continue }
            if let prior = latest {
                if s.generatedAtMs > prior.generatedAtMs {
                    latest = s
                }
            } else {
                latest = s
            }
        }
        return latest
    }

    public var totalCount: Int {
        states.count
    }
}

// MARK: - SQLite conformer

public actor BASSQLiteUserStateStorage: BASUserStateStorage {

    public enum StorageError: Error, Equatable, Sendable {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case encodeFailed(stateID: String, message: String)
        case decodeFailed(stateID: String, message: String)
    }

    public static let schemaVersion: Int = 1
    public let databaseURL: URL
    private nonisolated(unsafe) var db: OpaquePointer?

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(
            databaseURL.path, &handle, flags, nil)
        guard rc == SQLITE_OK, let handle else {
            let message = handle.flatMap { db -> String? in
                String(cString: sqlite3_errmsg(db))
            } ?? "sqlite3_open_v2 rc=\(rc)"
            if handle != nil { sqlite3_close_v2(handle) }
            throw StorageError.openFailed(
                code: rc, message: message)
        }
        self.db = handle
        try Self.runExec(db: handle, sql: "PRAGMA journal_mode=WAL;")
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")

        // M886 backport (M882 audit fix):read user_version FIRST。
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

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    @discardableResult
    public func append(
        _ state: BASUserState,
        sessionID: String
    ) async throws -> Bool {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        if try Self.fetchExists(db: db, stateID: state.stateID) {
            return false
        }
        try Self.insert(
            db: db, state: state, sessionID: sessionID)
        return true
    }

    public func state(
        forID stateID: String
    ) async -> BASUserState? {
        guard let db else { return nil }
        return try? Self.fetch(db: db, stateID: stateID)
    }

    public func latestState(
        forSession sessionID: String
    ) async -> BASUserState? {
        guard let db else { return nil }
        return try? Self.fetchLatestForSession(
            db: db, sessionID: sessionID)
    }

    public var totalCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countAll(db: db)) ?? 0
        }
    }

    // MARK: - Schema

    fileprivate static func ensureSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS user_states (
                state_id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                generated_at_ms INTEGER NOT NULL,
                payload_json TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                user_states_session_time_idx
                ON user_states(session_id, generated_at_ms DESC);
            """)
    }

    fileprivate static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let found = try readUserVersion(db: db)
        guard found == schemaVersion else {
            throw StorageError.schemaVersionMismatch(
                found: found, expected: schemaVersion)
        }
    }

    /// M886 backport (M882 audit fix):read PRAGMA user_version
    /// without setting。Returns 0 for fresh DBs。
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

    // MARK: - CRUD

    fileprivate static func insert(
        db: OpaquePointer,
        state: BASUserState,
        sessionID: String
    ) throws {
        let sql = """
            INSERT INTO user_states (
                state_id, session_id, generated_at_ms,
                payload_json
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
        let payloadJson: String
        do {
            let data = try JSONEncoder().encode(state)
            guard let s = String(data: data, encoding: .utf8)
            else {
                throw StorageError.encodeFailed(
                    stateID: state.stateID,
                    message: "encoded data not UTF-8")
            }
            payloadJson = s
        } catch let e as StorageError {
            throw e
        } catch {
            throw StorageError.encodeFailed(
                stateID: state.stateID,
                message: "\(error)")
        }
        bindText(stmt, 1, state.stateID)
        bindText(stmt, 2, sessionID)
        sqlite3_bind_int64(stmt, 3, state.generatedAtMs)
        bindText(stmt, 4, payloadJson)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetch(
        db: OpaquePointer,
        stateID: String
    ) throws -> BASUserState? {
        let sql = """
            SELECT payload_json FROM user_states
            WHERE state_id = ?
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
        bindText(stmt, 1, stateID)
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let json = readText(stmt, 0)
        return try decode(stateID: stateID, json: json)
    }

    fileprivate static func fetchExists(
        db: OpaquePointer,
        stateID: String
    ) throws -> Bool {
        let sql = """
            SELECT 1 FROM user_states WHERE state_id = ?
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
        bindText(stmt, 1, stateID)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    fileprivate static func fetchLatestForSession(
        db: OpaquePointer,
        sessionID: String
    ) throws -> BASUserState? {
        let sql = """
            SELECT state_id, payload_json FROM user_states
            WHERE session_id = ?
            ORDER BY generated_at_ms DESC
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
        bindText(stmt, 1, sessionID)
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        let id = readText(stmt, 0)
        let json = readText(stmt, 1)
        return try decode(stateID: id, json: json)
    }

    fileprivate static func countAll(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM user_states"
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

    fileprivate static func decode(
        stateID: String,
        json: String
    ) throws -> BASUserState {
        guard let data = json.data(using: .utf8) else {
            throw StorageError.decodeFailed(
                stateID: stateID,
                message: "payload_json not UTF-8")
        }
        do {
            return try JSONDecoder().decode(
                BASUserState.self, from: data)
        } catch {
            throw StorageError.decodeFailed(
                stateID: stateID, message: "\(error)")
        }
    }

    // MARK: - Utility (mirror of event log storage)

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
