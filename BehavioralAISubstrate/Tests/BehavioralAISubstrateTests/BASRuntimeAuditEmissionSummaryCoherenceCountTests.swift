// MARK: - BASRuntimeAuditEmissionSummaryCoherenceCountTests
// chapter 四百十九 / M1046

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryCoherenceCountTests:
    XCTestCase
{

    // MARK: - Default field is zero

    func testDefaultPlanLedgerCoherenceIssueCountIsZero() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative")
        XCTAssertEqual(
            s.planLedgerCoherenceIssueCount, 0)
    }

    // MARK: - Init wires field

    func testInitWiresPlanLedgerCoherenceIssueCount() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            planLedgerCoherenceIssueCount: 3)
        XCTAssertEqual(
            s.planLedgerCoherenceIssueCount, 3)
    }

    // MARK: - Negative input clamps to zero

    func testNegativeInputClampsToZero() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            planLedgerCoherenceIssueCount: -5)
        XCTAssertEqual(
            s.planLedgerCoherenceIssueCount, 0)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesField() throws {
        let original = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            planLedgerCoherenceIssueCount: 2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditEmissionSummary.self,
            from: data)
        XCTAssertEqual(
            decoded.planLedgerCoherenceIssueCount, 2)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - PayloadJson contains field

    func testPayloadJsonContainsCoherenceIssueCount() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            planLedgerCoherenceIssueCount: 3)
        let json = s.payloadJson() ?? ""
        XCTAssertTrue(
            json.contains(
                "\"planLedgerCoherenceIssueCount\":3"),
            "payloadJson must include " +
            "planLedgerCoherenceIssueCount")
    }
}
