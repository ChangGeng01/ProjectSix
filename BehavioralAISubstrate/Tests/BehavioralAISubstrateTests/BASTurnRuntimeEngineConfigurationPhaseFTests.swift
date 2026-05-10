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

    func testDefaultIsV1ByteEqualNoRegistry() {
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertEqual(config.runtimeMode, .v1ByteEqual,
            "default mode preserves V1 byte-equality" +
            " (ADR-014 OPT-IN)")
        XCTAssertNil(config.metalKernelRegistry,
            "default has no kernel registry — V1 path" +
            " takes over")
        XCTAssertNil(config.aneCapability,
            "default has no ANE capability — scheduler" +
            " falls back to .conservative")
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
        let base = BASTurnRuntimeEngineConfiguration
            .default()
        let updated = base.with(runtimeMode: .nativeV2)
        XCTAssertEqual(base.runtimeMode, .v1ByteEqual,
            "base unchanged")
        XCTAssertEqual(updated.runtimeMode, .nativeV2)
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
        XCTAssertEqual(config.runtimeMode, .v1ByteEqual)
    }
}
