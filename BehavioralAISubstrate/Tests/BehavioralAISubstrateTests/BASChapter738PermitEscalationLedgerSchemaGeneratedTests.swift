// MARK: - BASChapter738PermitEscalationLedgerSchemaGeneratedTests
// chapter 七百三十八 第二刀 / M2362
//
// LAYER-MIGRATION ARC continuation — verifies the BASSQLSchemaGen
// plugin emitted PermitEscalationLedgerSchema for the net-new
// 007_permit_escalation_ledger.sql in Sources/BASPolicy/SQL/。
//
// Lifecycle table pattern:
//   - Open escalation = INSERT row with closed_at_ms = NULL
//   - Close escalation = UPDATE row to stamp closed_at_ms
//   - Partial UNIQUE INDEX enforces at most one open
//     escalation per session at the DB layer (safety-critical
//     invariant — cannot be bypassed by application bug)
//
// Smoke gates:
//   - Schema enum reachable from tests
//   - statementCount == 4 (table + partial-unique + 2 indexes)
//   - All 10 columns present
//   - CHECK constraint on opening/current/prior_mode covers
//     all 9 BASActionPermitMode raw values
//   - Singleton open-escalation invariant enforced via
//     partial UNIQUE INDEX with WHERE closed_at_ms IS NULL
//   - Composite (session_id, opened_at_ms) index present
//   - current_mode index present for aggregation queries

import XCTest
@testable import BASPolicy

final class BASChapter738PermitEscalationLedgerSchemaGeneratedTests:
    XCTestCase
{

    func testGeneratedEnumIsImportable() {
        XCTAssertFalse(
            PermitEscalationLedgerSchema
                .allStatementsSQL.isEmpty)
    }

    func testStatementCountIsFour() {
        // 1 CREATE TABLE + 1 partial UNIQUE INDEX
        // + 2 CREATE INDEX = 4 statements。
        XCTAssertEqual(
            PermitEscalationLedgerSchema.statementCount, 4)
    }

    func testAllStatementsSQLContainsTable() {
        XCTAssertTrue(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains(
                    "CREATE TABLE IF NOT EXISTS permit_escalation_ledger"))
    }

    func testAllTenColumnsPresent() {
        let columns = [
            "escalation_id TEXT PRIMARY KEY NOT NULL",
            "session_id TEXT NOT NULL",
            "opened_at_ms INTEGER NOT NULL",
            "closed_at_ms INTEGER",
            "opening_mode TEXT NOT NULL",
            "current_mode TEXT NOT NULL",
            "prior_mode TEXT",
            "reason TEXT NOT NULL",
            "assertion_ceiling TEXT NOT NULL",
            "ledger_self_hash_b64 TEXT"
        ]
        for column in columns {
            XCTAssertTrue(
                PermitEscalationLedgerSchema.allStatementsSQL
                    .contains(column),
                "Missing column: \(column)")
        }
    }

    func testModeCheckConstraintMatchesAllNineModes() {
        // CHECK on opening_mode / current_mode / prior_mode
        // MUST match BASActionPermitMode raw values verbatim。
        // chapter 一百八十五 anti-magic-number — single source
        // of truth pinned in the SQL file。
        for mode in BASActionPermitMode.allCases {
            let needle = "'\(mode.rawValue)'"
            XCTAssertTrue(
                PermitEscalationLedgerSchema.allStatementsSQL
                    .contains(needle),
                "mode CHECK must include BASActionPermitMode"
                + ".\(mode.rawValue)")
        }
    }

    func testSingletonOpenEscalationInvariantViaPartialUniqueIndex() {
        // SAFETY-CRITICAL pin。 Every session MAY have at
        // most ONE open escalation at any time。 Replay
        // cannot synthesize a 2nd open escalation for the
        // same session because the partial UNIQUE INDEX
        // rejects the INSERT。
        XCTAssertTrue(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains(
                    "CREATE UNIQUE INDEX IF NOT EXISTS"),
            "Singleton invariant must use UNIQUE INDEX")
        XCTAssertTrue(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains(
                    "permit_escalation_open_singleton_idx"),
            "Singleton invariant index name missing")
        XCTAssertTrue(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains("WHERE closed_at_ms IS NULL"),
            "Partial-index WHERE clause must scope to open "
            + "escalations only")
    }

    func testCompositeSessionTimeIndexPresent() {
        XCTAssertTrue(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains(
                    "permit_escalation_session_time_idx"),
            "Composite (session_id, opened_at_ms) index missing")
        XCTAssertTrue(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains(
                    "(session_id, opened_at_ms)"),
            "Composite index must cover both columns")
    }

    func testCurrentModeIndexPresent() {
        // Enables "how many escalations currently in mode X
        // across all sessions" — a quick aggregation hook
        // for the L11 dashboard。
        XCTAssertTrue(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains(
                    "permit_escalation_current_mode_idx"),
            "current_mode index missing")
    }

    func testNullableClosedAtAndPriorMode() {
        // closed_at_ms must be NULL while escalation is
        // open;prior_mode must be NULL on initial insert
        // (no prior mode exists yet)。 Both nullability
        // shapes are part of the typed wire contract。
        XCTAssertFalse(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains("closed_at_ms INTEGER NOT NULL"),
            "closed_at_ms must be nullable")
        XCTAssertFalse(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains("prior_mode TEXT NOT NULL"),
            "prior_mode must be nullable")
    }

    func testLedgerSelfHashB64IsOptionalAtThisKnife() {
        // chapter 七百三十九 may flip NOT NULL once the
        // Rust seal lands;at chapter 七百三十八 it stays
        // nullable to permit V1 → V2 migration without
        // backfill。 If a future chapter forgets to
        // promote it,this test catches the drift。
        XCTAssertFalse(
            PermitEscalationLedgerSchema.allStatementsSQL
                .contains(
                    "ledger_self_hash_b64 TEXT NOT NULL"),
            "ledger_self_hash_b64 stays nullable at chapter "
            + "七百三十八;promote at chapter 七百三十九 only")
    }

    func testSchemaIsIdempotent() {
        // 不变量 #1/#2/#3 — boot-and-rebuild must be a no-op
        // on existing databases。
        let lines = PermitEscalationLedgerSchema
            .allStatementsSQL
            .split(separator: "\n")
            .map { String($0) }
        let createLines = lines.filter {
            $0.trimmingCharacters(in: .whitespaces)
                .hasPrefix("CREATE")
        }
        XCTAssertEqual(
            createLines.count, 4,
            "expected 4 CREATE statements")
        for line in createLines {
            XCTAssertTrue(
                line.contains("IF NOT EXISTS"),
                "CREATE must be idempotent: \(line)")
        }
    }
}
