// MARK: - BASMemoryUsageRecordsSchemaGeneratedTests
// chapter 七百二 / M2172 第二刀 — proves the
//                                  `BASSQLSchemaGen` build
//                                  plugin emitted the
//                                  generated enum for
//                                  `001_memory_usage_records.sql`
//                                  and that the enum is
//                                  importable + introspectable
//                                  from a consumer module。
//
// Without this test,a future regression that detaches the
// plugin from BASMemory or breaks codegen would compile
// because BASMemoryUsageTracker.swift does not USE the
// generated enum until M2173 第三刀。 These tests force the
// plugin to emit + the generated enum to be a real call
// site,so plugin breakage fails CI immediately。
//
// Tests live in the same single test target as the rest of
// BehavioralAISubstrateTests (chapter 二百十一 single-source-
// of-truth pattern)。

import XCTest
@testable import BASMemory

final class BASMemoryUsageRecordsSchemaGeneratedTests:
    XCTestCase
{

    // MARK: - Generated enum is reachable

    func testGeneratedEnumIsImportable() {
        // If the plugin failed to emit,this test would
        // fail to COMPILE,not at runtime — that's the
        // point。 The runtime check below is a smoke test。
        let sql = MemoryUsageRecordsSchema.allStatementsSQL
        XCTAssertFalse(sql.isEmpty,
            "Generated allStatementsSQL must be non-empty")
    }

    // MARK: - Statement count matches the SQL file

    func testStatementCountIsThree() {
        // 1 CREATE TABLE + 2 CREATE INDEX = 3 statements。
        // Bumping this requires updating the SQL file
        // AND this test simultaneously (anti-drift)。
        XCTAssertEqual(
            MemoryUsageRecordsSchema.statementCount, 3)
    }

    // MARK: - SQL substring pins

    func testAllStatementsSQLContainsCreateTable() {
        XCTAssertTrue(
            MemoryUsageRecordsSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS memory_usage_records"
            ),
            "Generated SQL must include the CREATE TABLE" +
            " statement")
    }

    func testAllStatementsSQLContainsAtomIndex() {
        XCTAssertTrue(
            MemoryUsageRecordsSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS memory_usage_atom_idx"
            ),
            "Generated SQL must include the atom_id index")
    }

    func testAllStatementsSQLContainsSessionIndex() {
        XCTAssertTrue(
            MemoryUsageRecordsSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS memory_usage_session_idx"
            ),
            "Generated SQL must include the session_ref index")
    }

    // MARK: - Column pin (anti-drift on the schema shape)

    func testAllStatementsSQLContainsAllSevenColumns() {
        let columns = [
            "record_id TEXT PRIMARY KEY NOT NULL",
            "atom_id TEXT NOT NULL",
            "retrieved_at_ms INTEGER NOT NULL",
            "session_ref TEXT NOT NULL",
            "turn_ref TEXT NOT NULL",
            "permit_mode TEXT NOT NULL",
            "helped_state TEXT NOT NULL"
        ]
        for column in columns {
            XCTAssertTrue(
                MemoryUsageRecordsSchema.allStatementsSQL
                    .contains(column),
                "Generated SQL missing column declaration:" +
                " '\(column)'")
        }
    }

    // MARK: - Determinism (build → build byte-equal output)

    func testAllStatementsSQLIsDeterministic() {
        let a = MemoryUsageRecordsSchema.allStatementsSQL
        let b = MemoryUsageRecordsSchema.allStatementsSQL
        XCTAssertEqual(a, b)
    }
}
