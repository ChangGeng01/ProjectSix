// MARK: - BASChapter738PermitEscalationStepsSchemaGeneratedTests
// chapter 七百三十八 第三刀 / M2363
//
// LAYER-MIGRATION ARC — verifies the BASSQLSchemaGen plugin
// emitted PermitEscalationStepsSchema for the net-new
// 008_permit_escalation_steps.sql in Sources/BASPolicy/SQL/。
//
// Append-only per-stage transition table:
//   - Captures BASPermitEscalationStageRecord shape verbatim
//     (stage / input_mode / output_mode / fired / reason_codes)
//   - FK to permit_escalation_ledger(escalation_id)
//   - Indexes for (escalation_id, step_ms),stage,fired,
//     session_id (denormalized for cross-escalation queries)
//
// Smoke gates:
//   - Schema enum reachable from tests
//   - statementCount == 5 (table + 4 indexes)
//   - All 10 columns present (the FOREIGN KEY clause is
//     declared inline,not as a separate column)
//   - CHECK on stage matches BASPermitEscalationStage raw
//     values verbatim (5 cases)
//   - CHECK on input_mode / output_mode matches
//     BASActionPermitMode raw values verbatim (9 cases each)
//   - CHECK on fired pinned to (0, 1)
//   - FOREIGN KEY clause declares the escalation_id link
//   - Append-only discipline pinned (no DELETE / UPDATE
//     paths in schema)

import XCTest
@testable import BASPolicy

