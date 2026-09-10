// MARK: - BASChapter775L13Phase2LedgersTests
// chapter 七百七十五 / M2526-M2530
//
// L13 PHASE 2 SQL persistence verification。 Confirms the
// BASSQLSchemaGen plugin emitted ShadowTrialRecords / EvolutionSeals /
// RetractionOrders enums + pins their statement counts + column shapes。

import XCTest
@testable import BASMemory

final class BASChapter775L13Phase2LedgersTests: XCTestCase {

    // MARK: - All 3 schema enums reachable

    func testShadowTrialRecordsSchemaImportable() {
        XCTAssertFalse(
            ShadowTrialRecordsSchema.allStatementsSQL.isEmpty)
    }

    func testEvolutionSealsSchemaImportable() {
        XCTAssertFalse(
            EvolutionSealsSchema.allStatementsSQL.isEmpty)
    }

    func testRetractionOrdersSchemaImportable() {
        XCTAssertFalse(
            RetractionOrdersSchema.allStatementsSQL.isEmpty)
    }

    // MARK: - Statement counts pinned

    func testShadowTrialRecordsStatementCount() {
        // 1 CREATE TABLE + 4 CREATE INDEX = 5
        XCTAssertEqual(ShadowTrialRecordsSchema.statementCount, 5)
    }

    func testEvolutionSealsStatementCount() {
        // 1 CREATE TABLE + 3 CREATE INDEX = 4
        XCTAssertEqual(EvolutionSealsSchema.statementCount, 4)
    }

    func testRetractionOrdersStatementCount() {
        // 1 CREATE TABLE + 3 CREATE INDEX = 4
        XCTAssertEqual(RetractionOrdersSchema.statementCount, 4)
    }

    // MARK: - shadow_trial_records column + CHECK pins

    func testShadowTrialRecordsColumns() {
        let sql = ShadowTrialRecordsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("audit_id TEXT PRIMARY KEY"))
        XCTAssertTrue(sql.contains("session_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("turn_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("verdict_ref TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("rule_ids_json TEXT"))
        XCTAssertTrue(sql.contains("signal_refs_json TEXT"))
        XCTAssertTrue(sql.contains("action_refs_json TEXT"))
        XCTAssertTrue(sql.contains("snapshot_ref TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("signature_payload TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("appended_at_ms INTEGER NOT NULL"))
        XCTAssertTrue(sql.contains("event_kind TEXT NOT NULL"))
    }

    func testShadowTrialRecordsEventKindCHECK() {
        let sql = ShadowTrialRecordsSchema.allStatementsSQL
        for kind in ["shadow_trial_started",
                     "shadow_trial_passed",
                     "shadow_trial_failed",
                     "shadow_trial_blocked",
                     "shadow_trial_cancelled"] {
            XCTAssertTrue(sql.contains("'\(kind)'"),
                "event_kind CHECK must pin '\(kind)'")
        }
    }

    // MARK: - evolution_seals column pins

    func testEvolutionSealsColumns() {
        let sql = EvolutionSealsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("seal_id TEXT PRIMARY KEY"))
        XCTAssertTrue(sql.contains("candidate_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("session_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("trial_ref TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("issued_at_ms INTEGER NOT NULL"))
        XCTAssertTrue(sql.contains("seal_signature TEXT NOT NULL"))
    }

    // MARK: - retraction_orders column + CHECK pins

    func testRetractionOrdersColumns() {
        let sql = RetractionOrdersSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("retraction_id TEXT PRIMARY KEY"))
        XCTAssertTrue(sql.contains("candidate_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("session_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("trial_ref TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("reason_kind TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("reason_text TEXT"))
        XCTAssertTrue(sql.contains("queued_at_ms INTEGER NOT NULL"))
    }

    func testRetractionOrdersReasonKindCHECK() {
        let sql = RetractionOrdersSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("'failed'"))
        XCTAssertTrue(sql.contains("'blocked'"))
    }

    // MARK: - All schemas idempotent

    func testAllSchemasIdempotent() {
        for sql in [ShadowTrialRecordsSchema.allStatementsSQL,
                    EvolutionSealsSchema.allStatementsSQL,
                    RetractionOrdersSchema.allStatementsSQL] {
            XCTAssertTrue(
                sql.contains("CREATE TABLE IF NOT EXISTS"),
                "Schema must be idempotent (CREATE TABLE IF NOT EXISTS)")
            XCTAssertTrue(
                sql.contains("CREATE INDEX IF NOT EXISTS"),
                "Schema indexes must be idempotent")
        }
    }

    // MARK: - L13 Phase 2 sub-arc cumulative scorecard

    func testL13Phase2SubArcCumulativeScorecard() {
        // Chapter 七百七十二 (Phase 1) + 七百七十四 (Phase 2 first
        // cut) + 七百七十五 (this chapter) = 3 chapters,15 knives
        struct CumulativeScorecard {
            let phase1Chapter: String       // 七百七十二
            let phase2ChaptersSoFar: [String] // 七百七十四 + 七百七十五
            let knivesSoFar: Int
            let rustCrate: String
            let sqlSchemasAdded: [String]
            let swiftBridge: String
        }
        let scorecard = CumulativeScorecard(
            phase1Chapter: "chapter 七百七十二",
            phase2ChaptersSoFar: [
                "chapter 七百七十四",  // Rust crate
                "chapter 七百七十五",  // SQL ledgers (this)
            ],
            knivesSoFar: 15,
            rustCrate: "bas-shadow-trial",
            sqlSchemasAdded: [
                "020_shadow_trial_records",
                "021_evolution_seals",
                "022_retraction_orders",
            ],
            swiftBridge: "BASShadowTrialBridge (via @_silgen_name)")
        XCTAssertEqual(scorecard.knivesSoFar, 15)
        XCTAssertEqual(scorecard.sqlSchemasAdded.count, 3)
        XCTAssertEqual(scorecard.phase2ChaptersSoFar.count, 2)
    }
}
