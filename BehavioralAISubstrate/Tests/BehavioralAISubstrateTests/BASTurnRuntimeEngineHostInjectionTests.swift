// MARK: - BASTurnRuntimeEngineHostInjectionTests
// chapter 四百三十八 / M1128-M1130

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASTurnRuntimeEngineHostInjectionTests:
    XCTestCase
{

    // MARK: - Configuration shape

    func testConfigurationDefaultsBothExecutorsNil() {
        let config = BASTurnRuntimeEngineConfiguration
            .default()
        XCTAssertNil(
            config.routedStageExecutor,
            "default config has nil routedStageExecutor")
        XCTAssertNil(
            config.fallbackStageExecutor,
            "default config has nil fallbackStageExecutor")
    }

    func testConfigurationCarriesRoutedExecutor() {
        let routed: BASNativeStageExecutor.RoutedStageExecutor =
            { _, _, _ in 42 }
        let config = BASTurnRuntimeEngineConfiguration(
            routedStageExecutor: routed)
        XCTAssertNotNil(
            config.routedStageExecutor,
            "routedStageExecutor must persist through" +
            " init")
    }

    func testConfigurationCarriesFallbackExecutor() {
        let fallback: BASNativeStageExecutor.StageExecutor =
            { _, _ in 99 }
        let config = BASTurnRuntimeEngineConfiguration(
            fallbackStageExecutor: fallback)
        XCTAssertNotNil(
            config.fallbackStageExecutor,
            "fallbackStageExecutor must persist through" +
            " init")
    }

    // MARK: - Immutable updaters

    func testWithRoutedStageExecutorUpdater() {
        let base = BASTurnRuntimeEngineConfiguration
            .default()
        let routed: BASNativeStageExecutor.RoutedStageExecutor =
            { _, _, _ in 0 }
        let updated = base.with(
            routedStageExecutor: routed)
        XCTAssertNil(base.routedStageExecutor)
        XCTAssertNotNil(updated.routedStageExecutor)
    }

    func testWithFallbackStageExecutorUpdater() {
        let base = BASTurnRuntimeEngineConfiguration
            .default()
        let fallback: BASNativeStageExecutor.StageExecutor =
            { _, _ in 0 }
        let updated = base.with(
            fallbackStageExecutor: fallback)
        XCTAssertNil(base.fallbackStageExecutor)
        XCTAssertNotNil(updated.fallbackStageExecutor)
    }

    func testBuilderChainPreservesAllPriorSlots() {
        // Combine new slots with existing slots —
        // builder chain must not drop anything
        let registry = BASMetalKernelRegistry()
        let capability = BASANECapability
            .nominalAppleSilicon()
        let routed: BASNativeStageExecutor.RoutedStageExecutor =
            { _, _, _ in 0 }
        let fallback: BASNativeStageExecutor.StageExecutor =
            { _, _ in 0 }
        let config = BASTurnRuntimeEngineConfiguration
            .default()
            .with(runtimeMode: .nativeV2)
            .with(metalKernelRegistry: registry)
            .with(aneCapability: capability)
            .with(routedStageExecutor: routed)
            .with(fallbackStageExecutor: fallback)
        XCTAssertEqual(
            config.runtimeMode, .nativeV2)
        XCTAssertNotNil(config.metalKernelRegistry)
        XCTAssertNotNil(config.aneCapability)
        XCTAssertNotNil(config.routedStageExecutor)
        XCTAssertNotNil(config.fallbackStageExecutor)
    }

    // MARK: - Sendability

    func testConfigurationIsSendableAcrossActorBoundary()
        async
    {
        let routed: BASNativeStageExecutor.RoutedStageExecutor =
            { _, _, _ in 0 }
        let config = BASTurnRuntimeEngineConfiguration(
            routedStageExecutor: routed)
        // Compile-time check: if config isn't Sendable
        // through a Task closure capture, this fails to
        // compile
        let task = Task { @Sendable in
            return config.routedStageExecutor != nil
        }
        let result = await task.value
        XCTAssertTrue(result)
    }
}
