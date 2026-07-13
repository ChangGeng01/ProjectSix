// MARK: - BASSQLiteVectorIndexStorage — chapter 三百六二 / M849
//
// Phase P1 G4 part 2: SQLite-backed cross-session persistence
// for `BASVectorIndex` entries。Closes the "SQLite blob persistence"
// gap noted in M847 (chapter 三百六十) commit message non-goals。
//
// ## Why this exists
//
// M847 shipped `BASVectorIndex` as an in-memory actor — fast top-k
// scan but **process-scoped**。On app restart the index is empty
// until manually re-populated。
//
// M840 §3.4 explicit design choice:
// > Vector index: cosine similarity over SQLite blob column +
// > in-memory Float32 array (no external vector DB needed for
// > iPhone-scale corpus < 10K atoms)
//
// This file ships:
//   - SQLite-backed actor that persists `BASVectorIndexEntry` rows
//   - Float32 array serialized as Data blob (4 bytes per dim,
//     compact + endian-stable on Apple silicon — iOS/macOS are
//     all little-endian since the Intel→Apple Silicon transition)
//   - `preload()` helper that bulk-loads all rows into an in-memory
//     `BASVectorIndex` at session start
//   - Cross-session persistence (mirror chapter 二百四十八 M735
//     idiom — the architectural pin that closes G4 properly)
//
// ## Schema (version 1)
//
//   CREATE TABLE vector_index (
//     atom_id TEXT PRIMARY KEY NOT NULL,
//     dimension INTEGER NOT NULL,
//     provider_version TEXT NOT NULL,
//     embedding_blob BLOB NOT NULL,
//     domain TEXT NOT NULL,
//     metadata_json TEXT NOT NULL
//   );
//   CREATE INDEX vector_index_provider_idx
//     ON vector_index(provider_version);
//   CREATE INDEX vector_index_domain_idx
//     ON vector_index(domain);
//
// **Provider version index** lets future migrations filter by
// embedding source (eg. "all entries that were embedded by
// NLEmbedding-en-v1" — useful when swapping to MiniLM)。
//
// ## Doctrine pins held
//
//   - All BASEmbeddingProvider / BASVectorIndex pins apply
//   - chapter 二百四十八 M735 SQLite idiom mirrored byte-for-byte
//   - chapter 二百一一 single-source-of-truth — ONE persistence
//     conformer mirroring the in-memory index's contract
//   - chapter 一百八十五 anti-magic-number — float byte size +
//     schema version pinned typed constants
//   - ADR-014 OPT-IN → PROD — hosts that don't wire SQLite
//     persistence keep the in-memory `BASVectorIndex` (no
//     behavior change)

import Foundation
import SQLite3
import BASRuntimeCore

// MARK: - SQLite-backed vector storage

