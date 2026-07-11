import Foundation
import SQLite3

/// #16 删除教义收口 (mega-audit M-a F4 / x-sov #5, 2026-07-08).
///
/// Every BAS SQLite store opened in WAL mode but NONE set `secure_delete`, so a `DELETE`
/// left the row's bytes sitting in freelist pages / the -wal until some later write
/// happened to overwrite them — forensically recoverable, in direct contradiction of the
/// deletion doctrine that a purged/tombstoned memory is actually GONE. With
/// `PRAGMA secure_delete=ON`, SQLite zeroes the freed content at delete/commit time.
///
/// ADR-014 graduation: DEFAULT-ON, with a kill-switch `BAS_SECURE_DELETE=0` for the rare
/// case an operator needs the pre-fix write cost back (secure_delete adds page zeroing to
/// each delete). Applied uniformly at connection open across all stores so a NEW store that
/// forgets it is the exception, not the rule.
public enum BASSQLiteSecureDelete {

    /// Default-on; only the explicit string "0" disables it (any other value, or unset,
    /// keeps the doctrine-safe default).
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["BAS_SECURE_DELETE"] != "0"
    }

    /// The PRAGMA to run immediately after opening a connection (right after
    /// `journal_mode=WAL`), or `nil` when the kill-switch is engaged — in which case the
    /// connection keeps SQLite's default (secure_delete OFF), matching pre-fix behavior.
    public static var openPragmaSQL: String? {
        isEnabled ? "PRAGMA secure_delete=ON;" : nil
    }

    // MARK: - memory-a F4 residual (2026-07-11): one-time legacy freelist purge

    /// `secure_delete=ON` only zeroes NEW deletions. Rows deleted BEFORE the #16 fix still sit
    /// as recoverable plaintext in legacy freelist pages until a VACUUM rewrites the file — the
    /// exact residual the #16 close-out documented ("VACUUM 对旧库历史空闲页是一次性迁移非每次
    /// open"). This runs that migration ONCE per store file: if the `_bas_secure_delete_vacuumed`
    /// marker table is absent, VACUUM (rewrites the file, dropping every freelist page) and mark.
    /// Every later open sees the marker and skips — steady-state cost is one SELECT.
    ///
    /// Call at connection open, right AFTER `openPragmaSQL` and OUTSIDE any transaction (VACUUM
    /// cannot run inside one). Best-effort by design: a VACUUM failure (disk-full, locked) logs
    /// loudly and returns false — deletion HYGIENE must not brick a store open (integrity is
    /// `BASSQLiteIntegrity`'s job); the migration retries on the next open because the marker is
    /// only written after a successful VACUUM. Kill-switch `BAS_SECURE_DELETE_VACUUM=0` (and the
    /// umbrella `BAS_SECURE_DELETE=0`) preserves pre-fix behavior.
    ///
    /// Returns true iff the VACUUM ran (and the marker was written) on THIS call.
    @discardableResult
    public static func runOneTimeLegacyVacuum(db: OpaquePointer?) -> Bool {
        guard let db else { return false }
        guard isEnabled,
              ProcessInfo.processInfo.environment["BAS_SECURE_DELETE_VACUUM"] != "0"
        else { return false }
        // marker present ⇒ already migrated
        var stmt: OpaquePointer?
        let probe = "SELECT 1 FROM sqlite_master WHERE type='table' AND name='_bas_secure_delete_vacuumed' LIMIT 1"
        guard sqlite3_prepare_v2(db, probe, -1, &stmt, nil) == SQLITE_OK else { return false }
        let marked = sqlite3_step(stmt) == SQLITE_ROW
        sqlite3_finalize(stmt)
        if marked { return false }
        guard sqlite3_exec(db, "VACUUM;", nil, nil, nil) == SQLITE_OK else {
            FileHandle.standardError.write(Data(
                ("BASSQLiteSecureDelete: one-time legacy VACUUM failed ("
                 + String(cString: sqlite3_errmsg(db))
                 + ") — legacy freelist plaintext may persist; will retry next open\n").utf8))
            return false
        }
        // marker only after success ⇒ a failed VACUUM retries next open
        _ = sqlite3_exec(db,
            "CREATE TABLE IF NOT EXISTS _bas_secure_delete_vacuumed (at_ms INTEGER NOT NULL);"
            + "INSERT INTO _bas_secure_delete_vacuumed VALUES (CAST(strftime('%s','now') AS INTEGER) * 1000);",
            nil, nil, nil)
        return true
    }
}
