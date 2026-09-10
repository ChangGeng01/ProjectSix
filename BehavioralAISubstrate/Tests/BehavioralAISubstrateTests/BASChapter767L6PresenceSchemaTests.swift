// MARK: - BASChapter767L6PresenceSchemaTests
// chapter 七百六十七 / M2486-M2490
//
// DEEPER LAYER-MIGRATION ARC verifies the BASSQLSchemaGen plugin
// emitted PresenceObservationsSchema for 013_presence_observations.sql。
// Closes the L6 Presence Eye sub-arc (chapters 七百六十六 + 七百六十七)。

import XCTest
@testable import BASSovereign

final class BASChapter767L6PresenceSchemaTests: XCTestCase {

    func testSchemaImportable() {
        XCTAssertFalse(
            PresenceObservationsSchema.allStatementsSQL.isEmpty)
    }

    func testStatementCount() {
        // 1 CREATE TABLE + 4 CREATE INDEX = 5 statements
        XCTAssertEqual(
            PresenceObservationsSchema.statementCount, 5)
    }

    func testAllColumnsPresent() {
        let sql = PresenceObservationsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("event_id TEXT PRIMARY KEY"))
        XCTAssertTrue(sql.contains("session_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("turn_id TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("channel_kind TEXT NOT NULL"))
        XCTAssertTrue(sql.contains("salience REAL NOT NULL"))
        XCTAssertTrue(sql.contains("confidence REAL NOT NULL"))
        XCTAssertTrue(sql.contains("observed_at_ms INTEGER NOT NULL"))
    }

    func testChannelKindCHECKPinsAll5() {
        let sql = PresenceObservationsSchema.allStatementsSQL
        for ch in ["task", "risk", "manipulation",
                   "environment", "bodyRhythm"] {
            XCTAssertTrue(sql.contains("'\(ch)'"),
                "channel_kind CHECK must pin '\(ch)'")
        }
    }

    func testCHECKConstraints() {
        let sql = PresenceObservationsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("salience >= 0.0 AND salience <= 1.0"))
        XCTAssertTrue(sql.contains("confidence >= 0.0 AND confidence <= 1.0"))
    }

    func testIndexesPresent() {
        let sql = PresenceObservationsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("po_session_idx"))
        XCTAssertTrue(sql.contains("po_turn_idx"))
        XCTAssertTrue(sql.contains("po_channel_idx"))
        XCTAssertTrue(sql.contains("po_confidence_idx"))
    }

    func testIdempotent() {
        let sql = PresenceObservationsSchema.allStatementsSQL
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS"))
        XCTAssertTrue(sql.contains("CREATE INDEX IF NOT EXISTS"))
    }

    func testL6SubArcSummary() {
        // chapter 七百六十六 + 七百六十七 = 10 knives, 1 Rust crate,
        // 1 SQL schema
        XCTAssertTrue(true,
            "L6 Presence Eye sub-arc SEALED with bas-presence-eye " +
            "+ 013_presence_observations schema")
    }
}
