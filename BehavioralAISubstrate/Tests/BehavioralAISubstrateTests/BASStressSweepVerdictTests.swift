// MARK: - BASStressSweepVerdictTests — chapter 四百十三 / M1022

import XCTest
@testable import BASHostKit

final class BASStressSweepVerdictTests: XCTestCase {

    // MARK: - 4 cases present

    func testFourCasesPresent() {
        XCTAssertEqual(
            BASStressSweepVerdict.allCases.count, 4)
    }

    func testAllRawValuesArePinned() {
        let raws = BASStressSweepVerdict.allCases
            .map { $0.rawValue }
        XCTAssertEqual(
            Set(raws),
            Set([
                "byte-equal", "divergent",
                "v1-failed", "v2-failed"
            ]))
    }

    // MARK: - isPass / isFail

    func testByteEqualIsPass() {
        XCTAssertTrue(
            BASStressSweepVerdict.byteEqual.isPass)
        XCTAssertFalse(
            BASStressSweepVerdict.byteEqual.isFail)
    }

    func testNonByteEqualVerdictsAreFails() {
        for v in BASStressSweepVerdict.allCases
        where v != .byteEqual
        {
            XCTAssertFalse(v.isPass)
            XCTAssertTrue(v.isFail)
        }
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesAllCases() throws {
        for v in BASStressSweepVerdict.allCases {
            let data = try JSONEncoder().encode(v)
            let decoded = try JSONDecoder().decode(
                BASStressSweepVerdict.self, from: data)
            XCTAssertEqual(decoded, v)
        }
    }

    // MARK: - Determinism + uniqueness

    func testRawValuesAreUnique() {
        let raws = BASStressSweepVerdict.allCases
            .map { $0.rawValue }
        XCTAssertEqual(raws.count, Set(raws).count)
    }

    func testAllCasesIsDeterministic() {
        XCTAssertEqual(
            BASStressSweepVerdict.allCases,
            BASStressSweepVerdict.allCases)
    }
}
