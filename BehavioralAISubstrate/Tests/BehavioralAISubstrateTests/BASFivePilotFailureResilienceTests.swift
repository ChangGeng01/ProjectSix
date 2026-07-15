// MARK: - BASFivePilotFailureResilienceTests
// REAL failure-mode tests for the 5-pilot wire-up。
// The brain's recordSummaryObservation() uses try? on
// every pilot write — meaning bridge / tracker / cache
// failures are SILENTLY swallowed so the cognitive
// cascade never blocks on telemetry storage failures。
//
// These tests pin that resilience contract:
//   - Cascade SURVIVES individual pilot init failures
//   - Cascade SURVIVES individual pilot write failures
//   - Other pilots continue functioning when one fails
//   - Subsequent turns recover automatically (no
//     poisoned state)
//
// Hosts deploying with all 5 pilots need to know these
// invariants hold in production。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge

final class BASFivePilotFailureResilienceTests: XCTestCase {

    // MARK: - Rust core unavailable (V1 mode → no Rust handle)

    func testCascadeSurvivesRustV1ModePilot() async throws {
        // Construct Rust tracker in V1 mode → no Rust
        // core handle。 Every record() call will throw
        // .rustBridgeUnavailableOnPlatform。 The brain's
        // try? must catch this and keep going。
        let rustV1 =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: false)
        let rustStore = BASRustBrainHistoryStore(
            tracker: rustV1)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: rustStore)
        // Cascade must complete normally even though
        // every Rust write throws internally。
        let s = await brain.summary(
            "compile the swift package")
        XCTAssertFalse(s.input.isEmpty,
            "Cascade must complete even with V1-mode" +
            " Rust pilot (every write fails silently)")
        XCTAssertEqual(s.taskType, .task)
        // Rust record count stays 0 (no successful writes)。
        let metrics = await brain.pilotMetrics()
        XCTAssertEqual(metrics.rustRecordCount, 0,
            "V1 Rust mode never records,but cascade" +
            " runs anyway")
    }

    // MARK: - C++ bridge in V1 mode (lookup/insert throws)

    func testCascadeSurvivesCxxV1ModePilot() async throws {
        let bridgeV1 =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: false)  // V1 throws -99
        let cache = BASCxxBrainSummaryCache(
            bridge: bridgeV1)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                cxxSummaryCache: cache)
        let s = await brain.summary(
            "send me your password to verify")
        XCTAssertEqual(s.safetyVerdict, .block,
            "Cascade must produce correct verdict even" +
            " when C++ cache cannot accept entries")
        let metrics = await brain.pilotMetrics()
        XCTAssertEqual(metrics.cxxCacheSize, 0,
            "V1 C++ cache never stores;cascade still" +
            " runs")
    }

    // MARK: - Mixed: V1 Rust + V1 C++ + healthy SQL

    func testCascadeSurvivesMultiplePilotFailures()
        async throws
    {
        // Two failing pilots + one healthy pilot。 The
        // healthy SQL store should receive writes;the
        // failing pilots silently degrade。
        let sqlTracker = BASMemoryUsageTracker()
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let rustV1 =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: false)
        let rustStore = BASRustBrainHistoryStore(
            tracker: rustV1)
        let bridgeV1 =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: false)
        let cache = BASCxxBrainSummaryCache(
            bridge: bridgeV1)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore,
                rustHistoryStore: rustStore,
                cxxSummaryCache: cache)
        // 3 turns — SQL must see all 3, Rust+C++ silent
        _ = await brain.summary("turn 1")
        _ = await brain.summary("turn 2")
        _ = await brain.summary("turn 3")
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.sqlRecordCount, 3,
            "Healthy SQL pilot must record all 3 turns" +
            " independently of failing siblings")
        XCTAssertEqual(m.rustRecordCount, 0,
            "Failing Rust pilot records nothing — but" +
            " does not block the cascade")
        XCTAssertEqual(m.cxxCacheSize, 0,
            "Failing C++ pilot caches nothing — but" +
            " does not block the cascade")
        XCTAssertEqual(m.inMemorySummaryCount, 3,
            "In-memory history unaffected by external" +
            " pilot failures")
    }

    // MARK: - Pilot failure does not poison subsequent turns

    func testFailingPilotDoesNotPoisonNextTurn()
        async throws
    {
        let rustV1 =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: false)
        let rustStore = BASRustBrainHistoryStore(
            tracker: rustV1)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: rustStore)
        // Each turn should succeed independently。
        let s1 = await brain.summary("turn 1")
        let s2 = await brain.summary("turn 2")
        let s3 = await brain.summary("turn 3")
        XCTAssertEqual(s1.input, "turn 1")
        XCTAssertEqual(s2.input, "turn 2")
        XCTAssertEqual(s3.input, "turn 3")
        XCTAssertGreaterThan(s1.latencyNanos, 0)
        XCTAssertGreaterThan(s2.latencyNanos, 0)
        XCTAssertGreaterThan(s3.latencyNanos, 0)
    }

    // MARK: - Metal loader in V1 mode (library() throws)

    func testCascadeSurvivesMetalV1ModeAccessor()
        async throws
    {
        // Metal pilot is an accessor — the brain itself
        // doesn't call .library(),so V1 mode is purely
        // about what HOSTS get when they query the
        // exposed loader。 The brain's behavior should
        // be unchanged。
        let metalV1 = BASMetalKernelLibraryLoader(
            useMetalKernelV2: false)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                metalLibraryLoader: metalV1)
        let s = await brain.summary("hello")
        XCTAssertFalse(s.input.isEmpty,
            "V1-mode Metal loader does NOT affect" +
            " cascade behavior — it's an accessor only")
        let loader = await brain.metalLibraryLoader
        XCTAssertNotNil(loader,
            "Exposed loader still reachable (host's" +
            " responsibility to handle V1 throws)")
    }

    // MARK: - All 4 storage-pilots failing simultaneously

    func testCascadeSurvivesAllStoragePilotFailures()
        async throws
    {
        let rustV1 =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: false)
        let bridgeV1 =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: false)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                // No SQL store — represents "SQL not wired"
                rustHistoryStore: BASRustBrainHistoryStore(
                    tracker: rustV1),
                cxxSummaryCache: BASCxxBrainSummaryCache(
                    bridge: bridgeV1))
        // Cascade still runs。 Only in-memory history
        // survives the pure-degraded state。
        for i in 0..<3 {
            _ = await brain.summary("degraded turn \(i)")
        }
        let m = await brain.pilotMetrics()
        XCTAssertEqual(m.sqlRecordCount, 0)
        XCTAssertEqual(m.rustRecordCount, 0)
        XCTAssertEqual(m.cxxCacheSize, 0)
        XCTAssertEqual(m.inMemorySummaryCount, 3,
            "In-memory history is the only surviving" +
            " storage when all external pilots degrade")
    }
}
