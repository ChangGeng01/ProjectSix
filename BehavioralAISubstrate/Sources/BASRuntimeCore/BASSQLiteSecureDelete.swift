import Foundation

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
}
