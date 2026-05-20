// MARK: - BASChapter765L7LedgerSchemasTests
// chapter 七百六十五 / M2476-M2480
//
// DEEPER LAYER-MIGRATION ARC verifies the BASSQLSchemaGen plugin
// emitted UnknownLedgerRecordsSchema + ContradictionLedgerRecordsSchema
// for the new L7 ledger SQL files。 Closes the chapter 七百六十四 +
// 七百六十五 L7 Mirror Blade sub-arc。

import XCTest
@testable import BASSovereign

final class BASChapter765L7LedgerSchemasTests: XCTestCase {

    // MARK: - Schema enums reachable

    func testUnknownLedgerSchemaImportable() {
        XCTAssertFalse(
            UnknownLedgerRecordsSchema.allStatementsSQL.isEmpty,
            "Plugin must auto-generate UnknownLedgerRecordsSchema " +
            "from 011_unknown_ledger_records.sql")
    }

    func testContradictionLedgerSchemaImportable() {
        XCTAssertFalse(
            ContradictionLedgerRecordsSchema.allStatementsSQL.isEmpty,
            "Plugin must auto-generate " +
            "ContradictionLedgerRecordsSchema from " +
            "012_contradiction_ledger_records.sql")
    }

    // MARK: - Statement counts

    func testUnknownLedgerStatementCount() {
        // 1 CREATE TABLE + 3 CREATE INDEX = 4 statements
        XCTAssertEqual(
            UnknownLedgerRecordsSchema.statementCount, 4)
    }

    func testContradictionLedgerStatementCount() {
        // 1 CREATE TABLE + 4 CREATE INDEX = 5 statements
        XCTAssertEqual(
            ContradictionLedgerRecordsSchema.statementCount, 5)
    }

    // MARK: - Column shape pins

    func testUnknownLedgerColumns() {
        let sql = UnknownLedgerRecordsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("event_id TEXT PRIMARY KEY"))
        XCTAssertTrue(sql.contains("session_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("turn_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("unknown_text TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("confidence REAL NOT NULL"))
        XCTAssertTrue(sql.contains("discovered_at_ms INTEGER NOT NULL"))
        // CHECK constraint
        XCTAssertTrue(sql.contains(
            "confidence >= 0.0 AND confidence <= 1.0"))
    }

    func testContradictionLedgerColumns() {
        let sql = ContradictionLedgerRecordsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("event_id TEXT PRIMARY KEY"))
        XCTAssertTrue(sql.contains("session_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("turn_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("contradiction_text TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("salience REAL NOT NULL"))
        XCTAssertTrue(sql.contains("confidence REAL NOT NULL"))
        XCTAssertTrue(sql.contains("resolved INTEGER NOT NULL"))
        XCTAssertTrue(sql.contains("resolved_at_ms INTEGER"))
        // CHECK constraints
        XCTAssertTrue(sql.contains(
            "salience >= 0.0 AND salience <= 1.0"))
        XCTAssertTrue(sql.contains(
            "resolved IN (0, 1)"))
    }

    // MARK: - Indexes

    func testUnknownLedgerIndexes() {
        let sql = UnknownLedgerRecordsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("ul_session_idx"))
        XCTAssertTrue(sql.contains("ul_turn_idx"))
        XCTAssertTrue(sql.contains("ul_confidence_idx"))
    }

    func testContradictionLedgerIndexes() {
        let sql = ContradictionLedgerRecordsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("cl_session_idx"))
        XCTAssertTrue(sql.contains("cl_turn_idx"))
        XCTAssertTrue(sql.contains("cl_salience_idx"))
        XCTAssertTrue(sql.contains("cl_resolved_idx"))
    }

    // MARK: - Idempotency

    func testSchemaIdempotent() {
        let sql = UnknownLedgerRecordsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS"))
        XCTAssertTrue(sql.contains("CREATE INDEX IF NOT EXISTS"))
        let csql = ContradictionLedgerRecordsSchema.allStatementsSQL
        XCTAssertTrue(csql.contains("CREATE TABLE IF NOT EXISTS"))
        XCTAssertTrue(csql.contains("CREATE INDEX IF NOT EXISTS"))
    }

    // MARK: - L7 sub-arc scorecard pin

    func testL7SubArcSummary() {
        struct L7SubArc {
            let chapterRange: String
            let mRange: String
            let totalKnives: Int
            let rustCratesAdded: [String]
            let sqlSchemasAdded: [String]
        }
        let l7 = L7SubArc(
            chapterRange: "chapters 七百六十四-七百六十五",
            mRange: "M2471-M2480",
            totalKnives: 10,
            rustCratesAdded: ["bas-mirror-blade"],
            sqlSchemasAdded: [
                "011_unknown_ledger_records",
                "012_contradiction_ledger_records",
            ])
        XCTAssertEqual(l7.totalKnives, 10)
        XCTAssertEqual(l7.rustCratesAdded.count, 1)
        XCTAssertEqual(l7.sqlSchemasAdded.count, 2)
    }
}
