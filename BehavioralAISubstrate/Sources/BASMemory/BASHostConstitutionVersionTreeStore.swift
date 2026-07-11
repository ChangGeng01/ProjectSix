// MARK: - BASHostConstitutionVersionTreeStore
// chapter 七百九十六 / M2631-M2635 — L5 version tree storage
//
// Persistence seam for L5 host-constitution version lineage
// (chapter 七百六十八)。 Pairs with SQL schema
// 014_host_constitution_version_tree。
//
// Includes BLOB signature_hash column (32-byte SHA-256) +
// nullable parent_version_id (genesis versions have no parent)
// + JSON merged_from list (variadic cardinality)。

import Foundation
import SQLite3
import BASRuntimeCore

// MARK: - BASHostConstitutionVersionRecord typed record

public struct BASHostConstitutionVersionRecord:
    Sendable, Equatable, Hashable, Codable
{
    public let versionID: String
    public let vaultID: String
    public let parentVersionID: String?
    public let createdAtMs: Int64
    /// 32-byte SHA-256 of the version's canonical bytes。
    public let signatureHash: Data
    public let isRollbackPoint: Bool
    /// JSON array of source version_ids when this is a merge;
    /// nil for ordinary edits。
    public let mergedFromJson: String?

    public init(
        versionID: String,
        vaultID: String,
        parentVersionID: String? = nil,
        createdAtMs: Int64,
        signatureHash: Data,
        isRollbackPoint: Bool = false,
        mergedFromJson: String? = nil
    ) {
        self.versionID = versionID
        self.vaultID = vaultID
        self.parentVersionID = parentVersionID
        self.createdAtMs = createdAtMs
        self.signatureHash = signatureHash
        self.isRollbackPoint = isRollbackPoint
        self.mergedFromJson = mergedFromJson
    }
}

// MARK: - BASHostConstitutionVersionTreeStore protocol

public protocol BASHostConstitutionVersionTreeStore: Sendable {
    func appendVersion(
        _ version: BASHostConstitutionVersionRecord
    ) async throws -> BASHostConstitutionVersionRecord
    func versions(forVault vaultID: String) async -> [BASHostConstitutionVersionRecord]
    func rollbackPoints(forVault vaultID: String) async -> [BASHostConstitutionVersionRecord]
    func version(forID versionID: String) async -> BASHostConstitutionVersionRecord?
    func count() async -> Int
}

// MARK: - In-memory reference impl

public actor BASInMemoryHostConstitutionVersionTreeStore:
    BASHostConstitutionVersionTreeStore
{
    public enum StoreError: Error, Equatable, Sendable {
        case duplicateVersionID(String)
    }

    private var versions: [BASHostConstitutionVersionRecord] = []
    private var indexByID: [String: Int] = [:]

    public init() {}

    public func appendVersion(
        _ version: BASHostConstitutionVersionRecord
    ) async throws -> BASHostConstitutionVersionRecord {
        if indexByID[version.versionID] != nil {
            throw StoreError.duplicateVersionID(version.versionID)
        }
        indexByID[version.versionID] = versions.count
        versions.append(version)
        return version
    }

    public func versions(
        forVault vaultID: String
    ) async -> [BASHostConstitutionVersionRecord] {
        versions.filter { $0.vaultID == vaultID }
    }

    public func rollbackPoints(
        forVault vaultID: String
    ) async -> [BASHostConstitutionVersionRecord] {
        versions.filter {
            $0.vaultID == vaultID && $0.isRollbackPoint
        }
    }

    public func version(
        forID versionID: String
    ) async -> BASHostConstitutionVersionRecord? {
        indexByID[versionID].map { versions[$0] }
    }

    public func count() async -> Int { versions.count }

    // MARK: - Batch append (chapter 八百六 — API symmetry)

    @discardableResult
    public func appendBatch(
        _ versions: [BASHostConstitutionVersionRecord]
    ) async throws -> [BASHostConstitutionVersionRecord] {
        for version in versions {
            _ = try await appendVersion(version)
        }
        return versions
    }
}

// MARK: - SQLite-backed conformer

