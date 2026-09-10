// MARK: - BASParallelStageDispatchSummaryFromRecordsTests
// chapter 四百十五 / M1031

import XCTest
@testable import BASHostKit

final class BASParallelStageDispatchSummaryFromRecordsTests:
    XCTestCase
{

    // MARK: - Empty records produces zero summary

    func testEmptyRecordsProducesZeroSummary() {
        let s = BASParallelStageDispatchSummary.from(
            records: [], group: .entryAA2)
        XCTAssertEqual(s.cardinalityActual, 0)
        XCTAssertEqual(s.maxStageDurationMs, 0)
        XCTAssertEqual(s.sumStageDurationMs, 0)
    }

    // MARK: - Single matching record

    func testSingleMatchingRecord() {
        let r = BASTurnRuntimeStageRecord.completed(
            .stageA, durationMs: 50)
        let s = BASParallelStageDispatchSummary.from(
            records: [r], group: .entryAA2)
        XCTAssertEqual(s.cardinalityActual, 1)
        XCTAssertEqual(s.maxStageDurationMs, 50)
        XCTAssertEqual(s.sumStageDurationMs, 50)
    }

    // MARK: - Two matching records aggregate correctly

    func testTwoMatchingRecordsAggregateCorrectly() {
        let rA = BASTurnRuntimeStageRecord.completed(
            .stageA, durationMs: 30)
        let rA2 = BASTurnRuntimeStageRecord.completed(
            .stageA2, durationMs: 50)
        let s = BASParallelStageDispatchSummary.from(
            records: [rA, rA2], group: .entryAA2)
        XCTAssertEqual(s.cardinalityActual, 2)
        XCTAssertEqual(s.maxStageDurationMs, 50,
            "max should pick the slowest stage (50)")
        XCTAssertEqual(s.sumStageDurationMs, 80,
            "sum should be 30+50=80")
    }

    // MARK: - Records outside group are filtered out

    func testRecordsOutsideGroupAreFiltered() {
        let rA = BASTurnRuntimeStageRecord.completed(
            .stageA, durationMs: 30)
        let rB = BASTurnRuntimeStageRecord.completed(
            .stageB, durationMs: 1000)
        let s = BASParallelStageDispatchSummary.from(
            records: [rA, rB], group: .entryAA2)
        XCTAssertEqual(s.cardinalityActual, 1,
            "only stageA matches entryAA2 group")
        XCTAssertEqual(s.maxStageDurationMs, 30,
            "stageB excluded from max")
    }

    // MARK: - Internal-fan-out group (M1) summary

    func testM1FourWaySummaryReadsM1Stage() {
        let r = BASTurnRuntimeStageRecord.completed(
            .stageM1, durationMs: 200)
        let s = BASParallelStageDispatchSummary.from(
            records: [r], group: .m1FourWay)
        XCTAssertEqual(s.cardinalityActual, 1)
        XCTAssertEqual(s.maxStageDurationMs, 200)
    }

    // MARK: - Determinism

    func testFactoryIsDeterministic() {
        let rA = BASTurnRuntimeStageRecord.completed(
            .stageA, durationMs: 30)
        let rA2 = BASTurnRuntimeStageRecord.completed(
            .stageA2, durationMs: 50)
        let s1 = BASParallelStageDispatchSummary.from(
            records: [rA, rA2], group: .entryAA2)
        let s2 = BASParallelStageDispatchSummary.from(
            records: [rA, rA2], group: .entryAA2)
        XCTAssertEqual(s1, s2)
    }
}
