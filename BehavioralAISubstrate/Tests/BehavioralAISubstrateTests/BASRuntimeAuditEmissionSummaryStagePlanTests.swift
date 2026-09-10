// MARK: - BASRuntimeAuditEmissionSummaryStagePlanTests
// chapter 四百九 / M1008

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryStagePlanTests:
    XCTestCase
{

    // MARK: - Default fields = nil-safe defaults

    func testDefaultFieldsAreZero() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative")
        XCTAssertEqual(s.stagePlanStepCount, 0)
        XCTAssertFalse(s.stagePlanIsCanonical)
    }

    // MARK: - Init wires fields

    func testInitWiresStagePlanFields() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            stagePlanStepCount: 16,
            stagePlanIsCanonical: true)
        XCTAssertEqual(s.stagePlanStepCount, 16)
        XCTAssertTrue(s.stagePlanIsCanonical)
    }

    // MARK: - Negative step counts clamp to zero

    func testNegativeStepCountClamps() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            stagePlanStepCount: -5,
            stagePlanIsCanonical: false)
        XCTAssertEqual(s.stagePlanStepCount, 0)
    }

    // MARK: - Codable round-trip preserves fields

    func testCodableRoundTripPreservesStagePlanFields() throws {
        let original = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 1,
            auditID: "a",
            runMode: "deliberative",
            stagePlanStepCount: 16,
            stagePlanIsCanonical: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditEmissionSummary.self,
            from: data)
        XCTAssertEqual(decoded.stagePlanStepCount, 16)
        XCTAssertTrue(decoded.stagePlanIsCanonical)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - payloadJson contains plan fields

    func testPayloadJsonContainsStagePlanFields() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            stagePlanStepCount: 16,
            stagePlanIsCanonical: true)
        let json = s.payloadJson() ?? ""
        XCTAssertTrue(
            json.contains("\"stagePlanStepCount\":16"),
            "payloadJson must include stagePlanStepCount")
        XCTAssertTrue(
            json.contains("\"stagePlanIsCanonical\":true"),
            "payloadJson must include stagePlanIsCanonical")
    }

    // MARK: - Stable JSON ordering preserved

    func testPayloadJsonRemainsSortedKeys() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "t",
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: 0,
            auditID: "a",
            runMode: "deliberative",
            stagePlanStepCount: 16,
            stagePlanIsCanonical: true)
        let json = s.payloadJson() ?? ""
        // Sorted-key check: auditID < auditProjections... <
        // failedStageCount < permitEscalation... <
        // permitMode... < runMode < stageCount <
        // stagePlanIsCanonical < stagePlanStepCount <
        // ticketCount < totalStageDurationMs < traceID <
        // verdictLevel...
        let auditIDIdx = json.range(
            of: "\"auditID\"")?.lowerBound
        let stagePlanIdx = json.range(
            of: "\"stagePlanIsCanonical\"")?.lowerBound
        let traceIdx = json.range(
            of: "\"traceID\"")?.lowerBound
        guard let a = auditIDIdx,
              let p = stagePlanIdx,
              let t = traceIdx else {
            return XCTFail("Expected fields missing in JSON")
        }
        XCTAssertLessThan(a, p)
        XCTAssertLessThan(p, t)
    }
}
