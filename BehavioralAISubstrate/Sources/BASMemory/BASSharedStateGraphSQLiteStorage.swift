// MARK: - BASSharedStateGraphSQLiteStorage
// chapter 九百五十六.7 / M3485.7
//
// SQLite-backed persistence for `BASSharedStateGraph` state objects
// + writer registry。 Mirrors the actor + WAL idiom from
// `BASHostConstitutionSQLiteStorage` (ch 二百四十九) and
// `BASSQLiteMemoryAtomStore` (ch 二百四十八)。
//
// Per user directive「继续 提高 Metal sql rust c c++ 比例」 the
// Agent Fabric scope now grows a real SQL surface — previously the
// graph was in-memory only。 This adapter ships disk-backed
// persistence with WAL journal,FK constraints,CHECK constraints,
// and idempotent UPSERT semantics so a process restart can hydrate
// the full shared graph snapshot。
//
// ## Schema (version 1)
//
//   CREATE TABLE shared_state_objects (
//     ref TEXT PRIMARY KEY NOT NULL,        -- "<domain>#<objectID>"
//     domain TEXT NOT NULL,                 -- BASStateDomain.rawValue
//     object_id TEXT NOT NULL,              -- pre-parsed for query
//     payload_json TEXT NOT NULL,           -- opaque agent payload
//     last_writer_agent_id TEXT NOT NULL,
//     version INTEGER NOT NULL CHECK (version >= 0),
//     updated_at_ms INTEGER NOT NULL
//   );
//   CREATE INDEX state_object_domain_idx
//     ON shared_state_objects(domain);
//
//   CREATE TABLE shared_state_writers (
//     domain TEXT PRIMARY KEY NOT NULL,     -- BASStateDomain.rawValue
//     agent_id TEXT NOT NULL,               -- registered writer
//     registered_at_ms INTEGER NOT NULL
//   );
//
// Both tables use TEXT for the domain key (BASStateDomain.rawValue
// — stable string enum)。 Numeric `version` + `*_ms` columns are
// INTEGER for SQL filtering without JSON parse。
//
// ## Doctrine pins
//
//   - 红线 7 — additive only;BASSharedStateGraph behavior
//     unchanged when no storage adapter is wired
//   - ADR-014 OPT-IN — persistence is opt-in via storage parameter
//   - Single-Writer-Per-Domain — storage is plumbing,not a gate
//     (writer-identity enforcement stays in `BASSharedStateGraph`
//     ch 956.5 USER-PASS gap #1 fix)
//   - chapter 一百二 五级删除 — `deleteObject(ref:)` issues real
//     SQL DELETE (no tombstone),symmetric with the in-memory
//     graph's "remove via writeObject empty payload" convention
//   - WAL + synchronous=NORMAL — crash leaves DB at a consistent
//     prior state (ch 二百四十八 idiom)

import Foundation
import SQLite3

