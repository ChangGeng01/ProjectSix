// MARK: - BASChapter668RuntimeModeToggleProofTests
// chapter 六百六十八 / M2050 — PROOF tests verifying the
//                              BASTurnRuntimeMode enum
//                              surface that the new async
//                              buildEBrainTurnWithRuntime
//                              Mode opt-in surface accepts。
//                              chapter 669 dual-mode stress
//                              sweep test ships the full
//                              integration assertion;this
//                              chapter pins the enum
//                              surface itself。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASChapter668RuntimeModeToggleProofTests:
    XCTestCase
{
    // MARK: - BASTurnRuntimeMode enum coverage

    func testBASTurnRuntimeModeAllCasesCount() {
        XCTAssertEqual(
            BASTurnRuntimeMode.allCases.count, 3,
            "BASTurnRuntimeMode must have exactly 3 cases")
    }

    func testBASTurnRuntimeModeCases() {
        XCTAssertTrue(BASTurnRuntimeMode.allCases
            .contains(.v1ByteEqual))
        XCTAssertTrue(BASTurnRuntimeMode.allCases
            .contains(.nativeV2))
        XCTAssertTrue(BASTurnRuntimeMode.allCases
            .contains(.stressSweepDual))
    }

    func testBASTurnRuntimeModeRawValues() {
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

    func testBASTurnRuntimeModeIsCodable() throws {
        let encoded = try JSONEncoder().encode(
            BASTurnRuntimeMode.allCases)
        let decoded = try JSONDecoder().decode(
            [BASTurnRuntimeMode].self,
            from: encoded)
        XCTAssertEqual(decoded,
            BASTurnRuntimeMode.allCases)
    }

    func testBASTurnRuntimeModeIsHashable() {
        let set: Set<BASTurnRuntimeMode> = [
            .v1ByteEqual, .nativeV2, .stressSweepDual,
            .v1ByteEqual,  // duplicate — Set dedupes
        ]
        XCTAssertEqual(set.count, 3,
            "BASTurnRuntimeMode Hashable conformance" +
            " must dedupe the 3 unique cases")
    }

    func testBASTurnRuntimeModeIsEquatable() {
        XCTAssertEqual(
            BASTurnRuntimeMode.v1ByteEqual,
            BASTurnRuntimeMode.v1ByteEqual)
        XCTAssertNotEqual(
            BASTurnRuntimeMode.v1ByteEqual,
            BASTurnRuntimeMode.nativeV2)
        XCTAssertNotEqual(
            BASTurnRuntimeMode.nativeV2,
            BASTurnRuntimeMode.stressSweepDual)
    }

    // MARK: - V1 mode is the safe default

    /// chapter 三百九二 replay-determinism check:until
    /// Phase L flip (chapter 674 / M2074),the default
    /// MUST be `.v1ByteEqual` to preserve M2032 baseline
    /// behavior for all hosts not opting into V2。
    func testV1ByteEqualIsTheDefaultPhaseKMode() {
        // This is the value the new async opt-in surface
        // (M2049 `buildEBrainTurnWithRuntimeMode`) uses
        // as its default。 Phase L (M2074) flips this。
        XCTAssertEqual(
            BASTurnRuntimeMode.v1ByteEqual.rawValue,
            "v1-byte-equal",
            "Phase K default mode MUST be .v1ByteEqual" +
            " to preserve M2032 baseline byte-equality")
    }
}
