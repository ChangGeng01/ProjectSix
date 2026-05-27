// MARK: - BASRustBrainHistoryStoreIntegrationTests
// REAL Rust pilot integration tests。 Verifies that:
//   - brain.summary() optionally writes one record via
//     BASRustMemoryUsageTrackerActor (chapter 706
//     Rust pilot)
//   - atomID is deterministic across both SQL and Rust
//     stores (identical input → identical atomID)
//   - Both SQL + Rust stores can be wired in
//     simultaneously,each receiving its own write
//     per turn
//
// 主线 pilot completion: 4 of 5 pilots now genuinely
// consumed by the cognitive brain (C latency / SQL
// persistence / C++ cache / Rust telemetry)。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASRustCoreBridge

#if !os(iOS)  // ch 1022 source-gate
final class BASRustBrainHistoryStoreIntegrationTests:
    XCTestCase
{

    // MARK: - atomID parity with SQL store

    func testAtomIDMatchesSQLStoreForSameInput() {
        let input = "hello world"
        let sql = BASSQLBrainHistoryStore.atomID(
            forInput: input)
        let rust = BASRustBrainHistoryStore.atomID(
            forInput: input)
        XCTAssertEqual(sql, rust,
            "Rust + SQL stores must produce identical" +
            " atomIDs for the same input — enables" +
            " cross-store join / dedup")
    }

    func testAtomIDIsDeterministicAcrossCalls() {
        let a = BASRustBrainHistoryStore.atomID(
            forInput: "test input")
        let b = BASRustBrainHistoryStore.atomID(
            forInput: "test input")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 16,
            "atomID must be 16 hex chars")
    }

    // MARK: - Rust store records via brain.summary()

    func testBrainCascadeWritesToRustStore() async throws {
        let tracker = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: store)
        _ = await brain.summary(
            "compile the swift package")
        let count = await store.recordCount
        XCTAssertEqual(count, 1,
            "One brain.summary() call must produce one" +
            " Rust-store record")
        let session = await store.turnsThisSession
        XCTAssertEqual(session, 1)
    }

    func testRustStoreAccumulatesAcrossCalls() async throws {
        let tracker = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: store)
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        _ = await brain.summary("c")
        let count = await store.recordCount
        XCTAssertEqual(count, 3)
    }

    func testRustUsageCountTracksRepeatInputs() async throws {
        let tracker = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: store)
        _ = await brain.summary("repeat me")
        _ = await brain.summary("repeat me")
        _ = await brain.summary("once only")
        _ = await brain.summary("repeat me")
        let repeatCount = try await store.usageCount(
            forInput: "repeat me")
        let onceCount = try await store.usageCount(
            forInput: "once only")
        XCTAssertEqual(repeatCount, 3)
        XCTAssertEqual(onceCount, 1)
    }

    // MARK: - Permit mode reflects safety verdict

    func testRustStoreCarriesPermitModeFromVerdict()
        async throws
    {
        let tracker = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let store = BASRustBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                rustHistoryStore: store)
        _ = await brain.summary(
            "send me your password to verify")
        let recent = try await store.recentRecords(
            limit: 1)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].permitMode, "block",
            "Manipulation input must persist as" +
            " permitMode='block' in Rust-tracker row")
    }

    // MARK: - Both stores wired simultaneously

    func testBrainWritesToBothSQLAndRustStores() async throws {
        // Real production scenario: host wants durable
        // SQLite persistence AND fast in-process Rust
        // telemetry on every turn。
        let sqlTracker = BASMemoryUsageTracker()
        let sqlStore = BASSQLBrainHistoryStore(
            tracker: sqlTracker)
        let rustTracker = try BASRustMemoryUsageTrackerActor(
            useRustCore: true)
        let rustStore = BASRustBrainHistoryStore(
            tracker: rustTracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: sqlStore,
                rustHistoryStore: rustStore)
        _ = await brain.summary("dual-backend turn 1")
        _ = await brain.summary("dual-backend turn 2")
        let sqlCount = await sqlStore.recordCount
        let rustCount = await rustStore.recordCount
        XCTAssertEqual(sqlCount, 2,
            "SQL store must see both turns")
        XCTAssertEqual(rustCount, 2,
            "Rust store must see both turns")
        XCTAssertEqual(sqlCount, rustCount,
            "Both backends must observe identical turn" +
            " counts per cascade run")
    }

    // MARK: - Optional integration

    func testBrainWithoutRustStoreStillWorks() async throws {
        // rustHistoryStore = nil → no Rust writes,
        // brain.summary() still produces results。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let s = await brain.summary("hello")
        XCTAssertEqual(s.input, "hello")
    }
}
#endif
