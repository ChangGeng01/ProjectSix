// MARK: - BASTurnRuntimeStressRiskBucketTests — chapter 四百十一 / M1015

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStressRiskBucketTests:
    XCTestCase
{

    // MARK: - 4 cases present

    func testFourCasesPresent() {
        XCTAssertEqual(
            BASTurnRuntimeStressRiskBucket
                .allCases.count, 4)
    }

    func testRawValuesArePinned() {
        let raws = BASTurnRuntimeStressRiskBucket
            .allCases.map { $0.rawValue }
        XCTAssertEqual(
            Set(raws),
            Set(["low", "medium", "high", "extreme"]))
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesAllCases() throws {
        for bucket in BASTurnRuntimeStressRiskBucket
            .allCases
        {
            let data = try JSONEncoder().encode(bucket)
            let decoded = try JSONDecoder().decode(
                BASTurnRuntimeStressRiskBucket.self,
                from: data)
            XCTAssertEqual(decoded, bucket)
        }
    }

    // MARK: - Determinism

    func testAllCasesIsDeterministic() {
        let a = BASTurnRuntimeStressRiskBucket.allCases
        let b = BASTurnRuntimeStressRiskBucket.allCases
        XCTAssertEqual(a, b)
    }

    // MARK: - Raw values are unique

    func testRawValuesAreUnique() {
        let raws = BASTurnRuntimeStressRiskBucket
            .allCases.map { $0.rawValue }
        XCTAssertEqual(raws.count, Set(raws).count)
    }
}
