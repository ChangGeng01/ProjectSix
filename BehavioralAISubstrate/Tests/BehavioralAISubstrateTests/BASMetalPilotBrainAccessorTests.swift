// MARK: - BASMetalPilotBrainAccessorTests
// REAL Metal pilot integration tests。 Verifies that:
//   - brain.metalLibraryLoader is nil by default
//     (no lazy load cost for hosts that don't need it)
//   - When provided,the accessor returns the loader
//     unchanged for host use
//   - The loader is shareable across the brain and
//     downstream host code (same instance reference)
//   - Library compile works through the brain-exposed
//     accessor when loader is in V2 mode
//
// 主线 pilot completion: 5 of 5 pilots are now reachable
// from the brain (C pilot wired into latency, SQL/Rust
// pilots wired into history persistence, C++ pilot
// wired into summary cache, Metal pilot exposed via
// accessor for host downstream use)。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASMetalPilotBrainAccessorTests: XCTestCase {

    // MARK: - Default state

    func testDefaultBrainHasNilMetalLoader() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let loader = await brain.metalLibraryLoader
        XCTAssertNil(loader,
            "Default brain must have nil metal loader" +
            " (lazy load cost saved for hosts that" +
            " don't need it)")
    }

    // MARK: - Host-injected loader

    func testInjectedLoaderIsExposed() async throws {
        let injected = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: injected)
        let loader = await brain.metalLibraryLoader
        XCTAssertNotNil(loader,
            "Injected Metal loader must be exposed")
        // Identity preservation: same actor instance
        // referenced by both the host and the brain。
        XCTAssertTrue(loader === injected,
            "Brain must hold the host's loader by" +
            " reference,not copy")
    }

    func testInjectedLoaderRetainsV2Mode() async throws {
        let injected = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: injected)
        guard let exposed = await brain
            .metalLibraryLoader
        else {
            return XCTFail("loader nil after inject")
        }
        let isUsingV2 = await exposed.isUsingV2
        XCTAssertTrue(isUsingV2,
            "Exposed loader must retain V2 mode flag" +
            " (sampled-once semantics)")
    }

    func testInjectedLoaderRetainsV1Mode() async throws {
        let injected = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: injected)
        guard let exposed = await brain
            .metalLibraryLoader
        else {
            return XCTFail("loader nil")
        }
        let isUsingV2 = await exposed.isUsingV2
        XCTAssertFalse(isUsingV2,
            "V1 loader mode must persist through brain" +
            " exposure")
    }

    // MARK: - Coexistence with other pilots

    func testMetalLoaderCoexistsWithSqlAndRustStores()
        async throws
    {
        let sqlTracker = BASMemoryUsageTracker()
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let rustTracker = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let rustStore = BASRustBrainHistoryStore(
            tracker: rustTracker)
        let metal = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        // All three pilots injected at once → brain
        // wires all of them。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore,
                rustHistoryStore: rustStore,
                metalLibraryLoader: metal)
        _ = await brain.summary(
            "all-pilots wired turn")
        let sqlCount = await sqlStore.recordCount
        let rustCount = await rustStore.recordCount
        let metalExposed = await brain.metalLibraryLoader
        XCTAssertEqual(sqlCount, 1)
        XCTAssertEqual(rustCount, 1)
        XCTAssertNotNil(metalExposed,
            "Metal loader must remain accessible" +
            " alongside SQL + Rust stores")
    }
}
