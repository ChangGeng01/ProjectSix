// MARK: - BASTurnRuntimeStageLedgerCompletenessAggregatesTests
// chapter 四百十七 / M1039

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStageLedgerCompletenessAggregatesTests:
    XCTestCase
{

    // MARK: - Empty ledger

    func testEmptyLedgerIsNotComplete() {
        let ledger = BASTurnRuntimeStageLedger.empty()
        XCTAssertFalse(ledger.isComplete)
        XCTAssertEqual(
            ledger.missingStages.count,
            BASTurnRuntimeStage.allCases.count)
        XCTAssertEqual(ledger.averageStageDurationMs, 0)
    }

    // MARK: - Partial ledger

    func testPartialLedgerHasMissingStages() {
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
            .appending(record: .completed(
                .stageB, durationMs: 20))
        XCTAssertFalse(ledger.isComplete)
        XCTAssertFalse(
            ledger.missingStages.contains(.stageA))
        XCTAssertFalse(
            ledger.missingStages.contains(.stageB))
        XCTAssertTrue(
            ledger.missingStages.contains(.stageC))
    }

    // MARK: - Complete ledger

    func testCompleteLedgerIsComplete() {
        var ledger = BASTurnRuntimeStageLedger.empty()
        for stage in BASTurnRuntimeStage.allCases {
            ledger = ledger.appending(
                record: .completed(stage, durationMs: 10))
        }
        XCTAssertTrue(ledger.isComplete)
        XCTAssertTrue(ledger.missingStages.isEmpty)
    }

    // MARK: - Average duration

    func testAverageDurationCorrect() {
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
            .appending(record: .completed(
                .stageB, durationMs: 20))
            .appending(record: .completed(
                .stageC, durationMs: 30))
        // total 60 / 3 = 20
        XCTAssertEqual(
            ledger.averageStageDurationMs, 20)
    }

    func testAverageDurationZeroWhenEmpty() {
        let ledger = BASTurnRuntimeStageLedger.empty()
        XCTAssertEqual(
            ledger.averageStageDurationMs, 0)
    }

    // MARK: - missingStages preserves M1000 order

    func testMissingStagesPreservesAllCasesOrder() {
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(
                .stageB, durationMs: 10))
        let missing = ledger.missingStages
        // First missing should be stageA (preceded stageB
        // in allCases)
        XCTAssertEqual(missing.first, .stageA)
        // stageB should not appear
        XCTAssertFalse(missing.contains(.stageB))
    }

    // MARK: - Determinism

    func testAccessorsAreDeterministic() {
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
        XCTAssertEqual(
            ledger.isComplete, ledger.isComplete)
        XCTAssertEqual(
            ledger.missingStages, ledger.missingStages)
        XCTAssertEqual(
            ledger.averageStageDurationMs,
            ledger.averageStageDurationMs)
    }
}
