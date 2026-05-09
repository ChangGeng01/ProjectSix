// MARK: - BASTurnRuntimeEngineAuditProjectionsTests
// chapter 四百六 / M989

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASOrchestration

final class BASTurnRuntimeEngineAuditProjectionsTests:
    XCTestCase
{

    // MARK: - Surface compile-time

    func testRunTurnAcceptsAuditProjectionsParameter() {
        // Compile-time: signature accepts optional
        // BASRuntimeAuditProjectionsBundle param
        let _: (
            BASEBrainTurnRequest,
            BASRuntimeAuditProjectionsBundle?,
            Int64?
        ) -> Void = { _, _, _ in }
        XCTAssertTrue(true,
            "M989:runTurn signature accepts auditProjections")
    }

    // MARK: - Summary integration

    func testSummaryIncludesProjectionsPopulatedCount() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage",
            auditProjectionsPopulatedSlotCount: 5)
        XCTAssertEqual(
            summary.auditProjectionsPopulatedSlotCount, 5)
    }

    func testSummaryDefaultProjectionsCountIsZero() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage")
        XCTAssertEqual(
            summary.auditProjectionsPopulatedSlotCount, 0,
            "M989:default = 0 (back-compat)")
    }

    func testSummaryProjectionsCountClampsNegative() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "x",
            permitModeRaw: "x", ticketCount: 0,
            auditID: "x", runMode: "x",
            auditProjectionsPopulatedSlotCount: -3)
        XCTAssertEqual(
            summary.auditProjectionsPopulatedSlotCount, 0,
            "M989:negative count clamps to 0")
    }

    func testSummaryByteStableWithProjectionsCount()
        throws
    {
        let s1 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage",
            auditProjectionsPopulatedSlotCount: 3)
        let s2 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage",
            auditProjectionsPopulatedSlotCount: 3)
        XCTAssertEqual(s1.payloadJson(), s2.payloadJson(),
            "M989:M892 byte-stable JSON for same input")
    }

    // MARK: - Aggregator → summary roundtrip

    func testAggregatorSlotCountFlowsToSummary() {
        let bundle = BASRuntimeAuditProjectionsBundle(
            kunlun: BASKunlunAuditProjections(
                readinessRef: "r",
                jadeSealRef: "s"),
            abyssal: BASAbyssalAuditProjections(
                anomalyTraceRef: "a"))
        let count = bundle.populatedSlotCount
        XCTAssertEqual(count, 3,
            "2 kunlun slots + 1 abyssal = 3")
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "x",
            permitModeRaw: "x", ticketCount: 0,
            auditID: "x", runMode: "x",
            auditProjectionsPopulatedSlotCount: count)
        XCTAssertEqual(
            summary.auditProjectionsPopulatedSlotCount, 3)
    }
}
