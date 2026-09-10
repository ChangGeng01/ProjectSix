// MARK: - BASRuntimeAuditEmissionSummaryFullPayloadIntegrationTests
// chapter 四百二十二 / M1059
//
// Cross-cutting integration test that exercises ALL 16 typed
// fields of `BASRuntimeAuditEmissionSummary` together
// (M967 + M989 + M996 + M1004 + M1008 + M1034 + M1040 + M1046)
// + verifies SHA256 digest stability across re-renders。
//
// Per-field unit tests (M1008 / M1034 / M1040 / M1046 etc.)
// already cover each field in isolation。 This integration
// test catches drift in the COMPOSED payload — eg. if a
// future field's encoding subtly broke sortedKeys ordering
// when combined with the other 15 fields。

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryFullPayloadIntegrationTests:
    XCTestCase
{

    private func makeFullyPopulatedSummary()
        -> BASRuntimeAuditEmissionSummary
    {
        let parallelSummary =
            BASParallelStageDispatchSummary(
                group: .entryAA2,
                cardinalityActual: 2,
                maxStageDurationMs: 50,
                sumStageDurationMs: 80)
        return BASRuntimeAuditEmissionSummary(
            traceID: "trace-deep-review",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 3,
            auditID: "audit-42",
            runMode: "deliberative",
            auditProjectionsPopulatedSlotCount: 5,
            permitEscalationFiredStageCount: 2,
            stageCount: 18,
            failedStageCount: 0,
            totalStageDurationMs: 320,
            stagePlanStepCount: 16,
            stagePlanIsCanonical: true,
            parallelDispatchSummaries: [parallelSummary],
            stageLedgerIsComplete: true,
            planLedgerCoherenceIssueCount: 0)
    }

    // MARK: - All 16 fields populated + accessor coverage

    func testAllSixteenFieldsPopulatedAndAccessorsAgree() {
        let s = makeFullyPopulatedSummary()
        // Required fields
        XCTAssertEqual(s.traceID, "trace-deep-review")
        XCTAssertEqual(s.verdictLevelRaw, "low")
        XCTAssertEqual(s.permitModeRaw, "answer")
        XCTAssertEqual(s.ticketCount, 3)
        XCTAssertEqual(s.auditID, "audit-42")
        XCTAssertEqual(s.runMode, "deliberative")
        // Phase 2 added fields
        XCTAssertEqual(
            s.auditProjectionsPopulatedSlotCount, 5)
        XCTAssertEqual(
            s.permitEscalationFiredStageCount, 2)
        XCTAssertEqual(s.stageCount, 18)
        XCTAssertEqual(s.failedStageCount, 0)
        XCTAssertEqual(s.totalStageDurationMs, 320)
        XCTAssertEqual(s.stagePlanStepCount, 16)
        XCTAssertTrue(s.stagePlanIsCanonical)
        XCTAssertEqual(
            s.parallelDispatchSummaries.count, 1)
        XCTAssertTrue(s.stageLedgerIsComplete)
        XCTAssertEqual(
            s.planLedgerCoherenceIssueCount, 0)
        // M1035 derived aggregate accessors agree with
        // the populated parallel summary
        XCTAssertEqual(s.nonEmptyParallelGroupCount, 1)
        XCTAssertEqual(
            s.parallelDispatchTotalDurationMs, 80)
        XCTAssertEqual(
            s.parallelDispatchMaxDurationMs, 50)
        // M1047 derived coherence Bool agrees with
        // the count
        XCTAssertTrue(s.planLedgerIsCoherent)
    }

    // MARK: - PayloadJson contains every field name

    func testPayloadJsonContainsEveryFieldName() {
        let s = makeFullyPopulatedSummary()
        let json = s.payloadJson() ?? ""
        XCTAssertFalse(json.isEmpty)
        // Every field name appears in the JSON output (with
        // quote prefix to avoid substring false positives)
        let expectedFieldNames = [
            "traceID", "verdictLevelRaw", "permitModeRaw",
            "ticketCount", "auditID", "runMode",
            "auditProjectionsPopulatedSlotCount",
            "permitEscalationFiredStageCount",
            "stageCount", "failedStageCount",
            "totalStageDurationMs",
            "stagePlanStepCount",
            "stagePlanIsCanonical",
            "parallelDispatchSummaries",
            "stageLedgerIsComplete",
            "planLedgerCoherenceIssueCount"
        ]
        for name in expectedFieldNames {
            XCTAssertTrue(
                json.contains("\"\(name)\""),
                "payloadJson missing field name " +
                "'\(name)':\n\(json)")
        }
        XCTAssertEqual(expectedFieldNames.count, 16,
            "16 typed fields total per chapter 三百八四 " +
            "audit-envelope schema doctrine")
    }

    // MARK: - SHA256 digest is byte-stable across rerenders

    func testSHA256DigestStableAcrossRerenders() {
        let s = makeFullyPopulatedSummary()
        let date = Date(timeIntervalSince1970: 1000)
        // Produce 5 digests over the same summary
        var digests: [String] = []
        for _ in 0..<5 {
            let d = BASRuntimeAuditEmissionSummaryDigest
                .from(summary: s, producedAt: date)
            digests.append(d.digestString)
        }
        // All 5 must equal the first
        let first = digests.first ?? ""
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first.count, 64,
            "SHA256 hex output is 64 chars")
        for d in digests {
            XCTAssertEqual(d, first,
                "SHA256 digest must be byte-stable across" +
                " rerenders (chapter 三百九二 anchor)")
        }
    }

    // MARK: - Codable round-trip preserves all 16 fields

    func testCodableRoundTripPreservesAllSixteenFields()
        throws
    {
        let original = makeFullyPopulatedSummary()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditEmissionSummary.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Sorted-key encoding holds

    func testSortedKeyEncodingHolds() {
        let s = makeFullyPopulatedSummary()
        let json = s.payloadJson() ?? ""
        // Sorted-key check: auditID < auditProjections...
        // < auditProjections... < failedStageCount <
        // nonEmpty... not present (derived) < parallel...
        // < permit... < permitMode... < planLedger... <
        // runMode < stage... < stagePlan... < ticketCount
        // < total... < trace... < verdict...
        let auditIDIdx = json.range(
            of: "\"auditID\"")?.lowerBound
        let traceIDIdx = json.range(
            of: "\"traceID\"")?.lowerBound
        let verdictIdx = json.range(
            of: "\"verdictLevelRaw\"")?.lowerBound
        guard let a = auditIDIdx,
              let t = traceIDIdx,
              let v = verdictIdx
        else {
            return XCTFail("Required fields missing")
        }
        XCTAssertLessThan(a, t,
            "'auditID' must precede 'traceID' in sorted" +
            "-key JSON")
        XCTAssertLessThan(t, v,
            "'traceID' must precede 'verdictLevelRaw' in" +
            " sorted-key JSON")
    }

    // MARK: - Empty summary still encodes valid JSON

    func testEmptySummaryEncodesValidJson() {
        let empty = BASRuntimeAuditEmissionSummary(
            traceID: "",
            verdictLevelRaw: "",
            permitModeRaw: "",
            ticketCount: 0,
            auditID: "",
            runMode: "")
        let json = empty.payloadJson()
        XCTAssertNotNil(json)
        XCTAssertTrue(json?.contains("\"traceID\":\"\"")
            ?? false)
    }

    // MARK: - Determinism across multiple summary instances

    func testIdenticalSummariesProduceIdenticalJson() {
        let a = makeFullyPopulatedSummary()
        let b = makeFullyPopulatedSummary()
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.payloadJson(), b.payloadJson())
    }
}
