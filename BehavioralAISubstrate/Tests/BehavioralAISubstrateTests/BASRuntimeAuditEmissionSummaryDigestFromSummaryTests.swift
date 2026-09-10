// MARK: - BASRuntimeAuditEmissionSummaryDigestFromSummaryTests
// chapter 四百二十 / M1051

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryDigestFromSummaryTests:
    XCTestCase
{

    private func makeSummary(
        traceID: String = "t",
        ticketCount: Int = 0
    ) -> BASRuntimeAuditEmissionSummary {
        BASRuntimeAuditEmissionSummary(
            traceID: traceID,
            verdictLevelRaw: "ok",
            permitModeRaw: "go",
            ticketCount: ticketCount,
            auditID: "a",
            runMode: "deliberative")
    }

    // MARK: - Algorithm raw name pinned

    func testAlgorithmRawNamePinned() {
        XCTAssertEqual(
            BASRuntimeAuditEmissionSummaryDigest
                .algorithmRawName,
            "json-sha256-sortedKeys-utf8")
    }

    // MARK: - Factory produces non-empty digest

    func testFactoryProducesNonEmptyDigest() {
        let date = Date(timeIntervalSince1970: 1000)
        let s = makeSummary()
        let d = BASRuntimeAuditEmissionSummaryDigest
            .from(summary: s, producedAt: date)
        XCTAssertFalse(d.digestString.isEmpty)
        XCTAssertEqual(
            d.algorithmName,
            BASRuntimeAuditEmissionSummaryDigest
                .algorithmRawName)
        XCTAssertEqual(d.producedAt, date)
    }

    // MARK: - SHA256 produces 64-char hex digest

    func testDigestIs64CharHex() {
        let date = Date(timeIntervalSince1970: 1000)
        let s = makeSummary()
        let d = BASRuntimeAuditEmissionSummaryDigest
            .from(summary: s, producedAt: date)
        XCTAssertEqual(d.digestString.count, 64,
            "SHA256 hex output is 64 chars")
    }

    // MARK: - Same summary → same digest

    func testSameSummaryProducesSameDigest() {
        let date = Date(timeIntervalSince1970: 1000)
        let s = makeSummary()
        let d1 = BASRuntimeAuditEmissionSummaryDigest
            .from(summary: s, producedAt: date)
        let d2 = BASRuntimeAuditEmissionSummaryDigest
            .from(summary: s, producedAt: date)
        XCTAssertEqual(d1.digestString, d2.digestString,
            "deterministic per chapter 三百九二")
    }

    // MARK: - Different summaries → different digests

    func testDifferentSummariesProduceDifferentDigests() {
        let date = Date(timeIntervalSince1970: 1000)
        let s1 = makeSummary(traceID: "trace-A")
        let s2 = makeSummary(traceID: "trace-B")
        let d1 = BASRuntimeAuditEmissionSummaryDigest
            .from(summary: s1, producedAt: date)
        let d2 = BASRuntimeAuditEmissionSummaryDigest
            .from(summary: s2, producedAt: date)
        XCTAssertNotEqual(
            d1.digestString, d2.digestString)
    }

    // MARK: - Same content + different producedAt → same digest content

    func testSameContentDifferentProducedAtSameDigest() {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let s = makeSummary()
        let d1 = BASRuntimeAuditEmissionSummaryDigest
            .from(summary: s, producedAt: date1)
        let d2 = BASRuntimeAuditEmissionSummaryDigest
            .from(summary: s, producedAt: date2)
        // digestString depends only on summary content
        XCTAssertEqual(
            d1.digestString, d2.digestString)
        // but producedAt differs
        XCTAssertNotEqual(d1, d2)
    }
}
