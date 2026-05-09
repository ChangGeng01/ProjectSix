// MARK: - BASTurnRuntimeStageLedgerParallelSummariesTests
// chapter 四百十五 / M1032

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStageLedgerParallelSummariesTests:
    XCTestCase
{

    // MARK: - Empty ledger produces 4 zero summaries

    func testEmptyLedgerProducesFourZeroSummaries() {
        let ledger = BASTurnRuntimeStageLedger.empty()
        let summaries = ledger.parallelDispatchSummaries()
        XCTAssertEqual(summaries.count, 4,
            "one summary per parallel group (4 cases)")
        for s in summaries {
            XCTAssertEqual(s.cardinalityActual, 0)
            XCTAssertEqual(s.maxStageDurationMs, 0)
            XCTAssertEqual(s.sumStageDurationMs, 0)
        }
    }

    // MARK: - Mixed records partition correctly

    func testMixedRecordsPartitionAcrossGroups() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
            .appending(record: .completed(
                .stageA2, durationMs: 20))
            .appending(record: .completed(
                .stageD, durationMs: 30))
            .appending(record: .completed(
                .stageM1, durationMs: 100))
            .appending(record: .completed(
                .stageO, durationMs: 200))
            .appending(record: .completed(
                .stageB, durationMs: 5))  // sequential
        let summaries = ledger.parallelDispatchSummaries()

        let entryAA2 = summaries[0]
        XCTAssertEqual(entryAA2.group, .entryAA2)
        XCTAssertEqual(entryAA2.cardinalityActual, 2)
        XCTAssertEqual(entryAA2.sumStageDurationMs, 30)

        let dD2 = summaries[1]
        XCTAssertEqual(dD2.group, .dD2)
        XCTAssertEqual(dD2.cardinalityActual, 1)
        XCTAssertEqual(dD2.sumStageDurationMs, 30)

        let m1 = summaries[2]
        XCTAssertEqual(m1.group, .m1FourWay)
        XCTAssertEqual(m1.cardinalityActual, 1)
        XCTAssertEqual(m1.maxStageDurationMs, 100)

        let o = summaries[3]
        XCTAssertEqual(o.group, .o12Way)
        XCTAssertEqual(o.cardinalityActual, 1)
        XCTAssertEqual(o.maxStageDurationMs, 200)
    }

    // MARK: - Order matches allCases

    func testSummaryOrderMatchesAllCases() {
        let ledger = BASTurnRuntimeStageLedger.empty()
        let summaries = ledger.parallelDispatchSummaries()
        let groups = summaries.map { $0.group }
        XCTAssertEqual(
            groups,
            BASTurnRuntimeStageParallelGroup.allCases)
    }

    // MARK: - Determinism

    func testParallelSummariesIsDeterministic() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageA, durationMs: 50))
            .appending(record: .completed(
                .stageA2, durationMs: 30))
        let s1 = ledger.parallelDispatchSummaries()
        let s2 = ledger.parallelDispatchSummaries()
        XCTAssertEqual(s1, s2)
    }
}
