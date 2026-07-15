// BASSQLiteIntegrity — shared open-time corruption gate.
//
// audit M-c (SQLite read fail-open / 损坏=空不可区分, one of the four systemic diseases): several
// stores read a corrupt SQLite file as an EMPTY result — `(try? fetchAll(db:)) ?? []` swallows the
// `corruptedRow` throw AND raw SQLite errors into `[]`, so a corrupted store looks identical to a
// genuinely empty one. Downstream that means "forgotten records resurrect as absent" / decisions
// made on silently-empty data. The EventLog store already had `assertIntegrity`; the KG / EvalRun /
// risk-observation stores did not.
//
// This is the shared version (sibling of `BASSQLiteSecureDelete`): run `PRAGMA integrity_check` at
// OPEN and THROW if the file is structurally corrupt, so corruption is SURFACED before any read can
// mistake it for empty (integrity-over-availability, per chapter 一百九十一 M91 doctrine).
//
// DEFAULT-ON (fail-closed) — the audit's whole thesis is that fail-open is the dominant disease and
// "dormant ≠ safe". A per-open `integrity_check` scans the file, so a kill-switch
// (`BAS_SKIP_STORE_INTEGRITY_CHECK=1`) is provided for a host that must trade the one-time open
// cost on a very large store. A healthy DB is byte-equal (the check passes and changes nothing);
// only a CORRUPT DB changes behavior — from a silent empty read to a loud throw at open.
//
// SCOPE: `integrity_check` validates SQLite STRUCTURE. A row that is valid SQLite but carries a
// corrupt JSON payload still throws `corruptedRow` from the decode path (which each store handles
// per its own read contract); this gate closes the far more common structural-corruption case.

import Foundation
import SQLite3

public enum BASSQLiteIntegrity {

    /// Fail-closed by default; a host sets `BAS_SKIP_STORE_INTEGRITY_CHECK=1` to skip the per-open
    /// scan (e.g. a very large store where the one-time cost is unacceptable).
    public static var enabled: Bool {
        ProcessInfo.processInfo.environment["BAS_SKIP_STORE_INTEGRITY_CHECK"] != "1"
    }

    /// A store whose backing SQLite file failed `PRAGMA integrity_check` at open.
    public struct CorruptStoreError: Error, Sendable, Equatable, CustomStringConvertible {
        public let store: String
        public let detail: String
        public init(store: String, detail: String) {
            self.store = store
            self.detail = detail
        }
        public var description: String {
            "BASSQLiteIntegrity: \(store) store failed integrity_check — \(detail)"
        }
    }

    /// Run `PRAGMA integrity_check` on an open DB handle. Throws `CorruptStoreError` unless the
    /// result is exactly `"ok"`. No-op (returns) when disabled via the kill-switch. A freshly
    /// created empty database passes (`integrity_check` = "ok"), so this is safe to call at every
    /// open including first run.
    public static func assertOK(db: OpaquePointer, store: String) throws {
        guard enabled else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            throw CorruptStoreError(
                store: store,
                detail: "integrity_check prepare failed: " + String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        var result = ""
        if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
            result = String(cString: c)
        }
        guard result == "ok" else {
            throw CorruptStoreError(store: store, detail: "integrity_check = \(result)")
        }
    }
}
