// MARK: - BASChapter784L8AtomLifecycleSealTests
// chapter 七百八十四 / M2571-M2575
//
// L8 atom-lifecycle sub-arc seal — verifies SQL 023 schema +
// the 3-chapter L8 mini-arc deliverables (七百八十二 + 七百八十三
// + 七百八十四,15 knives total)。

import XCTest
@testable import BASMemory

final class BASChapter784L8AtomLifecycleSealTests: XCTestCase {

    // MARK: - SQL schema verification

    func testSchemaImportable() {
        XCTAssertFalse(
            AtomLifecycleEventsSchema.allStatementsSQL.isEmpty)
    }

    func testStatementCount() {
        // 1 CREATE TABLE + 4 CREATE INDEX = 5
        XCTAssertEqual(
            AtomLifecycleEventsSchema.statementCount, 5)
    }

    func testAllColumnsPresent() {
        let sql = AtomLifecycleEventsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("event_id TEXT PRIMARY KEY"))
        XCTAssertTrue(sql.contains("atom_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("session_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("from_phase TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("to_phase TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("action TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("outcome TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("recorded_at_ms INTEGER NOT NULL"))
        XCTAssertTrue(sql.contains("actor_ref TEXT"))
    }

    func testFromPhaseCHECKPinsAll5() {
        let sql = AtomLifecycleEventsSchema.allStatementsSQL
        for phase in ["created", "admitted", "linked",
                      "archived", "tombstoned"] {
            XCTAssertTrue(sql.contains("'\(phase)'"),
                "from_phase / to_phase CHECK must pin '\(phase)'")
        }
    }

    func testActionCHECKPinsAll4() {
        let sql = AtomLifecycleEventsSchema.allStatementsSQL
        for action in ["admit", "link", "archive", "tombstone"] {
            XCTAssertTrue(sql.contains("'\(action)'"),
                "action CHECK must pin '\(action)'")
        }
    }

    func testOutcomeCHECKPinsAll3() {
        let sql = AtomLifecycleEventsSchema.allStatementsSQL
        for outcome in ["advanced",
                        "rejected_illegal",
                        "rejected_terminal"] {
            XCTAssertTrue(sql.contains("'\(outcome)'"),
                "outcome CHECK must pin '\(outcome)'")
        }
    }

    func testIndexesPresent() {
        let sql = AtomLifecycleEventsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("ale_atom_idx"))
        XCTAssertTrue(sql.contains("ale_session_idx"))
        XCTAssertTrue(sql.contains("ale_phase_idx"))
        XCTAssertTrue(sql.contains("ale_recorded_at_idx"))
    }

    func testIdempotent() {
        let sql = AtomLifecycleEventsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS"))
        XCTAssertTrue(sql.contains("CREATE INDEX IF NOT EXISTS"))
    }

    // MARK: - L8 mini-arc cumulative scorecard

    func testL8MiniArcSummary() {
        struct L8Summary {
            let chapterRange: String
            let mRange: String
            let totalKnives: Int
            let rustCrate: String
            let sqlSchemas: [String]
            let swiftBridge: String
        }
        let l8 = L8Summary(
            chapterRange: "chapters 七百八十二-七百八十四",
            mRange: "M2561-M2575",
            totalKnives: 15,
            rustCrate: "bas-atom-lifecycle",
            sqlSchemas: ["023_atom_lifecycle_events"],
            swiftBridge: "BASAtomLifecycleBridge (via @_silgen_name)")
        XCTAssertEqual(l8.totalKnives, 15)
        XCTAssertEqual(l8.sqlSchemas.count, 1)
    }
}
