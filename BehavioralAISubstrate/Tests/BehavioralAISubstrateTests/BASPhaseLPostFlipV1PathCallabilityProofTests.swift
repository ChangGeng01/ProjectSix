// MARK: - BASPhaseLPostFlipV1PathCallabilityProofTests
// chapter 六百七十五 / M2079 — verify V1 path remains
//                              callable post-flip via the
//                              two OPT-OUT mechanisms。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASPhaseLPostFlipV1PathCallabilityProofTests:
    XCTestCase
{
    // MARK: - Explicit init OPT-OUT path

    func testExplicitInitWithV1ByteEqualPreservesV1Mode() {
        let config = BASTurnRuntimeEngineConfiguration(
            runtimeMode: .v1ByteEqual)
        XCTAssertEqual(config.runtimeMode, .v1ByteEqual,
            "Explicit init(runtimeMode:.v1ByteEqual)" +
            " MUST preserve V1 mode even after M2074 flip")
    }

    // MARK: - Default returns post-flip mode

    func testDefaultReturnsNativeV2PostFlip() {
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertEqual(config.runtimeMode, .nativeV2,
            "default() returns .nativeV2 post-M2074 flip")
    }

    // MARK: - .with(runtimeMode:) pivots back to V1

    func testWithRuntimeModePivotsBackToV1() {
        let base = BASTurnRuntimeEngineConfiguration
            .default()
        let pivoted = base.with(
            runtimeMode: .v1ByteEqual)
        XCTAssertEqual(base.runtimeMode, .nativeV2,
            "base unchanged from post-flip default")
        XCTAssertEqual(pivoted.runtimeMode, .v1ByteEqual,
            ".with(runtimeMode:.v1ByteEqual) pivots back" +
            " to V1 mode — OPT-OUT path works")
    }

    // MARK: - Env var override mechanism

    func testEnvOverrideResolvesV1ByteEqualCorrectly() {
        let mode = BASSampleHostRuntimeModeEnvVarBridge
            .currentRuntimeModeRespectingOverride(
                environment: [
                    "BAS_RUNTIME_MODE_OVERRIDE":
                        "v1-byte-equal"
                ])
        XCTAssertEqual(mode, .v1ByteEqual,
            "BAS_RUNTIME_MODE_OVERRIDE=v1-byte-equal" +
            " MUST resolve to .v1ByteEqual — Phase L" +
            " zero-redeploy revert path active")
    }

    func testEnvOverrideBeatsBASRuntimeModeEvenForV1() {
        let mode = BASSampleHostRuntimeModeEnvVarBridge
            .currentRuntimeModeRespectingOverride(
                environment: [
                    "BAS_RUNTIME_MODE": "native-v2",
                    "BAS_RUNTIME_MODE_OVERRIDE":
                        "v1-byte-equal"
                ])
        XCTAssertEqual(mode, .v1ByteEqual,
            "Override beats BAS_RUNTIME_MODE — production" +
            " can roll back from V2 to V1 without redeploy")
    }

    // MARK: - Original currentRuntimeMode default unchanged

    func testOriginalCurrentRuntimeModeDefaultStillV1() {
        // BASSampleHostRuntimeModeEnvVarBridge's M2049
        // .defaultModeWhenAbsent contract is UNCHANGED by
        // Phase L。 Only the BASTurnRuntimeEngineConfig.
        // default() flipped。
        XCTAssertEqual(
            BASSampleHostRuntimeModeEnvVarBridge
                .defaultModeWhenAbsent,
            .v1ByteEqual,
            "Bridge's defaultModeWhenAbsent is" +
            " UNCHANGED — only BASTurnRuntimeEngineConfig." +
            "default() flipped at M2074")
    }

    // MARK: - Phase L safety nets still wired

    func testPhaseLContractStillReflectsCurrentReality() {
        // Pre-flip gate contract was for chapter 673 /
        // M2069。 Now sealed。 Contract doctrine should
        // still pin 0% divergence requirement。
        XCTAssertEqual(
            BASPhaseLPreFlipGateContractDoctrine
                .divergenceTolerancePercent, 0.0)
        XCTAssertEqual(
            BASPhaseLPreFlipGateContractDoctrine
                .runnerCountRequirement, 100)
        XCTAssertEqual(
            BASPhaseLPreFlipGateContractDoctrine
                .flipMNumber, 2074)
    }
}
