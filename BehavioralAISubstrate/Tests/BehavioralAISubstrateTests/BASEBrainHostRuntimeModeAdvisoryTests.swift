// MARK: - BASEBrainHostRuntimeModeAdvisoryTests
// chapter 四百九十八 / M1370 — production runtime-mode advisory tests

import XCTest
@testable import BASHostKit

final class BASEBrainHostRuntimeModeAdvisoryTests:
    XCTestCase
{

    // MARK: - 1) v1ByteEqual advisory is honored vacuously

    func testV1ByteEqualAdvisoryHonoredVacuously() {
        let advisory =
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .advisoryFor(
                    preferredMode: .v1ByteEqual,
                    hostID: "H",
                    recordedAtMs: 1_700_000_000_000)
        XCTAssertTrue(advisory.wasHonored)
        XCTAssertTrue(advisory.reasonCodes.isEmpty)
        XCTAssertEqual(advisory.preferredMode,
                       .v1ByteEqual)
    }

    // MARK: - 2) nativeV2 advisory is NOT honored at chapter 498

    func testNativeV2AdvisoryNotHonoredAtChapter498() {
        let advisory =
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .advisoryFor(
                    preferredMode: .nativeV2,
                    hostID: "H",
                    recordedAtMs: 1_700_000_000_000)
        XCTAssertFalse(advisory.wasHonored,
            "chapter 498 production wire-in NOT done;" +
            " nativeV2 advisories cannot be honored yet")
        XCTAssertFalse(advisory.reasonCodes.isEmpty)
        XCTAssertTrue(advisory.reasonCodes
            .contains("tier-1-deferred-no-host-" +
                      "integration-ci-lane"))
    }

    // MARK: - 3) stressSweepDual advisory is NOT honored

    func testStressSweepDualAdvisoryNotHonoredAtChapter498() {
        let advisory =
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .advisoryFor(
                    preferredMode: .stressSweepDual,
                    hostID: "H",
                    recordedAtMs: 1_700_000_000_000)
        XCTAssertFalse(advisory.wasHonored)
        XCTAssertEqual(
            advisory.reasonCodes,
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .unhonoredReasonCodes)
    }

    // MARK: - 4) Active default mode pin

    func testActiveDefaultModeIsV1ByteEqual() {
        XCTAssertEqual(
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .activeDefaultMode,
            .v1ByteEqual,
            "chapter 498 doctrine pin:active default" +
            " runtime mode MUST remain .v1ByteEqual" +
            " until chapter 499+ production wire-in")
    }

    // MARK: - 5) advisoryHonoredInProduction is FALSE

    func testAdvisoryHonoredInProductionIsFalse() {
        XCTAssertFalse(
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .advisoryHonoredInProduction,
            "chapter 498 HONEST scope:production V1 path" +
            " does NOT honor non-v1 advisories;wire-in" +
            " deferred to chapter 499+")
    }

    // MARK: - 6) Codable round-trip

    func testCodableRoundTrip() throws {
        let original = BASEBrainHostRuntimeModeAdvisory(
            preferredMode: .nativeV2,
            hostID: "test-host",
            recordedAtMs: 1_700_000_000_000,
            wasHonored: false,
            reasonCodes: ["test-reason"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASEBrainHostRuntimeModeAdvisory.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 7) Unhonored reason codes are non-empty
    //             at chapter 498

    func testUnhonoredReasonCodesAreNonEmpty() {
        let codes =
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .unhonoredReasonCodes
        XCTAssertGreaterThanOrEqual(codes.count, 3,
            "chapter 498 doctrine: substrate MUST emit" +
            " typed reason codes when advisories are" +
            " not honored (audit trail)")
    }

    // MARK: - 8) Sendable

    func testAdvisoryIsSendable() async {
        let advisory =
            BASEBrainHostRuntimeModeAdvisoryDoctrine
                .advisoryFor(
                    preferredMode: .v1ByteEqual,
                    hostID: "H",
                    recordedAtMs: 1)
        let captured = advisory
        let task = Task {
            captured.wasHonored
        }
        let result = await task.value
        XCTAssertTrue(result)
    }
}
