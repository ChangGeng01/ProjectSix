// MARK: - BASTurnRuntimeModeTests — chapter 四百二十七 / M1081

import XCTest
@testable import BASHostKit

final class BASTurnRuntimeModeTests: XCTestCase {

    func testThreeCases() {
        XCTAssertEqual(
            BASTurnRuntimeMode.allCases.count, 3)
    }

    func testRawValuesPinned() {
        XCTAssertEqual(
            BASTurnRuntimeMode.v1ByteEqual.rawValue,
            "v1-byte-equal")
        XCTAssertEqual(
            BASTurnRuntimeMode.nativeV2.rawValue,
            "native-v2")
        XCTAssertEqual(
            BASTurnRuntimeMode.stressSweepDual.rawValue,
            "stress-sweep-dual")
    }

    func testCodableRoundTripPreservesAllCases() throws {
        for mode in BASTurnRuntimeMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(
                BASTurnRuntimeMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testRawValuesAreUnique() {
        let raws = BASTurnRuntimeMode.allCases
            .map { $0.rawValue }
        XCTAssertEqual(raws.count, Set(raws).count)
    }

    func testV1ByteEqualIsImpliedDefault() {
        // Convention: v1ByteEqual is the default for
        // ADR-014 OPT-IN compliance。 First case in
        // CaseIterable order pins this。
        XCTAssertEqual(
            BASTurnRuntimeMode.allCases.first,
            .v1ByteEqual)
    }

    func testDeterminism() {
        XCTAssertEqual(
            BASTurnRuntimeMode.allCases,
            BASTurnRuntimeMode.allCases)
    }
}
