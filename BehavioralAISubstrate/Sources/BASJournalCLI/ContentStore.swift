// MARK: - ContentStore — the secure_delete-ON content store (increment 4)
//
// WHY THIS EXISTS. The substrate's event store persists only a SHA-256 content DIGEST, never the
// raw text (L8 privacy doctrine), so the journal owns its own content store for recall.
// Increment 1 kept it as per-atom content/*.txt files and "secure-deleted" by overwriting the
// bytes in place then unlinking. On APFS that is WEAKER than it reads: APFS is copy-on-write, so
// an in-place overwrite can land on NEW blocks and leave the old plaintext intact in the freed
// region — the "truly gone" guarantee is not actually met by file overwrite.
//
// This store moves content into SQLite with secure_delete=ON (the #16 deletion doctrine used by
// all 18 substrate stores): SQLite zeroes freed pages within the DB file on DELETE. Under WAL
// that is not sufficient on its own (the plaintext INSERT frame lives in the -wal file, which
// secure_delete never touches), so delete() also runs a VERIFIED wal_checkpoint(TRUNCATE) and the
// store checkpoints on open to scrub any WAL orphaned by a crash between a delete and its
// checkpoint. Byte-accurate binding (explicit UTF-8 length) preserves content with embedded NULs.

import Foundation
import SQLite3
import BASRuntimeCore

enum ContentStoreError: Error, CustomStringConvertible {
    case openFailed(String)
    case sqlFailed(String)
    case secureDeleteIncomplete(String)

    var description: String {
        switch self {
        case .openFailed(let m): return "content store open failed: \(m)"
        case .sqlFailed(let m): return "content store sql failed: \(m)"
        case .secureDeleteIncomplete(let m): return "content secure-delete incomplete: \(m)"
        }
    }
}

/// A one-table SQLite store mapping an atom id → its raw journal text. Synchronous; the CLI runs
/// one command per process, so no intra-process concurrency wrapper is needed.
final class ContentStore {
    private var db: OpaquePointer?

    init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(
            path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let handle
        else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "open_v2 failed"
            if handle != nil { sqlite3_close_v2(handle) }
            throw ContentStoreError.openFailed(msg)
        }
        self.db = handle
        do {
            try Self.exec(handle, "PRAGMA journal_mode=WAL;")
            // #16 deletion doctrine: zero freed pages so a forgotten entry's plaintext does not
            // survive in the DB file (kill-switch BAS_SECURE_DELETE=0).
            if let sd = BASSQLiteSecureDelete.openPragmaSQL { try Self.exec(handle, sd) }
            // memory-a F4 residual: one-time legacy freelist purge (see BASSQLiteSecureDelete). Outside txn.
            BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: handle)
            try Self.exec(handle,
                "CREATE TABLE IF NOT EXISTS content (atom_id TEXT PRIMARY KEY, text TEXT NOT NULL);")
            // Scrub any WAL left plaintext-bearing by a crash between a prior delete's DELETE and
            // its checkpoint (best-effort — a no-op if the WAL is empty or briefly busy).
            var pnLog: Int32 = 0, pnCkpt: Int32 = 0
            _ = sqlite3_wal_checkpoint_v2(handle, nil, SQLITE_CHECKPOINT_TRUNCATE, &pnLog, &pnCkpt)
        } catch {
            sqlite3_close_v2(handle)
            self.db = nil
            throw error
        }
    }

    deinit { if let db { sqlite3_close_v2(db) } }

    func put(_ id: UUID, _ text: String) throws {
        try run("INSERT INTO content (atom_id, text) VALUES (?,?) "
            + "ON CONFLICT(atom_id) DO UPDATE SET text=excluded.text") { stmt in
            bindText(stmt, 1, id.uuidString)
            bindText(stmt, 2, text)
        }
    }

    /// Returns the stored text, `nil` if the row is genuinely ABSENT, and THROWS on a real DB
    /// error — callers must distinguish the two (a transient error must never be read as "gone").
    func get(_ id: UUID) throws -> String? {
        guard let db else { throw ContentStoreError.sqlFailed("db closed") }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT text FROM content WHERE atom_id=?", -1, &stmt, nil)
            == SQLITE_OK, let stmt else {
            throw ContentStoreError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id.uuidString)
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_DONE { return nil }   // genuinely absent
        guard rc == SQLITE_ROW else {
            throw ContentStoreError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
        guard let c = sqlite3_column_text(stmt, 0) else { return "" }
        let n = Int(sqlite3_column_bytes(stmt, 0))   // byte length preserves embedded NULs
        return String(decoding: UnsafeBufferPointer(start: c, count: n), as: UTF8.self)
    }

    func has(_ id: UUID) throws -> Bool { try get(id) != nil }

    /// Secure-delete a row. Two steps, because secure_delete alone is NOT enough under WAL:
    ///   1. DELETE — secure_delete=ON zeroes the freed cell in the main-DB page.
    ///   2. VERIFIED wal_checkpoint(TRUNCATE) — the sensitive plaintext lives in the -wal file
    ///      (the original INSERT frame), which secure_delete (main-DB-only) never touches. The
    ///      checkpoint flushes the zeroed page into the main DB and truncates the WAL to zero
    ///      bytes. We inspect the result (`pnLog == 0`): a BUSY/blocked checkpoint that leaves
    ///      frames in the WAL THROWS `secureDeleteIncomplete` rather than silently reporting a
    ///      clean delete while the plaintext lingers.
    @discardableResult
    func delete(_ id: UUID) throws -> Bool {
        try run("DELETE FROM content WHERE atom_id=?") { stmt in bindText(stmt, 1, id.uuidString) }
        guard let db else { throw ContentStoreError.sqlFailed("db closed") }
        let changed = sqlite3_changes(db) > 0
        var pnLog: Int32 = -1, pnCkpt: Int32 = -1
        let rc = sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, &pnLog, &pnCkpt)
        guard rc == SQLITE_OK, pnLog == 0 else {
            throw ContentStoreError.secureDeleteIncomplete(
                "wal_checkpoint(TRUNCATE) rc=\(rc) framesLeftInWAL=\(pnLog) — plaintext may linger")
        }
        return changed
    }

    // MARK: - SQLite plumbing

    private func run(_ sql: String, _ bind: (OpaquePointer) -> Void) throws {
        guard let db else { throw ContentStoreError.sqlFailed("db closed") }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ContentStoreError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ContentStoreError.sqlFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let m = err.map { p -> String in let s = String(cString: p); sqlite3_free(p); return s }
                ?? "exec failed"
            throw ContentStoreError.sqlFailed(m)
        }
    }

    private static let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

    /// Bind by EXPLICIT UTF-8 byte length (not -1 / strlen), so content containing an embedded
    /// NUL round-trips faithfully instead of being silently truncated at the first NUL.
    private func bindText(_ stmt: OpaquePointer, _ i: Int32, _ v: String) {
        let bytes = Array(v.utf8)
        if bytes.isEmpty {
            sqlite3_bind_text(stmt, i, "", 0, Self.SQLITE_TRANSIENT)
            return
        }
        bytes.withUnsafeBytes { raw in
            sqlite3_bind_text(
                stmt, i, raw.baseAddress!.assumingMemoryBound(to: CChar.self),
                Int32(bytes.count), Self.SQLITE_TRANSIENT)
        }
    }
}
