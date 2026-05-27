// MARK: - BASCognitiveBrainConfigSnapshotTests
// REAL tests for brain.configSnapshot() — the runtime
// configuration introspection surface that completes
// the observability triad (status + metrics + config)。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainConfigSnapshotTests: XCTestCase {

    // MARK: - Default brain settings

    func testDefaultConfigSnapshot() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let snap = await brain.configSnapshot()
        XCTAssertEqual(snap.summaryHistoryCapacity,
            BASCognitiveBrain
                .defaultSummaryHistoryCapacity)
        XCTAssertEqual(snap.safetyConfidenceThreshold,
            BASCognitiveBrain.safetyConfidenceThreshold)
        XCTAssertTrue(snap.pilotStatus.cActive)
        XCTAssertFalse(snap.pilotStatus.sqlActive)
    }

    // MARK: - Custom settings reach the snapshot

    func testCustomHistoryCapacityReachesSnapshot()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                summaryHistoryCapacity: 42)
        let snap = await brain.configSnapshot()
        XCTAssertEqual(snap.summaryHistoryCapacity, 42)
    }

    func testCustomThresholdReachesSnapshot() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 0.85)
        let snap = await brain.configSnapshot()
        XCTAssertEqual(snap.safetyConfidenceThreshold,
            0.85)
    }

    func testClampedThresholdReachesSnapshot()
        async throws
    {
        // Negative input clamps to 0 in the brain。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: -0.5)
        let snap = await brain.configSnapshot()
        XCTAssertEqual(snap.safetyConfidenceThreshold,
            0.0,
            "Negative threshold input must clamp to 0" +
            " and reach the snapshot as 0")
    }

    // MARK: - Pilot status embedded

    func testPilotStatusEmbeddedInConfigSnapshot()
        async throws
    {
        let sqlTracker = BASMemoryUsageTracker()
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore)
        let snap = await brain.configSnapshot()
        XCTAssertTrue(snap.pilotStatus.sqlActive,
            "configSnapshot.pilotStatus must reflect" +
            " wired SQL pilot")
        XCTAssertEqual(snap.pilotStatus.activeCount, 2,
            "C (built-in) + SQL active")
    }

    // MARK: - Codable round-trip

    func testConfigSnapshotCodableRoundTrip() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                summaryHistoryCapacity: 75,
                safetyConfidenceThreshold: 0.7)
        let original = await brain.configSnapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainConfigSnapshot.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Snapshot is stable across summary() calls

    func testConfigSnapshotIsStableAcrossTurns()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                safetyConfidenceThreshold: 0.55)
        let before = await brain.configSnapshot()
        _ = await brain.summary("turn 1")
        _ = await brain.summary("turn 2")
        let after = await brain.configSnapshot()
        XCTAssertEqual(before, after,
            "configSnapshot is construction-time stable;" +
            " summary calls must NOT mutate it")
    }

    // MARK: - Snapshot is cheap (no cascade run)

    func testConfigSnapshotIsFast() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let start = Date()
        for _ in 0..<100 {
            _ = await brain.configSnapshot()
        }
        let elapsed = Date().timeIntervalSince(start)
        // 100 snapshots in under 100ms → ~1ms each。
        // No cascade run means it's much faster than
        // process() / summary() / cascadeDigest()。
        XCTAssertLessThan(elapsed, 0.1,
            "100 configSnapshot calls took \(elapsed)s," +
            " expected < 100ms (cheap accessor,no" +
            " cascade run)")
    }
}
#endif
