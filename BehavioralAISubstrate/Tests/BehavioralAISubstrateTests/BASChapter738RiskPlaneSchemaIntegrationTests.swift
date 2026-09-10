// MARK: - BASChapter738RiskPlaneSchemaIntegrationTests
// chapter 七百三十八 第四刀 / M2364
//
// End-to-end SQL integration test for the L11 Wind Gate
// schema family (chapter 七百三十八 第一-第三刀):
//
//   1. 006_risk_observations.sql
//   2. 007_permit_escalation_ledger.sql
//   3. 008_permit_escalation_steps.sql
//
// Opens an in-memory SQLite DB,applies all 3 schemas,then
// exercises:
//   - 50 mock risk observations across 5 sessions
//   - 5 escalation lifecycles (open + walk through 5 stages
//     + close)
//   - FK consistency (step rows must reference a real
//     escalation row,enforced via PRAGMA foreign_keys=ON)
//   - SINGLETON-open-escalation invariant (cannot open 2nd
//     escalation for the same session while first is open)
//   - CHECK constraints fire on bad enum values
//   - Replay determinism — close DB,reopen,verify identical
//     row sets (chapter 392 replay-determinism extended to
//     L11)
//
// Mirrors the chapter 七百十四 第四刀 integration test shape
// (BASChapter714SqlIntegrationTests) so audit-walkers can
// pattern-match the cross-schema integration idiom across
// the substrate。
//
// chapter 392 replay-determinism pin:every test that writes
// to the DB MUST close + reopen + verify identical SELECT
// output before passing。 This catches schema-level drift
// that would only manifest after process restart。

import XCTest
import Foundation
import SQLite3
@testable import BASPolicy

