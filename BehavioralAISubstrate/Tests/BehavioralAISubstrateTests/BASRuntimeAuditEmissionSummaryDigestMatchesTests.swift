// MARK: - BASRuntimeAuditEmissionSummaryDigestMatchesTests
// chapter 四百二十 / M1052

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryDigestMatchesTests:
    XCTestCase
{

    // MARK: - Identical digests match

    func testIdenticalDigestsMatch() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "abc",
            producedAt: date)
        let b = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "abc",
            producedAt: date)
        XCTAssertTrue(a.matches(b))
    }

    // MARK: - Same content + different timestamps match

    func testSameContentDifferentTimestampsMatch() {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let a = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "abc",
            producedAt: date1)
        let b = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "abc",
            producedAt: date2)
        XCTAssertTrue(a.matches(b),
            "matches() ignores producedAt by design")
        XCTAssertNotEqual(a, b,
            "Equatable still discriminates timestamps")
    }

    // MARK: - Different algorithm doesn't match

    func testDifferentAlgorithmDoesNotMatch() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo-1", digestString: "abc",
            producedAt: date)
        let b = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo-2", digestString: "abc",
            producedAt: date)
        XCTAssertFalse(a.matches(b))
    }

    // MARK: - Different digest doesn't match

    func testDifferentDigestStringDoesNotMatch() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "abc",
            producedAt: date)
        let b = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "def",
            producedAt: date)
        XCTAssertFalse(a.matches(b))
    }

    // MARK: - Determinism

    func testMatchesIsDeterministic() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "abc",
            producedAt: date)
        let b = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "abc",
            producedAt: date)
        XCTAssertEqual(a.matches(b), a.matches(b))
    }

    // MARK: - Reflexive

    func testMatchesIsReflexive() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo", digestString: "abc",
            producedAt: date)
        XCTAssertTrue(a.matches(a))
    }
}
