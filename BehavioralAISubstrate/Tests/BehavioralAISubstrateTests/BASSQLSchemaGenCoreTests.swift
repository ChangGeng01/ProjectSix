// MARK: - BASSQLSchemaGenCoreTests
// chapter 七百二 / M2171 第一刀 — anti-drift PROOF tests
//                                  for the SQL codegen
//                                  pure function。
//
// Tests live in BehavioralAISubstrateTests (single test
// target,established in chapter 二百十一 single-source-
// of-truth pattern)。 They import BASSQLSchemaGenCore
// directly,bypassing the executable tool so no process
// spawn is required for validation。
//
// ## Coverage matrix (12 tests)
//
//   1. Empty SQL → 0 statements,fallback "Schema" enum
//   2. Single CREATE TABLE → 1 statement
//   3. Three statements → 3 statements (real-world case
//      mirroring BASMemoryUsageTracker schema)
//   4. Line comments (`--`) DO NOT count as statements
//   5. Block comments (`/* */`) DO NOT count as statements
//   6. Generated header carries the GENERATED prefix
//   7. Source filename appears in the generated header
//   8. allStatementsSQL preserves input verbatim
//   9. Deterministic — two invocations byte-equal
//  10. schemaName strips leading `<digits>_` prefix
//  11. schemaName CamelCases `_`-separated parts
//  12. schemaName falls back to "Schema" for empty input

import XCTest
@testable import BASSQLSchemaGenCore

final class BASSQLSchemaGenCoreTests: XCTestCase {

    // MARK: - Helper:standard 3-statement SQL fixture
    //
    // Mirrors the production schema that chapter 七百二
    // 第二刀 (M2172) extracts from BASMemoryUsageTracker
    // .swift:321-341。 Test fixture stays here so the
    // codegen tests are decoupled from the file extraction
    // step (which lands at M2172,not M2171)。
    private let threeStatementSQL: String = """
        CREATE TABLE IF NOT EXISTS memory_usage_records (
            record_id TEXT PRIMARY KEY NOT NULL,
            atom_id TEXT NOT NULL,
            retrieved_at_ms INTEGER NOT NULL,
            session_ref TEXT NOT NULL,
            turn_ref TEXT NOT NULL,
            permit_mode TEXT NOT NULL,
            helped_state TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS memory_usage_atom_idx
          ON memory_usage_records(atom_id);
        CREATE INDEX IF NOT EXISTS memory_usage_session_idx
          ON memory_usage_records(session_ref);
        """

    // MARK: - Statement counting

    func testEmptyInputCountsZeroStatements() {
        XCTAssertEqual(
            BASSQLSchemaGenCore.countStatements(in: ""),
            0)
    }

    func testSingleCreateTableCountsOne() {
        let sql = "CREATE TABLE t (x INTEGER);"
        XCTAssertEqual(
            BASSQLSchemaGenCore.countStatements(in: sql),
            1)
    }

    func testThreeStatementFixtureCountsThree() {
        XCTAssertEqual(
            BASSQLSchemaGenCore.countStatements(
                in: threeStatementSQL),
            3,
            "Real-world memory_usage_records fixture has" +
            " 3 `;`-terminated statements (1 CREATE TABLE" +
            " + 2 CREATE INDEX)。")
    }

    func testLineCommentsAreNotCountedAsStatements() {
        let sql = """
            -- this comment has a ; inside but should not count
            -- ; ; ;
            CREATE TABLE t (x INTEGER);
            """
        XCTAssertEqual(
            BASSQLSchemaGenCore.countStatements(in: sql),
            1)
    }

    func testBlockCommentsAreNotCountedAsStatements() {
        let sql = """
            /* multi-line comment
               with ; and ; inside */
            CREATE TABLE t (x INTEGER);
            /* another ; comment */
            CREATE INDEX i ON t(x);
            """
        XCTAssertEqual(
            BASSQLSchemaGenCore.countStatements(in: sql),
            2)
    }