/// SQLite-backed `BASSharedStateGraph` persistence。 The actor's
/// isolation boundary serializes all method calls,so the underlying
/// `OpaquePointer` does not need a separate lock。
///
/// Hosts call `upsertObject(_:)` whenever the graph's `writeObject`
/// succeeds,and `upsertWriter(domain:agentID:)` whenever a writer
/// is claimed (or auto-claimed on first write)。 They call
/// `loadAllObjects()` + `loadAllWriters()` at session boot to
/// hydrate the actor。
public actor BASSharedStateGraphSQLiteStorage:
    BASSharedStateGraphStorage
{

    // MARK: - Errors

    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case corruptedRow(ref: String, reason: String)
        case unknownDomain(rawValue: String)
    }

    public static let schemaVersion: Int = 1

    // MARK: - Stored state

    /// Database file URL。
    public let databaseURL: URL

    /// Owned SQLite handle。 `nonisolated(unsafe)` opt-out is the
    /// chapter 二百四十八 / M735 idiom for deinit-time cleanup of an
    /// actor-isolated `OpaquePointer`。
    private nonisolated(unsafe) var db: OpaquePointer?

    // MARK: - Lifecycle

    /// Open or create the SQLite-backed graph storage。 Parent
    /// directory MUST exist。
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
        try Self.runExec(
            db: handle, sql: "PRAGMA foreign_keys=ON;")
        let existingVersion = try Self.readUserVersion(db: handle)
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
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - State object persistence

    public func upsertObject(
        _ obj: BASStateGraphObject
    ) async throws {
        guard let db else { return }
        try Self.upsertObjectRow(db: db, obj: obj)
    }

    public func loadObject(
        ref: String
    ) async throws -> BASStateGraphObject? {
        guard let db else { return nil }
        return try Self.fetchObject(db: db, ref: ref)
    }

    public func loadAllObjects(
    ) async throws -> [BASStateGraphObject] {
        guard let db else { return [] }
        return try Self.fetchAllObjects(db: db)
    }

    public func deleteObject(ref: String) async throws {
        guard let db else { return }
        try Self.deleteObjectRow(db: db, ref: ref)
    }

    // MARK: - Writer registry persistence

    public func upsertWriter(
        domain: BASStateDomain,
        agentID: String
    ) async throws {
        guard let db else { return }
        try Self.upsertWriterRow(
            db: db, domain: domain, agentID: agentID)
    }

    public func loadAllWriters(
    ) async throws -> [(domain: BASStateDomain, agentID: String)] {
        guard let db else { return [] }
        return try Self.fetchAllWriters(db: db)
    }

    // MARK: - Observability (test / audit only)

    public var objectCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countObjects(db: db)) ?? 0
        }
    }

    public var writerCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countWriters(db: db)) ?? 0
        }
    }

    // MARK: - Schema setup

    private static func ensureSchema(db: OpaquePointer) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS shared_state_objects (
                ref TEXT PRIMARY KEY NOT NULL,
                domain TEXT NOT NULL,
                object_id TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                last_writer_agent_id TEXT NOT NULL,
                version INTEGER NOT NULL CHECK (version >= 0),
                updated_at_ms INTEGER NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS state_object_domain_idx
              ON shared_state_objects(domain);
            """)
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS shared_state_writers (
                domain TEXT PRIMARY KEY NOT NULL,
                agent_id TEXT NOT NULL,
                registered_at_ms INTEGER NOT NULL
            );
            """)
    }

    fileprivate static func readUserVersion(
        db: OpaquePointer
    ) throws -> Int {
        var stmt: OpaquePointer?
        let sql = "PRAGMA user_version;"
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

    // MARK: - State object CRUD

    fileprivate static func upsertObjectRow(
        db: OpaquePointer, obj: BASStateGraphObject
    ) throws {
        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)
        let sql = """
            INSERT INTO shared_state_objects (
                ref, domain, object_id, payload_json,
                last_writer_agent_id, version, updated_at_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(ref) DO UPDATE SET
                domain = excluded.domain,
                object_id = excluded.object_id,
                payload_json = excluded.payload_json,
                last_writer_agent_id =
                    excluded.last_writer_agent_id,
                version = excluded.version,
                updated_at_ms = excluded.updated_at_ms
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
        bindText(stmt, 1, obj.ref)
        bindText(stmt, 2, obj.domain.rawValue)
        bindText(stmt, 3, obj.objectID)
        bindText(stmt, 4, obj.payloadJson)
        bindText(stmt, 5, obj.lastWriterAgentID)
        sqlite3_bind_int64(stmt, 6, obj.version)
        sqlite3_bind_int64(stmt, 7, nowMs)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchObject(
        db: OpaquePointer, ref: String
    ) throws -> BASStateGraphObject? {
        let sql = """
            SELECT domain, object_id, payload_json,
                   last_writer_agent_id, version
            FROM shared_state_objects
            WHERE ref = ?
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
        bindText(stmt, 1, ref)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return try decodeObjectRow(stmt: stmt)
    }

    fileprivate static func fetchAllObjects(
        db: OpaquePointer
    ) throws -> [BASStateGraphObject] {
        let sql = """
            SELECT domain, object_id, payload_json,
                   last_writer_agent_id, version
            FROM shared_state_objects
            ORDER BY ref ASC
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
        var out: [BASStateGraphObject] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else {
                throw StorageError.stepFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
            }
            out.append(try decodeObjectRow(stmt: stmt))
        }
        return out
    }

    private static func decodeObjectRow(
        stmt: OpaquePointer
    ) throws -> BASStateGraphObject {
        let domainRaw = String(
            cString: sqlite3_column_text(stmt, 0))
        let objectID = String(
            cString: sqlite3_column_text(stmt, 1))
        let payloadJson = String(
            cString: sqlite3_column_text(stmt, 2))
        let lastWriter = String(
            cString: sqlite3_column_text(stmt, 3))
        let version = sqlite3_column_int64(stmt, 4)
        guard let domain = BASStateDomain(rawValue: domainRaw)
        else {
            throw StorageError.unknownDomain(rawValue: domainRaw)
        }
        return BASStateGraphObject(
            domain: domain,
            objectID: objectID,
            payloadJson: payloadJson,
            lastWriterAgentID: lastWriter,
            version: version)
    }

    fileprivate static func deleteObjectRow(
        db: OpaquePointer, ref: String
    ) throws {
        let sql = """
            DELETE FROM shared_state_objects WHERE ref = ?
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
        bindText(stmt, 1, ref)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func countObjects(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM shared_state_objects"
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

    // MARK: - Writer registry CRUD

    fileprivate static func upsertWriterRow(
        db: OpaquePointer,
        domain: BASStateDomain,
        agentID: String
    ) throws {
        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)
        let sql = """
            INSERT INTO shared_state_writers (
                domain, agent_id, registered_at_ms
            ) VALUES (?, ?, ?)
            ON CONFLICT(domain) DO UPDATE SET
                agent_id = excluded.agent_id,
                registered_at_ms = excluded.registered_at_ms
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
        bindText(stmt, 1, domain.rawValue)
        bindText(stmt, 2, agentID)
        sqlite3_bind_int64(stmt, 3, nowMs)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchAllWriters(
        db: OpaquePointer
    ) throws -> [(domain: BASStateDomain, agentID: String)] {
        let sql = """
            SELECT domain, agent_id FROM shared_state_writers
            ORDER BY domain ASC
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
        var out: [(BASStateDomain, String)] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else {
                throw StorageError.stepFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
            }
            let domainRaw = String(
                cString: sqlite3_column_text(stmt, 0))
            let agentID = String(
                cString: sqlite3_column_text(stmt, 1))
            guard let domain = BASStateDomain(
                rawValue: domainRaw)
            else {
                throw StorageError.unknownDomain(
                    rawValue: domainRaw)
            }
            out.append((domain, agentID))
        }
        return out
    }

    fileprivate static func countWriters(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM shared_state_writers"
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

    // MARK: - SQL helpers

    fileprivate static func runExec(
        db: OpaquePointer, sql: String
    ) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.flatMap { String(cString: $0) }
                ?? "exec failed rc=\(rc)"
            if let errMsg { sqlite3_free(errMsg) }
            throw StorageError.stepFailed(sql: sql, message: msg)
        }
    }

    fileprivate static func bindText(
        _ stmt: OpaquePointer, _ idx: Int32, _ s: String
    ) {
        let transient = unsafeBitCast(
            -1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, idx, s, -1, transient)
    }
}
