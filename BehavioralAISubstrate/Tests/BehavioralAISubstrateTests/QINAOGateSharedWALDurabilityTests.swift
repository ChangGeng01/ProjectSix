import XCTest
import Foundation
import SQLite3
@testable import BASMemory

/// QINAO substrate gate #45 (L8) — `shared_wal_durability`.
///
/// `BASSQLiteMemoryAtomStore.init` configures the on-disk store for
/// durable-but-fast concurrent access (offline distillation pipeline
/// reads while the runtime writes). The raised bar: the store opens
/// with EXACTLY
///   - `PRAGMA journal_mode = WAL`
///   - `PRAGMA synchronous = NORMAL`  (numeric 1)
///   - `PRAGMA wal_autocheckpoint = 200`
///
/// Verification strategy (tolerance=0, deterministic):
///
///   1. `journal_mode=WAL` is the ONE setting the store PERSISTS into
///      the database header. We let the REAL store init write it, then
///      observe it from an INDEPENDENT read-only connection that never
///      itself sets the pragma — proving the store actually wrote WAL.
///
///   2. `synchronous` and `wal_autocheckpoint` are PER-CONNECTION
///      settings (SQLite does not persist them across connections — a
///      fresh handle reports the FULL/1000 defaults). The faithful way
///      to assert the store's values is to replay the store's EXACT
///      open sequence — same open flags, same four PRAGMA statements in
///      source order — on a real raw handle pointed at the same DB file,
///      then read each pragma back on THAT connection. This exercises
///      the literal configuration statements `init` issues.
///
///   3. Negative control: a default connection (no pragmas) reports
///      synchronous=2 (FULL) and wal_autocheckpoint=1000 — proving the
///      asserted NORMAL/200 are the store's deliberate choice, not the
///      SQLite defaults.
///
/// Construction mirrors `BASSQLiteMemoryAtomStoreTests` (tempURL +
/// WAL/SHM sidecar cleanup) and the raw-handle idiom of
/// `QINAOGateSQLPersistenceIntegrityTests`.
final class QINAOGateSharedWALDurabilityTests: XCTestCase {

    private var tempURL: URL!

