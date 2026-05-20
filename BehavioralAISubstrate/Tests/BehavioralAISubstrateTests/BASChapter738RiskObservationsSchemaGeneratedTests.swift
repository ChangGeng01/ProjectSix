// MARK: - BASChapter738RiskObservationsSchemaGeneratedTests
// chapter 七百三十八 第一刀 / M2361
//
// LAYER-MIGRATION ARC opener — verifies the BASSQLSchemaGen
// plugin emitted RiskObservationsSchema for the net-new
// 006_risk_observations.sql in Sources/BASPolicy/SQL/。
//
// Schema-First pattern from chapter 七百十三 第三刀 + 七百十四
// 三-knife extended to L11 Wind Gate per the user directive
// 「Swift 仍然应该保留为 façade / Apple glue / public API。
//  真正应该移植的是每层里的 热路径、状态机、持久化、审计、
//  数学计算。」
//
// At this knife the schema lands UNCONDITIONALLY (no
// consumer wires it yet)。 Chapter 七百三十九 ports the L11
// state machine to Rust and wires the SQL persistence
// behind a `useRoutedRiskPlane: Bool = false` flag。
//
// Smoke gates:
//   - Schema enum reachable from tests
//   - statementCount == 4 (CREATE TABLE + 3 CREATE INDEX)
//   - All 11 columns present
//   - CHECK constraints pinned for risk_band + observation_kind
//   - Indexes on (session_id, observed_at_ms),risk_band,
//     observation_kind all present
//   - All 6 BASRiskSignalKind raw values appear in the
//     observation_kind CHECK clause
//   - All 4 risk band buckets appear in the risk_band CHECK

import XCTest
@testable import BASPolicy

final class BASChapter738RiskObservationsSchemaGeneratedTests:
    XCTestCase
{

    func testGeneratedEnumIsImportable() {
        XCTAssertFalse(
            RiskObservationsSchema.allStatementsSQL.isEmpty)
    }

    func testStatementCountIsFour() {
        // 1 CREATE TABLE + 3 CREATE INDEX = 4 statements。
        XCTAssertEqual(
            RiskObservationsSchema.statementCount, 4)
    }

    func testAllStatementsSQLContainsTable() {
        XCTAssertTrue(
            RiskObservationsSchema.allStatementsSQL.contains(
                "CREATE TABLE IF NOT EXISTS risk_observations"))
    }

    func testAllElevenColumnsPresent() {
        let columns = [
            "event_id TEXT PRIMARY KEY NOT NULL",
            "session_id TEXT NOT NULL",
            "turn_id TEXT NOT NULL",
            "intent_id TEXT NOT NULL",
            "observed_at_ms INTEGER NOT NULL",
            "risk_band TEXT NOT NULL",
            "risk_score REAL NOT NULL",
            "observation_kind TEXT NOT NULL",
            "salience REAL NOT NULL",
            "confidence REAL NOT NULL",
            "payload_json TEXT"
        ]
        for column in columns {
            XCTAssertTrue(
                RiskObservationsSchema.allStatementsSQL
                    .contains(column),
                "Missing column: \(column)")
        }
    }

    func testRiskBandCheckConstraintHasFourBuckets() {
        // The categorical bucket axis the gate aggregates
        // observations into。 Four buckets pinned in the
        // CHECK constraint。
        let buckets = ["'low'", "'medium'", "'high'", "'critical'"]
        for bucket in buckets {
            XCTAssertTrue(
                RiskObservationsSchema.allStatementsSQL
                    .contains(bucket),
                "risk_band CHECK must include bucket: \(bucket)")
        }
    }

    func testObservationKindCheckMatchesAllSixSignalKinds() {
        // The CHECK constraint on observation_kind MUST
        // match BASRiskSignalKind raw values verbatim。
        // chapter 一百八十五 anti-magic-number — single
        // source of truth pinned in the SQL file。
        for kind in BASRiskSignalKind.allCases {
            let needle = "'\(kind.rawValue)'"
            XCTAssertTrue(
                RiskObservationsSchema.allStatementsSQL
                    .contains(needle),
                "observation_kind CHECK must include "
                + "BASRiskSignalKind.\(kind.rawValue)")
        }
    }

    func testSessionTimeCompositeIndexPresent() {
        // The "all observations for session S in time range
        // [t1, t2]" query depends on this composite index
        // for sub-millisecond scans。
        XCTAssertTrue(
            RiskObservationsSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS risk_observations_session_time_idx"),
            "session_time composite index missing")
        XCTAssertTrue(
            RiskObservationsSchema.allStatementsSQL.contains(
                "ON risk_observations(session_id, observed_at_ms)"),
            "composite index must cover (session_id, observed_at_ms)")
    }

    func testRiskBandIndexPresent() {
        // The "how many high-band observations in last 24h?"
        // aggregation depends on this single-column index。
        XCTAssertTrue(
            RiskObservationsSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS risk_observations_band_idx"),
            "risk_band index missing")
    }

    func testObservationKindIndexPresent() {
        // The "all hazardReading observations" filter
        // depends on this index。 Filters by kind are the
        // primary L11 audit query。
        XCTAssertTrue(
            RiskObservationsSchema.allStatementsSQL.contains(
                "CREATE INDEX IF NOT EXISTS risk_observations_kind_idx"),
            "observation_kind index missing")
    }

    func testNoFTSTableInThisSchema() {
        // Risk observations are NOT full-text-searchable at
        // this knife。 The opaque payload_json content is
        // signal-kind-specific structured data,not narrative
        // text。 Future chapters MAY add FTS if a structured
        // query surface emerges。
        XCTAssertFalse(
            RiskObservationsSchema.allStatementsSQL.contains(
                "USING fts5"),
            "FTS5 not appropriate for structured risk "
            + "observations at this knife")
    }

    func testSchemaIsIdempotent() {
        // EVERY DDL statement must be IF NOT EXISTS so
        // boot-and-rebuild is a no-op on existing
        // databases。 不变量 #1/#2/#3 pin。
        let lines = RiskObservationsSchema.allStatementsSQL
            .split(separator: "\n")
            .map { String($0) }
        let createLines = lines.filter {
            $0.trimmingCharacters(in: .whitespaces)
                .hasPrefix("CREATE")
        }
        XCTAssertEqual(
            createLines.count, 4,
            "expected 4 CREATE statements (1 table + 3 idx)")
        for line in createLines {
            XCTAssertTrue(
                line.contains("IF NOT EXISTS"),
                "CREATE statement must be idempotent: \(line)")
        }
    }
}
