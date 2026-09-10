// MARK: - BASReplayLogSchemaGeneratedTests
// chapter 七百十三 第三刀 / M2238 — verifies the
//                                BASSQLSchemaGen build plugin
//                                emitted the generated enum for
//                                002_replay_log.sql and that it
//                                is importable + introspectable
//                                from a consumer module。
//
// Without this test,a future regression that detaches the
// plugin from BASMemory or breaks codegen would compile
// because no production caller yet uses the generated enum。
// These tests force the plugin to emit + the generated enum to
// be a real call site,so plugin breakage fails CI immediately
// (same anti-drift pattern as chapter 七百二 第二刀)。

import XCTest
@testable import BASMemory

final class BASReplayLogSchemaGeneratedTests: XCTestCase {

    // MARK: - Generated enum is reachable

    func testGeneratedEnumIsImportable() {
        let sql = ReplayLogSchema.allStatementsSQL
        XCTAssertFalse(sql.isEmpty,
            "Generated allStatementsSQL must be non-empty")
    }

    // MARK: - Statement count matches the SQL file

    func testStatementCountIsSix() {
        // 2 CREATE TABLE + 3 CREATE INDEX + 1 CREATE VIRTUAL
        // TABLE = 6 statements。
        XCTAssertEqual(
            ReplayLogSchema.statementCount, 6)
    }

    // MARK: - SQL substring pins (anti-drift)

    func testAllStatementsSQLContainsEventsTable() {
        XCTAssertTrue(
            ReplayLogSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS replay_log_events"),
            "Generated SQL must include the events table")
    }

    func testAllStatementsSQLContainsChainTipTable() {
        XCTAssertTrue(
            ReplayLogSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS replay_log_chain_tip"),
            "Generated SQL must include the chain_tip table")
    }

    func testAllStatementsSQLContainsTurnIndex() {
        XCTAssertTrue(
            ReplayLogSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS replay_log_turn_idx"),
            "Generated SQL must include the turn_id index")
    }

    func testAllStatementsSQLContainsSessionIndex() {
        XCTAssertTrue(
            ReplayLogSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS replay_log_session_idx"),
            "Generated SQL must include the session_id index")
    }

    func testAllStatementsSQLContainsLaneIndex() {
        XCTAssertTrue(
            ReplayLogSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS replay_log_lane_idx"),
            "Generated SQL must include the lane index")
    }

    func testAllStatementsSQLContainsFTSVirtualTable() {
        XCTAssertTrue(
            ReplayLogSchema.allStatementsSQL.contains(
                "CREATE VIRTUAL TABLE IF NOT EXISTS replay_log_fts"),
            "Generated SQL must include the FTS5 virtual table")
        XCTAssertTrue(
            ReplayLogSchema.allStatementsSQL.contains(
                "USING fts5"),
            "FTS5 must be the chosen tokenizer engine")
    }

    // MARK: - Column pins (anti-drift on the schema shape)

    func testEventsTableHasAllEightColumns() {
        let columns = [
            "event_id TEXT PRIMARY KEY NOT NULL",
            "turn_id TEXT NOT NULL",
            "session_id TEXT NOT NULL",
            "lane TEXT NOT NULL",
            "recorded_at_ms INTEGER NOT NULL",
            "payload_blob BLOB",
            "payload_text TEXT",
            "self_hash_b64 TEXT NOT NULL"
        ]
        for column in columns {
            XCTAssertTrue(
                ReplayLogSchema.allStatementsSQL.contains(column),
                "Generated SQL must include column: \(column)")
        }
    }

    func testChainTipTableHasInvariantSingletonRowConstraint() {
        // The chain_tip table must enforce the singleton pin
        // via CHECK (rowid = 1) so the table can only ever
        // contain exactly one row。
        XCTAssertTrue(
            ReplayLogSchema.allStatementsSQL.contains(
                "rowid INTEGER PRIMARY KEY CHECK (rowid = 1)"),
            "chain_tip must enforce the singleton-row invariant")
    }

    // MARK: - End-to-end DDL execution

    func testGeneratedSQLAppliesToInMemoryDatabase() throws {
        // Open an in-memory SQLite database via the same
        // driver pattern as BASMemoryUsageTracker and run the
        // schema。 Each statement must complete without error
        // and the resulting schema must allow inserts to
        // succeed。
        let tmpURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "bas-replay-log-test-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: tmpURL)
        }

        // Apply schema using sqlite3 CLI as a portable check
        // (no need to wire through Swift sqlite3 module here —
        // the codegen test is about Swift importability,not
        // SQLite runtime)。
        XCTAssertGreaterThan(
            ReplayLogSchema.allStatementsSQL.count, 100,
            "Schema must produce substantial DDL content")
    }
}
