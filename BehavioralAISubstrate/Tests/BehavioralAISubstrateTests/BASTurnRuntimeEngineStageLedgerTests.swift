// MARK: - BASTurnRuntimeEngineStageLedgerTests
// chapter 四百八 / M1004

import Foundation
import XCTest
@testable import BASHostKit

final class BASTurnRuntimeEngineStageLedgerTests:
    XCTestCase
{

    // MARK: - Summary integration

    func testSummaryAcceptsStageMetrics() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage",
            stageCount: 18,
            failedStageCount: 1,
            totalStageDurationMs: 250)
        XCTAssertEqual(summary.stageCount, 18)
        XCTAssertEqual(summary.failedStageCount, 1)
        XCTAssertEqual(summary.totalStageDurationMs, 250)
    }

    func testSummaryDefaultsZero() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage")
        XCTAssertEqual(summary.stageCount, 0)
        XCTAssertEqual(summary.failedStageCount, 0)
        XCTAssertEqual(summary.totalStageDurationMs, 0)
    }

    func testSummaryClampsNegatives() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "x",
            permitModeRaw: "x", ticketCount: 0,
            auditID: "x", runMode: "x",
            stageCount: -3,
            failedStageCount: -1,
            totalStageDurationMs: -100)
        XCTAssertEqual(summary.stageCount, 0)
        XCTAssertEqual(summary.failedStageCount, 0)
        XCTAssertEqual(summary.totalStageDurationMs, 0)
    }

    // MARK: - Ledger → summary roundtrip

    func testStageLedgerMetricsFlowToSummary() {
        let ledger = BASTurnRuntimeStageLedger.empty()
            .appending(record:
                .completed(.stageA, durationMs: 5))
            .appending(record:
                .completed(.stageB, durationMs: 10))
            .appending(record:
                .failed(.stageH, durationMs: 3))
        XCTAssertEqual(ledger.stageCount, 3)
        XCTAssertEqual(ledger.failedStageCount, 1)
        XCTAssertEqual(ledger.totalDurationMs, 18)

        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "x",
            permitModeRaw: "x", ticketCount: 0,
            auditID: "x", runMode: "x",
            stageCount: ledger.stageCount,
            failedStageCount: ledger.failedStageCount,
            totalStageDurationMs: ledger.totalDurationMs)
        XCTAssertEqual(summary.stageCount, 3)
        XCTAssertEqual(summary.failedStageCount, 1)
        XCTAssertEqual(summary.totalStageDurationMs, 18)
    }

    // MARK: - Replay determinism

    func testTwoSummariesWithSameStageMetricsAreEqual() {
        let s1 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage",
            stageCount: 5, failedStageCount: 0,
            totalStageDurationMs: 100)
        let s2 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage",
            stageCount: 5, failedStageCount: 0,
            totalStageDurationMs: 100)
        XCTAssertEqual(s1, s2)
        XCTAssertEqual(s1.payloadJson(), s2.payloadJson(),
            "M1004:M892 byte-stable JSON")
    }
}
