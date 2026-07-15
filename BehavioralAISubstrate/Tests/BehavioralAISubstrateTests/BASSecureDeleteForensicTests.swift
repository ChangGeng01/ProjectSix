import XCTest
import SQLite3
@testable import BASRuntimeCore

/// #16 删除教义收口 (mega-audit M-a F4 / x-sov #5, 2026-07-08): forensic proof that
/// `secure_delete=ON` actually zeroes deleted content on disk, and that the kill-switch
/// genuinely changes behavior (so the test has teeth — it isn't asserting a tautology).
///
/// Uses a raw SQLite handle configured exactly like a BAS store (WAL + the shared
/// `BASSQLiteSecureDelete.openPragmaSQL`), writes a distinctive secret, deletes it,
/// checkpoints, and scans the raw db file bytes for the secret.
final class BASSecureDeleteForensicTests: XCTestCase {

    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private let secret = "SECRET-PLAINTEXT-7f3a9c2e-do-not-recover-me"

    private func exec(_ db: OpaquePointer?, _ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    /// Opens a fresh db, writes+deletes the secret with the given secure_delete pragma,
    /// checkpoints, closes, and returns whether the secret bytes survive in the db file.
    private func secretSurvivesOnDisk(secureDeletePragma: String?) throws -> Bool {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bas-sd-\(abs(secret.hashValue))-\(secureDeletePragma == nil ? "off" : "on")")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("store.sqlite")

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        exec(db, "PRAGMA journal_mode=WAL;")
        if let sd = secureDeletePragma { exec(db, sd) }
        exec(db, "CREATE TABLE t(id INTEGER PRIMARY KEY, payload TEXT);")
        // Insert enough rows that the secret lands on a real page, then the target secret.
        for i in 0..<200 { exec(db, "INSERT INTO t(payload) VALUES('filler-row-\(i)');") }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO t(payload) VALUES(?);", -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, secret, -1, Self.SQLITE_TRANSIENT)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
        sqlite3_finalize(stmt)
        // Delete the secret row and force the freed page content to the main db file.
        exec(db, "DELETE FROM t WHERE payload='\(secret)';")
        exec(db, "PRAGMA wal_checkpoint(TRUNCATE);")
        sqlite3_close_v2(db)

        // Scan every db-related file (main + any residual -wal/-shm) for the secret bytes.
        let secretBytes = Array(secret.utf8)
        for suffix in ["", "-wal", "-shm"] {
            let p = dbURL.path + suffix
            guard let data = FileManager.default.contents(atPath: p) else { continue }
            if data.range(of: Data(secretBytes)) != nil { return true }
        }
        try? FileManager.default.removeItem(at: dir)
        return false
    }

    func testSecureDeleteOnErasesSecretFromDisk() throws {
        // The doctrine: with secure_delete ON, the deleted secret must NOT be recoverable.
        let survives = try secretSurvivesOnDisk(secureDeletePragma: "PRAGMA secure_delete=ON;")
        XCTAssertFalse(survives, "secure_delete=ON must zero the deleted secret on disk")
    }

    func testSharedHelperPragmaErasesSecret() throws {
        // The exact pragma the stores apply must achieve the erasure (guards against the
        // helper drifting to a no-op string). Skipped when the kill-switch is engaged.
        try XCTSkipIf(!BASSQLiteSecureDelete.isEnabled, "BAS_SECURE_DELETE=0 — helper disabled")
        let sd = BASSQLiteSecureDelete.openPragmaSQL
        XCTAssertEqual(sd, "PRAGMA secure_delete=ON;", "default-on helper must emit the ON pragma")
        let survives = try secretSurvivesOnDisk(secureDeletePragma: sd)
        XCTAssertFalse(survives, "helper pragma must erase the deleted secret")
    }

    /// Reads `PRAGMA secure_delete` back as an Int on a connection configured with the
    /// given pragma, proving the setting is genuinely engaged (not a silent no-op) —
    /// deterministic teeth that don't depend on the platform's default page-zeroing.
    private func secureDeleteSetting(applying pragma: String?) -> Int32 {
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        defer { sqlite3_close_v2(db) }
        if let p = pragma { exec(db, p) } else { exec(db, "PRAGMA secure_delete=OFF;") }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "PRAGMA secure_delete;", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return -1 }
        return sqlite3_column_int(stmt, 0)
    }

    func testSecureDeletePragmaIsActuallyEngaged() throws {
        // Teeth: the helper's ON pragma must read back as 1, and an explicit OFF as 0 —
        // proving the setting has real effect and the store isn't applying a no-op string.
        try XCTSkipIf(!BASSQLiteSecureDelete.isEnabled, "BAS_SECURE_DELETE=0 — helper disabled")
        XCTAssertEqual(secureDeleteSetting(applying: BASSQLiteSecureDelete.openPragmaSQL), 1,
                       "the store's secure_delete pragma must read back engaged (1)")
        XCTAssertEqual(secureDeleteSetting(applying: "PRAGMA secure_delete=OFF;"), 0,
                       "explicit OFF must read back 0 — confirms the query has teeth")
    }

    func testKillSwitchDisablesHelper() {
        // The ADR-014 kill-switch: when BAS_SECURE_DELETE=0 the helper emits no pragma, so
        // the connection keeps SQLite's default. (Env is process-wide; assert the pure
        // mapping rather than mutating the environment mid-suite.)
        if ProcessInfo.processInfo.environment["BAS_SECURE_DELETE"] == "0" {
            XCTAssertNil(BASSQLiteSecureDelete.openPragmaSQL)
            XCTAssertFalse(BASSQLiteSecureDelete.isEnabled)
        } else {
            XCTAssertEqual(BASSQLiteSecureDelete.openPragmaSQL, "PRAGMA secure_delete=ON;")
            XCTAssertTrue(BASSQLiteSecureDelete.isEnabled)
        }
    }
}