    // MARK: - Generated header

    func testGeneratedHeaderCarriesGeneratedPrefix() {
        let output = BASSQLSchemaGenCore.generateSwift(
            from: "CREATE TABLE t (x INTEGER);",
            schemaName: "T",
            sourceFileName: "t.sql")
        XCTAssertTrue(
            output.hasPrefix(
                BASSQLSchemaGenCore.generatedHeaderPrefix),
            "Output must start with the GENERATED — do not edit" +
            " sentinel so a regression that drops the warning" +
            " header is caught immediately。")
    }

    func testSourceFilenameAppearsInGeneratedHeader() {
        let output = BASSQLSchemaGenCore.generateSwift(
            from: "CREATE TABLE t (x INTEGER);",
            schemaName: "T",
            sourceFileName: "001_memory_usage_records.sql")
        XCTAssertTrue(
            output.contains("Source:001_memory_usage_records.sql"),
            "Source filename must appear in the header so a" +
            " reader can trace generated → input。")
    }

    // MARK: - allStatementsSQL verbatim preservation

    func testAllStatementsSQLPreservesInputVerbatim() {
        let output = BASSQLSchemaGenCore.generateSwift(
            from: threeStatementSQL,
            schemaName: "MemoryUsageRecords",
            sourceFileName: "001_memory_usage_records.sql")
        // Every line of input must appear in the output
        // (with the standard 4-space triple-quoted indent)。
        let inputLines = threeStatementSQL
            .split(separator: "\n", omittingEmptySubsequences: false)
        for line in inputLines {
            let indented = "    \(line)"
            XCTAssertTrue(
                output.contains(indented),
                "Generated output missing input line:" +
                " '\(line)'")
        }
    }

    // MARK: - Determinism (byte-equality invariant)

    func testTwoInvocationsProduceByteEqualOutput() {
        let a = BASSQLSchemaGenCore.generateSwift(
            from: threeStatementSQL,
            schemaName: "MemoryUsageRecords",
            sourceFileName: "001_memory_usage_records.sql")
        let b = BASSQLSchemaGenCore.generateSwift(
            from: threeStatementSQL,
            schemaName: "MemoryUsageRecords",
            sourceFileName: "001_memory_usage_records.sql")
        XCTAssertEqual(a, b,
            "Pure function — identical inputs must yield" +
            " identical output bytes。 Critical for the V1" +
            " byte-equality invariant (752 clean commits" +
            " at chapter 七百一 close-out)。")
    }

    // MARK: - schemaName derivation

    func testSchemaNameStripsLeadingDigitUnderscorePrefix() {
        XCTAssertEqual(
            BASSQLSchemaGenCore.schemaName(
                fromBaseName: "001_memory_usage_records"),
            "MemoryUsageRecords")
        XCTAssertEqual(
            BASSQLSchemaGenCore.schemaName(
                fromBaseName: "42_atom_store"),
            "AtomStore")
    }

    func testSchemaNameCamelCasesUnderscoreSeparatedParts() {
        XCTAssertEqual(
            BASSQLSchemaGenCore.schemaName(
                fromBaseName: "policy_catalog"),
            "PolicyCatalog")
        XCTAssertEqual(
            BASSQLSchemaGenCore.schemaName(
                fromBaseName: "memory_usage_records"),
            "MemoryUsageRecords")
    }

    func testSchemaNameEmptyInputFallsBackToSchemaSentinel() {
        XCTAssertEqual(
            BASSQLSchemaGenCore.schemaName(fromBaseName: ""),
            "Schema",
            "Empty basename must produce a non-empty fallback" +
            " so the generated enum is always parseable。")
    }

    // MARK: - Contract version pin

    func testCodegenContractVersionIsOne() {
        XCTAssertEqual(
            BASSQLSchemaGenCore.codegenContractVersion,
            1,
            "Bumping this signals a generated-file format" +
            " change that consumers (and byte-equality" +
            " tests) must re-validate。")
    }
}
