// MARK: - BASChapter742VerdictDecisionsSchemaGeneratedTests
// chapter 七百四十二 第三刀 / M2383
//
// LAYER-MIGRATION ARC — verifies the BASSQLSchemaGen plugin
// emitted VerdictDecisionsSchema for 010_verdict_decisions.sql
// in Sources/BASSovereign/SQL/。
//
// Smoke gates:
//   - Schema enum reachable
//   - statementCount == 5
//   - 17 columns (decision_id + session_id + turn_id +
//     decided_at_ms + hard_bits + 7 softs + domain_raw +
//     evidence_sufficient + verdict_level + pinned_domain +
//     audit_entry_ref)
//   - domain_raw CHECK pins 6 operation domains
//   - verdict_level CHECK pins 8 verdict levels
//   - evidence_sufficient CHECK pinned to (0, 1)
//   - All indexes present + idempotent

import XCTest
@testable import BASSovereign

final class BASChapter742VerdictDecisionsSchemaGeneratedTests:
    XCTestCase
{

    func testGeneratedEnumIsImportable() {
        XCTAssertFalse(
            VerdictDecisionsSchema.allStatementsSQL.isEmpty)
    }

    func testStatementCountIsFive() {
        XCTAssertEqual(
            VerdictDecisionsSchema.statementCount, 5)
    }

    func testAllSeventeenColumnsPresent() {
        let columns = [
            "decision_id TEXT PRIMARY KEY NOT NULL",
            "session_id TEXT NOT NULL",
            "turn_id TEXT",
            "decided_at_ms INTEGER NOT NULL",
            "hard_bits INTEGER NOT NULL",
            "integrity_soft REAL NOT NULL",
            "privilege_violation_soft REAL NOT NULL",
            "self_mod_soft REAL NOT NULL",
            "memory_contamination_soft REAL NOT NULL",
            "irreversible_harm_soft REAL NOT NULL",
            "runtime_instability_soft REAL NOT NULL",
            "manipulation_intrusion_soft REAL NOT NULL",
            "domain_raw TEXT NOT NULL",
            "evidence_sufficient INTEGER NOT NULL",
            "verdict_level TEXT NOT NULL",
            "pinned_domain TEXT",
            "audit_entry_ref TEXT"
        ]
        for col in columns {
            XCTAssertTrue(
                VerdictDecisionsSchema.allStatementsSQL
                    .contains(col),
                "Missing column: \(col)")
        }
    }

    func testDomainRawCheckHasSixDomains() {
        let domains = ["pureInference", "toolRead",
                       "toolWrite", "hostMutate",
                       "memoryPromote", "rulePromotion"]
        for d in domains {
            XCTAssertTrue(
                VerdictDecisionsSchema.allStatementsSQL
                    .contains("'\(d)'"),
                "domain_raw CHECK must include \(d)")
        }
    }

    func testVerdictLevelCheckHasAllEightLevels() {
        let levels = ["pass", "throttle", "shadowLock",
                      "toolCut", "memoryFreeze",
                      "quarantine", "rollback", "deadStop"]
        for l in levels {
            XCTAssertTrue(
                VerdictDecisionsSchema.allStatementsSQL
                    .contains("'\(l)'"),
                "verdict_level CHECK must include \(l)")
        }
    }

    func testEvidenceSufficientIsBoolean() {
        XCTAssertTrue(
            VerdictDecisionsSchema.allStatementsSQL.contains(
                "CHECK (evidence_sufficient IN (0, 1))"))
    }

    func testAllIndexesPresent() {
        let indexes = ["vd_session_idx", "vd_level_idx",
                       "vd_domain_idx", "vd_evidence_idx"]
        for idx in indexes {
            XCTAssertTrue(
                VerdictDecisionsSchema.allStatementsSQL
                    .contains(idx),
                "Missing index: \(idx)")
        }
    }

    func testSchemaIsIdempotent() {
        let lines = VerdictDecisionsSchema.allStatementsSQL
            .split(separator: "\n")
            .map { String($0) }
        let creates = lines.filter {
            $0.trimmingCharacters(in: .whitespaces)
                .hasPrefix("CREATE")
        }
        XCTAssertEqual(creates.count, 5)
        for c in creates {
            XCTAssertTrue(c.contains("IF NOT EXISTS"))
        }
    }
}
