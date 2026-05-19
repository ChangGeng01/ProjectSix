// MARK: - BASTombstoneSchemaGeneratedTests
// chapter 七百十四 第三刀 / M2243 — verifies the BASSQLSchemaGen
// plugin emitted TombstoneSchema for 005_tombstone.sql。 The
// MONOTONIC-redaction invariant (unique on target tuple) is
// the safety-critical pin。

import XCTest
@testable import BASMemory

final class BASTombstoneSchemaGeneratedTests: XCTestCase {

    func testGeneratedEnumIsImportable() {
        XCTAssertFalse(
            TombstoneSchema.allStatementsSQL.isEmpty)
    }

    func testStatementCountIsSix() {
        // 1 CREATE TABLE + 4 CREATE INDEX (incl. 1 UNIQUE)
        // + 1 CREATE VIRTUAL TABLE = 6 statements。
        XCTAssertEqual(TombstoneSchema.statementCount, 6)
    }

    func testAllStatementsSQLContainsTable() {
        XCTAssertTrue(
            TombstoneSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS tombstone_records"))
    }

    func testTargetKindCheckConstraint() {
        XCTAssertTrue(
            TombstoneSchema.allStatementsSQL.contains(
                "CHECK (target_kind IN" +
                "\n        ('atom', 'episode', 'bundle'))"),
            "target_kind must enforce 3-value typed invariant")
    }

    func testMonotonicRedactionInvariantViaUniqueIndex() {
        // The SAFETY-CRITICAL pin。 Every target can be
        // tombstoned AT MOST ONCE — replay cannot synthesize
        // a 2nd tombstone for the same target via SQLite
        // because the UNIQUE INDEX rejects the INSERT。
        XCTAssertTrue(
            TombstoneSchema.allStatementsSQL.contains(
                "CREATE UNIQUE INDEX IF NOT EXISTS tombstone_target_idx"),
            "Monotonic redaction must be enforced via UNIQUE INDEX")
        XCTAssertTrue(
            TombstoneSchema.allStatementsSQL.contains(
                "ON tombstone_records(target_kind, target_ref)"))
    }

    func testAllSevenColumns() {
        let columns = [
            "tombstone_id TEXT PRIMARY KEY NOT NULL",
            "target_kind TEXT NOT NULL",
            "target_ref TEXT NOT NULL",
            "redaction_reason TEXT NOT NULL",
            "redaction_detail_text TEXT",
            "sealed_at_ms INTEGER NOT NULL",
            "ledger_self_hash_b64 TEXT NOT NULL",
        ]
        for column in columns {
            XCTAssertTrue(
                TombstoneSchema.allStatementsSQL.contains(column),
                "Missing column: \(column)")
        }
    }

    func testSecondaryIndexesPresent() {
        let indexes = [
            "CREATE INDEX IF NOT EXISTS tombstone_target_kind_idx",
            "CREATE INDEX IF NOT EXISTS tombstone_sealed_at_idx",
            "CREATE INDEX IF NOT EXISTS tombstone_ledger_idx",
        ]
        for idx in indexes {
            XCTAssertTrue(
                TombstoneSchema.allStatementsSQL.contains(idx),
                "Missing index: \(idx)")
        }
    }

    func testFTSTablePresent() {
        XCTAssertTrue(
            TombstoneSchema.allStatementsSQL.contains(
                "CREATE VIRTUAL TABLE IF NOT EXISTS tombstone_fts"))
        XCTAssertTrue(
            TombstoneSchema.allStatementsSQL.contains("USING fts5"))
    }

    func testLedgerChainColumnPresent() {
        // chapter 七百十二 第一刀 link — ledger_self_hash_b64
        // pins each tombstone to the audit chain so replay
        // verify can catch post-hoc injection。
        XCTAssertTrue(
            TombstoneSchema.allStatementsSQL.contains(
                "ledger_self_hash_b64 TEXT NOT NULL"),
            "ledger_self_hash_b64 NOT NULL — every tombstone" +
            " must link to the audit chain")
    }
}
