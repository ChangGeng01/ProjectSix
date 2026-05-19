// MARK: - BASBundleSchemaGeneratedTests
// chapter 七百十四 第二刀 / M2242 — verifies the BASSQLSchemaGen
// plugin emitted BundleSchema for 004_bundle.sql。

import XCTest
@testable import BASMemory

final class BASBundleSchemaGeneratedTests: XCTestCase {

    func testGeneratedEnumIsImportable() {
        XCTAssertFalse(
            BundleSchema.allStatementsSQL.isEmpty)
    }

    func testStatementCountIsSeven() {
        // 2 CREATE TABLE + 4 CREATE INDEX + 1 CREATE VIRTUAL
        // TABLE = 7 statements。
        XCTAssertEqual(BundleSchema.statementCount, 7)
    }

    func testAllStatementsSQLContainsBundleRecordsTable() {
        XCTAssertTrue(
            BundleSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS bundle_records"))
    }

    func testAllStatementsSQLContainsBundleAtomsTable() {
        XCTAssertTrue(
            BundleSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS bundle_atoms"))
    }

    func testBundleStateCheckConstraint() {
        XCTAssertTrue(
            BundleSchema.allStatementsSQL.contains(
                "CHECK (state IN ('open', 'sealed'))"),
            "state column must enforce the 2-value invariant")
    }

    func testBundleAtomsCompositePrimaryKey() {
        XCTAssertTrue(
            BundleSchema.allStatementsSQL.contains(
                "PRIMARY KEY (bundle_id, sequence_index)"),
            "bundle_atoms must enforce (bundle_id," +
            " sequence_index) composite PK for ordering")
    }

    func testAllSevenColumnsInBundleRecords() {
        let columns = [
            "bundle_id TEXT PRIMARY KEY NOT NULL",
            "episode_id TEXT NOT NULL",
            "kind TEXT NOT NULL",
            "sealed_at_ms INTEGER",
            "state TEXT NOT NULL",
            "summary_text TEXT",
            "canonical_hash_hex TEXT NOT NULL",
        ]
        for column in columns {
            XCTAssertTrue(
                BundleSchema.allStatementsSQL.contains(column),
                "bundle_records missing column: \(column)")
        }
    }

    func testBundleAtomsHasThreeColumns() {
        let columns = [
            "bundle_id TEXT NOT NULL",
            "atom_id TEXT NOT NULL",
            "sequence_index INTEGER NOT NULL",
        ]
        for column in columns {
            XCTAssertTrue(
                BundleSchema.allStatementsSQL.contains(column),
                "bundle_atoms missing column: \(column)")
        }
    }

    func testIndexesPresent() {
        let indexes = [
            "CREATE INDEX IF NOT EXISTS bundle_episode_idx",
            "CREATE INDEX IF NOT EXISTS bundle_kind_idx",
            "CREATE INDEX IF NOT EXISTS bundle_atoms_atom_idx",
            "CREATE INDEX IF NOT EXISTS bundle_atoms_bundle_idx",
        ]
        for idx in indexes {
            XCTAssertTrue(
                BundleSchema.allStatementsSQL.contains(idx),
                "Missing index: \(idx)")
        }
    }

    func testFTSTablePresent() {
        XCTAssertTrue(
            BundleSchema.allStatementsSQL.contains(
                "CREATE VIRTUAL TABLE IF NOT EXISTS bundle_fts"))
        XCTAssertTrue(
            BundleSchema.allStatementsSQL.contains("USING fts5"))
    }
}
