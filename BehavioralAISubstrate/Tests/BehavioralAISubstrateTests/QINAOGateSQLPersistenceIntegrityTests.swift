import XCTest
import Foundation
import SQLite3
@testable import BASMemory

/// QINAO substrate gate #44 (L8) — SQLite open-path integrity bar.
final class QINAOGateSQLPersistenceIntegrityTests: XCTestCase {

    private static let transient = unsafeBitCast(
        OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

    private func tmpURL(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "qinao-sqlintegrity-\(tag)-\(UUID().uuidString).sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }

    /// Build a healthy memory_atoms DB directly via a raw SQLite connection so the test
    /// owns no actor handle (deterministic, no actor-deinit race), with the given user_version.
    private func writeRawDB(at url: URL, userVersion: Int, withTable: Bool) throws {
        var raw: OpaquePointer?
        XCTAssertEqual(
            sqlite3_open_v2(url.path, &raw,
                SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil),
            SQLITE_OK, "raw open for fixture build")
        defer { sqlite3_close_v2(raw) }
        if withTable {
            XCTAssertEqual(sqlite3_exec(raw, """
                CREATE TABLE IF NOT EXISTS memory_atoms (
                    atom_id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL,
                    scope TEXT NOT NULL, sensitivity TEXT NOT NULL, tier TEXT NOT NULL,
                    governance_status TEXT NOT NULL, created_at_ms INTEGER NOT NULL,
                    last_updated_at_ms INTEGER NOT NULL, payload_json TEXT NOT NULL);
                """, nil, nil, nil), SQLITE_OK, "create table")
        }
        XCTAssertEqual(
            sqlite3_exec(raw, "PRAGMA user_version=\(userVersion);", nil, nil, nil),
            SQLITE_OK, "set user_version=\(userVersion)")
    }

    func test_qinao_sql_persistence_integrity_gate() async throws {
        // Snapshot + restore the opt-in static so the gate never leaks state into other tests (tolerance=0).
        let savedFlag = BASSQLiteMemoryAtomStore.runIntegrityCheckOnOpen
        defer { BASSQLiteMemoryAtomStore.runIntegrityCheckOnOpen = savedFlag }

        // ── Part A: user_version mismatch THROWS schemaVersionMismatch (NO silent overwrite). ──
        let expected = BASSQLiteMemoryAtomStore.schemaVersion   // 1
        let mismatch = expected + 998                           // a value that can never equal the schema
        let mismatchURL = tmpURL("mismatch")
        defer { cleanup(mismatchURL) }
        try writeRawDB(at: mismatchURL, userVersion: mismatch, withTable: true)

        // Open via the store WITHOUT integrity scan — the version branch alone must reject it.
        BASSQLiteMemoryAtomStore.runIntegrityCheckOnOpen = false
        var threwMismatch = false
        do {
            _ = try BASSQLiteMemoryAtomStore(databaseURL: mismatchURL)
            XCTFail("a non-matching user_version must THROW, not silently re-stamp the schema")
        } catch let e as BASSQLiteMemoryAtomStore.StorageError {
            XCTAssertEqual(
                e, .schemaVersionMismatch(found: mismatch, expected: expected),
                "must throw the typed schemaVersionMismatch carrying found+expected verbatim")
            threwMismatch = true
        }
        XCTAssertTrue(threwMismatch, "schema-mismatch open must surface a typed StorageError")

        // Mutate+assert (no silent overwrite): the on-disk user_version is UNCHANGED after the rejected open.
        var verify: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(mismatchURL.path, &verify, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        var vstmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(verify, "PRAGMA user_version;", -1, &vstmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(vstmt), SQLITE_ROW)
        let onDisk = Int(sqlite3_column_int64(vstmt, 0))
        sqlite3_finalize(vstmt); sqlite3_close_v2(verify)
        XCTAssertEqual(onDisk, mismatch,
            "the rejected open must NOT overwrite user_version (\(mismatch) preserved, integrity > availability)")

        // ── Part B: with the integrity scan ON, a HEALTHY db opens; a CORRUPT db THROWS. ──
        BASSQLiteMemoryAtomStore.runIntegrityCheckOnOpen = true

        // B1: healthy db (matching user_version, real table) → integrity_check == "ok" → opens.
        let healthyURL = tmpURL("healthy")
        defer { cleanup(healthyURL) }
        try writeRawDB(at: healthyURL, userVersion: expected, withTable: true)
        let healthy = try BASSQLiteMemoryAtomStore(databaseURL: healthyURL)
        let cnt = try await healthy.countOrThrow()
        XCTAssertEqual(cnt, 0, "healthy store opens past the integrity gate and is readable")

        // B2: a non-SQLite (garbage) file → the open path must surface a typed error, never a fresh empty store.
        let corruptURL = tmpURL("corrupt")
        defer { cleanup(corruptURL) }
        try Data(repeating: 0xFF, count: 8192).write(to: corruptURL)
        var threwCorrupt = false
        do {
            _ = try BASSQLiteMemoryAtomStore(databaseURL: corruptURL)
            XCTFail("a corrupt/non-sqlite file must THROW at open, not be silently truncated")
        } catch let e as BASSQLiteMemoryAtomStore.StorageError {
            // openFailed / prepareFailed / stepFailed are all acceptable surfacings of corruption — any
            // typed StorageError proves the open path refused to proceed. Tolerance=0 on "must throw typed".
            _ = e
            threwCorrupt = true
        }
        XCTAssertTrue(threwCorrupt, "corrupt-at-open must surface a typed StorageError")

        print("QINAO-GATE sql_persistence_integrity_gate: PASS "
            + "(user_version \(mismatch)≠\(expected) → schemaVersionMismatch + on-disk version preserved; "
            + "integrity-on: healthy opens, corrupt throws)")
    }
}
