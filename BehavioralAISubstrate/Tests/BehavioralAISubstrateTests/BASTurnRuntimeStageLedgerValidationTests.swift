// MARK: - BASTurnRuntimeStageLedgerValidationTests — chapter 四百十七 / M1038

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStageLedgerValidationTests:
    XCTestCase
{

    // MARK: - Empty ledger is valid

    func testEmptyLedgerIsWellFormed() {
        let ledger = BASTurnRuntimeStageLedger.empty()
        XCTAssertTrue(ledger.isWellFormed)
        XCTAssertTrue(ledger.validate().isEmpty)
    }

    // MARK: - Distinct-stage records pass

    func testDistinctStageRecordsAreWellFormed() {
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
            .appending(record: .completed(
                .stageB, durationMs: 20))
        XCTAssertTrue(ledger.isWellFormed)
    }

    // MARK: - Duplicate stage flagged

    func testDuplicateStageFlagged() {
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
            .appending(record: .completed(
                .stageA, durationMs: 20))
        var found = false
        for issue in ledger.validate() {
            if case let .duplicateStageRecords(
                stages) = issue
            {
                XCTAssertTrue(stages.contains(.stageA))
                found = true
            }
        }
        XCTAssertTrue(found)
        XCTAssertFalse(ledger.isWellFormed)
    }

    // MARK: - Negative duration via Codable bypass

    func testNegativeDurationDetectedAfterDecode() throws {
        // Build a ledger with valid initialization (clamped
        // ≥ 0),then mutate the JSON to force a negative
        // durationMs and re-decode。
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
        var data = try JSONEncoder().encode(ledger)
        var json = String(data: data, encoding: .utf8) ?? ""
        json = json.replacingOccurrences(
            of: "\"durationMs\":10",
            with: "\"durationMs\":-5")
        data = json.data(using: .utf8) ?? Data()
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeStageLedger.self, from: data)
        // Decoded ledger now has a negative duration
        var found = false
        for issue in decoded.validate() {
            if case let .negativeDurationRecord(
                stage) = issue
            {
                XCTAssertEqual(stage, .stageA)
                found = true
            }
        }
        XCTAssertTrue(found)
    }

    // MARK: - Plan-count overflow flagged

    func testPlanCountOverflowFlagged() {
        var ledger = BASTurnRuntimeStageLedger.empty()
        for i in 0..<19 {
            // 19 > 18 canonical stage count;use stageA for
            // all to exercise overflow (also produces dup)
            _ = i
            ledger = ledger.appending(
                record: .completed(.stageA, durationMs: 1))
        }
        var foundOverflow = false
        for issue in ledger.validate() {
            if case let .recordsExceedingPlanCount(
                n) = issue
            {
                XCTAssertEqual(n, 19)
                foundOverflow = true
            }
        }
        XCTAssertTrue(foundOverflow)
    }

    // MARK: - Determinism

    func testValidationIsDeterministic() {
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
            .appending(record: .completed(
                .stageA, durationMs: 20))
        XCTAssertEqual(
            ledger.validate(), ledger.validate())
    }
}
