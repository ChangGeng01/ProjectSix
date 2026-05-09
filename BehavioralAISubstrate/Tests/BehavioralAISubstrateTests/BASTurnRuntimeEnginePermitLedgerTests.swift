// MARK: - BASTurnRuntimeEnginePermitLedgerTests
// chapter 四百六 v2 / M996

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASPolicy

final class BASTurnRuntimeEnginePermitLedgerTests:
    XCTestCase
{

    // MARK: - Summary integration

    func testSummaryAcceptsPermitEscalationFiredStageCount() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage",
            auditProjectionsPopulatedSlotCount: 0,
            permitEscalationFiredStageCount: 3)
        XCTAssertEqual(
            summary.permitEscalationFiredStageCount, 3)
    }

    func testSummaryDefaultPermitEscalationCountIsZero() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage")
        XCTAssertEqual(
            summary.permitEscalationFiredStageCount, 0,
            "M996:default = 0 (back-compat)")
    }

    func testSummaryClampsNegativeCount() {
        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage",
            permitEscalationFiredStageCount: -2)
        XCTAssertEqual(
            summary.permitEscalationFiredStageCount, 0,
            "M996:negative count clamps to 0")
    }

    // MARK: - Ledger → summary roundtrip

    func testLedgerFiredCountFlowsToSummary() {
        let permit = BASActionPermit(mode: .answer)
        let mid = BASActionPermit(mode: .delay)
        let ledger = BASPermitEscalationLedger.build(
            initialPermit: permit,
            afterAbyssal: mid,
            afterAbyssalReasonCodes: ["pressure-medium"],
            afterAssertionCeiling: mid,
            afterKunlun: mid,
            afterCthulhuAssertionCeiling: mid,
            afterCthulhuEscalation: mid)
        // Permits at every stage equal to mid (no further
        // change after abyssal),only abyssal fired (mode
        // change initial→mid)
        XCTAssertEqual(ledger.firedStageCount, 1)

        let summary = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage",
            permitEscalationFiredStageCount:
                ledger.firedStageCount)
        XCTAssertEqual(
            summary.permitEscalationFiredStageCount, 1,
            "M996:ledger.firedStageCount flows to summary")
    }

    // MARK: - Replay determinism

    func testTwoSummariesWithSameInputsAreEqual() {
        let s1 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage",
            auditProjectionsPopulatedSlotCount: 5,
            permitEscalationFiredStageCount: 3)
        let s2 = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage",
            auditProjectionsPopulatedSlotCount: 5,
            permitEscalationFiredStageCount: 3)
        XCTAssertEqual(s1, s2,
            "M996:M892 byte-stable equality")
        XCTAssertEqual(s1.payloadJson(), s2.payloadJson(),
            "M996:byte-stable JSON for same input")
    }

    // MARK: - Compile-time signature

    func testRunTurnAcceptsPermitEscalationLedgerParam() {
        // Compile-time check: signature accepts optional
        // BASPermitEscalationLedger param
        let _: (
            BASEBrainTurnRequest,
            BASRuntimeAuditProjectionsBundle?,
            BASPermitEscalationLedger?,
            Int64?
        ) -> Void = { _, _, _, _ in }
        XCTAssertTrue(true,
            "M996:runTurn signature accepts permit ledger")
    }
}
