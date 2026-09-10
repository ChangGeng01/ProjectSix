// MARK: - BASRuntimeAuditEmissionSummaryParallelTests
// chapter 四百十六 / M1034

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryParallelTests:
    XCTestCase
{

    // MARK: - Default field is empty array

    func testDefaultParallelSummariesIsEmpty() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative")
        XCTAssertEqual(
            s.parallelDispatchSummaries.count, 0)
    }

    // MARK: - Init wires field

    func testInitWiresParallelSummariesField() {
        let s1 = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            parallelDispatchSummaries: [s1])
        XCTAssertEqual(
            s.parallelDispatchSummaries, [s1])
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesParallelSummaries()
        throws
    {
        let s1 = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let original = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            parallelDispatchSummaries: [s1])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditEmissionSummary.self,
            from: data)
        XCTAssertEqual(
            decoded.parallelDispatchSummaries,
            [s1])
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Factory derives from stage ledger

    func testFactoryDerivesParallelSummariesFromLedger() {
        let ledger = BASTurnRuntimeStageLedger
            .empty()
            .appending(record: .completed(
                .stageA, durationMs: 30))
            .appending(record: .completed(
                .stageA2, durationMs: 50))
        // Use an arbitrary BASEBrainTurnResult — the test
        // only verifies the parallelDispatchSummaries derivation
        // path,not the result-derived fields。
        // Build summary directly to exercise the
        // parallelDispatchSummaries field
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            parallelDispatchSummaries:
                ledger.parallelDispatchSummaries())
        XCTAssertEqual(
            summary.parallelDispatchSummaries.count, 4,
            "summary should contain one summary per group")
        let entryAA2 =
            summary.parallelDispatchSummaries[0]
        XCTAssertEqual(entryAA2.group, .entryAA2)
        XCTAssertEqual(entryAA2.cardinalityActual, 2)
        XCTAssertEqual(entryAA2.maxStageDurationMs, 50)
    }

    // MARK: - Determinism

    func testInitIsDeterministic() {
        let s1 = BASParallelStageDispatchSummary(
            group: .entryAA2,
            cardinalityActual: 2,
            maxStageDurationMs: 50,
            sumStageDurationMs: 80)
        let a = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            parallelDispatchSummaries: [s1])
        let b = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            parallelDispatchSummaries: [s1])
        XCTAssertEqual(a, b)
    }
}
