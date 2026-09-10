// MARK: - BASChapter741SovereignTokensSchemaGeneratedTests
// chapter 七百四十一 第三刀 / M2378
//
// LAYER-MIGRATION ARC — verifies the BASSQLSchemaGen plugin
// emitted SovereignTokensSchema for the net-new
// 009_sovereign_tokens.sql in Sources/BASSovereign/SQL/。
//
// Smoke gates:
//   - Schema enum reachable from tests
//   - statementCount == 5 (table + 4 indexes)
//   - All 13 columns present
//   - token_kind CHECK pinned to ('commit', 'warrant')
//   - Partial expires_at index uses WHERE revoked_at_ms IS NULL
//   - All CREATE statements idempotent (IF NOT EXISTS)

import XCTest
@testable import BASSovereign

final class BASChapter741SovereignTokensSchemaGeneratedTests:
    XCTestCase
{

    func testGeneratedEnumIsImportable() {
        XCTAssertFalse(
            SovereignTokensSchema.allStatementsSQL.isEmpty)
    }

    func testStatementCountIsFive() {
        XCTAssertEqual(
            SovereignTokensSchema.statementCount, 5)
    }

    func testTableCreate() {
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS sovereign_tokens"))
    }

    func testAllThirteenColumnsPresent() {
        let columns = [
            "token_id TEXT PRIMARY KEY NOT NULL",
            "token_kind TEXT NOT NULL",
            "session_id TEXT NOT NULL",
            "turn_id TEXT",
            "scope_raw TEXT NOT NULL",
            "action_digest_b64 TEXT NOT NULL",
            "snapshot_ref TEXT NOT NULL",
            "issued_at_ms INTEGER NOT NULL",
            "expires_at_ms INTEGER NOT NULL",
            "revoked_at_ms INTEGER",
            "policy_hash_hex TEXT NOT NULL",
            "allowed_targets_json TEXT",
            "signature_b64 TEXT NOT NULL"
        ]
        for column in columns {
            XCTAssertTrue(
                SovereignTokensSchema.allStatementsSQL
                    .contains(column),
                "Missing column: \(column)")
        }
    }

    func testTokenKindCheckConstraint() {
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL
                .contains("'commit'"),
            "token_kind CHECK must include 'commit'")
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL
                .contains("'warrant'"),
            "token_kind CHECK must include 'warrant'")
    }

    func testPartialExpiresIndex() {
        // Partial index for periodic expiry sweep:only
        // tracks live (non-revoked) tokens to minimize
        // scan size。
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL.contains(
                "sovereign_tokens_expires_idx"))
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL.contains(
                "WHERE revoked_at_ms IS NULL"))
    }

    func testRevokedAtAndKindIndexesPresent() {
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL.contains(
                "sovereign_tokens_revoked_at_idx"))
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL.contains(
                "sovereign_tokens_kind_idx"))
    }

    func testSessionIndexComposite() {
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL.contains(
                "sovereign_tokens_session_idx"))
        XCTAssertTrue(
            SovereignTokensSchema.allStatementsSQL.contains(
                "ON sovereign_tokens(session_id, issued_at_ms)"))
    }

    func testSchemaIsIdempotent() {
        let lines = SovereignTokensSchema.allStatementsSQL
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