/// Append-mostly SQLite store for `BASVectorIndexEntry` rows。
/// Mirrors the chapter 二百四十八 / M735 storage idiom (WAL +
/// transient-destructor + typed StorageError + schema version
/// pragma + actor isolation)。
public actor BASSQLiteVectorIndexStorage {

    // MARK: - Errors

    public enum StorageError:
        Error, Equatable, Sendable, Codable
    {
        case openFailed(code: Int32, message: String)
        case prepareFailed(sql: String, message: String)
        case stepFailed(sql: String, message: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case encodeFailed(atomID: String, message: String)
        case decodeFailed(atomID: String, message: String)
        case dimensionMismatch(
            atomID: String, expected: Int, got: Int)
    }

    public static let schemaVersion: Int = 1

    /// 先稳 P2 — OPT-IN (default off): run `PRAGMA integrity_check` at open + throw if corrupt. Off by
    /// default (full-DB scan ⇒ boot latency). Static so a host can enable it before init.
    public nonisolated(unsafe) static var runIntegrityCheckOnOpen: Bool = false

    /// Float32 byte size — pinned per chapter 一百八十五 anti-
    /// magic-number。Used by encode/decode of embedding_blob。
    public static let floatByteSize: Int = 4

    /// deep-audit LOW: overflow-safe embedding byte-size for an UNTRUSTED `dimension` read from the DB.
    /// Throws `.dimensionMismatch` on a negative or `* floatByteSize`-overflowing value rather than
    /// letting the raw multiply TRAP (crash) on a corrupt/tampered local vector DB.
    static func safeEmbeddingByteSize(dimension: Int, atomID: String) throws -> Int {
        let (product, overflowed) = dimension.multipliedReportingOverflow(by: floatByteSize)
        guard dimension >= 0, !overflowed else {
            throw StorageError.dimensionMismatch(atomID: atomID, expected: -1, got: dimension)
        }
        return product
    }

    // MARK: - State

    public let databaseURL: URL
    private nonisolated(unsafe) var db: OpaquePointer?

    /// 先稳 P0 — OPT-IN diagnostic hook (default nil). Non-throwing accessors route a swallowed SQLite error
    /// here BEFORE defaulting, so a host can tell "absent" from "DB broken". Fires only on the error path
    /// ⇒ byte-equal on success. Default nil ⇒ today's exact behavior.
    public var onSilentFailure: (@Sendable (Error) -> Void)?

    /// Wire the diagnostic hook (actor-isolated; set once at setup; zero init-signature change).
    public func setOnSilentFailure(_ handler: (@Sendable (Error) -> Void)?) {
        self.onSilentFailure = handler
    }

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
        // 先稳 P2 — bound WAL growth over long sessions (mirrors the event log's M891 setting).
        try Self.runExec(db: handle, sql: "PRAGMA wal_autocheckpoint=200;")

        // M886 backport (M882 audit fix):read user_version FIRST,
        // branch on:0 → write current,equal → accept,mismatch
        // → throw schemaVersionMismatch。Pre-M886 the unconditional
        // pragma write silently overwrote any existing value,
        // making `verifySchemaVersion` a no-op for upgraded DBs。
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
        if Self.runIntegrityCheckOnOpen {
            try Self.assertIntegrity(db: handle)   // 先稳 P2 — opt-in proactive corruption scan
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    /// 先稳 P2 — run `PRAGMA integrity_check`; throw if not "ok" (called at init when the flag is set).
    private static func assertIntegrity(db: OpaquePointer) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            throw StorageError.openFailed(
                code: -2, message: "integrity_check prepare failed: " +
                    String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var result = ""
        if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
            result = String(cString: c)
        }
        guard result == "ok" else {
            throw StorageError.openFailed(code: -2, message: "integrity_check failed: \(result)")
        }
    }

    // MARK: - Public API

    /// Insert / replace an entry by atom ID。Returns true on
    /// new insert,false if existing row was replaced。
    @discardableResult
    public func upsert(
        _ entry: BASVectorIndexEntry
    ) async throws -> Bool {
        guard let db else {
            throw StorageError.openFailed(
                code: -1, message: "db handle nil")
        }
        let existed = try Self.fetchExists(
            db: db, atomID: entry.atomID)
        try Self.upsertEntry(db: db, entry: entry)
        return !existed
    }

    /// Fetch a single entry by atom ID。Returns nil if absent。
    public func entry(
        forID atomID: String
    ) async -> BASVectorIndexEntry? {
        guard let db else { return nil }
        do { return try Self.fetch(db: db, atomID: atomID) }
        catch { onSilentFailure?(error); return nil }
    }

    /// 先稳 P0 — throwing sibling of `entry(forID:)`: surfaces a SQLite error instead of returning nil.
    public func entryOrThrow(forID atomID: String) async throws -> BASVectorIndexEntry? {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        return try Self.fetch(db: db, atomID: atomID)
    }

    /// Remove entry by atom ID。Returns true if removed,false
    /// if absent。
    @discardableResult
    public func remove(atomID: String) async throws -> Bool {
        guard let db else { return false }
        let existed = try Self.fetchExists(
            db: db, atomID: atomID)
        guard existed else { return false }
        try Self.delete(db: db, atomID: atomID)
        // deep-audit P2-18 (2026-07-13): a forgotten atom's embedding still lives as the
        // original INSERT frame in the -wal (secure_delete=ON only zeroes the main-DB page).
        // remove(atomID:) is the explicit forget path — truncate the WAL so the vector of a
        // forgotten memory is gone from disk too.
        try BASSQLiteSecureDelete.checkpointTruncateAfterSecureDelete(db: db)
        return true
    }

    /// Total entry count。
    public var totalCount: Int {
        get async {
            guard let db else { return 0 }
            do { return try Self.countAll(db: db) }
            catch { onSilentFailure?(error); return 0 }
        }
    }

    /// 先稳 P0 — throwing sibling of `totalCount` (surfaces SQLite errors instead of returning 0).
    public func totalCountOrThrow() async throws -> Int {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        return try Self.countAll(db: db)
    }

    /// Bulk-fetch all entries (for preload at session start)。
    /// Order: insertion order via `created_at_ms` ASC fallback to
    /// `atom_id` ASC for stable deterministic replay。
    public func allEntries() async -> [BASVectorIndexEntry] {
        guard let db else { return [] }
        do { return try Self.fetchAll(db: db) }
        catch { onSilentFailure?(error); return [] }
    }

    /// 先稳 P0 — throwing sibling of `allEntries()` (surfaces SQLite errors instead of returning []).
    public func allEntriesOrThrow() async throws -> [BASVectorIndexEntry] {
        guard let db else {
            throw StorageError.openFailed(code: -1, message: "db handle unavailable")
        }
        return try Self.fetchAll(db: db)
    }

    // MARK: - Preload helper

    /// Preload all persisted entries into an in-memory
    /// `BASVectorIndex`。Use at session start to restore the
    /// vector index from disk。
    ///
    /// Returns the count of entries preloaded。Errors are
    /// individually-skipped — corrupt rows are dropped (logged
    /// to caller via the `corruptedAtomIDs` callback) rather
    /// than failing the whole preload。
    public func preload(
        into index: BASVectorIndex,
        onCorruptRow: (@Sendable (String, Error) -> Void)? = nil
    ) async -> Int {
        let entries = await allEntries()
        var loaded = 0
        for entry in entries {
            do {
                try await index.upsert(entry)
                loaded += 1
            } catch {
                onCorruptRow?(entry.atomID, error)
            }
        }
        return loaded
    }

    // MARK: - Schema setup

    fileprivate static func ensureSchema(
        db: OpaquePointer
    ) throws {
        try runExec(db: db, sql: """
            CREATE TABLE IF NOT EXISTS vector_index (
                atom_id TEXT PRIMARY KEY NOT NULL,
                dimension INTEGER NOT NULL,
                provider_version TEXT NOT NULL,
                embedding_blob BLOB NOT NULL,
                domain TEXT NOT NULL,
                metadata_json TEXT NOT NULL
            );
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                vector_index_provider_idx
                ON vector_index(provider_version);
            """)
        try runExec(db: db, sql: """
            CREATE INDEX IF NOT EXISTS
                vector_index_domain_idx
                ON vector_index(domain);
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

    /// M886 backport (M882 audit fix):read `PRAGMA user_version`
    /// without setting it。Returns 0 for a freshly-created
    /// SQLite file。
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

    // MARK: - CRUD primitives

    fileprivate static func upsertEntry(
        db: OpaquePointer,
        entry: BASVectorIndexEntry
    ) throws {
        let sql = """
            INSERT INTO vector_index (
                atom_id, dimension, provider_version,
                embedding_blob, domain, metadata_json
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(atom_id) DO UPDATE SET
                dimension = excluded.dimension,
                provider_version = excluded.provider_version,
                embedding_blob = excluded.embedding_blob,
                domain = excluded.domain,
                metadata_json = excluded.metadata_json
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

        let blob = encodeFloatArray(
            entry.normalizedEmbedding.vector)
        let metadataJson: String
        do {
            let data = try JSONEncoder()
                .encode(entry.metadata)
            metadataJson = String(
                data: data, encoding: .utf8) ?? "{}"
        } catch {
            throw StorageError.encodeFailed(
                atomID: entry.atomID,
                message: "metadata encode: \(error)")
        }

        bindText(stmt, 1, entry.atomID)
        sqlite3_bind_int64(
            stmt, 2,
            Int64(entry.normalizedEmbedding.dimension))
        bindText(
            stmt, 3,
            entry.normalizedEmbedding.providerVersion)
        // Bind blob — SQLITE_TRANSIENT copies into SQLite-owned
        // memory so `blob` Data can deinit immediately after。
        // sqlite3_bind_blob returns Int32 (SQLITE_OK / error),
        // which we discard via the leading `_ =` since the
        // subsequent sqlite3_step check surfaces any actual
        // failure path。
        _ = blob.withUnsafeBytes { rawBuf in
            sqlite3_bind_blob(
                stmt, 4,
                rawBuf.baseAddress,
                Int32(blob.count),
                SQLITE_TRANSIENT)
        }
        bindText(stmt, 5, entry.domain)
        bindText(stmt, 6, metadataJson)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func fetch(
        db: OpaquePointer,
        atomID: String
    ) throws -> BASVectorIndexEntry? {
        let sql = """
            SELECT dimension, provider_version,
                   embedding_blob, domain, metadata_json
            FROM vector_index
            WHERE atom_id = ?
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
        bindText(stmt, 1, atomID)
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }
        guard rc == SQLITE_ROW else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
        return try decodeRow(
            stmt: stmt, atomID: atomID)
    }

    fileprivate static func fetchExists(
        db: OpaquePointer, atomID: String
    ) throws -> Bool {
        let sql =
            "SELECT 1 FROM vector_index WHERE atom_id = ? LIMIT 1"
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
        bindText(stmt, 1, atomID)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    fileprivate static func delete(
        db: OpaquePointer, atomID: String
    ) throws {
        let sql = "DELETE FROM vector_index WHERE atom_id = ?"
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
        bindText(stmt, 1, atomID)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StorageError.stepFailed(
                sql: sql,
                message: String(cString: sqlite3_errmsg(db)))
        }
    }

    fileprivate static func countAll(
        db: OpaquePointer
    ) throws -> Int {
        let sql = "SELECT COUNT(*) FROM vector_index"
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

    fileprivate static func fetchAll(
        db: OpaquePointer
    ) throws -> [BASVectorIndexEntry] {
        let sql = """
            SELECT atom_id, dimension, provider_version,
                   embedding_blob, domain, metadata_json
            FROM vector_index
            ORDER BY atom_id ASC
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
        var out: [BASVectorIndexEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let atomID = readText(stmt, 0)
            // Use a 5-col window starting from index 1
            // (skip atom_id which we already read)
            let entry = try decodeRowWithoutID(
                stmt: stmt,
                atomID: atomID,
                offset: 1)
            out.append(entry)
        }
        return out
    }

    // MARK: - Row decode

    fileprivate static func decodeRow(
        stmt: OpaquePointer,
        atomID: String
    ) throws -> BASVectorIndexEntry {
        // Columns: dimension, provider_version,
        // embedding_blob, domain, metadata_json (offset 0)
        try decodeRowWithoutID(
            stmt: stmt, atomID: atomID, offset: 0)
    }

    fileprivate static func decodeRowWithoutID(
        stmt: OpaquePointer,
        atomID: String,
        offset: Int32
    ) throws -> BASVectorIndexEntry {
        let dimension = Int(
            sqlite3_column_int64(stmt, offset))
        let providerVersion = readText(
            stmt, offset + 1)
        // Blob
        guard let blobPtr = sqlite3_column_blob(
            stmt, offset + 2)
        else {
            throw StorageError.decodeFailed(
                atomID: atomID,
                message: "embedding_blob column null")
        }
        let blobSize = Int(
            sqlite3_column_bytes(stmt, offset + 2))
        // deep-audit LOW: `dimension` comes straight from the DB column; a corrupt/tampered value
        // makes `dimension * floatByteSize` overflow and TRAP (crash) on a bad local vector DB.
        // safeEmbeddingByteSize throws (recoverable) on negative/overflow instead of aborting.
        let expectedSize = try Self.safeEmbeddingByteSize(dimension: dimension, atomID: atomID)
        guard blobSize == expectedSize else {
            throw StorageError.dimensionMismatch(
                atomID: atomID,
                expected: expectedSize,
                got: blobSize)
        }
        let data = Data(bytes: blobPtr, count: blobSize)
        let vector = decodeFloatArray(
            data, dimension: dimension)
        let domain = readText(stmt, offset + 3)
        let metadataJson = readText(stmt, offset + 4)
        let metadata: [String: String]
        if let mdData = metadataJson.data(using: .utf8), !mdData.isEmpty {
            do {
                metadata = try JSONDecoder().decode([String: String].self, from: mdData)
            } catch {
                // Audit fix: a NON-EMPTY but unparseable metadata blob is corruption — surface it (the
                // non-throwing accessors route it to onSilentFailure; the throwing siblings rethrow) instead of
                // silently returning [:] and masking the damage. Mirrors embedding/dimension corruption.
                throw StorageError.decodeFailed(
                    atomID: atomID, message: "metadata_json decode failed: \(error)")
            }
        } else {
            metadata = [:]
        }
        let embedding = BASEmbedding(
            vector: vector,
            dimension: dimension,
            providerVersion: providerVersion)
        return BASVectorIndexEntry(
            atomID: atomID,
            normalizedEmbedding: embedding,
            domain: domain,
            metadata: metadata)
    }

    // MARK: - Float32 array <-> Data

    /// Encode `[Float]` → `Data` (little-endian Float32 bytes)。
    /// On Apple silicon (all current iOS / macOS targets),host
    /// byte order IS little-endian,so `withUnsafeBytes(of:)`
    /// over a Float gives us the canonical encoding。
    fileprivate static func encodeFloatArray(
        _ vector: [Float]
    ) -> Data {
        var data = Data(
            capacity: vector.count * floatByteSize)
        for value in vector {
            var v = value
            data.append(
                Data(bytes: &v, count: floatByteSize))
        }
        return data
    }

    /// Decode `Data` → `[Float]`,assuming little-endian Float32
    /// encoding (matches `encodeFloatArray`)。
    ///
    /// Caller MUST ensure `data.count == dimension * 4` (verified
    /// by the calling code path)。
    fileprivate static func decodeFloatArray(
        _ data: Data, dimension: Int
    ) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(dimension)
        data.withUnsafeBytes { rawBuf in
            let floatPtr = rawBuf.bindMemory(to: Float.self)
            for i in 0..<dimension {
                out.append(floatPtr[i])
            }
        }
        return out
    }

    // MARK: - Utility (mirrors existing storage idiom)

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
