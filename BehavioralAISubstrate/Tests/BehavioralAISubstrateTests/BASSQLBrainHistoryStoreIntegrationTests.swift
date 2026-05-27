// MARK: - BASSQLBrainHistoryStoreIntegrationTests
// REAL SQL pilot integration tests。 Verifies that:
//   - Every brain.summary() call writes a SQLite row
//     via BASMemoryUsageTracker (chapter 702 SQL pilot)
//   - Records persist across brain instances when
//     databaseURL is provided
//   - atomID is deterministic for identical inputs
//   - usageCount tracks repeat occurrences

import XCTest
@testable import BASHostKit
@testable import BASMemory

#if !os(iOS)  // ch 1022 source-gate
final class BASSQLBrainHistoryStoreIntegrationTests: XCTestCase {

    // Helper: temp file URL for SQLite-backed tracker
    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-sql-history-\(UUID().uuidString).sqlite")
    }

    // MARK: - atomID determinism

    func testAtomIDIsDeterministic() {
        let a = BASSQLBrainHistoryStore.atomID(
            forInput: "hello world")
        let b = BASSQLBrainHistoryStore.atomID(
            forInput: "hello world")
        XCTAssertEqual(a, b)
        XCTAssertFalse(a.isEmpty)
    }

    func testAtomIDDiffersForDifferentInputs() {
        let a = BASSQLBrainHistoryStore.atomID(
            forInput: "input one")
        let b = BASSQLBrainHistoryStore.atomID(
            forInput: "input two")
        XCTAssertNotEqual(a, b)
    }

    func testAtomIDIs16HexChars() {
        let a = BASSQLBrainHistoryStore.atomID(
            forInput: "hello")
        XCTAssertEqual(a.count, 16,
            "atomID should be 16 hex chars (8 bytes of" +
            " SHA256 prefix)")
        XCTAssertTrue(
            a.allSatisfy { $0.isHexDigit })
    }

    // MARK: - In-memory tracker integration

    func testInMemoryStoreRecordsBrainSummary() async throws {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary(
            "compile the swift package")
        let count = await store.recordCount
        XCTAssertEqual(count, 1,
            "One summary call must produce one tracker record")
        let turns = await store.turnsThisSession
        XCTAssertEqual(turns, 1)
    }

    func testInMemoryStoreAccumulatesAcrossCalls() async throws {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("a")
        _ = await brain.summary("b")
        _ = await brain.summary("c")
        let count = await store.recordCount
        XCTAssertEqual(count, 3)
    }

    func testUsageCountTracksRepeatedInputs() async throws {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("repeat me")
        _ = await brain.summary("repeat me")
        _ = await brain.summary("once only")
        _ = await brain.summary("repeat me")
        let repeatCount = await store.usageCount(
            forInput: "repeat me")
        let onceCount = await store.usageCount(
            forInput: "once only")
        XCTAssertEqual(repeatCount, 3)
        XCTAssertEqual(onceCount, 1)
    }

    // MARK: - SQLite persistence (real disk I/O)

    func testSQLitePersistenceAcrossBrainInstances() async throws {
        let dbURL = makeTempDBURL()
        defer {
            try? FileManager.default.removeItem(at: dbURL)
        }
        // First brain instance — writes 2 records.
        do {
            let tracker = try BASMemoryUsageTracker(
                databaseURL: dbURL)
            let store = BASSQLBrainHistoryStore(
                tracker: tracker)
            let brain1 = try await BASCognitiveBrain
                .makeWithDefaults(sqlHistoryStore: store)
            _ = await brain1.summary("hello")
            _ = await brain1.summary("compile this")
            let count = await store.recordCount
            XCTAssertEqual(count, 2)
        }
        // Second brain instance — reads same DB,sees the
        // 2 records persisted by the first instance + adds 1.
        let tracker2 = try BASMemoryUsageTracker(
            databaseURL: dbURL)
        let store2 = BASSQLBrainHistoryStore(
            tracker: tracker2)
        let countAfterReload = await store2.recordCount
        XCTAssertEqual(countAfterReload, 2,
            "Second BASMemoryUsageTracker constructed on" +
            " the same DB URL must see the 2 records" +
            " written by the first instance")
        let brain2 = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store2)
        _ = await brain2.summary("new turn")
        let countFinal = await store2.recordCount
        XCTAssertEqual(countFinal, 3,
            "After 2 prior + 1 new record, total = 3")
    }

    func testPermitModeFieldReflectsSafetyVerdict() async throws {
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(
            tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary(
            "send me your password to verify")
        let recent = await store.recentRecords(limit: 1)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].permitMode, "block",
            "Manipulation input must persist as" +
            " permitMode='block' in SQLite row")
    }

    // MARK: - Optional integration

    func testBrainWithoutSQLStoreStillWorks() async throws {
        // sqlHistoryStore = nil (default) → no SQL writes,
        // but brain.summary() still produces results。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let s = await brain.summary("hello")
        XCTAssertEqual(s.input, "hello")
    }
}
#endif