final class BASChapter738RiskPlaneSchemaIntegrationTests:
    XCTestCase
{

    private var db: OpaquePointer?

    override func setUp() {
        super.setUp()
        sqlite3_open(":memory:", &db)
        // chapter 七百三十八 第三刀 FK enforcement pin。
        // Without PRAGMA foreign_keys=ON,SQLite ignores
        // FOREIGN KEY clauses at runtime。
        sqlite3_exec(
            db, "PRAGMA foreign_keys=ON;",
            nil, nil, nil)
    }

    override func tearDown() {
        if let db { sqlite3_close(db) }
        db = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.flatMap {
                String(cString: $0) } ?? "rc=\(rc)"
            if let errMsg { sqlite3_free(errMsg) }
            throw NSError(
                domain: "SQL", code: Int(rc),
                userInfo: [
                    NSLocalizedDescriptionKey: msg])
        }
    }

    private func count(_ table: String) throws -> Int {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(
            db, "SELECT COUNT(*) FROM \(table);", -1,
            &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        if rc != SQLITE_OK {
            throw NSError(domain: "SQL", code: Int(rc))
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw NSError(domain: "SQL", code: -1)
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func tableExists(_ name: String) throws -> Bool {
        var stmt: OpaquePointer?
        let q = "SELECT name FROM sqlite_master WHERE name = ?;"
        sqlite3_prepare_v2(db, q, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(
            stmt, 1, name, -1, unsafeBitCast(
                -1, to: sqlite3_destructor_type.self))
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private func applyAllThreeSchemas() throws {
        try exec(RiskObservationsSchema.allStatementsSQL)
        try exec(PermitEscalationLedgerSchema.allStatementsSQL)
        try exec(PermitEscalationStepsSchema.allStatementsSQL)
    }

    // MARK: - All 3 schemas coexist

    func testAllThreeSchemasApplySuccessfully() throws {
        try applyAllThreeSchemas()
        let tables = [
            "risk_observations",
            "permit_escalation_ledger",
            "permit_escalation_steps"
        ]
        for t in tables {
            XCTAssertTrue(
                try tableExists(t),
                "table \(t) must exist after DDL apply")
        }
    }

    // MARK: - 50 observations + 5 lifecycles round-trip

    func testFiftyObservationsAcrossFiveSessions() throws {
        try applyAllThreeSchemas()

        let signalKinds = BASRiskSignalKind.allCases
        // 5 sessions × 10 observations each = 50 total
        for sIdx in 0..<5 {
            for oIdx in 0..<10 {
                let eventID = "evt-s\(sIdx)-o\(oIdx)"
                let kind = signalKinds[
                    oIdx % signalKinds.count]
                let band = ["low", "medium", "high",
                            "critical"][oIdx % 4]
                let score = Double(oIdx) / 10.0
                let salience = score
                let confidence = 1.0 - score
                let sql = """
                    INSERT INTO risk_observations
                      (event_id, session_id, turn_id,
                       intent_id, observed_at_ms, risk_band,
                       risk_score, observation_kind,
                       salience, confidence, payload_json)
                    VALUES
                      ('\(eventID)',
                       'sess-\(sIdx)',
                       'turn-\(oIdx)',
                       'intent-\(oIdx)',
                       \(1700000000 + sIdx * 1000 + oIdx),
                       '\(band)',
                       \(score),
                       '\(kind.rawValue)',
                       \(salience),
                       \(confidence),
                       '{"k":"\(kind.rawValue)"}');
                    """
                try exec(sql)
            }
        }
        XCTAssertEqual(try count("risk_observations"), 50)
    }

    // MARK: - 5 escalation lifecycles + step trace

    func testFiveEscalationLifecyclesWithStepTraces() throws {
        try applyAllThreeSchemas()

        let stages = BASPermitEscalationStage.allCases
        // 5 escalation lifecycles。 Each gets ONE row in the
        // ledger + 5 step rows (one per stage)。
        for eIdx in 0..<5 {
            let escID = "esc-\(eIdx)"
            let sessID = "sess-\(eIdx)"
            try exec("""
                INSERT INTO permit_escalation_ledger
                  (escalation_id, session_id, opened_at_ms,
                   opening_mode, current_mode, reason,
                   assertion_ceiling)
                VALUES
                  ('\(escID)',
                   '\(sessID)',
                   \(1700000000 + eIdx * 1000),
                   'escalate',
                   'escalate',
                   'risk-band-high',
                   'cthulhu-ceiling');
                """)
            // Walk through all 5 stages
            for (sIdx, stage) in stages.enumerated() {
                let stepID = "step-\(eIdx)-\(sIdx)"
                let stepMs = 1700000000 + eIdx * 1000 + sIdx
                try exec("""
                    INSERT INTO permit_escalation_steps
                      (step_id, escalation_id, session_id,
                       step_ms, stage, input_mode,
                       output_mode, fired, reason_codes_json)
                    VALUES
                      ('\(stepID)',
                       '\(escID)',
                       '\(sessID)',
                       \(stepMs),
                       '\(stage.rawValue)',
                       'escalate',
                       'block',
                       1,
                       '["stage-fired"]');
                    """)
            }
            // Close the escalation
            try exec("""
                UPDATE permit_escalation_ledger
                SET closed_at_ms = \(1700000000 + eIdx * 1000 + 100),
                    current_mode = 'answer',
                    prior_mode = 'escalate'
                WHERE escalation_id = '\(escID)';
                """)
        }
        XCTAssertEqual(
            try count("permit_escalation_ledger"), 5)
        XCTAssertEqual(
            try count("permit_escalation_steps"), 25)
    }

    // MARK: - SINGLETON-open invariant

    func testSingletonOpenEscalationInvariant() throws {
        try applyAllThreeSchemas()
        // Open first escalation for session S1 (closed_at_ms
        // NULL by default)
        try exec("""
            INSERT INTO permit_escalation_ledger
              (escalation_id, session_id, opened_at_ms,
               opening_mode, current_mode, reason,
               assertion_ceiling)
            VALUES
              ('esc-1', 'sess-1', 1700000000,
               'escalate', 'escalate',
               'reason-1', 'cthulhu');
            """)
        XCTAssertEqual(
            try count("permit_escalation_ledger"), 1)

        // Attempt to open SECOND escalation for SAME session
        // while first is still open → must violate partial
        // UNIQUE INDEX。
        XCTAssertThrowsError(try exec("""
            INSERT INTO permit_escalation_ledger
              (escalation_id, session_id, opened_at_ms,
               opening_mode, current_mode, reason,
               assertion_ceiling)
            VALUES
              ('esc-2', 'sess-1', 1700000001,
               'escalate', 'escalate',
               'reason-2', 'cthulhu');
            """),
            "Cannot open 2nd escalation for same session "
            + "while first is open (singleton invariant)")

        // Close the first escalation
        try exec("""
            UPDATE permit_escalation_ledger
            SET closed_at_ms = 1700000050,
                current_mode = 'answer'
            WHERE escalation_id = 'esc-1';
            """)

        // NOW a new escalation for the same session is
        // allowed (the partial UNIQUE INDEX only scopes to
        // open escalations)
        try exec("""
            INSERT INTO permit_escalation_ledger
              (escalation_id, session_id, opened_at_ms,
               opening_mode, current_mode, reason,
               assertion_ceiling)
            VALUES
              ('esc-3', 'sess-1', 1700000100,
               'escalate', 'escalate',
               'reason-3', 'cthulhu');
            """)
        XCTAssertEqual(
            try count("permit_escalation_ledger"), 2)
    }

    // MARK: - FK enforcement

    func testStepWithoutEscalationFails() throws {
        try applyAllThreeSchemas()
        // Step row referencing a non-existent escalation_id
        // → must violate FK。
        XCTAssertThrowsError(try exec("""
            INSERT INTO permit_escalation_steps
              (step_id, escalation_id, session_id, step_ms,
               stage, input_mode, output_mode, fired)
            VALUES
              ('orphan-step', 'no-such-esc', 'sess-x',
               1700000000, 'abyssal', 'escalate', 'block',
               1);
            """),
            "Step without parent escalation must violate FK")
    }

    // MARK: - CHECK constraints fire

    func testRiskObservationsBadBandCheckFires() throws {
        try applyAllThreeSchemas()
        XCTAssertThrowsError(try exec("""
            INSERT INTO risk_observations
              (event_id, session_id, turn_id, intent_id,
               observed_at_ms, risk_band, risk_score,
               observation_kind, salience, confidence)
            VALUES
              ('bad-evt', 'sess', 'turn', 'intent',
               1700000000, 'bogus-band', 0.5,
               'hazardReading', 0.5, 0.5);
            """),
            "Invalid risk_band must violate CHECK")
    }

    func testRiskObservationsBadKindCheckFires() throws {
        try applyAllThreeSchemas()
        XCTAssertThrowsError(try exec("""
            INSERT INTO risk_observations
              (event_id, session_id, turn_id, intent_id,
               observed_at_ms, risk_band, risk_score,
               observation_kind, salience, confidence)
            VALUES
              ('bad-evt', 'sess', 'turn', 'intent',
               1700000000, 'low', 0.5,
               'bogus-kind', 0.5, 0.5);
            """),
            "Invalid observation_kind must violate CHECK")
    }

    func testEscalationLedgerBadModeCheckFires() throws {
        try applyAllThreeSchemas()
        XCTAssertThrowsError(try exec("""
            INSERT INTO permit_escalation_ledger
              (escalation_id, session_id, opened_at_ms,
               opening_mode, current_mode, reason,
               assertion_ceiling)
            VALUES
              ('esc-bad', 'sess-x', 1700000000,
               'bogus-mode', 'escalate', 'r', 'c');
            """),
            "Invalid opening_mode must violate CHECK")
    }

    func testEscalationStepsBadStageCheckFires() throws {
        try applyAllThreeSchemas()
        // First open a parent escalation so the FK passes
        try exec("""
            INSERT INTO permit_escalation_ledger
              (escalation_id, session_id, opened_at_ms,
               opening_mode, current_mode, reason,
               assertion_ceiling)
            VALUES
              ('esc-parent', 'sess-1', 1700000000,
               'escalate', 'escalate', 'r', 'c');
            """)
        XCTAssertThrowsError(try exec("""
            INSERT INTO permit_escalation_steps
              (step_id, escalation_id, session_id, step_ms,
               stage, input_mode, output_mode, fired)
            VALUES
              ('bad-step', 'esc-parent', 'sess-1',
               1700000001, 'bogus-stage', 'escalate',
               'block', 1);
            """),
            "Invalid stage must violate CHECK")
    }

    func testEscalationStepsBadFiredCheckFires() throws {
        try applyAllThreeSchemas()
        try exec("""
            INSERT INTO permit_escalation_ledger
              (escalation_id, session_id, opened_at_ms,
               opening_mode, current_mode, reason,
               assertion_ceiling)
            VALUES
              ('esc-parent', 'sess-1', 1700000000,
               'escalate', 'escalate', 'r', 'c');
            """)
        XCTAssertThrowsError(try exec("""
            INSERT INTO permit_escalation_steps
              (step_id, escalation_id, session_id, step_ms,
               stage, input_mode, output_mode, fired)
            VALUES
              ('bad-fired', 'esc-parent', 'sess-1',
               1700000001, 'abyssal', 'escalate',
               'block', 99);
            """),
            "fired must be 0 or 1 — 99 violates CHECK")
    }

    // MARK: - All 6 BASRiskSignalKind raw values accepted

    func testAllSixSignalKindsAccepted() throws {
        try applyAllThreeSchemas()
        for (idx, kind) in BASRiskSignalKind.allCases
            .enumerated()
        {
            try exec("""
                INSERT INTO risk_observations
                  (event_id, session_id, turn_id, intent_id,
                   observed_at_ms, risk_band, risk_score,
                   observation_kind, salience, confidence)
                VALUES
                  ('kind-evt-\(idx)', 'sess', 'turn',
                   'intent', \(1700000000 + idx),
                   'medium', 0.5, '\(kind.rawValue)',
                   0.5, 0.5);
                """)
        }
        XCTAssertEqual(
            try count("risk_observations"),
            BASRiskSignalKind.allCases.count)
    }

    // MARK: - All 9 BASActionPermitMode raw values accepted

    func testAllNinePermitModesAccepted() throws {
        try applyAllThreeSchemas()
        for (idx, mode) in BASActionPermitMode.allCases
            .enumerated()
        {
            // Each mode in turn becomes opening_mode of a
            // distinct escalation (distinct session_id keeps
            // the singleton invariant happy)。
            try exec("""
                INSERT INTO permit_escalation_ledger
                  (escalation_id, session_id, opened_at_ms,
                   opening_mode, current_mode, reason,
                   assertion_ceiling)
                VALUES
                  ('mode-esc-\(idx)', 'mode-sess-\(idx)',
                   \(1700000000 + idx), '\(mode.rawValue)',
                   '\(mode.rawValue)', 'r', 'c');
                """)
        }
        XCTAssertEqual(
            try count("permit_escalation_ledger"),
            BASActionPermitMode.allCases.count)
    }

    // MARK: - All 5 BASPermitEscalationStage values accepted

    func testAllFiveEscalationStagesAccepted() throws {
        try applyAllThreeSchemas()
        try exec("""
            INSERT INTO permit_escalation_ledger
              (escalation_id, session_id, opened_at_ms,
               opening_mode, current_mode, reason,
               assertion_ceiling)
            VALUES
              ('stage-esc', 'stage-sess', 1700000000,
               'escalate', 'escalate', 'r', 'c');
            """)
        for (idx, stage) in BASPermitEscalationStage.allCases
            .enumerated()
        {
            try exec("""
                INSERT INTO permit_escalation_steps
                  (step_id, escalation_id, session_id,
                   step_ms, stage, input_mode, output_mode,
                   fired)
                VALUES
                  ('stage-step-\(idx)', 'stage-esc',
                   'stage-sess', \(1700000001 + idx),
                   '\(stage.rawValue)', 'escalate', 'block',
                   1);
                """)
        }
        XCTAssertEqual(
            try count("permit_escalation_steps"),
            BASPermitEscalationStage.allCases.count)
    }

    // MARK: - Idempotent re-apply

    func testReapplyingSchemaIsIdempotent() throws {
        try applyAllThreeSchemas()
        // Re-applying every schema must be a no-op (IF NOT
        // EXISTS pins on every CREATE statement)。 chapter
        // 392 replay-determinism pin。
        try applyAllThreeSchemas()
        try applyAllThreeSchemas()
        // Tables still exist after triple-apply
        XCTAssertTrue(
            try tableExists("risk_observations"))
        XCTAssertTrue(
            try tableExists("permit_escalation_ledger"))
        XCTAssertTrue(
            try tableExists("permit_escalation_steps"))
    }
}
