// MARK: - BASCognitiveBrainHealthTrendDeltaTests
// 主线 继续 开发: BASCognitiveBrainHealthSnapshotTrend
// now tracks C-probe deltas (RSS / threads / uptime)
// across the history buffer。 Hosts can detect memory
// leaks + thread leaks + use uptime delta as a sanity
// check for the span。

import XCTest
@testable import BASHostKit

final class BASCognitiveBrainHealthTrendDeltaTests:
    XCTestCase
{
    // MARK: - Codable round-trip with all new fields

    func testTrendCodableRoundTripWithCProbeDeltas()
        throws
    {
        let trend = BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: 5,
            spanSeconds: 60.0,
            totalStorageEventsDelta: 100,
            hitRateDelta: 0.15,
            cacheContentBytesDelta: 4096,
            residentMemoryDelta: 1024 * 1024,
            threadCountDelta: 2,
            systemUptimeDelta: 60)
        let data = try JSONEncoder().encode(trend)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainHealthSnapshotTrend.self,
            from: data)
        XCTAssertEqual(decoded, trend)
        XCTAssertEqual(decoded.residentMemoryDelta,
            1024 * 1024)
        XCTAssertEqual(decoded.threadCountDelta, 2)
        XCTAssertEqual(decoded.systemUptimeDelta, 60)
    }

    func testTrendBackwardCompatNilCProbeDeltas() {
        // Legacy initializer (no new args) defaults to
        // nil for all C-probe deltas。 Preserves
        // backward-compat with stored historical trend
        // data。
        let trend = BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: 1,
            spanSeconds: 0,
            totalStorageEventsDelta: 0,
            hitRateDelta: nil,
            cacheContentBytesDelta: nil)
        XCTAssertNil(trend.residentMemoryDelta)
        XCTAssertNil(trend.threadCountDelta)
        XCTAssertNil(trend.systemUptimeDelta)
    }

    // MARK: - Derived: bytes-per-second

    func testResidentMemoryBytesPerSecondPositive() {
        let trend = BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: 2, spanSeconds: 10.0,
            totalStorageEventsDelta: 0,
            hitRateDelta: nil,
            cacheContentBytesDelta: nil,
            residentMemoryDelta: 1_000_000)
        XCTAssertEqual(
            trend.residentMemoryBytesPerSecond ?? 0,
            100_000.0, accuracy: 1e-6,
            "1MB over 10s → 100KB/s")
    }

    func testResidentMemoryBytesPerSecondNegative() {
        let trend = BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: 2, spanSeconds: 5.0,
            totalStorageEventsDelta: 0,
            hitRateDelta: nil,
            cacheContentBytesDelta: nil,
            residentMemoryDelta: -500_000)
        XCTAssertEqual(
            trend.residentMemoryBytesPerSecond ?? 0,
            -100_000.0, accuracy: 1e-6,
            "RSS shrink reflected as negative rate")
    }

    func testBytesPerSecondNilOnZeroSpan() {
        let trend = BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: 2, spanSeconds: 0,
            totalStorageEventsDelta: 0,
            hitRateDelta: nil,
            cacheContentBytesDelta: nil,
            residentMemoryDelta: 1_000_000)
        XCTAssertNil(trend.residentMemoryBytesPerSecond)
    }

    func testBytesPerSecondNilOnNilDelta() {
        let trend = BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: 2, spanSeconds: 10,
            totalStorageEventsDelta: 0,
            hitRateDelta: nil,
            cacheContentBytesDelta: nil,
            residentMemoryDelta: nil)
        XCTAssertNil(trend.residentMemoryBytesPerSecond)
    }

    // MARK: - End-to-end via brain history

    func testTrendPopulatesCProbeDeltasFromHistory()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 5)
        _ = await brain.recordHealthSnapshot()
        // Brain activity to allocate memory + run
        _ = await brain.summary("event one")
        _ = await brain.summary("event two")
        _ = await brain.summary("event three")
        try await Task.sleep(nanoseconds: 100_000_000)
        _ = await brain.recordHealthSnapshot()
        let history = await brain.healthHistory
        let trend = await history!.trendSummary()
        XCTAssertNotNil(trend)
        // C-probe deltas should populate since both
        // captures have cSystemProbes
        XCTAssertNotNil(trend?.residentMemoryDelta,
            "C probes captured in both snapshots →" +
            " delta populated")
        XCTAssertNotNil(trend?.threadCountDelta)
        XCTAssertNotNil(trend?.systemUptimeDelta)
        // Uptime delta should be ≥ 0 (host clock
        // forward-only)
        XCTAssertGreaterThanOrEqual(
            trend?.systemUptimeDelta ?? -1, 0)
    }

    // MARK: - Saturating UInt64 → Int64 delta semantics

    func testRSSGrowthEncodedAsPositiveDelta() async throws
    {
        // Build two snapshots manually with known
        // RSS values to exercise the saturating delta
        // helper directly via trend semantics。
        let probesOld =
            BASCognitiveBrainCSystemProbeSnapshot(
                residentMemoryBytes: 1_000_000,
                threadCount: 5,
                logicalCpuCount: 12,
                systemUptimeSeconds: 100,
                physicalMemoryBytes: 16_000_000_000)
        let probesNew =
            BASCognitiveBrainCSystemProbeSnapshot(
                residentMemoryBytes: 1_500_000,
                threadCount: 7,
                logicalCpuCount: 12,
                systemUptimeSeconds: 200,
                physicalMemoryBytes: 16_000_000_000)
        let snapOld = BASCognitiveBrainHealthSnapshot(
            pilotStatus: BASCognitiveBrainPilotStatus(
                cActive: true, sqlActive: false,
                cxxActive: false, rustActive: false,
                metalActive: false),
            pilotMetrics: BASCognitiveBrainPilotMetrics(
                sqlRecordCount: 0, rustRecordCount: 0,
                cxxCacheSize: 0, inMemorySummaryCount: 0),
            sqlAggregation: nil,
            rustAggregation: nil,
            cxxTelemetry: nil,
            warmupResult: nil,
            cSystemProbes: probesOld,
            collectedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let snapNew = BASCognitiveBrainHealthSnapshot(
            pilotStatus: snapOld.pilotStatus,
            pilotMetrics: snapOld.pilotMetrics,
            sqlAggregation: nil,
            rustAggregation: nil,
            cxxTelemetry: nil,
            warmupResult: nil,
            cSystemProbes: probesNew,
            collectedAt: Date(
                timeIntervalSince1970: 1_700_000_100))
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 5)
        await history.append(snapOld)
        await history.append(snapNew)
        let trend = await history.trendSummary()
        XCTAssertNotNil(trend)
        XCTAssertEqual(trend?.residentMemoryDelta,
            500_000,
            "RSS grew by 500_000 bytes")
        XCTAssertEqual(trend?.threadCountDelta, 2)
        XCTAssertEqual(trend?.systemUptimeDelta, 100)
    }

    func testRSSShrinkEncodedAsNegativeDelta() async throws
    {
        let probesOld =
            BASCognitiveBrainCSystemProbeSnapshot(
                residentMemoryBytes: 2_000_000,
                threadCount: 10,
                logicalCpuCount: 12,
                systemUptimeSeconds: 100,
                physicalMemoryBytes: 16_000_000_000)
        let probesNew =
            BASCognitiveBrainCSystemProbeSnapshot(
                residentMemoryBytes: 1_500_000,
                threadCount: 5,
                logicalCpuCount: 12,
                systemUptimeSeconds: 105,
                physicalMemoryBytes: 16_000_000_000)
        let snapOld = BASCognitiveBrainHealthSnapshot(
            pilotStatus: BASCognitiveBrainPilotStatus(
                cActive: true, sqlActive: false,
                cxxActive: false, rustActive: false,
                metalActive: false),
            pilotMetrics: BASCognitiveBrainPilotMetrics(
                sqlRecordCount: 0, rustRecordCount: 0,
                cxxCacheSize: 0, inMemorySummaryCount: 0),
            sqlAggregation: nil,
            rustAggregation: nil,
            cxxTelemetry: nil,
            warmupResult: nil,
            cSystemProbes: probesOld,
            collectedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let snapNew = BASCognitiveBrainHealthSnapshot(
            pilotStatus: snapOld.pilotStatus,
            pilotMetrics: snapOld.pilotMetrics,
            sqlAggregation: nil,
            rustAggregation: nil,
            cxxTelemetry: nil,
            warmupResult: nil,
            cSystemProbes: probesNew,
            collectedAt: Date(
                timeIntervalSince1970: 1_700_000_005))
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 5)
        await history.append(snapOld)
        await history.append(snapNew)
        let trend = await history.trendSummary()
        XCTAssertEqual(trend?.residentMemoryDelta,
            -500_000,
            "RSS shrink encoded as negative signed delta")
        XCTAssertEqual(trend?.threadCountDelta, -5,
            "Thread count drop encoded negative")
    }
}