final class BASChapter738PermitEscalationStepsSchemaGeneratedTests:
    XCTestCase
{

    func testGeneratedEnumIsImportable() {
        XCTAssertFalse(
            PermitEscalationStepsSchema
                .allStatementsSQL.isEmpty)
    }

    func testStatementCountIsFive() {
        // 1 CREATE TABLE + 4 CREATE INDEX = 5 statements。
        XCTAssertEqual(
            PermitEscalationStepsSchema.statementCount, 5)
    }

    func testAllStatementsSQLContainsTable() {
        XCTAssertTrue(
            PermitEscalationStepsSchema.allStatementsSQL
                .contains(
                    "CREATE TABLE IF NOT EXISTS permit_escalation_steps"))
    }

    func testAllTenColumnsPresent() {
        let columns = [
            "step_id TEXT PRIMARY KEY NOT NULL",
            "escalation_id TEXT NOT NULL",
            "session_id TEXT NOT NULL",
            "step_ms INTEGER NOT NULL",
            "stage TEXT NOT NULL",
            "input_mode TEXT NOT NULL",
            "output_mode TEXT NOT NULL",
            "fired INTEGER NOT NULL",
            "reason_codes_json TEXT",
            "evidence_digest_b64 TEXT"
        ]
        for column in columns {
            XCTAssertTrue(
                PermitEscalationStepsSchema.allStatementsSQL
                    .contains(column),
                "Missing column: \(column)")
        }
    }

    func testStageCheckMatchesAllFiveBASPermitEscalationStages() {
        // CHECK on stage MUST match BASPermitEscalationStage
        // raw values verbatim (5 cases)。 chapter 一百八十五
        // single source of truth pin。
        for stage in BASPermitEscalationStage.allCases {
            let needle = "'\(stage.rawValue)'"
            XCTAssertTrue(
                PermitEscalationStepsSchema.allStatementsSQL
                    .contains(needle),
                "stage CHECK must include "
                + "BASPermitEscalationStage.\(stage.rawValue)")
        }
    }

    func testInputOutputModeCheckMatchesAllNineModes() {
        // Both input_mode and output_mode CHECK constraints
        // must cover all 9 BASActionPermitMode raw values。
        // We check by ensuring each mode appears at least
        // TWICE in the SQL (once in input_mode CHECK, once
        // in output_mode CHECK)。
        for mode in BASActionPermitMode.allCases {
            let needle = "'\(mode.rawValue)'"
            let count = PermitEscalationStepsSchema
                .allStatementsSQL
                .components(separatedBy: needle).count - 1
            XCTAssertGreaterThanOrEqual(
                count, 2,
                "BASActionPermitMode.\(mode.rawValue) must "
                + "appear in both input_mode and output_mode "
                + "CHECK clauses")
        }
    }

    func testFiredIsBoolean() {
        XCTAssertTrue(
            PermitEscalationStepsSchema.allStatementsSQL
                .contains("CHECK (fired IN (0, 1))"),
            "fired CHECK constraint must enforce boolean")
    }

    func testForeignKeyClauseDeclared() {
        // The chapter 七百十二 第一刀 chain link discipline
        // says: every step row REFERENCES its lifecycle row。
        // SQLite enforces this only when PRAGMA foreign_keys
        // = ON,but the DDL pin is the schema's single source
        // of truth and chapter 七百三十九 producer code sets
        // the PRAGMA at connection open。
        XCTAssertTrue(
            PermitEscalationStepsSchema.allStatementsSQL
                .contains("FOREIGN KEY (escalation_id)"),
            "FK clause missing")
        XCTAssertTrue(
            PermitEscalationStepsSchema.allStatementsSQL
                .contains(
                    "REFERENCES permit_escalation_ledger(escalation_id)"),
            "FK reference must point at the lifecycle table")
    }

    func testEscalationTimeCompositeIndexPresent() {
        XCTAssertTrue(
            PermitEscalationStepsSchema.allStatementsSQL
                .contains(
                    "permit_escalation_steps_escalation_time_idx"),
            "(escalation_id, step_ms) composite index missing")
        XCTAssertTrue(
            PermitEscalationStepsSchema.allStatementsSQL
                .contains(
                    "ON permit_escalation_steps(escalation_id, step_ms)"))
    }

    func testStageAndFiredAndSessionIndexesPresent() {
        let indexNames = [
            "permit_escalation_steps_stage_idx",
            "permit_escalation_steps_fired_idx",
            "permit_escalation_steps_session_idx"
        ]
        for indexName in indexNames {
            XCTAssertTrue(
                PermitEscalationStepsSchema.allStatementsSQL
                    .contains(indexName),
                "Missing index: \(indexName)")
        }
    }

    func testAppendOnlyDisciplineNoUpdateOrDeleteDDL() {
        // The schema itself contains no UPDATE / DELETE DDL
        // statements (the producer code path enforces this
        // discipline)。 This test is a drift-catcher:if a
        // future contributor accidentally adds a TRIGGER
        // or DELETE FROM clause,this fails。
        //
        // We check for actual DDL syntax — "UPDATE ... SET"
        // or "DELETE FROM" — NOT the word "DELETE" anywhere
        // (the doc-comment legitimately says "never DELETE")。
        let sql = PermitEscalationStepsSchema
            .allStatementsSQL.uppercased()
        XCTAssertFalse(
            sql.contains("DELETE FROM"),
            "Append-only schema must contain no DELETE FROM")
        XCTAssertFalse(
            sql.contains("UPDATE PERMIT_ESCALATION_STEPS"),
            "Append-only schema must contain no UPDATE "
            + "permit_escalation_steps")
        // Drift-catcher for triggers that would write to
        // the table。
        XCTAssertFalse(
            sql.contains("CREATE TRIGGER"),
            "Append-only schema must contain no triggers")
    }

    func testSchemaIsIdempotent() {
        let lines = PermitEscalationStepsSchema
            .allStatementsSQL
            .split(separator: "\n")
            .map { String($0) }
        let createLines = lines.filter {
            $0.trimmingCharacters(in: .whitespaces)
                .hasPrefix("CREATE")
        }
        XCTAssertEqual(
            createLines.count, 5,
            "expected 5 CREATE statements")
        for line in createLines {
            XCTAssertTrue(
                line.contains("IF NOT EXISTS"),
                "CREATE must be idempotent: \(line)")
        }
    }
}
