// MARK: - BASCognitiveBrainHealthSnapshotProbeWireInTests
// 严查 修复: brain.healthSnapshot() now ACTUALLY surfaces:
//   - The 5 C-pilot probes (RSS / threads / CPU / uptime
//     / physical memory) — previously created in
//     BASRuntimeCore but consumed nowhere
//   - SQL Round-3 temporal aggregates (oldest/newest +
//     helped_flag distribution) — previously wired
//     through BASSQLBrainHistoryStore but never read

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainHealthSnapshotProbeWireInTests:
    XCTestCase
{
    // MARK: - C probes wired into healthSnapshot

    func testHealthSnapshotIncludesCSystemProbes()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let snap = await brain.healthSnapshot()
        XCTAssertNotNil(snap.cSystemProbes,
            "C-pilot probes must populate in the unified" +
            " snapshot (the previous gap)")
        let probes = snap.cSystemProbes!
        // Apple silicon must populate every probe field
        XCTAssertNotNil(probes.residentMemoryBytes)
        XCTAssertNotNil(probes.threadCount)
        XCTAssertNotNil(probes.logicalCpuCount)
        XCTAssertNotNil(probes.systemUptimeSeconds)
        XCTAssertNotNil(probes.physicalMemoryBytes)
    }

    func testCSystemProbesSanityBounds() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let snap = await brain.healthSnapshot()
        let probes = snap.cSystemProbes!
        XCTAssertGreaterThan(
            probes.residentMemoryBytes ?? 0, 0)
        XCTAssertGreaterThan(probes.threadCount ?? 0, 0)
        XCTAssertGreaterThan(
            probes.logicalCpuCount ?? 0, 0)
        XCTAssertGreaterThan(
            probes.systemUptimeSeconds ?? 0, 0)
        XCTAssertGreaterThan(
            probes.physicalMemoryBytes ?? 0,
            1_000_000_000)  // > 1 GB
    }

    func testResidentMemoryFractionDerivedField()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let snap = await brain.healthSnapshot()
        let probes = snap.cSystemProbes!
        let fraction = probes.residentMemoryFraction
        XCTAssertNotNil(fraction)
        XCTAssertGreaterThan(fraction!, 0)
        XCTAssertLessThan(fraction!, 1.0,
            "Our RSS must be < total physical RAM")
    }

    func testResidentMemoryFractionNilOnMissing() {
        let probes = BASCognitiveBrainCSystemProbeSnapshot(
            residentMemoryBytes: nil,
            threadCount: 5,
            logicalCpuCount: 10,
            systemUptimeSeconds: 1000,
            physicalMemoryBytes: 16_000_000_000)
        XCTAssertNil(probes.residentMemoryFraction,
            "Nil RSS → nil fraction")
    }

    func testProbeSnapshotCodableRoundTrip() throws {
        let probes = BASCognitiveBrainCSystemProbeSnapshot(
            residentMemoryBytes: 50_000_000,
            threadCount: 8,
            logicalCpuCount: 12,
            systemUptimeSeconds: 3600,
            physicalMemoryBytes: 16_000_000_000)
        let data = try JSONEncoder().encode(probes)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainCSystemProbeSnapshot.self,
            from: data)
        XCTAssertEqual(decoded, probes)
        XCTAssertEqual(
            decoded.residentMemoryFraction ?? 0,
            50_000_000.0 / 16_000_000_000.0,
            accuracy: 1e-9)
    }

    // MARK: - SQL aggregation Round-3 wired through

    func testSQLAggregationIncludesOldestNewest()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("first")
        _ = await brain.summary("second")
        let snap = await brain.healthSnapshot()
        let sql = snap.sqlAggregation!
        XCTAssertNotNil(sql.oldestRecordAt,
            "Oldest timestamp must surface in SQL" +
            " aggregation (previous gap)")
        XCTAssertNotNil(sql.newestRecordAt)
        XCTAssertGreaterThanOrEqual(
            sql.newestRecordAt!, sql.oldestRecordAt!,
            "Newest must be >= oldest")
    }

    func testSQLAggregationIncludesHelpedFlagDistribution()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        let snap = await brain.healthSnapshot()
        let sql = snap.sqlAggregation!
        XCTAssertEqual(sql.recordsByHelpedFlag["unknown"],
            2,
            "Both brain.summary calls default helped=unknown")
    }

    func testSQLAggregationTimeSpanDerivedField()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("first")
        // ~50ms delay so the time span is measurable
        try await Task.sleep(nanoseconds: 50_000_000)
        _ = await brain.summary("second")
        let snap = await brain.healthSnapshot()
        let sql = snap.sqlAggregation!
        let span = sql.recordsTimeSpanSeconds
        XCTAssertNotNil(span)
        XCTAssertGreaterThanOrEqual(span!, 0.04,
            "≥ 40ms (we slept 50ms;allow some slack" +
            " for clock resolution)")
    }

    func testEmptySQLAggregationTimeSpanIsNil() throws {
        let agg = BASSQLBrainHistoryStoreAggregation(
            totalRecords: 0,
            recordsByPermitMode: [:],
            turnsThisSession: 0,
            isSQLBacked: true,
            distinctSessions: 0)
        XCTAssertNil(agg.oldestRecordAt)
        XCTAssertNil(agg.newestRecordAt)
        XCTAssertNil(agg.recordsTimeSpanSeconds,
            "Empty SQL → nil time span")
        XCTAssertEqual(agg.recordsByHelpedFlag, [:])
    }

    // MARK: - healthSnapshot Codable round-trip

    func testHealthSnapshotCodableWithNewFields()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        _ = await brain.summary("hello")
        let original = await brain.healthSnapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(
            BASCognitiveBrainHealthSnapshot.self,
            from: data)
        // C probes survive round-trip
        XCTAssertEqual(
            decoded.cSystemProbes?.residentMemoryBytes,
            original.cSystemProbes?.residentMemoryBytes)
        XCTAssertEqual(
            decoded.cSystemProbes?.logicalCpuCount,
            original.cSystemProbes?.logicalCpuCount)
        // SQL temporal fields survive
        XCTAssertEqual(
            decoded.sqlAggregation?.recordsByHelpedFlag,
            original.sqlAggregation?
                .recordsByHelpedFlag)
    }

    // MARK: - Bare brain doesn't surface C probes (they need V2 path)
    // Note: even bare brain, the C probes ARE captured
    // because BASProcessMemoryProbe(useCBridge: true)
    // doesn't depend on the brain's pilot wiring — it's
    // a direct system call。 So they ARE populated even
    // in the bare brain。 Pin that semantic。

    func testBareBrainStillGetsCProbes() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let snap = await brain.healthSnapshot()
        // C probes are NOT gated on pilot wiring — they
        // always populate when the C bridge is available。
        XCTAssertNotNil(snap.cSystemProbes,
            "C probes are always available — they don't" +
            " require a wired SQL/Rust/C++/Metal pilot")
        XCTAssertNotNil(
            snap.cSystemProbes?.residentMemoryBytes)
    }
}
#endif
