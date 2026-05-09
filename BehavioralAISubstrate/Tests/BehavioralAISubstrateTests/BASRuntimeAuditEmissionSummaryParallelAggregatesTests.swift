// MARK: - BASRuntimeAuditEmissionSummaryParallelAggregatesTests
// chapter 四百十六 / M1035

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryParallelAggregatesTests:
    XCTestCase
{

    private func makeSummary(
        _ summaries: [BASParallelStageDispatchSummary]
    ) -> BASRuntimeAuditEmissionSummary {
        BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            parallelDispatchSummaries: summaries)
    }

    // MARK: - Empty array → all aggregates zero

    func testEmptyArrayProducesZeroAggregates() {
        let s = makeSummary([])
        XCTAssertEqual(s.nonEmptyParallelGroupCount, 0)
        XCTAssertEqual(
            s.parallelDispatchTotalDurationMs, 0)
        XCTAssertEqual(
            s.parallelDispatchMaxDurationMs, 0)
    }

    // MARK: - Non-empty group counted

    func testNonEmptyGroupCounted() {
        let active = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let zero = BASParallelStageDispatchSummary
            .empty(group: .dD2)
        let s = makeSummary([active, zero])
        XCTAssertEqual(
            s.nonEmptyParallelGroupCount, 1,
            "only entryAA2 has cardinalityActual > 0")
    }

    // MARK: - Total duration sums

    func testTotalDurationSums() {
        let a = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let b = BASParallelStageDispatchSummary(
            group: .dD2,
            cardinalityActual: 2,
            maxStageDurationMs: 30,
            sumStageDurationMs: 40)
        let s = makeSummary([a, b])
        XCTAssertEqual(
            s.parallelDispatchTotalDurationMs, 120,
            "sum of 80 + 40 = 120")
    }

    // MARK: - Max picks dominant wall-clock contributor

    func testMaxPicksDominantWallClockContributor() {
        let a = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let b = BASParallelStageDispatchSummary(
            group: .o12Way,
            cardinalityActual: 1,
            maxStageDurationMs: 200,
            sumStageDurationMs: 200)
        let s = makeSummary([a, b])
        XCTAssertEqual(
            s.parallelDispatchMaxDurationMs, 200,
            "max picks the group dominating wall-clock")
    }

    // MARK: - Determinism

    func testAggregatesAreDeterministic() {
        let a = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let s = makeSummary([a])
        XCTAssertEqual(
            s.nonEmptyParallelGroupCount,
            s.nonEmptyParallelGroupCount)
        XCTAssertEqual(
            s.parallelDispatchTotalDurationMs,
            s.parallelDispatchTotalDurationMs)
    }
}
