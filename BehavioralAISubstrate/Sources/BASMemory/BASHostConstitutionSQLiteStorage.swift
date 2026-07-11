// MARK: - BASHostConstitutionSQLiteStorage — chapter 二百四十九 / M736
//
// Cross-session L5 host constitution vault persistence.
//
// ## Why this exists
//
// `BASHostConstitutionVault` is a Codable + Sendable + Equatable
// schema (`BASSchemaVersioned`) that wraps a full
// `BASHostConstitution` snapshot (11 lattice / genome / spine /
// veil / canopy / etc. domains) plus the deletion manifest, rollback
// lineage, sync revocation ledger, and device consistency report.
// Pre-chapter 二百四十九 it lived only in memory: every session boot
// rebuilt the vault from scratch, every save was a pure value-type
// snapshot in actor state. Cross-session continuity was vacuous.
//
// chapter 二百四十九 ships the second 附录 V Stage 0 storage primitive
// (after chapter 二百四十八 `BASSQLiteMemoryAtomStore`). Same
// idiom, same SQLite3 system framework, but a different shape:
//   - one row per vault (vaultID is PK)
//   - the entire `BASHostConstitutionVault` lives in a single
//     `payload_json` column (matches M270 ticket lifecycle storage)
//   - structural mirror columns (host_id / constitution_id /
//     active_version / schema_version / version_signature /
//     last_updated_at_ms) for SQL filtering without JSON parse
//
// ## Why JSON blob over 11-table normalized schema
//
// The plan初稿 sketched "12 个 host constitution domains 各自一表"
// (12 tables, one per domain). After surveying `BASHostConstitution`
// the verdict is: **JSON blob is the right shape**. Reasoning:
//
//   1. The 11 domains live on a single `BASHostConstitution`
//      Codable struct. Splitting into JOIN tables creates artificial
//      complexity for what is conceptually one snapshot.
//   2. Domain-level revocation is orchestrated by
//      `BASHostDeletionManifest` (already a vault field). The
//      manifest names targets via refs; the host runtime applies
//      them and re-saves the vault. Storage just persists state —
//      domain-level cascading lives in higher layers.
//   3. M270 ticket lifecycle storage's `entry_json` proved this
//      shape works for evolving Codable schemas without painful SQL
//      migrations.
//   4. If query-by-domain becomes a hot path later, indices on
//      derived columns can be added (or the JSON1 extension can
//      query within the blob without re-shape).
//
// ## Doctrine pins
//
//   - 不变量 #1 先醒再答: storage doesn't change runtime ordering.
//   - 不变量 #2 神经不掌权: persistence is plumbing, not a permit
//     gate. The L11 single commit mouth is unchanged.
//   - 不变量 #3 私有经验不进权重: the JSON payload is the same
//     `BASHostConstitutionVault` data the in-memory actor would
//     carry — persisting it does not feed L2 base weights.
//   - chapter 一百二 五级删除 doctrine: `remove(vaultID:)` issues a
//     real SQL `DELETE` (not a tombstone). Domain-level cascade
//     (revoke specific ref refs) is host-level orchestration above
//     this layer; it works by mutating the vault's
//     `BASHostDeletionManifest` and re-saving.
//   - chapter 一百九十一 M91 / chapter 二百六十八 M270 SQLite idiom:
//     `import SQLite3` system framework (no new package deps),
//     `OpaquePointer` actor-isolated handle, transient bind
//     destructor, WAL journal mode for concurrent readers, schema-
//     version pragma verified on every open.
//   - chapter 二百十一 single-source-of-truth: vault data model
//     stays in `HostConstitutionCore.swift`; this file is a
//     storage adapter, not a contract definer.
//
// ## Schema (version 1)
//
//   CREATE TABLE host_constitution_vaults (
//     vault_id TEXT PRIMARY KEY NOT NULL,    -- vault.vaultID
//     host_id TEXT NOT NULL,                 -- vault.snapshot.hostID
//     constitution_id TEXT NOT NULL,         -- vault.constitutionID
//     active_version TEXT NOT NULL,          -- snapshot.activeVersion
//     schema_version TEXT NOT NULL,          -- vault.schemaVersion
//     version_signature TEXT NOT NULL,       -- vault.versionSignature
//     last_updated_at_ms INTEGER NOT NULL,
//     payload_json TEXT NOT NULL             -- vault Codable JSON
//   );
//   CREATE INDEX host_constitution_host_idx
//     ON host_constitution_vaults(host_id);
//
// One vault per host is the typical case but the schema does not
// enforce that — multi-host installations get one row per host's
// vault.

import Foundation
import SQLite3
import BASRuntimeCore

