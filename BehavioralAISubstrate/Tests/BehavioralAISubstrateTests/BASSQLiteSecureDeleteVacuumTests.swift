import XCTest
import SQLite3
@testable import BASRuntimeCore

/// mega-audit memory-a F4 residual (2026-07-11, operator-directed close): `secure_delete=ON`
/// (the #16 fix) only zeroes NEW deletions — rows deleted BEFORE the fix still sit as plaintext
/// in legacy freelist pages until a VACUUM rewrites the file. This is the ONE-TIME migration:
/// on open, if the `_bas_secure_delete_vacuumed` marker is absent, VACUUM once and mark.
/// Forensic teeth (the #16 pattern): a legacy secret physically vanishes from the file bytes.
final class BASSQLiteSecureDeleteVacuumTests: XCTestCase {

    private func makeLegacyDB(secret: String) throws -> String {
        // Simulate a PRE-#16 store: secure_delete OFF, insert secret, DELETE — the plaintext
        // stays in freelist pages.
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-f4-\(UUID().uuidString).sqlite").path
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        for sql in ["PRAGMA journal_mode=DELETE;",   // no WAL side files for byte-scan simplicity
                    "PRAGMA secure_delete=OFF;",
                    "CREATE TABLE t (v TEXT);",
                    "INSERT INTO t VALUES ('\(secret)');",
                    "DELETE FROM t;"] {
            XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, sql)
        }
        return path
    }

    private func fileContains(_ path: String, _ needle: String) throws -> Bool {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return data.range(of: Data(needle.utf8)) != nil
    }

    func testOneTimeVacuumPurgesLegacyFreelistPlaintext() throws {
        let secret = "F4-LEGACY-SECRET-9c41e77a"
        let path = try makeLegacyDB(secret: secret)
        defer { try? FileManager.default.removeItem(atPath: path) }
        XCTAssertTrue(try fileContains(path, secret),
            "premise: the legacy deletion left plaintext in freelist pages")

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        let ranFirst = BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: db)
        XCTAssertTrue(ranFirst, "cold marker ⇒ the one-time VACUUM runs")
        // second open: marker present ⇒ no re-VACUUM (the one-TIME property)
        let ranSecond = BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: db)
        XCTAssertFalse(ranSecond, "marker present ⇒ VACUUM must not run again")
        sqlite3_close(db)

        XCTAssertFalse(try fileContains(path, secret),
            "the one-time VACUUM physically purges legacy freelist plaintext")
    }

    func testKillSwitchSkipsAndLeavesNoMarker() throws {
        let secret = "F4-KILLSWITCH-SECRET-2b8d"
        let path = try makeLegacyDB(secret: secret)
        defer { try? FileManager.default.removeItem(atPath: path) }

        setenv("BAS_SECURE_DELETE_VACUUM", "0", 1)
        defer { unsetenv("BAS_SECURE_DELETE_VACUUM") }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        let ran = BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: db)
        sqlite3_close(db)
        XCTAssertFalse(ran, "kill-switch ⇒ skip")
        XCTAssertTrue(try fileContains(path, secret),
            "kill-switch ⇒ legacy bytes untouched (pre-fix behavior preserved)")
    }

    func testHealthyStoreRoundTripSurvivesTheMigration() throws {
        // The migration must not disturb live rows.
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-f4-live-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE t (v TEXT); INSERT INTO t VALUES ('keep-me');", nil, nil, nil), SQLITE_OK)
        _ = BASSQLiteSecureDelete.runOneTimeLegacyVacuum(db: db)
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT v FROM t", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        XCTAssertEqual(String(cString: sqlite3_column_text(stmt, 0)), "keep-me")
        sqlite3_finalize(stmt)
        sqlite3_close(db)
    }
}