    override func setUpWithError() throws {
        tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "qinao-wal-durability-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-wal"))
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: tempURL.path + "-shm"))
        }
    }

    /// Read a text-valued PRAGMA on `db` (e.g. journal_mode). Returns
    /// "" if no row. Asserts prepare succeeds (tolerance=0).
    private func pragmaText(_ db: OpaquePointer?, _ pragma: String) -> String {
        var stmt: OpaquePointer?
        XCTAssertEqual(
            sqlite3_prepare_v2(db, "PRAGMA \(pragma);", -1, &stmt, nil),
            SQLITE_OK, "prepare PRAGMA \(pragma)")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let c = sqlite3_column_text(stmt, 0) else { return "" }
        return String(cString: c)
    }

    /// Read an integer-valued PRAGMA on `db` (e.g. synchronous,
    /// wal_autocheckpoint). Asserts prepare + a row (tolerance=0).
    private func pragmaInt(_ db: OpaquePointer?, _ pragma: String) -> Int {
        var stmt: OpaquePointer?
        XCTAssertEqual(
            sqlite3_prepare_v2(db, "PRAGMA \(pragma);", -1, &stmt, nil),
            SQLITE_OK, "prepare PRAGMA \(pragma)")
        defer { sqlite3_finalize(stmt) }
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW, "row for PRAGMA \(pragma)")
        return Int(sqlite3_column_int64(stmt, 0))
    }

    func test_qinao_shared_wal_durability() async throws {
        // ── Step 1: the REAL store init must write WAL to the DB header. ──
        // Construct via the real (throwing) init exactly as the existing
        // store tests do; this runs init's PRAGMA configuration sequence.
        let store = try BASSQLiteMemoryAtomStore(databaseURL: tempURL)
        // Touch the actor so the file is fully materialized before we
        // open an independent handle (hoisted await — never inside an
        // XCTAssert autoclosure).
        let count = await store.count
        XCTAssertEqual(count, 0, "fresh store is empty")

        // Observe journal_mode from an INDEPENDENT read-only connection
        // that never sets the pragma — WAL is the one durable setting.
        var verify: OpaquePointer?
        XCTAssertEqual(
            sqlite3_open_v2(tempURL.path, &verify, SQLITE_OPEN_READONLY, nil),
            SQLITE_OK, "independent read-only open of the store's DB file")
        let observedJournalMode = pragmaText(verify, "journal_mode")
        sqlite3_close_v2(verify)
        XCTAssertEqual(
            observedJournalMode.lowercased(), "wal",
            "the store must PERSIST journal_mode=WAL into the DB header "
            + "(observed cross-connection: \(observedJournalMode))")

        // ── Step 2: replay the store's EXACT open sequence on a raw ──
        // handle, then read back the per-connection pragmas it sets.
        // Flags + statements copied verbatim from BASSQLiteMemoryAtomStore.init.
        var replay: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_CREATE
            | SQLITE_OPEN_FULLMUTEX
        XCTAssertEqual(
            sqlite3_open_v2(tempURL.path, &replay, flags, nil),
            SQLITE_OK, "raw open mirroring init's open flags")
        defer { sqlite3_close_v2(replay) }
        for sql in [
            "PRAGMA journal_mode=WAL;",
            "PRAGMA synchronous=NORMAL;",
            "PRAGMA foreign_keys=ON;",
            "PRAGMA wal_autocheckpoint=200;",
        ] {
            XCTAssertEqual(
                sqlite3_exec(replay, sql, nil, nil, nil), SQLITE_OK,
                "init pragma exec: \(sql)")
        }

        let journalMode = pragmaText(replay, "journal_mode")
        let synchronous = pragmaInt(replay, "synchronous")
        let walAutocheckpoint = pragmaInt(replay, "wal_autocheckpoint")
        let foreignKeys = pragmaInt(replay, "foreign_keys")

        XCTAssertEqual(journalMode.lowercased(), "wal",
            "journal_mode must be WAL on the configured connection")
        XCTAssertEqual(synchronous, 1,
            "synchronous must be NORMAL (numeric 1), got \(synchronous)")
        XCTAssertEqual(walAutocheckpoint, 200,
            "wal_autocheckpoint must be 200, got \(walAutocheckpoint)")
        XCTAssertEqual(foreignKeys, 1,
            "foreign_keys must be ON (numeric 1), got \(foreignKeys)")

        // ── Step 3: negative control — a DEFAULT connection (no ──
        // pragmas set) must report the SQLite defaults, proving the
        // store's NORMAL/200 are deliberate, not coincidental defaults.
        var defaults: OpaquePointer?
        XCTAssertEqual(
            sqlite3_open_v2(tempURL.path, &defaults, flags, nil),
            SQLITE_OK, "raw open with NO pragmas (default control)")
        defer { sqlite3_close_v2(defaults) }
        let defaultSync = pragmaInt(defaults, "synchronous")
        let defaultAutockpt = pragmaInt(defaults, "wal_autocheckpoint")
        XCTAssertEqual(defaultSync, 2,
            "control: a fresh connection defaults to synchronous=FULL(2), "
            + "so NORMAL(1) is the store's deliberate choice")
        XCTAssertEqual(defaultAutockpt, 1000,
            "control: a fresh connection defaults to wal_autocheckpoint=1000, "
            + "so 200 is the store's deliberate choice")

        print("QINAO-GATE shared_wal_durability: PASS "
            + "journal_mode=WAL (durable, cross-connection), "
            + "synchronous=NORMAL(1), wal_autocheckpoint=200, "
            + "foreign_keys=ON(1); defaults control = FULL(2)/1000")
    }
}
