// MARK: - BASRuntimeModeOverrideEnvVarProofTests
// chapter 六百七十二 / M2066 — PROOF tests for the
//                              BAS_RUNTIME_MODE_OVERRIDE
//                              env var safety net。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASRuntimeModeOverrideEnvVarProofTests:
    XCTestCase
{
    typealias Bridge = BASSampleHostRuntimeModeEnvVarBridge

    // MARK: - Override env var name pin

    func testOverrideEnvVarNameIsBAS_RUNTIME_MODE_OVERRIDE() {
        XCTAssertEqual(Bridge.overrideEnvVarName,
            "BAS_RUNTIME_MODE_OVERRIDE")
    }

    // MARK: - Override takes priority over BAS_RUNTIME_MODE

    func testOverrideBeatsBAS_RUNTIME_MODE_v1_over_nativeV2() {
        let env: [String: String] = [
            "BAS_RUNTIME_MODE": "native-v2",
            "BAS_RUNTIME_MODE_OVERRIDE": "v1-byte-equal"
        ]
        let result = Bridge
            .currentRuntimeModeRespectingOverride(
                environment: env)
        XCTAssertEqual(result, .v1ByteEqual,
            "OVERRIDE must beat BAS_RUNTIME_MODE — this is" +
            " the Phase L revert safety net")
    }

    func testOverrideBeatsBAS_RUNTIME_MODE_nativeV2_over_v1() {
        let env: [String: String] = [
            "BAS_RUNTIME_MODE": "v1-byte-equal",
            "BAS_RUNTIME_MODE_OVERRIDE": "native-v2"
        ]
        let result = Bridge
            .currentRuntimeModeRespectingOverride(
                environment: env)
        XCTAssertEqual(result, .nativeV2)
    }

    // MARK: - Override absent → falls through to BAS_RUNTIME_MODE

    func testAbsentOverrideFallsThroughToBAS_RUNTIME_MODE() {
        let env: [String: String] = [
            "BAS_RUNTIME_MODE": "native-v2"
        ]
        let result = Bridge
            .currentRuntimeModeRespectingOverride(
                environment: env)
        XCTAssertEqual(result, .nativeV2)
    }

    // MARK: - Both absent → default

    func testBothAbsentFallsThroughToDefault() {
        let result = Bridge
            .currentRuntimeModeRespectingOverride(
                environment: [:])
        XCTAssertEqual(result, .v1ByteEqual)
    }

    // MARK: - Invalid override → falls through to BAS_RUNTIME_MODE

    func testInvalidOverrideFallsThroughToBAS_RUNTIME_MODE() {
        let env: [String: String] = [
            "BAS_RUNTIME_MODE": "native-v2",
            "BAS_RUNTIME_MODE_OVERRIDE": "future-v3"
        ]
        let result = Bridge
            .currentRuntimeModeRespectingOverride(
                environment: env)
        XCTAssertEqual(result, .nativeV2,
            "Invalid override must fall through to" +
            " BAS_RUNTIME_MODE,not silently to default")
    }

    // MARK: - Override valid + BAS_RUNTIME_MODE invalid → override wins

    func testValidOverrideBeatsInvalidBAS_RUNTIME_MODE() {
        let env: [String: String] = [
            "BAS_RUNTIME_MODE": "future-v3",
            "BAS_RUNTIME_MODE_OVERRIDE": "stress-sweep-dual"
        ]
        let result = Bridge
            .currentRuntimeModeRespectingOverride(
                environment: env)
        XCTAssertEqual(result, .stressSweepDual)
    }

    // MARK: - All 3 valid override values resolve correctly

    func testV1ByteEqualOverrideResolves() {
        let env: [String: String] = [
            "BAS_RUNTIME_MODE_OVERRIDE": "v1-byte-equal"
        ]
        XCTAssertEqual(
            Bridge.currentRuntimeModeRespectingOverride(
                environment: env),
            .v1ByteEqual)
    }

    func testNativeV2OverrideResolves() {
        let env: [String: String] = [
            "BAS_RUNTIME_MODE_OVERRIDE": "native-v2"
        ]
        XCTAssertEqual(
            Bridge.currentRuntimeModeRespectingOverride(
                environment: env),
            .nativeV2)
    }

    func testStressSweepDualOverrideResolves() {
        let env: [String: String] = [
            "BAS_RUNTIME_MODE_OVERRIDE": "stress-sweep-dual"
        ]
        XCTAssertEqual(
            Bridge.currentRuntimeModeRespectingOverride(
                environment: env),
            .stressSweepDual)
    }

    // MARK: - isOverrideActive flag

    func testIsOverrideActiveFalseWhenAbsent() {
        XCTAssertFalse(Bridge.isOverrideActive(
            environment: [:]))
    }

    func testIsOverrideActiveTrueWhenValid() {
        XCTAssertTrue(Bridge.isOverrideActive(
            environment: [
                "BAS_RUNTIME_MODE_OVERRIDE": "v1-byte-equal"
            ]))
    }

    func testIsOverrideActiveFalseWhenInvalid() {
        XCTAssertFalse(Bridge.isOverrideActive(
            environment: [
                "BAS_RUNTIME_MODE_OVERRIDE": "future-v3"
            ]))
    }

    // MARK: - Original currentRuntimeMode UNCHANGED

    func testOriginalCurrentRuntimeModeIgnoresOverride() {
        // M2049 chapter 668 contract preserved:the
        // original `currentRuntimeMode(_:)` does NOT
        // consult the override env var。 Callers wanting
        // override precedence opt in by calling
        // `currentRuntimeModeRespectingOverride(_:)`。
        let env: [String: String] = [
            "BAS_RUNTIME_MODE": "v1-byte-equal",
            "BAS_RUNTIME_MODE_OVERRIDE": "native-v2"
        ]
        let result = Bridge.currentRuntimeMode(
            environment: env)
        XCTAssertEqual(result, .v1ByteEqual,
            "Original currentRuntimeMode MUST ignore" +
            " BAS_RUNTIME_MODE_OVERRIDE — back-compat" +
            " contract with M2049 callers")
    }
}
