// MARK: - BASRuntimeAuditEmissionSummaryStageLedgerCompleteTests
// chapter 四百十七 / M1040

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryStageLedgerCompleteTests:
    XCTestCase
{

    // MARK: - Default field is false

    func testDefaultStageLedgerIsCompleteIsFalse() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative")
        XCTAssertFalse(s.stageLedgerIsComplete)
    }

    // MARK: - Init wires field

    func testInitWiresStageLedgerIsCompleteField() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            stageLedgerIsComplete: true)
        XCTAssertTrue(s.stageLedgerIsComplete)
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
            stageLedgerIsComplete: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditEmissionSummary.self,
            from: data)
        XCTAssertTrue(decoded.stageLedgerIsComplete)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - PayloadJson contains field

    func testPayloadJsonContainsStageLedgerIsComplete() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            stageLedgerIsComplete: true)
        let json = s.payloadJson() ?? ""
        XCTAssertTrue(
            json.contains(
                "\"stageLedgerIsComplete\":true"),
            "payloadJson must include " +
            "stageLedgerIsComplete")
    }
}
