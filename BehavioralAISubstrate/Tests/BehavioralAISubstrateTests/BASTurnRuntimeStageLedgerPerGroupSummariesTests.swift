// MARK: - BASTurnRuntimeStageLedgerPerGroupSummariesTests
// chapter 四百十六 / M1036

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStageLedgerPerGroupSummariesTests:
    XCTestCase
{

    // MARK: - Per-group accessors

    func testEntryAA2DispatchSummaryAccessor() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
            .appending(record: .completed(
                .stageA2, durationMs: 20))
        let s = ledger.entryAA2DispatchSummary
        XCTAssertEqual(s.group, .entryAA2)
        XCTAssertEqual(s.cardinalityActual, 2)
        XCTAssertEqual(s.maxStageDurationMs, 20)
        XCTAssertEqual(s.sumStageDurationMs, 30)
    }

    func testDD2DispatchSummaryAccessor() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageD, durationMs: 100))
        let s = ledger.dD2DispatchSummary
        XCTAssertEqual(s.group, .dD2)
        XCTAssertEqual(s.cardinalityActual, 1)
    }

    func testM1FourWayDispatchSummaryAccessor() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageM1, durationMs: 200))
        let s = ledger.m1FourWayDispatchSummary
        XCTAssertEqual(s.group, .m1FourWay)
        XCTAssertEqual(s.maxStageDurationMs, 200)
    }

    func testO12WayDispatchSummaryAccessor() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageO, durationMs: 300))
        let s = ledger.o12WayDispatchSummary
        XCTAssertEqual(s.group, .o12Way)
        XCTAssertEqual(s.maxStageDurationMs, 300)
    }

    // MARK: - Empty ledger produces all-zero accessors

    func testEmptyLedgerAccessorsAreZero() {
        let ledger = BASTurnRuntimeStageLedger.empty()
        XCTAssertEqual(
            ledger.entryAA2DispatchSummary
                .cardinalityActual, 0)
        XCTAssertEqual(
            ledger.dD2DispatchSummary
                .cardinalityActual, 0)
        XCTAssertEqual(
            ledger.m1FourWayDispatchSummary
                .cardinalityActual, 0)
        XCTAssertEqual(
            ledger.o12WayDispatchSummary
                .cardinalityActual, 0)
    }

    // MARK: - Cross-check against M1032 array order

    func testAccessorsMatchM1032ArrayPositions() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
            .appending(record: .completed(
                .stageD, durationMs: 30))
            .appending(record: .completed(
                .stageM1, durationMs: 100))
            .appending(record: .completed(
                .stageO, durationMs: 200))
        let array = ledger.parallelDispatchSummaries()
        XCTAssertEqual(
            ledger.entryAA2DispatchSummary, array[0])
        XCTAssertEqual(
            ledger.dD2DispatchSummary, array[1])
        XCTAssertEqual(
            ledger.m1FourWayDispatchSummary, array[2])
        XCTAssertEqual(
            ledger.o12WayDispatchSummary, array[3])
    }

    // MARK: - Determinism

    func testAccessorsAreDeterministic() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageA, durationMs: 10))
        XCTAssertEqual(
            ledger.entryAA2DispatchSummary,
            ledger.entryAA2DispatchSummary)
    }
}
