// MARK: - BASHostConstitutionDeletionManifestStore
// chapter 七百九十六 / M2631-M2635 — L5 deletion manifest storage
//
// Persistence seam for L5 host-constitution deletion audit
// (chapter 七百六十九)。 Pairs with SQL schema
// 015_host_constitution_deletion_manifest。

import Foundation
import SQLite3

// MARK: - BASHostConstitutionDeletionRecord typed record

public struct BASHostConstitutionDeletionRecord:
    Sendable, Equatable, Hashable, Codable
{
    public let manifestID: String
    public let vaultID: String
    public let targetRefsJson: String
    /// "cascade" / "selective" / "rollback" per schema 015 CHECK。
    public let deletionType: String
    public let appliedAtMs: Int64
    public let cascadedRefsJson: String?
    public let versionRef: String?

    public init(
        manifestID: String,
        vaultID: String,
        targetRefsJson: String,
        deletionType: String,
        appliedAtMs: Int64,
        cascadedRefsJson: String? = nil,
        versionRef: String? = nil
    ) {
        self.manifestID = manifestID
        self.vaultID = vaultID
        self.targetRefsJson = targetRefsJson
        self.deletionType = deletionType
        self.appliedAtMs = appliedAtMs
        self.cascadedRefsJson = cascadedRefsJson
        self.versionRef = versionRef
    }
}

// MARK: - BASHostConstitutionDeletionManifestStore protocol

public protocol BASHostConstitutionDeletionManifestStore: Sendable {
    func appendManifest(
        _ manifest: BASHostConstitutionDeletionRecord
    ) async throws -> BASHostConstitutionDeletionRecord
    func manifests(forVault vaultID: String) async -> [BASHostConstitutionDeletionRecord]
    func manifests(forType deletionType: String) async -> [BASHostConstitutionDeletionRecord]
    func count() async -> Int
}

// MARK: - In-memory reference impl

public actor BASInMemoryHostConstitutionDeletionManifestStore:
    BASHostConstitutionDeletionManifestStore
{
    public enum StoreError: Error, Equatable, Sendable {
        case duplicateManifestID(String)
    }

    private var manifests: [BASHostConstitutionDeletionRecord] = []
    private var indexByID: [String: Int] = [:]

    public init() {}

    public func appendManifest(
        _ manifest: BASHostConstitutionDeletionRecord
    ) async throws -> BASHostConstitutionDeletionRecord {
        if indexByID[manifest.manifestID] != nil {
            throw StoreError.duplicateManifestID(manifest.manifestID)
        }
        indexByID[manifest.manifestID] = manifests.count
        manifests.append(manifest)
        return manifest
    }

    public func manifests(
        forVault vaultID: String
    ) async -> [BASHostConstitutionDeletionRecord] {
        manifests.filter { $0.vaultID == vaultID }
    }

    public func manifests(
        forType deletionType: String
    ) async -> [BASHostConstitutionDeletionRecord] {
        manifests.filter { $0.deletionType == deletionType }
    }

    public func count() async -> Int { manifests.count }

    // MARK: - Batch append (chapter 八百六 — API symmetry)

    @discardableResult
    public func appendBatch(
        _ batch: [BASHostConstitutionDeletionRecord]
    ) async throws -> [BASHostConstitutionDeletionRecord] {
        for manifest in batch {
            _ = try await appendManifest(manifest)
        }
        return batch
    }
}

// MARK: - SQLite-backed conformer

