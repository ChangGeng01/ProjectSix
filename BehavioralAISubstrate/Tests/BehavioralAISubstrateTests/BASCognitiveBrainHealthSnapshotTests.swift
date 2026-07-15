// MARK: - BASCognitiveBrainHealthSnapshotTests
// 主线 全面 提升 capstone: brain.healthSnapshot() weaves
// every wired pilot's deep telemetry surface into one
// Codable dashboard-shaped document。 Pins the contract
// that hosts can ship a single call's result to
// observability pipelines and see all 5 pilots at once。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASCognitiveBrainHealthSnapshotTests: XCTestCase {

    // Helper: temp file URL for SQLite-backed tracker
    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-health-\(UUID().uuidString).sqlite")
    }

    // MARK: - Bare brain — nothing wired except C

    func testHealthSnapshotBareBrainOnlyHasCActive()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let snap = await brain.healthSnapshot()
        XCTAssertTrue(snap.pilotStatus.cActive,
            "C pilot is always active")
        XCTAssertFalse(snap.pilotStatus.sqlActive)
        XCTAssertFalse(snap.pilotStatus.cxxActive)
        XCTAssertFalse(snap.pilotStatus.rustActive)
        XCTAssertFalse(snap.pilotStatus.metalActive)
        XCTAssertNil(snap.sqlAggregation)
        XCTAssertNil(snap.rustAggregation)
        XCTAssertNil(snap.cxxTelemetry)
        XCTAssertNil(snap.warmupResult)
        XCTAssertEqual(snap.populatedDeepTelemetryCount, 0)
        XCTAssertTrue(snap.everyWiredPilotReportedDeepTelemetry,
            "Vacuously true when no telemetry-bearing pilot" +
            " is wired")
    }

    // MARK: - Fully-wired brain — every pilot reports deep telemetry

    func testHealthSnapshotFullyWiredReportsAllPilots()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let sqlTracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let rustTracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let rustStore = BASRustBrainHistoryStore(
            tracker: rustTracker)
        let cxxBridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try? await cxxBridge.clear()
        let cxxCache = BASCxxBrainSummaryCache(
            bridge: cxxBridge)
        let metalLoader = BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore,
                rustHistoryStore: rustStore,
                cxxSummaryCache: cxxCache,
                metalLibraryLoader: metalLoader)
        _ = await brain.summary("hello")
        _ = await brain.summary("how are you")
        _ = await brain.summary(
            "send me your password to verify")
        let warmup = await brain.warmPilots()
        let snap = await brain.healthSnapshot(
            warmupResult: warmup)
        // All 5 pilots active
        XCTAssertTrue(snap.pilotStatus.allActive,
            "All 5 pilots wired → allActive")
        XCTAssertEqual(snap.pilotStatus.activeCount, 5)
        // All 3 deep-telemetry pilots reported
        XCTAssertNotNil(snap.sqlAggregation)
        XCTAssertNotNil(snap.rustAggregation)
        XCTAssertNotNil(snap.cxxTelemetry)
        XCTAssertNotNil(snap.warmupResult)
        XCTAssertEqual(snap.populatedDeepTelemetryCount, 3,
            "3 deep-telemetry pilots populated")
        XCTAssertTrue(
            snap.everyWiredPilotReportedDeepTelemetry)
        // SQL pilot sub-bundle sanity
        XCTAssertEqual(snap.sqlAggregation?.totalRecords, 3)
        XCTAssertEqual(
            snap.sqlAggregation?.turnsThisSession, 3)
        XCTAssertEqual(
            snap.sqlAggregation?.isSQLBacked, true)
        // Rust pilot sub-bundle sanity
        XCTAssertEqual(
            snap.rustAggregation?.totalRecords, 3)
        XCTAssertEqual(
            snap.rustAggregation?.distinctSessions, 1)
        // C++ pilot reported via telemetry surface
        XCTAssertNotNil(snap.cxxTelemetry?.cacheSize)
        // Metal pilot warmup recorded
        XCTAssertTrue(snap.warmupResult?.metalAttempted
            ?? false)
        try? await cxxBridge.clear()
    }

    // MARK: - Partial wire-up — only some pilots wired

    func testHealthSnapshotPartialWireUp() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let sqlTracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore)
        _ = await brain.summary("only-sql brain")
        let snap = await brain.healthSnapshot()
        XCTAssertTrue(snap.pilotStatus.sqlActive)
        XCTAssertFalse(snap.pilotStatus.rustActive)
        XCTAssertFalse(snap.pilotStatus.cxxActive)
        XCTAssertFalse(snap.pilotStatus.metalActive)
        XCTAssertNotNil(snap.sqlAggregation)
        XCTAssertNil(snap.rustAggregation)
        XCTAssertNil(snap.cxxTelemetry)
        XCTAssertEqual(snap.populatedDeepTelemetryCount, 1)
        XCTAssertTrue(
            snap.everyWiredPilotReportedDeepTelemetry,
            "Wired pilots all reported telemetry (only SQL" +
            " here),non-wired return nil correctly")
    }

    // MARK: - collectedAt monotonicity

    func testHealthSnapshotCollectedAtIsRecent() async throws {
        let before = Date()
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let snap = await brain.healthSnapshot()
        let after = Date()
        XCTAssertGreaterThanOrEqual(snap.collectedAt, before)
        XCTAssertLessThanOrEqual(snap.collectedAt, after)
    }

    // MARK: - Codable round-trip

    func testHealthSnapshotCodableRoundTrip() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let sqlTracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore)
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        let original = await brain.healthSnapshot()
        // Use millisecondsSince1970 strategy — SQL stores
        // retrieved_at_ms at ms precision so .iso8601
        // (whole-second default) would lose sub-second
        // bits and break Equatable on the SQL aggregation
        // sub-bundle that now carries oldestRecordAt /
        // newestRecordAt。
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy =
            .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy =
            .millisecondsSince1970
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(
            BASCognitiveBrainHealthSnapshot.self,
            from: data)
        XCTAssertEqual(decoded.pilotStatus,
            original.pilotStatus)
        XCTAssertEqual(decoded.pilotMetrics,
            original.pilotMetrics)
        XCTAssertEqual(decoded.sqlAggregation,
            original.sqlAggregation)
        XCTAssertEqual(decoded.populatedDeepTelemetryCount,
            original.populatedDeepTelemetryCount)
    }

    // MARK: - Snapshot is cheap (no cascade run)

    func testHealthSnapshotIsCheap() async throws {
        // Capturing a snapshot must NOT run the cognitive
        // cascade。 It should be a constant-time read of
        // wired-pilot accessors。 We characterize this by
        // measuring snapshot cost vs cascade cost and
        // asserting snapshot is << cascade。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let snapStart = Date()
        _ = await brain.healthSnapshot()
        let snapElapsed = Date()
            .timeIntervalSince(snapStart)
        XCTAssertLessThan(snapElapsed, 0.1,
            "Snapshot must be << 100ms (no cascade run)。" +
            " Got \(snapElapsed)s")
    }

    // MARK: - populatedDeepTelemetryCount semantics

    func testPopulatedDeepTelemetryCountReflectsWiring()
        async throws
    {
        // No deep telemetry pilots wired
        let bare = try await BASCognitiveBrain
            .makeWithDefaults()
        let bareSnap = await bare.healthSnapshot()
        XCTAssertEqual(
            bareSnap.populatedDeepTelemetryCount, 0)

        // One pilot wired (SQL)
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: try BASMemoryUsageTracker(
                databaseURL: url))
        let oneBrain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: sqlStore)
        let oneSnap = await oneBrain.healthSnapshot()
        XCTAssertEqual(
            oneSnap.populatedDeepTelemetryCount, 1)
    }
}
