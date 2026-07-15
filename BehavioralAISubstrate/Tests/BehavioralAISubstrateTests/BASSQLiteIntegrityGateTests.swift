import XCTest
import SQLite3
@testable import BASRuntimeCore

/// audit M-c (SQLite read fail-open / 损坏=空, systemic disease #4) — the KG / EvalRun /
/// risk-observation stores read a corrupt SQLite file as an EMPTY result (`(try? fetchAll) ?? []`
/// swallowed the error), so a corrupt store was indistinguishable from an empty one. The fix runs
/// `PRAGMA integrity_check` at OPEN (default-on, fail-closed) so corruption is SURFACED before any
/// read can mistake it for empty. The wiring is identical for all three stores; verified here on
/// the shared `BASSQLiteIntegrity` gate + the KG store integration.
final class BASSQLiteIntegrityGateTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-integrity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
    }

    // MARK: - The gate mechanism (deterministic, raw DB — DELETE journal keeps data in the main file)

    /// A healthy DB passes; a structurally-corrupt DB (b-tree broken, file header intact so
    /// `sqlite3_open` still succeeds) is caught. This is the fail-open shape: a naive open + read
    /// swallowed the resulting error to `[]`; the gate surfaces it via `integrity_check`.
    func testAssertOKPassesHealthyThrowsCorrupt() throws {
        let url = tempRoot.appendingPathComponent("raw.sqlite")

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        _ = sqlite3_exec(db, "PRAGMA journal_mode=DELETE;", nil, nil, nil)   // no WAL → main file
        _ = sqlite3_exec(db, "CREATE TABLE t(id INTEGER PRIMARY KEY, v TEXT);", nil, nil, nil)
        _ = sqlite3_exec(db, "BEGIN;", nil, nil, nil)
        for i in 0..<800 {
            _ = sqlite3_exec(db, "INSERT INTO t(v) VALUES('row-\(i)-paddddddddddding');", nil, nil, nil)
        }
        _ = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        // Healthy → passes (no false positive).
        XCTAssertNoThrow(try BASSQLiteIntegrity.assertOK(db: db!, store: "raw"))
        sqlite3_close(db)

        // Break the b-tree past the 100-byte file header (header stays valid → open succeeds).
        try corrupt(url, atOffset: 100, count: 3000)

        var db2: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db2), SQLITE_OK)   // open still succeeds (header intact)
        defer { sqlite3_close(db2) }
        XCTAssertThrowsError(try BASSQLiteIntegrity.assertOK(db: db2!, store: "raw"),
            "integrity_check must SURFACE structural corruption, not let a later read swallow it to []") { err in
            XCTAssertTrue(err is BASSQLiteIntegrity.CorruptStoreError, "must be CorruptStoreError: \(err)")
        }
    }

    /// The kill-switch makes `assertOK` a no-op (perf escape) — even on a corrupt handle it does not
    /// throw, and `enabled` is false. Default-on is the only behavioral difference for a healthy DB.
    func testKillSwitchDisablesGate() throws {
        setenv("BAS_SKIP_STORE_INTEGRITY_CHECK", "1", 1)
        defer { unsetenv("BAS_SKIP_STORE_INTEGRITY_CHECK") }
        XCTAssertFalse(BASSQLiteIntegrity.enabled, "kill-switch must disable the gate")

        let url = tempRoot.appendingPathComponent("killswitch.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        _ = sqlite3_exec(db, "PRAGMA journal_mode=DELETE;", nil, nil, nil)
        _ = sqlite3_exec(db, "CREATE TABLE t(id INTEGER PRIMARY KEY, v TEXT);", nil, nil, nil)
        _ = sqlite3_exec(db, "BEGIN;", nil, nil, nil)
        for i in 0..<800 { _ = sqlite3_exec(db, "INSERT INTO t(v) VALUES('row-\(i)-padddding');", nil, nil, nil) }
        _ = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        sqlite3_close(db)
        try corrupt(url, atOffset: 100, count: 3000)

        var db2: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db2), SQLITE_OK)
        defer { sqlite3_close(db2) }
        XCTAssertNoThrow(try BASSQLiteIntegrity.assertOK(db: db2!, store: "raw"),
            "with the kill-switch set, the gate is skipped (no throw even on a corrupt DB)")
    }

    // MARK: - Store integration (the wiring: no false positive on a healthy store)

    private func node(_ id: String) -> BASKnowledgeNode {
        BASKnowledgeNode(nodeID: id, kind: .event, label: "L", createdAtMs: 1, payloadJson: "{}")
    }

    /// A healthy KG store round-trips its data across reopen — the gate wired into `init` must NOT
    /// false-positive (a real store open + read still works).
    func testHealthyStoreReopensAndReturnsData() async throws {
        let url = tempRoot.appendingPathComponent("healthy.sqlite")
        do {
            let s = try BASSQLiteKnowledgeGraphStorage(databaseURL: url)
            _ = try await s.appendNode(node("n1"))
        }
        let reopened = try BASSQLiteKnowledgeGraphStorage(databaseURL: url)   // gate runs at open
        let nodes = await reopened.allNodes()
        XCTAssertEqual(nodes.count, 1, "a healthy store must reopen + return its data (no false positive)")
    }

    private func corrupt(_ url: URL, atOffset offset: Int, count: Int) throws {
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        handle.write(Data(repeating: 0xFF, count: count))
    }
}
