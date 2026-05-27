// MARK: - BASCognitiveBrainPilotStatusTests
// REAL tests for the brain.pilotStatus accessor that
// reports which of the 5 multi-language pilots are
// wired into a given brain instance。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainPilotStatusTests: XCTestCase {

    // MARK: - Bare brain — only C pilot active

    func testBareBrainHasOnlyCPilotActive() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let status = await brain.pilotStatus
        XCTAssertTrue(status.cActive,
            "C pilot must always be active")
        XCTAssertFalse(status.sqlActive)
        XCTAssertFalse(status.cxxActive)
        XCTAssertFalse(status.rustActive)
        XCTAssertFalse(status.metalActive)
        XCTAssertEqual(status.activeCount, 1)
        XCTAssertFalse(status.allActive)
    }

    // MARK: - Each pilot toggles independently

    func testSQLPilotMarksActive() async throws {
        let sqlTracker = BASMemoryUsageTracker()
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore)
        let status = await brain.pilotStatus
        XCTAssertTrue(status.sqlActive)
        XCTAssertEqual(status.activeCount, 2,
            "C + SQL active")
    }

    func testRustPilotMarksActive() async throws {
        let rustTracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let rustStore = BASRustBrainHistoryStore(
            tracker: rustTracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: rustStore)
        let status = await brain.pilotStatus
        XCTAssertTrue(status.rustActive)
        XCTAssertEqual(status.activeCount, 2,
            "C + Rust active")
    }

    func testCxxPilotMarksActive() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        let cache = BASCxxBrainSummaryCache(
            bridge: bridge)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                cxxSummaryCache: cache)
        let status = await brain.pilotStatus
        XCTAssertTrue(status.cxxActive)
        XCTAssertEqual(status.activeCount, 2,
            "C + C++ active")
        try? await bridge.clear()
    }

    func testMetalPilotMarksActive() async throws {
        let metal = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: metal)
        let status = await brain.pilotStatus
        XCTAssertTrue(status.metalActive)
        XCTAssertEqual(status.activeCount, 2,
            "C + Metal active")
    }

    // MARK: - All 5 pilots active

    func testAllFivePilotsActive() async throws {
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: BASMemoryUsageTracker())
        let rustStore = BASRustBrainHistoryStore(
            tracker:
                try BASRustMemoryUsageTrackerActor(
                    useRustCore: true))
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        let cache = BASCxxBrainSummaryCache(
            bridge: bridge)
        let metal = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore,
                rustHistoryStore: rustStore,
                cxxSummaryCache: cache,
                metalLibraryLoader: metal)
        let status = await brain.pilotStatus
        XCTAssertTrue(status.allActive,
            "All 5 pilots wired → allActive must be true")
        XCTAssertEqual(status.activeCount, 5)
        try? await bridge.clear()
    }

    // MARK: - Codable round-trip

    func testPilotStatusCodableRoundTrip() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let original = await brain.pilotStatus
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainPilotStatus.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Status is stable across summary() calls

    func testPilotStatusStableAcrossTurns() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let before = await brain.pilotStatus
        _ = await brain.summary("hello")
        _ = await brain.summary("world")
        let after = await brain.pilotStatus
        XCTAssertEqual(before, after,
            "pilotStatus is construction-time stable;" +
            " summary calls must NOT mutate it")
    }
}
#endif
