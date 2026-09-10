// MARK: - BASSampleHostRuntimeModeEnvVarBridgeTests
// chapter 六百七十 / M2058 — PROOF tests for the M2057
//                            env var bridge。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASSampleHostRuntimeModeEnvVarBridgeTests:
    XCTestCase
{
    typealias Bridge = BASSampleHostRuntimeModeEnvVarBridge

    // MARK: - Env var name pin

    func testEnvVarNameIsBAS_RUNTIME_MODE() {
        XCTAssertEqual(Bridge.envVarName,
            "BAS_RUNTIME_MODE")
    }

    // MARK: - Default mode pin

    func testDefaultModeWhenAbsentIsV1ByteEqual() {
        XCTAssertEqual(Bridge.defaultModeWhenAbsent,
            .v1ByteEqual)
    }

    // MARK: - Absent env var resolves to default

    func testAbsentEnvVarResolvesToDefault() {
        let result = Bridge.currentRuntimeMode(
            environment: [:])
        XCTAssertEqual(result, .v1ByteEqual)
    }

    // MARK: - Each runtime mode raw value resolves correctly

    func testV1ByteEqualRawValueResolves() {
        let result = Bridge.currentRuntimeMode(
            environment: [
                "BAS_RUNTIME_MODE": "v1-byte-equal"
            ])
        XCTAssertEqual(result, .v1ByteEqual)
    }

    func testNativeV2RawValueResolves() {
        let result = Bridge.currentRuntimeMode(
            environment: [
                "BAS_RUNTIME_MODE": "native-v2"
            ])
        XCTAssertEqual(result, .nativeV2)
    }

    func testStressSweepDualRawValueResolves() {
        let result = Bridge.currentRuntimeMode(
            environment: [
                "BAS_RUNTIME_MODE": "stress-sweep-dual"
            ])
        XCTAssertEqual(result, .stressSweepDual)
    }

    // MARK: - Unrecognized value falls back to default

    func testUnrecognizedValueFallsBackToDefault() {
        let result = Bridge.currentRuntimeMode(
            environment: [
                "BAS_RUNTIME_MODE": "future-v3"
            ])
        XCTAssertEqual(result, .v1ByteEqual,
            "Unrecognized env var values must fall back" +
            " to .v1ByteEqual per ADR-014 OPT-IN contract")
    }

    func testEmptyValueFallsBackToDefault() {
        let result = Bridge.currentRuntimeMode(
            environment: [
                "BAS_RUNTIME_MODE": ""
            ])
        XCTAssertEqual(result, .v1ByteEqual)
    }

    // MARK: - isOptedInToNonDefault flag

    func testIsOptedInFalseWhenAbsent() {
        XCTAssertFalse(Bridge.isOptedInToNonDefault(
            environment: [:]))
    }

    func testIsOptedInFalseWhenV1ByteEqualExplicit() {
        XCTAssertFalse(Bridge.isOptedInToNonDefault(
            environment: [
                "BAS_RUNTIME_MODE": "v1-byte-equal"
            ]))
    }

    func testIsOptedInTrueWhenNativeV2() {
        XCTAssertTrue(Bridge.isOptedInToNonDefault(
            environment: [
                "BAS_RUNTIME_MODE": "native-v2"
            ]))
    }

    func testIsOptedInTrueWhenStressSweepDual() {
        XCTAssertTrue(Bridge.isOptedInToNonDefault(
            environment: [
                "BAS_RUNTIME_MODE": "stress-sweep-dual"
            ]))
    }

    func testIsOptedInFalseWhenUnrecognized() {
        XCTAssertFalse(Bridge.isOptedInToNonDefault(
            environment: [
                "BAS_RUNTIME_MODE": "future-v3"
            ]),
            "Unrecognized value resolves to .v1ByteEqual" +
            " so isOptedInToNonDefault is false")
    }
}
