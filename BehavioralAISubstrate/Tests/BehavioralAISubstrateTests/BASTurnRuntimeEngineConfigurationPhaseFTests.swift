// MARK: - BASTurnRuntimeEngineConfigurationPhaseFTests
// chapter 四百三十二 / M1100

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASTurnRuntimeEngineConfigurationPhaseFTests:
    XCTestCase
{

    // MARK: - Default has v1ByteEqual + nil registry +
    // nil capability

    func testDefaultIsNativeV2PostFlipNoRegistry() {
        // M2074 chapter 六百七十四 第二刀 THE FLIP:
        // BASTurnRuntimeEngineConfiguration.default() now
        // returns runtimeMode=.nativeV2 (was .v1ByteEqual
        // pre-M2074)。 Hosts needing V1 semantics opt out
        // explicitly via init(runtimeMode: .v1ByteEqual)
        // or BAS_RUNTIME_MODE_OVERRIDE=v1-byte-equal env
        // var per BASRuntimeModeOverrideDoctrine M2067。
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertEqual(config.runtimeMode, .nativeV2,
            "default mode FLIPPED to .nativeV2 at M2074" +
            " (Phase L)。 ADR-014 OPT-OUT path:explicit" +
            " init(runtimeMode: .v1ByteEqual) preserved。")
        XCTAssertNil(config.metalKernelRegistry,
            "default has no kernel registry")
        XCTAssertNil(config.aneCapability,
            "default has no ANE capability")
    }

    // MARK: - All M998 originals still accessible

    func testM998SlotsStillPresent() {
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertNil(config.eventLog)
        let id = config.eventIDFactory()
        XCTAssertFalse(id.isEmpty,
            "default eventID factory returns non-empty UUID")
        let clock = config.clockMs()
        XCTAssertGreaterThan(clock, 0,
            "default clock returns positive ms timestamp")
    }

    // MARK: - Init with full set of new slots

    func testInitWithAllNewSlots() async {
        let registry = BASMetalKernelRegistry()
        let capability = BASANECapability
            .nominalAppleSilicon()
        let config = BASTurnRuntimeEngineConfiguration(
            runtimeMode: .nativeV2,
            metalKernelRegistry: registry,
            aneCapability: capability)
        XCTAssertEqual(config.runtimeMode, .nativeV2)
        XCTAssertNotNil(config.metalKernelRegistry)
        XCTAssertEqual(
            config.aneCapability, capability)
    }

    // MARK: - Immutable updates per slot

    func testWithRuntimeMode() {
        // M2074 chapter 674 第二刀 THE FLIP:default() now
        // returns nativeV2。 with(runtimeMode:) to v1Byte
        // Equal demonstrates the OPT-OUT pivot path。
        let base = BASTurnRuntimeEngineConfiguration
            .default()
        let updated = base.with(runtimeMode: .v1ByteEqual)
        XCTAssertEqual(base.runtimeMode, .nativeV2,
            "base unchanged from post-flip default")
        XCTAssertEqual(updated.runtimeMode, .v1ByteEqual,
            "with(runtimeMode:) pivots to OPT-OUT V1 path")
    }

    func testWithMetalKernelRegistry() async {
        let registry = BASMetalKernelRegistry()
        await registry.register(BASMatMulKernel())
        let base = BASTurnRuntimeEngineConfiguration
            .default()
        let updated = base.with(
            metalKernelRegistry: registry)
        XCTAssertNil(base.metalKernelRegistry,
            "base unchanged")
        XCTAssertNotNil(updated.metalKernelRegistry)
        // Verify the kernel is reachable through the
        // updated config's registry
        let count = await updated.metalKernelRegistry?
            .kernelCount
        XCTAssertEqual(count, 1)
    }

    func testWithANECapability() {
        let capability = BASANECapability
            .nominalAppleSilicon()
        let base = BASTurnRuntimeEngineConfiguration
            .default()
        let updated = base.with(
            aneCapability: capability)
        XCTAssertNil(base.aneCapability,
            "base unchanged")
        XCTAssertEqual(
            updated.aneCapability?.acceleratorPriority,
            .aneFirst)
    }

    // MARK: - Builder chain preserves all slots

    func testBuilderChainPreservesAllSlots() {
        let capability = BASANECapability
            .nominalAppleSilicon()
        let id1: @Sendable () -> String = { "fixed-id" }
        let clock1: @Sendable () -> Int64 = { 12345 }
        let config = BASTurnRuntimeEngineConfiguration
            .default()
            .with(eventIDFactory: id1)
            .with(clockMs: clock1)
            .with(runtimeMode: .stressSweepDual)
            .with(aneCapability: capability)
        XCTAssertEqual(config.eventIDFactory(), "fixed-id")
        XCTAssertEqual(config.clockMs(), 12345)
        XCTAssertEqual(
            config.runtimeMode, .stressSweepDual)
        XCTAssertEqual(
            config.aneCapability, capability)
    }

    // MARK: - Sendability discipline

    func testConfigurationIsSendable() {
        // Compile-time check: passing across actor
        // boundaries must be allowed
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        Task {
            let _: BASTurnRuntimeEngineConfiguration =
                config
        }
        // M2074 chapter 674 第二刀 THE FLIP:default()
        // now returns .nativeV2 (was .v1ByteEqual pre-
        // M2074)。
        XCTAssertEqual(config.runtimeMode, .nativeV2)
    }
}
