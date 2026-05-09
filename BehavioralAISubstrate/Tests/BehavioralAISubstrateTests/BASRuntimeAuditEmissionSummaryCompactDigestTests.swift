// MARK: - BASRuntimeAuditEmissionSummaryCompactDigestTests
// chapter 四百二十三 / M1064

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryCompactDigestTests:
    XCTestCase
{

    private func makeSummary() -> BASRuntimeAuditEmissionSummary {
        BASRuntimeAuditEmissionSummary(
            traceID: "trace-x",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 3,
            auditID: "audit-42",
            runMode: "deliberative",
            stageCount: 18,
            failedStageCount: 0,
            totalStageDurationMs: 320,
            parallelDispatchSummaries: [
                BASParallelStageDispatchSummary(
                    group: .entryAA2,
                    cardinalityActual: 2,
                    maxStageDurationMs: 50,
                    sumStageDurationMs: 80)
            ],
            planLedgerCoherenceIssueCount: 0)
    }

    // MARK: - Compact digest format

    func testCompactDigestContainsAllLoadBearingFields() {
        let s = makeSummary()
        let digest = s.compactDigest()
        XCTAssertTrue(
            digest.contains("trace=trace-x"))
        XCTAssertTrue(
            digest.contains("verdict=low"))
        XCTAssertTrue(
            digest.contains("permit=answer"))
        XCTAssertTrue(
            digest.contains("ticket=3"))
        XCTAssertTrue(
            digest.contains("audit=audit-42"))
        XCTAssertTrue(
            digest.contains("stages=18/0/320ms"))
        XCTAssertTrue(
            digest.contains("parallel=1grp/80ms"))
        XCTAssertTrue(
            digest.contains("coherent=true"))
    }

    // MARK: - One-line output (no newlines)

    func testCompactDigestIsOneLine() {
        let s = makeSummary()
        let digest = s.compactDigest()
        XCTAssertFalse(digest.contains("\n"))
        XCTAssertFalse(digest.contains("\r"))
    }

    // MARK: - Determinism

    func testCompactDigestIsDeterministic() {
        let s = makeSummary()
        XCTAssertEqual(
            s.compactDigest(), s.compactDigest())
    }

    // MARK: - Different summaries → different digests

    func testDifferentTraceIDProducesDifferentDigest() {
        let s1 = makeSummary()
        let s2 = BASRuntimeAuditEmissionSummary(
            traceID: "trace-y",
            verdictLevelRaw: "low",
            permitModeRaw: "answer",
            ticketCount: 3,
            auditID: "audit-42",
            runMode: "deliberative")
        XCTAssertNotEqual(
            s1.compactDigest(), s2.compactDigest())
    }

    // MARK: - Empty / default summary still produces digest

    func testEmptySummaryProducesNonEmptyDigest() {
        let s = BASRuntimeAuditEmissionSummary(
            traceID: "",
            verdictLevelRaw: "",
            permitModeRaw: "",
            ticketCount: 0,
            auditID: "",
            runMode: "")
        let digest = s.compactDigest()
        XCTAssertFalse(digest.isEmpty)
        XCTAssertTrue(digest.contains("trace="))
        XCTAssertTrue(digest.contains("ticket=0"))
        XCTAssertTrue(digest.contains("coherent=true"),
            "default summary has 0 coherence issues " +
            "→ planLedgerIsCoherent = true")
    }

    // MARK: - Compact digest stays under reasonable size

    func testCompactDigestUnderTwoHundredChars() {
        let s = makeSummary()
        XCTAssertLessThan(
            s.compactDigest().count, 200,
            "compact digest should fit in one log line")
    }
}
