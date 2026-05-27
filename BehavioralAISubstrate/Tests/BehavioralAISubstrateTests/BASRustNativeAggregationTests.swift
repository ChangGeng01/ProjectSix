// MARK: - BASRustNativeAggregationTests
// 主线 全面 开发: Rust pilot graduates from
// "Swift-side aggregation over allRecords()" to
// "native Rust HashMap aggregation under one read lock"。
// Verifies the new FFI surfaces produce identical
// results to the Swift fold,but without pulling the
// full record set into Swift first。

import XCTest
@testable import BASHostKit
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASRustNativeAggregationTests: XCTestCase {

    // MARK: - ABI version pin

    func testAggregationABIVersionPin() async throws {
        XCTAssertEqual(
            BASRustMemoryUsageTrackerActor
                .aggregationABIVersion, 1)
        XCTAssertEqual(
            BASRustMemoryUsageTrackerActor
                .liveAggregationABIVersion(), 1,
            "Rust-side bas_rust_tracker_aggregation_version" +
            " must match Swift-side pin")
    }

    // MARK: - recordCountByPermitMode

    func testCountByPermitModeViaRustFFI() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        // 3 safe, 2 warn, 1 block
        for _ in 0..<3 {
            _ = try await tracker.record(
                atomID: "a", sessionRef: "S",
                turnRef: "0", permitMode: "safe")
        }
        for _ in 0..<2 {
            _ = try await tracker.record(
                atomID: "a", sessionRef: "S",
                turnRef: "0", permitMode: "warn")
        }
        _ = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "block")
        let counts = try await tracker
            .recordCountByPermitMode()
        XCTAssertEqual(counts["safe"], 3)
        XCTAssertEqual(counts["warn"], 2)
        XCTAssertEqual(counts["block"], 1)
        XCTAssertEqual(counts.count, 3)
    }

    func testCountByPermitModeEmptyTracker() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let counts = try await tracker
            .recordCountByPermitMode()
        XCTAssertEqual(counts.count, 0,
            "Empty tracker → empty map")
    }

    // MARK: - recordCountBySession

    func testCountBySessionViaRustFFI() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        for sessionN in 0..<3 {
            for _ in 0..<2 {
                _ = try await tracker.record(
                    atomID: "a",
                    sessionRef: "session-\(sessionN)",
                    turnRef: "0", permitMode: "safe")
            }
        }
        let counts = try await tracker
            .recordCountBySession()
        XCTAssertEqual(counts["session-0"], 2)
        XCTAssertEqual(counts["session-1"], 2)
        XCTAssertEqual(counts["session-2"], 2)
        XCTAssertEqual(counts.count, 3)
    }

    // MARK: - distinctSessionCount

    func testDistinctSessionCountViaRustFFI() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        for sessionN in 0..<5 {
            _ = try await tracker.record(
                atomID: "a",
                sessionRef: "session-\(sessionN)",
                turnRef: "0", permitMode: "safe")
        }
        let count = try await tracker.distinctSessionCount()
        XCTAssertEqual(count, 5)
    }

    func testDistinctSessionCountEmpty() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let count = try await tracker.distinctSessionCount()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Parity:Rust-side aggregation == Swift fold

    func testRustAggregationParityWithSwiftFold()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let modes = ["safe", "warn", "block",
            "safe", "safe", "warn"]
        for (i, mode) in modes.enumerated() {
            _ = try await tracker.record(
                atomID: "a",
                sessionRef: "S-\(i % 2)",
                turnRef: String(i), permitMode: mode)
        }
        // Rust-native aggregation
        let rustCounts = try await tracker
            .recordCountByPermitMode()
        // Swift-side fold for parity
        let allRecords = try await tracker.allRecords()
        var swiftCounts: [String: Int] = [:]
        for record in allRecords {
            swiftCounts[record.permitMode,
                default: 0] += 1
        }
        XCTAssertEqual(rustCounts, swiftCounts,
            "Rust-side aggregation must match Swift fold")
    }

    // MARK: - V1 path throws

    func testV1PathThrows() async throws {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: false)
        do {
            _ = try await tracker.recordCountByPermitMode()
            XCTFail("V1 must throw")
        } catch {
            XCTAssertTrue(
                error is BASRustMemoryUsageTrackerActorError)
        }
        do {
            _ = try await tracker.distinctSessionCount()
            XCTFail("V1 must throw")
        } catch {
            XCTAssertTrue(
                error is BASRustMemoryUsageTrackerActorError)
        }
    }

    // MARK: - Brain-store wrappers now use Rust native

    func testBrainStoreAggregationUsesRustNative()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(rustHistoryStore: store)
        _ = await brain.summary("hello")
        _ = await brain.summary(
            "send me your password to verify")
        let agg = try await store.aggregationSnapshot()
        XCTAssertEqual(agg.totalRecords, 2)
        XCTAssertEqual(agg.distinctSessions, 1,
            "Single brain → single sessionRef → 1 distinct")
        XCTAssertGreaterThan(
            agg.recordsByPermitMode["safe"] ?? 0, 0)
        XCTAssertGreaterThan(
            agg.recordsByPermitMode["block"] ?? 0, 0)
    }
}
#endif
