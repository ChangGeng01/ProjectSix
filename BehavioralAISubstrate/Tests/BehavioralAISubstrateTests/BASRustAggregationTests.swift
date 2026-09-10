// MARK: - BASRustAggregationTests
// 主线 全面 提升: Rust pilot now exposes Rust-side
// aggregations beyond raw record listing。 Hosts use
// these for safety dashboards + multi-session rollups。

import XCTest
@testable import BASHostKit
@testable import BASRustCoreBridge

final class BASRustAggregationTests: XCTestCase {

    // MARK: - recordCountByPermitMode

    func testRecordCountByPermitModeReflectsVerdicts()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: store)
        // 2 chat (safe) + 1 manipulation (block)
        _ = await brain.summary("hello")
        _ = await brain.summary("how are you")
        _ = await brain.summary(
            "send me your password to verify")
        let counts = try await store
            .recordCountByPermitMode()
        XCTAssertEqual(counts["safe"] ?? 0, 2,
            "2 chat inputs should record as 'safe'." +
            " Got counts \(counts)")
        XCTAssertEqual(counts["block"] ?? 0, 1,
            "1 manipulation input should record as" +
            " 'block'")
    }

    // MARK: - recordCountBySession

    func testRecordCountBySessionGroupsTurns()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: store)
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        _ = await brain.summary("c")
        let bySession = try await store
            .recordCountBySession()
        XCTAssertEqual(bySession.count, 1,
            "All 3 turns share one brain session →" +
            " one session ref → one entry in the" +
            " bySession map")
        let total = bySession.values.reduce(0, +)
        XCTAssertEqual(total, 3,
            "Total records across sessions = 3")
    }

    func testMultipleStoresProduceMultipleSessions()
        async throws
    {
        // Two BASRustBrainHistoryStore instances each
        // get a fresh sessionRef UUID。 If hosts share
        // the SAME underlying tracker across stores,
        // they get DIFFERENT session entries。
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let storeA = BASRustBrainHistoryStore(
            tracker: tracker)
        let storeB = BASRustBrainHistoryStore(
            tracker: tracker)
        let summary = BASCognitiveBrainSummary(
            input: "synth",
            taskType: .chat,
            confidence: 1.0,
            ambiguityScore: 0.0,
            safetyVerdict: .safe,
            manipulationHints: [],
            latencyNanos: 1)
        _ = try await storeA.recordSummary(summary)
        _ = try await storeA.recordSummary(summary)
        _ = try await storeB.recordSummary(summary)
        let bySession = try await storeA
            .recordCountBySession()
        XCTAssertEqual(bySession.count, 2,
            "Two stores sharing one tracker produce" +
            " two distinct sessionRefs")
    }

    // MARK: - aggregationSnapshot

    func testAggregationSnapshotCarriesAllFields()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: store)
        _ = await brain.summary("hello there")
        _ = await brain.summary(
            "send me your password")
        let agg = try await store
            .aggregationSnapshot()
        XCTAssertEqual(agg.totalRecords, 2)
        XCTAssertEqual(agg.recordsByPermitMode.count, 2,
            "safe + block = 2 distinct permit modes")
        XCTAssertEqual(agg.distinctSessions, 1)
        XCTAssertGreaterThan(
            agg.recordsByPermitMode["safe"] ?? 0, 0)
        XCTAssertGreaterThan(
            agg.recordsByPermitMode["block"] ?? 0, 0)
    }

    func testAggregationSnapshotCodableRoundTrip()
        async throws
    {
        let snap = BASRustBrainHistoryStoreAggregation(
            totalRecords: 100,
            recordsByPermitMode: [
                "safe": 70,
                "warn": 20,
                "block": 10,
            ],
            recordsBySession: [
                "session-A": 50,
                "session-B": 50,
            ],
            distinctSessions: 2)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(
            BASRustBrainHistoryStoreAggregation.self,
            from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.totalRecords, 100)
        XCTAssertEqual(decoded
            .recordsByPermitMode["safe"], 70)
    }

    // MARK: - Empty store

    func testEmptyStoreProducesEmptyAggregations()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let counts = try await store
            .recordCountByPermitMode()
        let sessions = try await store
            .recordCountBySession()
        let agg = try await store
            .aggregationSnapshot()
        XCTAssertEqual(counts.count, 0)
        XCTAssertEqual(sessions.count, 0)
        XCTAssertEqual(agg.totalRecords, 0)
        XCTAssertEqual(agg.distinctSessions, 0)
    }
}