/// SQLite-backed `BASHostConstitutionVault` persistence. Vaults
/// live across process restarts in the configured database file.
/// The actor's isolation boundary serializes every method call, so
/// the underlying `OpaquePointer` does not need a separate lock.
///
/// Hosts call `save(_:)` whenever the vault changes (after a
/// constitutional update, after a domain revocation, after a
/// rollback). They call `loadVault(vaultID:)` at session boot.
/// Both flows are idempotent.
public actor BASHostConstitutionSQLiteStorage {

    // MARK: - Errors

    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case encodeFailed(vaultID: String, message: String)
        case decodeFailed(vaultID: String, message: String)
        case corruptedRow(vaultID: String, reason: String)
    }

    public static let schemaVersion: Int = 1

    // MARK: - Stored state

    /// Database file URL.
    public let databaseURL: URL

    /// Owned SQLite handle. See chapter 二百四十八 / M735 commentary
    /// on why `nonisolated(unsafe)` is the right opt-out for
    /// deinit-time cleanup of an actor-isolated `OpaquePointer`.
    private nonisolated(unsafe) var db: OpaquePointer?

    // MARK: - Lifecycle

    /// Open or create the SQLite-backed vault store at
    /// `databaseURL`. Parent directory must exist.
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
        // #16 删除教义 (mega-audit, 2026-07-08): secure_delete zeroes freed pages
        // at delete time — default-on, BAS_SECURE_DELETE=0 kill-switch.
        if let sdSQL = BASSQLiteSecureDelete.openPragmaSQL {
            try Self.runExec(db: handle, sql: sdSQL)
        }
        // memory-a F4 residual: one-time legacy freelist purge (secure_delete only
        // zeroes NEW deletions; VACUUM once rewrites the file, dropping pre-fix
        // plaintext). Marker-gated ⇒ steady-state cost is one SELECT. Outside any txn.
        BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: handle)
        try Self.runExec(
            db: handle, sql: "PRAGMA synchronous=NORMAL;")
        try Self.runExec(db: handle, sql: "PRAGMA foreign_keys=ON;")

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

    // MARK: - Save / load / remove

    /// Insert or replace one vault. Returns `true` if the row
    /// was new, `false` if it replaced an existing row.
    @discardableResult
    public func save(
        _ vault: BASHostConstitutionVault
    ) async throws -> Bool {
        guard let db else { return false }
        let existed = (try? Self.fetchVault(
            db: db, vaultID: vault.vaultID)) != nil
        try Self.upsertVault(db: db, vault: vault)
        return !existed
    }

    /// Fetch one vault by `vaultID`. Returns `nil` if absent.
    /// Decoding errors throw `StorageError.decodeFailed` — the
    /// caller is the L5 vault layer, which can either refuse the
    /// session (integrity > availability per chapter 一百九十一)
    /// or fall through to a fresh constitution.
    public func loadVault(
        vaultID: String
    ) async throws -> BASHostConstitutionVault? {
        guard let db else { return nil }
        return try Self.fetchVault(db: db, vaultID: vaultID)
    }

    /// Fetch the first vault belonging to `hostID`. Convenience for
    /// the common single-host case. Returns `nil` if absent.
    public func loadFirstVault(
        forHostID hostID: String
    ) async throws -> BASHostConstitutionVault? {
        guard let db else { return nil }
        return try Self.fetchFirstVault(db: db, hostID: hostID)
    }

    /// Real `DELETE` (not a tombstone). Returns the prior vault if
    /// it existed. Domain-level cascading (export invalidation,
    /// projection revocation) is host-level orchestration above
    /// this primitive — call `save(_:)` first with the vault's
    /// updated `BASHostDeletionManifest`, then optionally call
    /// `remove(vaultID:)` for terminal-level cascade.
    @discardableResult
    public func remove(
        vaultID: String
    ) async -> BASHostConstitutionVault? {
        guard let db else { return nil }
        guard let existing = try? Self.fetchVault(
            db: db, vaultID: vaultID) else { return nil }
        do {
            try Self.deleteVault(db: db, vaultID: vaultID)
            return existing
        } catch {
            return nil
        }
    }

    /// Fetch every vault stored. Caller-supplied scoping (filter
    /// by host, slice, etc.) is host responsibility — this is the
    /// storage surface, not a query layer.
    public func loadAll() async throws
    -> [BASHostConstitutionVault] {
        guard let db else { return [] }
        return try Self.fetchAllVaults(db: db)
    }

    // MARK: - Observation surface

    /// Total number of vaults persisted.
    public var vaultCount: Int {
        get async {
            guard let db else { return 0 }
            return (try? Self.countVaults(db: db)) ?? 0
        }
    }

    /// All vault IDs currently stored.
    public var allVaultIDs: Set<String> {
        get async {
            guard let db else { return [] }
            return (try? Self.fetchAllVaultIDs(db: db)) ?? []
        }
    }

    // MARK: - Schema setup

    private static func ensureSchema(db: OpaquePointer) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS host_constitution_vaults (
                vault_id TEXT PRIMARY KEY NOT NULL,
                host_id TEXT NOT NULL,
                constitution_id TEXT NOT NULL,
                active_version TEXT NOT NULL,
                schema_version TEXT NOT NULL,
                version_signature TEXT NOT NULL,
                last_updated_at_ms INTEGER NOT NULL,
                payload_json TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS host_constitution_host_idx
              ON host_constitution_vaults(host_id);
            """)
    }

    private static func verifySchemaVersion(
        db: OpaquePointer
    ) throws {
        let version = try readUserVersion(db: db)
        guard version == schemaVersion else {
            throw StorageError.schemaVersionMismatch(
                found: version, expected: schemaVersion)
        }
    }

    /// M886 backport (M882 audit fix):read PRAGMA user_version
    /// without setting。Returns 0 for fresh DBs。
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

    // MARK: - CRUD primitives

    fileprivate static func upsertVault(
        db: OpaquePointer,
        vault: BASHostConstitutionVault
    ) throws {
        let vaultID = vault.vaultID
        let json: String
        do {
            let data = try JSONEncoder().encode(vault)
            guard let s = String(data: data, encoding: .utf8) else {
                throw StorageError.encodeFailed(
                    vaultID: vaultID,
                    message: "encoded JSON not UTF-8")
            }
            json = s
        } catch let storageError as StorageError {
            throw storageError
        } catch {
            throw StorageError.encodeFailed(
                vaultID: vaultID, message: "\(error)")
        }

        let nowMs = Int64(
            Date().timeIntervalSince1970 * 1000)

        let sql = """
            INSERT INTO host_constitution_vaults (
                vault_id, host_id, constitution_id,
                active_version, schema_version,
                version_signature, last_updated_at_ms,
                payload_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(vault_id) DO UPDATE SET
                host_id = excluded.host_id,
                constitution_id = excluded.constitution_id,
                active_version = excluded.active_version,
                schema_version = excluded.schema_version,
                version_signature = excluded.version_signature,
                last_updated_at_ms = excluded.last_updated_at_ms,
                payload_json = excluded.payload_json
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

        bindText(stmt, 1, vaultID)
        bindText(stmt, 2, vault.constitutionSnapshot.hostID)
        bindText(stmt, 3, vault.constitutionID)
        bindText(stmt, 4, vault.constitutionSnapshot.activeVersion)
        bindText(stmt, 5, vault.schemaVersion)
        bindText(stmt, 6, vault.versionSignature)
        sqlite3_bind_int64(stmt, 7, nowMs)
        bindText(stmt, 8, json)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchVault(
        db: OpaquePointer,
        vaultID: String
    ) throws -> BASHostConstitutionVault? {
        let sql = """
            SELECT payload_json FROM host_constitution_vaults
             WHERE vault_id = ?
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

        bindText(stmt, 1, vaultID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }

        return try decodeVault(stmt: stmt, vaultID: vaultID)
    }

    fileprivate static func fetchFirstVault(
        db: OpaquePointer,
        hostID: String
    ) throws -> BASHostConstitutionVault? {
        let sql = """
            SELECT vault_id, payload_json
              FROM host_constitution_vaults
             WHERE host_id = ?
             ORDER BY last_updated_at_ms DESC
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

        bindText(stmt, 1, hostID)
        let stepRC = sqlite3_step(stmt)
        if stepRC == SQLITE_DONE { return nil }
        guard stepRC == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }

        let vaultID = readText(stmt, 0)
        let json = readText(stmt, 1)
        return try decodePayload(json: json, vaultID: vaultID)
    }

    fileprivate static func deleteVault(
        db: OpaquePointer,
        vaultID: String
    ) throws {
        let sql = """
            DELETE FROM host_constitution_vaults
             WHERE vault_id = ?
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
        bindText(stmt, 1, vaultID)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetchAllVaults(
        db: OpaquePointer
    ) throws -> [BASHostConstitutionVault] {
        let sql = """
            SELECT vault_id, payload_json
              FROM host_constitution_vaults
             ORDER BY last_updated_at_ms ASC
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

        var vaults: [BASHostConstitutionVault] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let vaultID = readText(stmt, 0)
            let json = readText(stmt, 1)
            vaults.append(try decodePayload(
                json: json, vaultID: vaultID))
        }
        return vaults
    }

    fileprivate static func countVaults(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM host_constitution_vaults"
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

    fileprivate static func fetchAllVaultIDs(
        db: OpaquePointer
    ) throws -> Set<String> {
        let sql = "SELECT vault_id FROM host_constitution_vaults"
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
        var ids: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.insert(readText(stmt, 0))
        }
        return ids
    }

    // MARK: - Decode helpers

    fileprivate static func decodeVault(
        stmt: OpaquePointer,
        vaultID: String
    ) throws -> BASHostConstitutionVault {
        let json = readText(stmt, 0)
        return try decodePayload(json: json, vaultID: vaultID)
    }

    fileprivate static func decodePayload(
        json: String,
        vaultID: String
    ) throws -> BASHostConstitutionVault {
        guard let data = json.data(using: .utf8) else {
            throw StorageError.corruptedRow(
                vaultID: vaultID,
                reason: "payload_json not UTF-8")
        }
        do {
            return try JSONDecoder()
                .decode(BASHostConstitutionVault.self, from: data)
        } catch {
            throw StorageError.decodeFailed(
                vaultID: vaultID, message: "\(error)")
        }
    }

    // MARK: - Utility

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

    /// SQLite's transient-destructor sentinel — see chapter
    /// 二百四十八 / M735 commentary.
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
