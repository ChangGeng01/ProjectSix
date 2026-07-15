// MARK: - BASCognitiveBrainPilotMetricsTests
// REAL tests for the brain.pilotMetrics() snapshot +
// brain.clearVolatilePilotStorage() lifecycle helper。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASCognitiveBrainPilotMetricsTests: XCTestCase {

    // MARK: - Bare brain — zero records, zero cache

    func testBareBrainMetricsAreAllZero() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.sqlRecordCount, 0)
        XCTAssertEqual(m.rustRecordCount, 0)
        XCTAssertEqual(m.cxxCacheSize, 0)
        XCTAssertEqual(m.inMemorySummaryCount, 0)
        XCTAssertEqual(m.totalStorageEvents, 0)
    }

    // MARK: - In-memory history grows with summary() calls

    func testInMemoryCountGrowsWithSummaryCalls()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("turn 1")
        _ = await brain.summary("turn 2")
        _ = await brain.summary("turn 3")
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.inMemorySummaryCount, 3)
    }

    // MARK: - SQL record count reflects writes

    func testSQLRecordCountReflectsWrites() async throws {
        let sqlTracker = BASMemoryUsageTracker()
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore)
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.sqlRecordCount, 2)
        XCTAssertEqual(m.rustRecordCount, 0)
        XCTAssertEqual(m.cxxCacheSize, 0)
        XCTAssertEqual(m.totalStorageEvents, 4,
            "2 SQL + 2 in-memory = 4 total")
    }

    // MARK: - Rust record count reflects writes

    func testRustRecordCountReflectsWrites() async throws {
        let rust = BASRustBrainHistoryStore(
            tracker: try BASRustMemoryUsageTrackerActor(
                useRustCore: true))
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: rust)
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        _ = await brain.summary("c")
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.rustRecordCount, 3)
    }

    // MARK: - C++ cache size reflects distinct inputs

    func testCxxCacheSizeReflectsDistinctInputs()
        async throws
    {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        let cache = BASCxxBrainSummaryCache(
            bridge: bridge)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                cxxSummaryCache: cache)
        // 3 distinct inputs + 2 repeat → C++ caches 3
        _ = await brain.summary("alpha")
        _ = await brain.summary("alpha")  // hit
        _ = await brain.summary("beta")
        _ = await brain.summary("alpha")  // hit
        _ = await brain.summary("gamma")
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.cxxCacheSize, 3,
            "C++ cache holds 3 distinct entries" +
            " (alpha, beta, gamma)")
        try? await bridge.clear()
    }

    // MARK: - All 4 storage-shaped pilots aggregated

    func testTotalStorageEventsAcrossAllPilots()
        async throws
    {
        let sql = BASSQLBrainHistoryStore(
            tracker: BASMemoryUsageTracker())
        let rust = BASRustBrainHistoryStore(
            tracker: try BASRustMemoryUsageTrackerActor(
                useRustCore: true))
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        let cache = BASCxxBrainSummaryCache(
            bridge: bridge)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sql,
                rustHistoryStore: rust,
                cxxSummaryCache: cache)
        // 5 distinct turns → SQL=5, Rust=5, C++=5,
        // in-memory=5 → total = 20
        for i in 0..<5 {
            _ = await brain.summary("unique \(i)")
        }
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.sqlRecordCount, 5)
        XCTAssertEqual(m.rustRecordCount, 5)
        XCTAssertEqual(m.cxxCacheSize, 5)
        XCTAssertEqual(m.inMemorySummaryCount, 5)
        XCTAssertEqual(m.totalStorageEvents, 20)
        try? await bridge.clear()
    }

    // MARK: - Codable round-trip

    func testPilotMetricsCodableRoundTrip() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("test")
        let original = await brain.pilotMetrics()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainPilotMetrics.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - clearVolatilePilotStorage

    func testClearVolatileClearsInMemoryHistory()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        _ = await brain.summary("turn 1")
        _ = await brain.summary("turn 2")
        let before = await brain.pilotMetrics()
        XCTAssertEqual(before.inMemorySummaryCount, 2)
        await brain.clearVolatilePilotStorage()
        let after = await brain.pilotMetrics()
        XCTAssertEqual(after.inMemorySummaryCount, 0)
    }

    func testClearVolatileClearsCxxCache() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        let cache = BASCxxBrainSummaryCache(
            bridge: bridge)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                cxxSummaryCache: cache)
        _ = await brain.summary("turn 1")
        _ = await brain.summary("turn 2")
        let before = await brain.pilotMetrics()
        XCTAssertEqual(before.cxxCacheSize, 2)
        await brain.clearVolatilePilotStorage()
        let after = await brain.pilotMetrics()
        XCTAssertEqual(after.cxxCacheSize, 0)
        try? await bridge.clear()
    }

    func testClearVolatileDoesNotClearDurableStores()
        async throws
    {
        // Critical invariant: durable history is NOT
        // affected by volatile-clear。 Hosts wanting to
        // wipe SQL/Rust must call the underlying tracker
        // APIs directly。
        let sql = BASSQLBrainHistoryStore(
            tracker: BASMemoryUsageTracker())
        let rust = BASRustBrainHistoryStore(
            tracker: try BASRustMemoryUsageTrackerActor(
                useRustCore: true))
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sql,
                rustHistoryStore: rust)
        _ = await brain.summary("durable turn 1")
        _ = await brain.summary("durable turn 2")
        await brain.clearVolatilePilotStorage()
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.sqlRecordCount, 2,
            "SQL records must survive volatile clear")
        XCTAssertEqual(m.rustRecordCount, 2,
            "Rust records must survive volatile clear")
        XCTAssertEqual(m.inMemorySummaryCount, 0)
    }
}