public actor BASSQLiteHostConstitutionDeletionManifestStore:
    BASHostConstitutionDeletionManifestStore
{
    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case duplicateManifestID(String)
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
            sql: HostConstitutionDeletionManifestSchema.allStatementsSQL)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    public func appendManifest(
        _ manifest: BASHostConstitutionDeletionRecord
    ) async throws -> BASHostConstitutionDeletionRecord {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            INSERT INTO host_constitution_deletion_manifest (
                manifest_id, vault_id, target_refs_json,
                deletion_type, applied_at_ms,
                cascaded_refs_json, version_ref
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
        Self.bindText(stmt, 1, manifest.manifestID)
        Self.bindText(stmt, 2, manifest.vaultID)
        Self.bindText(stmt, 3, manifest.targetRefsJson)
        Self.bindText(stmt, 4, manifest.deletionType)
        sqlite3_bind_int64(stmt, 5, manifest.appliedAtMs)
        if let cascaded = manifest.cascadedRefsJson {
            Self.bindText(stmt, 6, cascaded)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        if let versionRef = manifest.versionRef {
            Self.bindText(stmt, 7, versionRef)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE {
            if rc == SQLITE_CONSTRAINT {
                throw StorageError.duplicateManifestID(
                    manifest.manifestID)
            }
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return manifest
    }

    public func manifests(
        forVault vaultID: String
    ) async -> [BASHostConstitutionDeletionRecord] {
        return (try? queryManifests(
            whereClause: "vault_id = ?",
            bindings: [vaultID])) ?? []
    }

    public func manifests(
        forType deletionType: String
    ) async -> [BASHostConstitutionDeletionRecord] {
        return (try? queryManifests(
            whereClause: "deletion_type = ?",
            bindings: [deletionType])) ?? []
    }

    public func count() async -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM host_constitution_deletion_manifest;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                == SQLITE_OK, let stmt else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Batch append (chapter 八百六)

    @discardableResult
    public func appendBatch(
        _ batch: [BASHostConstitutionDeletionRecord]
    ) async throws -> [BASHostConstitutionDeletionRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        if batch.isEmpty { return [] }
        try Self.runExec(db: db, sql: "BEGIN IMMEDIATE;")
        let sql = """
            INSERT INTO host_constitution_deletion_manifest (
                manifest_id, vault_id, target_refs_json,
                deletion_type, applied_at_ms,
                cascaded_refs_json, version_ref
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
        for manifest in batch {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            Self.bindText(stmt, 1, manifest.manifestID)
            Self.bindText(stmt, 2, manifest.vaultID)
            Self.bindText(stmt, 3, manifest.targetRefsJson)
            Self.bindText(stmt, 4, manifest.deletionType)
            sqlite3_bind_int64(stmt, 5, manifest.appliedAtMs)
            if let cascaded = manifest.cascadedRefsJson {
                Self.bindText(stmt, 6, cascaded)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            if let versionRef = manifest.versionRef {
                Self.bindText(stmt, 7, versionRef)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            let rc = sqlite3_step(stmt)
            if rc != SQLITE_DONE {
                try? Self.runExec(db: db, sql: "ROLLBACK;")
                if rc == SQLITE_CONSTRAINT {
                    throw StorageError.duplicateManifestID(
                        manifest.manifestID)
                }
                throw StorageError.stepFailed(
                    sql: sql,
                    message: String(cString: sqlite3_errmsg(db)))
            }
        }
        try Self.runExec(db: db, sql: "COMMIT;")
        return batch
    }

    private func queryManifests(
        whereClause: String, bindings: [String]
    ) throws -> [BASHostConstitutionDeletionRecord] {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let sql = """
            SELECT manifest_id, vault_id, target_refs_json,
                   deletion_type, applied_at_ms,
                   cascaded_refs_json, version_ref
            FROM host_constitution_deletion_manifest
            WHERE \(whereClause)
            ORDER BY applied_at_ms ASC, rowid ASC
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
        var results: [BASHostConstitutionDeletionRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let cascaded: String? =
                sqlite3_column_type(stmt, 5) == SQLITE_NULL
                ? nil : String(cString: sqlite3_column_text(stmt, 5))
            let versionRef: String? =
                sqlite3_column_type(stmt, 6) == SQLITE_NULL
                ? nil : String(cString: sqlite3_column_text(stmt, 6))
            results.append(BASHostConstitutionDeletionRecord(
                manifestID: String(cString: sqlite3_column_text(stmt, 0)),
                vaultID: String(cString: sqlite3_column_text(stmt, 1)),
                targetRefsJson: String(cString: sqlite3_column_text(stmt, 2)),
                deletionType: String(cString: sqlite3_column_text(stmt, 3)),
                appliedAtMs: sqlite3_column_int64(stmt, 4),
                cascadedRefsJson: cascaded,
                versionRef: versionRef))
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
