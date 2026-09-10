// MARK: - BASChapter714SqlIntegrationTests
// chapter 七百十四 第四刀 / M2244
//
// End-to-end SQL test:opens an in-memory SQLite database,
// applies ALL FOUR schemas (replay_log + episode + bundle +
// tombstone),verifies the tables/indexes/FTS-virtual-tables
// all exist,then exercises each for an insert + select +
// uniqueness-violation round-trip。 Proves the schemas coexist
// cleanly,the FKs / CHECK constraints fire,and FTS5 is queryable。

import XCTest
import Foundation
import SQLite3
@testable import BASMemory

final class BASChapter714SqlIntegrationTests: XCTestCase {

    private var db: OpaquePointer?

    override func setUp() {
        super.setUp()
        sqlite3_open(":memory:", &db)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;",
            nil, nil, nil)
    }

    override func tearDown() {
        if let db { sqlite3_close(db) }
        db = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.flatMap {
                String(cString: $0) } ?? "rc=\(rc)"
            if let errMsg { sqlite3_free(errMsg) }
            throw NSError(domain: "SQL", code: Int(rc),
                userInfo: [
                    NSLocalizedDescriptionKey: msg])
        }
    }

    private func count(_ table: String) throws -> Int {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(
            db, "SELECT COUNT(*) FROM \(table);", -1,
            &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        if rc != SQLITE_OK {
            throw NSError(domain: "SQL", code: Int(rc))
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw NSError(domain: "SQL", code: -1)
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func tableExists(_ name: String) throws -> Bool {
        var stmt: OpaquePointer?
        let q = "SELECT name FROM sqlite_master WHERE name = ?;"
        sqlite3_prepare_v2(db, q, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, name, -1, unsafeBitCast(
            -1, to: sqlite3_destructor_type.self))
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    // MARK: - All 4 schemas coexist

    func testAllFourSchemasApplySuccessfully() throws {
        try exec(ReplayLogSchema.allStatementsSQL)
        try exec(EpisodeSchema.allStatementsSQL)
        try exec(BundleSchema.allStatementsSQL)
        try exec(TombstoneSchema.allStatementsSQL)

        // Every table/virtual-table from every schema must
        // exist after the unified DDL apply。
        let tables = [
            "replay_log_events", "replay_log_chain_tip",
            "replay_log_fts",
            "episode_records", "episode_fts",
            "bundle_records", "bundle_atoms", "bundle_fts",
            "tombstone_records", "tombstone_fts",
        ]
        for t in tables {
            XCTAssertTrue(try tableExists(t),
                "table \(t) must exist after DDL apply")
        }
    }

    // MARK: - Episode INSERT round-trip + state CHECK

    func testEpisodeInsertAndStateCheckConstraint() throws {
        try exec(EpisodeSchema.allStatementsSQL)
        // Valid insert
        try exec("""
            INSERT INTO episode_records
              (episode_id, session_id, started_at_ms,
               state, chain_self_hash_b64)
            VALUES
              ('ep-1', 'sess-1', 1700000000, 'open', 'hash-1');
            """)
        XCTAssertEqual(try count("episode_records"), 1)

        // Invalid state value → CHECK rejects
        XCTAssertThrowsError(try exec("""
            INSERT INTO episode_records
              (episode_id, session_id, started_at_ms,
               state, chain_self_hash_b64)
            VALUES
              ('ep-2', 'sess-1', 1700000001,
               'bogus-state', 'hash-2');
            """),
            "Invalid state value must violate CHECK constraint")
        XCTAssertEqual(try count("episode_records"), 1)
    }

    // MARK: - Bundle composite-PK round-trip

    func testBundleCompositePrimaryKey() throws {
        try exec(BundleSchema.allStatementsSQL)
        try exec("""
            INSERT INTO bundle_records
              (bundle_id, episode_id, kind, state,
               canonical_hash_hex)
            VALUES
              ('b-1', 'ep-1', 'retrieval-context',
               'open', 'abc123');
            """)
        // Insert 2 atoms in sequence
        try exec("""
            INSERT INTO bundle_atoms VALUES
              ('b-1', 'atom-1', 0),
              ('b-1', 'atom-2', 1);
            """)
        XCTAssertEqual(try count("bundle_atoms"), 2)

        // Composite PK violation: same (bundle_id,
        // sequence_index) twice should fail
        XCTAssertThrowsError(try exec("""
            INSERT INTO bundle_atoms VALUES
              ('b-1', 'atom-3', 0);
            """),
            "(bundle_id, sequence_index) must be unique")
    }

    // MARK: - Tombstone monotonic-redaction invariant

    func testTombstoneMonotonicRedactionInvariant() throws {
        try exec(TombstoneSchema.allStatementsSQL)
        try exec("""
            INSERT INTO tombstone_records VALUES
              ('ts-1', 'atom', 'atom-xyz',
               'sovereign-redaction', NULL, 1700000000,
               'ledger-hash-1');
            """)
        XCTAssertEqual(try count("tombstone_records"), 1)

        // Attempt to tombstone the SAME target twice — must
        // fail per the UNIQUE INDEX on (target_kind, target_ref)
        XCTAssertThrowsError(try exec("""
            INSERT INTO tombstone_records VALUES
              ('ts-2', 'atom', 'atom-xyz',
               'replay-attempt', NULL, 1700000001,
               'ledger-hash-2');
            """),
            "Tombstoning the same target twice must violate" +
            " the UNIQUE INDEX (monotonic-redaction invariant)")

        // But tombstoning a DIFFERENT target succeeds
        try exec("""
            INSERT INTO tombstone_records VALUES
              ('ts-3', 'bundle', 'bundle-xyz',
               'expert-redaction', NULL, 1700000002,
               'ledger-hash-3');
            """)
        XCTAssertEqual(try count("tombstone_records"), 2)
    }

    // MARK: - target_kind CHECK constraint

    func testTombstoneTargetKindCheckConstraint() throws {
        try exec(TombstoneSchema.allStatementsSQL)
        XCTAssertThrowsError(try exec("""
            INSERT INTO tombstone_records VALUES
              ('ts-bad', 'invalid-kind', 'x',
               'reason', NULL, 1700000000, 'h');
            """),
            "Invalid target_kind must violate CHECK constraint")
    }

    // MARK: - Replay-log chain-tip singleton

    func testReplayLogChainTipSingletonConstraint() throws {
        try exec(ReplayLogSchema.allStatementsSQL)
        try exec("""
            INSERT INTO replay_log_chain_tip
              (rowid, last_event_id, last_self_hash_b64,
               sealed_at_ms)
            VALUES (1, 'e-1', 'h-1', 1700000000);
            """)
        XCTAssertEqual(try count("replay_log_chain_tip"), 1)

        // Cannot insert a 2nd row (rowid != 1 violates CHECK)
        XCTAssertThrowsError(try exec("""
            INSERT INTO replay_log_chain_tip
              (rowid, last_event_id, last_self_hash_b64,
               sealed_at_ms)
            VALUES (2, 'e-2', 'h-2', 1700000001);
            """),
            "chain_tip must be a singleton (rowid = 1)")
    }

    // MARK: - FTS5 round-trip across all 4 schemas

    func testAllFTSTablesAreQueryable() throws {
        try exec(ReplayLogSchema.allStatementsSQL)
        try exec(EpisodeSchema.allStatementsSQL)
        try exec(BundleSchema.allStatementsSQL)
        try exec(TombstoneSchema.allStatementsSQL)
        // Just confirm each FTS table is queryable without
        // error。 Actual content-table-linked indexing requires
        // INSERT triggers,deferred to a later knife。
        for table in [
            "replay_log_fts", "episode_fts",
            "bundle_fts", "tombstone_fts"
        ] {
            try exec(
                "SELECT * FROM \(table) WHERE \(table) MATCH 'nonexistent';"
            )
        }
    }
}
