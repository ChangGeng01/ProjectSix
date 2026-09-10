// MARK: - BASRuntimeAuditEmissionSummaryTests — chapter 四百四 / M967

import Foundation
import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryTests: XCTestCase {

    // MARK: - Init shape

    func testInitPreservesFields() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "trace-1",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 3,
            auditID: "audit-1",
            runMode: "engage")
        XCTAssertEqual(s.traceID, "trace-1")
        XCTAssertEqual(s.verdictLevelRaw, "low")
        XCTAssertEqual(s.permitModeRaw, "answer")
        XCTAssertEqual(s.ticketCount, 3)
        XCTAssertEqual(s.auditID, "audit-1")
        XCTAssertEqual(s.runMode, "engage")
    }

    func testTicketCountClampsToZeroOnNegative() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "x",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: -5,
            auditID: "a",
            runMode: "engage")
        XCTAssertEqual(s.ticketCount, 0,
            "M967:negative ticket count clamps to 0")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "medium",
            permitModeRaw: "delay",
            ticketCount: 1,
            auditID: "a",
            runMode: "engage")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(s)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditEmissionSummary.self, from: data)
        XCTAssertEqual(decoded, s)
    }

    // MARK: - payloadJson() byte-stability

    func testPayloadJsonNotNilForValidStruct() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage")
        XCTAssertNotNil(s.payloadJson())
    }

    func testPayloadJsonByteStableForSameInput() {
        let s1 = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage")
        let s2 = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage")
        XCTAssertEqual(
            s1.payloadJson(), s2.payloadJson(),
            "M967:M892 byte-stable JSON for same input")
    }

    func testPayloadJsonHasSortedKeys() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 0,
            auditID: "a",
            runMode: "engage")
        let json = s.payloadJson() ?? ""
        // Sorted keys: auditID, permitModeRaw, runMode,
        // ticketCount, traceID, verdictLevelRaw
        // (alphabetical order)
        let firstKey = json.range(of: "\"")
        XCTAssertNotNil(firstKey)
        // Spot-check: 'auditID' should appear before 'verdictLevelRaw'
        if let auditIDPos = json.range(of: "auditID"),
           let verdictPos = json.range(of: "verdictLevelRaw") {
            XCTAssertLessThan(
                auditIDPos.lowerBound,
                verdictPos.lowerBound,
                "M967:sorted-keys encoding (auditID before verdict)")
        }
    }

    // MARK: - Equality

    func testTwoSummariesWithSameFieldsAreEqual() {
        let a = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage")
        let b = BASRuntimeAuditEmissionSummary(
            traceID: "t", verdictLevelRaw: "low",
            permitModeRaw: "answer", ticketCount: 0,
            auditID: "a", runMode: "engage")
        XCTAssertEqual(a, b)
    }
}
