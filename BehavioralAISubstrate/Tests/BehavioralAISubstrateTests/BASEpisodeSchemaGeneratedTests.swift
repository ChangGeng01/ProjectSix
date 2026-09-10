// MARK: - BASEpisodeSchemaGeneratedTests
// chapter 七百十四 第一刀 / M2241 — verifies the BASSQLSchemaGen
// plugin emitted EpisodeSchema for 003_episode.sql。 Anti-drift
// pinning on the table shape,index set,and FTS5 wiring。

import XCTest
@testable import BASMemory

final class BASEpisodeSchemaGeneratedTests: XCTestCase {

    func testGeneratedEnumIsImportable() {
        let sql = EpisodeSchema.allStatementsSQL
        XCTAssertFalse(sql.isEmpty,
            "Generated allStatementsSQL must be non-empty")
    }

    func testStatementCountIsFive() {
        // 1 CREATE TABLE + 3 CREATE INDEX + 1 CREATE VIRTUAL
        // TABLE = 5 statements。
        XCTAssertEqual(EpisodeSchema.statementCount, 5)
    }

    func testAllStatementsSQLContainsEpisodeTable() {
        XCTAssertTrue(
            EpisodeSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS episode_records"),
            "Must include episode_records table")
    }

    func testAllStatementsSQLContainsStateCheck() {
        XCTAssertTrue(
            EpisodeSchema.allStatementsSQL.contains(
                "CHECK (state IN ('open', 'sealed', 'abandoned'))"),
            "state column must enforce the 3-value invariant")
    }

    func testAllStatementsSQLContainsAllEightColumns() {
        let columns = [
            "episode_id TEXT PRIMARY KEY NOT NULL",
            "session_id TEXT NOT NULL",
            "started_at_ms INTEGER NOT NULL",
            "ended_at_ms INTEGER",
            "state TEXT NOT NULL",
            "summary_text TEXT",
            "canonical_payload_blob BLOB",
            "chain_self_hash_b64 TEXT NOT NULL",
        ]
        for column in columns {
            XCTAssertTrue(
                EpisodeSchema.allStatementsSQL.contains(column),
                "Missing column: \(column)")
        }
    }

    func testAllStatementsSQLContainsSessionIndex() {
        XCTAssertTrue(
            EpisodeSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS episode_session_idx"))
    }

    func testAllStatementsSQLContainsStateIndex() {
        XCTAssertTrue(
            EpisodeSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS episode_state_idx"))
    }

    func testAllStatementsSQLContainsStartedAtIndex() {
        XCTAssertTrue(
            EpisodeSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS episode_started_at_idx"))
    }

    func testAllStatementsSQLContainsFTSTable() {
        XCTAssertTrue(
            EpisodeSchema.allStatementsSQL.contains(
                "CREATE VIRTUAL TABLE IF NOT EXISTS episode_fts"))
        XCTAssertTrue(
            EpisodeSchema.allStatementsSQL.contains("USING fts5"))
        XCTAssertTrue(
            EpisodeSchema.allStatementsSQL.contains(
                "tokenize='unicode61 remove_diacritics 1'"))
    }
}