public actor BASSQLiteHostConstitutionVersionTreeStore:
    BASHostConstitutionVersionTreeStore
{
    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case duplicateVersionID(String)
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
        // memory-a F4 residual: one-time legacy freelist purge (secure_delete only
        // zeroes NEW deletions; VACUUM once rewrites the file, dropping pre-fix
        // plaintext). Marker-gated ⇒ steady-state cost is one SELECT. Outside any txn.
        BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: handle)
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
            sql: HostConstitutionVersionTreeSchema.allStatementsSQL)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    public func appendVersion(
        _ version: BASHostConstitutionVersionRecord
    ) async throws -> BASHostConstitutionVersionRecord {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            INSERT INTO host_constitution_version_tree (
                version_id, vault_id, parent_version_id,
                created_at_ms, signature_hash, is_rollback_point,
                merged_from_json
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
        Self.bindText(stmt, 1, version.versionID)
        Self.bindText(stmt, 2, version.vaultID)
        if let parent = version.parentVersionID {
            Self.bindText(stmt, 3, parent)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int64(stmt, 4, version.createdAtMs)
        // BLOB binding for signature_hash
        _ = version.signatureHash.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 5,
                bytes.baseAddress,
                Int32(version.signatureHash.count),
                Self.SQLITE_TRANSIENT)
        }
        sqlite3_bind_int(stmt, 6,
            version.isRollbackPoint ? 1 : 0)
        if let merged = version.mergedFromJson {
            Self.bindText(stmt, 7, merged)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE {
            if rc == SQLITE_CONSTRAINT {
                throw StorageError.duplicateVersionID(
                    version.versionID)
            }
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return version
    }

    public func versions(
        forVault vaultID: String
    ) async -> [BASHostConstitutionVersionRecord] {
        return (try? queryVersions(
            whereClause: "vault_id = ?",
            bindings: [vaultID])) ?? []
    }

    public func rollbackPoints(
        forVault vaultID: String
    ) async -> [BASHostConstitutionVersionRecord] {
        return (try? queryVersions(
            whereClause: "vault_id = ? AND is_rollback_point = 1",
            bindings: [vaultID])) ?? []
    }

    public func version(
        forID versionID: String
    ) async -> BASHostConstitutionVersionRecord? {
        return (try? queryVersions(
            whereClause: "version_id = ?",
            bindings: [versionID]))?.first
    }

    public func count() async -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM host_constitution_version_tree;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Batch append (chapter 八百六)

    @discardableResult
    public func appendBatch(
        _ versions: [BASHostConstitutionVersionRecord]
    ) async throws -> [BASHostConstitutionVersionRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        if versions.isEmpty { return [] }
        try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")
        let sql = """
            INSERT INTO host_constitution_version_tree (
                version_id, vault_id, parent_version_id,
                created_at_ms, signature_hash, is_rollback_point,
                merged_from_json
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
        for version in versions {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            Self.bindText(stmt, 1, version.versionID)
            Self.bindText(stmt, 2, version.vaultID)
            if let parent = version.parentVersionID {
                Self.bindText(stmt, 3, parent)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_int64(stmt, 4, version.createdAtMs)
            _ = version.signatureHash.withUnsafeBytes { bytes in
                sqlite3_bind_blob(stmt, 5,
                    bytes.baseAddress,
                    Int32(version.signatureHash.count),
                    Self.SQLITE_TRANSIENT)
            }
            sqlite3_bind_int(stmt, 6,
                version.isRollbackPoint ? 1 : 0)
            if let merged = version.mergedFromJson {
                Self.bindText(stmt, 7, merged)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            let rc = sqlite3_step(stmt)
            if rc != SQLITE_DONE {
                try? Self.runExec(db: db, sql: "ROLLBACK;")
                if rc == SQLITE_CONSTRAINT {
                    throw StorageError.duplicateVersionID(
                        version.versionID)
                }
                throw StorageError.stepFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
            }
        }
        try Self.runExec(db: db, sql: "COMMIT;")
        return versions
    }

    private func queryVersions(
        whereClause: String, bindings: [String]
    ) throws -> [BASHostConstitutionVersionRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            SELECT version_id, vault_id, parent_version_id,
                   created_at_ms, signature_hash,
                   is_rollback_point, merged_from_json
            FROM host_constitution_version_tree
            WHERE \(whereClause)
            ORDER BY created_at_ms ASC, rowid ASC
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
        var results: [BASHostConstitutionVersionRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let parent: String? =
                sqlite3_column_type(stmt, 2) == SQLITE_NULL
                ? nil : String(cString: sqlite3_column_text(stmt, 2))
            // BLOB read for signature_hash
            let blobLen = sqlite3_column_bytes(stmt, 4)
            let blobPtr = sqlite3_column_blob(stmt, 4)
            let signatureHash: Data
            if let blobPtr {
                signatureHash = Data(bytes: blobPtr,
                    count: Int(blobLen))
            } else {
                signatureHash = Data()
            }
            let mergedFromJson: String? =
                sqlite3_column_type(stmt, 6) == SQLITE_NULL
                ? nil : String(cString: sqlite3_column_text(stmt, 6))
            results.append(BASHostConstitutionVersionRecord(
                versionID: String(cString: sqlite3_column_text(stmt, 0)),
                vaultID: String(cString: sqlite3_column_text(stmt, 1)),
                parentVersionID: parent,
                createdAtMs: sqlite3_column_int64(stmt, 3),
                signatureHash: signatureHash,
                isRollbackPoint: sqlite3_column_int(stmt, 5) != 0,
                mergedFromJson: mergedFromJson))
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

    fileprivate static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self)

    fileprivate static func bindText(
        _ stmt: OpaquePointer?,
        _ index: Int32,
        _ value: String
    ) {
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }
}
