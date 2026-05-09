// MARK: - BASRuntimeAuditEmissionSummaryDigestTests — chapter 四百二十 / M1050

import XCTest
@testable import BASHostKit

final class BASRuntimeAuditEmissionSummaryDigestTests:
    XCTestCase
{

    // MARK: - Init wires fields

    func testInitWiresAllFields() {
        let date = Date(timeIntervalSince1970: 1000)
        let d = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "json-sortedKeys-utf8",
            digestString: "abc123",
            producedAt: date)
        XCTAssertEqual(
            d.algorithmName, "json-sortedKeys-utf8")
        XCTAssertEqual(d.digestString, "abc123")
        XCTAssertEqual(d.producedAt, date)
    }

    // MARK: - Empty factory

    func testEmptyFactoryHasEmptyAlgoAndDigest() {
        let date = Date(timeIntervalSince1970: 1000)
        let d = BASRuntimeAuditEmissionSummaryDigest
            .empty(producedAt: date)
        XCTAssertEqual(d.algorithmName, "")
        XCTAssertEqual(d.digestString, "")
        XCTAssertEqual(d.producedAt, date)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesFields() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let original = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "test-algo",
            digestString: "deadbeef",
            producedAt: date)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASRuntimeAuditEmissionSummaryDigest.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equality + Hashable

    func testEqualDigestsHaveEqualHash() {
        let date = Date(timeIntervalSince1970: 1000)
        let d1 = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "a", digestString: "x",
            producedAt: date)
        let d2 = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "a", digestString: "x",
            producedAt: date)
        XCTAssertEqual(d1, d2)
        XCTAssertEqual(d1.hashValue, d2.hashValue)
    }

    // MARK: - Different algos discriminate

    func testDifferentAlgorithmsAreNotEqual() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo-1", digestString: "x",
            producedAt: date)
        let b = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "algo-2", digestString: "x",
            producedAt: date)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Determinism

    func testInitIsDeterministic() {
        let date = Date(timeIntervalSince1970: 1000)
        let a = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "a", digestString: "x",
            producedAt: date)
        let b = BASRuntimeAuditEmissionSummaryDigest(
            algorithmName: "a", digestString: "x",
            producedAt: date)
        XCTAssertEqual(a, b)
    }
}
