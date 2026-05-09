// MARK: - BASRuntimeAuditEmissionSummaryCoherenceBooleanTests
// chapter 四百十九 / M1047

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryCoherenceBooleanTests:
    XCTestCase
{

    private func make(
        _ count: Int
    ) -> BASRuntimeAuditEmissionSummary {
        BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            planLedgerCoherenceIssueCount: count)
    }

    // MARK: - Zero count → coherent

    func testZeroCountIsCoherent() {
        XCTAssertTrue(make(0).planLedgerIsCoherent)
    }

    // MARK: - Non-zero count → not coherent

    func testNonZeroCountIsNotCoherent() {
        XCTAssertFalse(make(1).planLedgerIsCoherent)
        XCTAssertFalse(make(5).planLedgerIsCoherent)
    }

    // MARK: - Negative input → coherent (clamps to 0)

    func testNegativeInputClampsTrueCoherent() {
        XCTAssertTrue(make(-3).planLedgerIsCoherent)
    }

    // MARK: - Determinism

    func testCoherenceBooleanIsDeterministic() {
        let s = make(2)
        XCTAssertEqual(
            s.planLedgerIsCoherent,
            s.planLedgerIsCoherent)
    }

    // MARK: - Default summary is coherent

    func testDefaultSummaryIsCoherent() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative")
        XCTAssertTrue(s.planLedgerIsCoherent)
    }
}
