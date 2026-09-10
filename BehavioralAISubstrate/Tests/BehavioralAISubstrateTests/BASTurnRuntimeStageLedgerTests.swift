// MARK: - BASTurnRuntimeStageLedgerTests — chapter 四百八 / M1003

import Foundation
import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStageLedgerTests: XCTestCase {

    // MARK: - Init

    func testEmptyFactoryReturnsEmptyRecords() {
        let l = BASTurnRuntimeStageLedger.empty()
        XCTAssertTrue(l.records.isEmpty)
        XCTAssertEqual(l.stageCount, 0)
    }

    func testInitWithRecords() {
        let r = BASTurnRuntimeStageRecord.completed(
            .stageA, durationMs: 5)
        let l = BASTurnRuntimeStageLedger(records: [r])
        XCTAssertEqual(l.records.count, 1)
    }

    // MARK: - Immutable update

    func testAppendingRecordReturnsFreshLedger() {
        let original = BASTurnRuntimeStageLedger.empty()
        let updated = original.appending(
            record: .completed(.stageH, durationMs: 3))
        XCTAssertEqual(original.records.count, 0,
            "M1003:appending must NOT mutate original")
        XCTAssertEqual(updated.records.count, 1)
    }

    // MARK: - Aggregate accessors

    func testTotalDurationMsSums() {
        let l = BASTurnRuntimeStageLedger.empty()
            .appending(record:
                .completed(.stageA, durationMs: 5))
            .appending(record:
                .completed(.stageB, durationMs: 7))
            .appending(record:
                .completed(.stageC, durationMs: 3))
        XCTAssertEqual(l.totalDurationMs, 15)
    }

    func testCompletedStageCountFiltersByStatus() {
        let l = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(.stageA))
            .appending(record: .skipped(.stageB))
            .appending(record: .failed(.stageC))
            .appending(record: .completed(.stageD))
        XCTAssertEqual(l.completedStageCount, 2)
        XCTAssertEqual(l.skippedStageCount, 1)
        XCTAssertEqual(l.failedStageCount, 1)
    }

    func testHasAnyFailureTrueWhenFailedExists() {
        let l = BASTurnRuntimeStageLedger.empty()
            .appending(record: .failed(.stageH))
        XCTAssertTrue(l.hasAnyFailure)
    }

    func testHasAnyFailureFalseForAllCompleted() {
        let l = BASTurnRuntimeStageLedger.empty()
            .appending(record: .completed(.stageA))
            .appending(record: .completed(.stageB))
        XCTAssertFalse(l.hasAnyFailure)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let l = BASTurnRuntimeStageLedger.empty()
            .appending(record:
                .completed(.stageA, durationMs: 5))
            .appending(record: .skipped(.stageD2))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(l)
        let decoded = try JSONDecoder().decode(
            BASTurnRuntimeStageLedger.self, from: data)
        XCTAssertEqual(decoded, l)
    }

    // MARK: - Replay determinism

    func testTwoLedgersWithSameRecordsAreEqual() {
        let l1 = BASTurnRuntimeStageLedger.empty()
            .appending(record:
                .completed(.stageA, durationMs: 1))
        let l2 = BASTurnRuntimeStageLedger.empty()
            .appending(record:
                .completed(.stageA, durationMs: 1))
        XCTAssertEqual(l1, l2,
            "M1003:M892 byte-stable equality")
    }
}
