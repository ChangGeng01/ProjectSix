// MARK: - BASTurnRuntimeStressDimensionTests — chapter 四百十一 / M1014

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeStressDimensionTests:
    XCTestCase
{

    // MARK: - All 6 cases present

    func testAllCasesAreSixDimensions() {
        XCTAssertEqual(
            BASTurnRuntimeStressDimension.allCases.count, 6)
    }

    func testAllCaseNamesArePinned() {
        let raws = BASTurnRuntimeStressDimension.allCases
            .map { $0.rawValue }
        XCTAssertTrue(raws.contains("risk"))
        XCTAssertTrue(raws.contains("permit-mode"))
        XCTAssertTrue(raws.contains("quarantines"))
        XCTAssertTrue(raws.contains("anchor-tone"))
        XCTAssertTrue(raws.contains("neural-core"))
        XCTAssertTrue(raws.contains("evolution-feedback"))
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesDimension() throws {
        for dim in BASTurnRuntimeStressDimension.allCases {
            let data = try JSONEncoder().encode(dim)
            let decoded = try JSONDecoder().decode(
                BASTurnRuntimeStressDimension.self,
                from: data)
            XCTAssertEqual(decoded, dim)
        }
    }

    // MARK: - Determinism

    func testAllCasesIsDeterministic() {
        let a = BASTurnRuntimeStressDimension.allCases
        let b = BASTurnRuntimeStressDimension.allCases
        XCTAssertEqual(a, b)
    }

    // MARK: - Raw values are unique

    func testRawValuesAreUnique() {
        let raws = BASTurnRuntimeStressDimension.allCases
            .map { $0.rawValue }
        XCTAssertEqual(
            raws.count,
            Set(raws).count,
            "no duplicate raw values allowed")
    }
}
