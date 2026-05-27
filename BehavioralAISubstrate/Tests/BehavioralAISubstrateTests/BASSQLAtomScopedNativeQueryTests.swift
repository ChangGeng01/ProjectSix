// MARK: - BASSQLAtomScopedNativeQueryTests
// 主线 解构 重构: SQL pilot now pushes usageCount,
// distinctSessionCount,and atom-filtered recentRecords
// queries into native SQL。 Pins the contract that:
//   - SQL-backed path runs queries inside the engine
//   - In-memory fallback returns identical results
//   - Parity: both paths produce equal results for
//     identical data sets

import XCTest
@testable import BASHostKit
@testable import BASMemory

#if !os(iOS)  // ch 1022 source-gate
final class BASSQLAtomScopedNativeQueryTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-sql-atom-\(UUID().uuidString).sqlite")
    }

    // MARK: - usageCountViaSQL

    func testUsageCountViaSQLOnSQLiteBackedTracker()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        // Record 3 events for "alpha", 1 for "beta"。
        let alphaID = BASBrainHistoryAtomID.derive(
            forInput: "alpha")
        let betaID = BASBrainHistoryAtomID.derive(
            forInput: "beta")
        for i in 0..<3 {
            _ = try await tracker.record(
                atomID: alphaID, sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        _ = try await tracker.record(
            atomID: betaID, sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        // Verify native SQL count
        let alphaCount = try await tracker.usageCountViaSQL(
            forAtomID: alphaID)
        let betaCount = try await tracker.usageCountViaSQL(
            forAtomID: betaID)
        let missingCount = try await tracker
            .usageCountViaSQL(forAtomID: "no-such-atom")
        XCTAssertEqual(alphaCount, 3)
        XCTAssertEqual(betaCount, 1)
        XCTAssertEqual(missingCount, 0,
            "Missing atomID → COUNT(*) returns 0")
    }

    func testUsageCountViaSQLOnInMemoryFallsBack()
        async throws
    {
        let tracker = BASMemoryUsageTracker()  // in-memory
        let id = BASBrainHistoryAtomID.derive(
            forInput: "test")
        for i in 0..<5 {
            _ = try await tracker.record(
                atomID: id, sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        let count = try await tracker.usageCountViaSQL(
            forAtomID: id)
        XCTAssertEqual(count, 5,
            "In-memory fallback returns same count")
    }

    func testUsageCountViaSQLParity() async throws {
        // Same operations on both modes → same result。
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let sqlTracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let memTracker = BASMemoryUsageTracker()
        let id = BASBrainHistoryAtomID.derive(
            forInput: "shared")
        for i in 0..<7 {
            _ = try await sqlTracker.record(
                atomID: id, sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
            _ = try await memTracker.record(
                atomID: id, sessionRef: "S",
                turnRef: String(i), permitMode: "safe")
        }
        let sqlCount = try await sqlTracker.usageCountViaSQL(
            forAtomID: id)
        let memCount = try await memTracker.usageCountViaSQL(
            forAtomID: id)
        XCTAssertEqual(sqlCount, memCount)
        XCTAssertEqual(sqlCount, 7)
    }

    // MARK: - distinctSessionCountViaSQL

    func testDistinctSessionCountViaSQL() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        // 3 sessions × multiple turns each
        for sessionN in 0..<3 {
            for turn in 0..<4 {
                _ = try await tracker.record(
                    atomID: "atom",
                    sessionRef: "session-\(sessionN)",
                    turnRef: String(turn),
                    permitMode: "safe")
            }
        }
        let distinct = try await tracker
            .distinctSessionCountViaSQL()
        XCTAssertEqual(distinct, 3,
            "3 distinct session_ref values via native" +
            " COUNT(DISTINCT)")
    }

    func testDistinctSessionCountViaSQLEmptyDB()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let distinct = try await tracker
            .distinctSessionCountViaSQL()
        XCTAssertEqual(distinct, 0,
            "Empty DB → 0 distinct sessions")
    }

    func testDistinctSessionCountInMemoryFallback()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        _ = try await tracker.record(
            atomID: "a", sessionRef: "X",
            turnRef: "0", permitMode: "safe")
        _ = try await tracker.record(
            atomID: "b", sessionRef: "Y",
            turnRef: "0", permitMode: "safe")
        _ = try await tracker.record(
            atomID: "c", sessionRef: "X",
            turnRef: "1", permitMode: "safe")
        let distinct = try await tracker
            .distinctSessionCountViaSQL()
        XCTAssertEqual(distinct, 2,
            "2 distinct sessions (X + Y) via Swift Set" +
            " fallback")
    }

    // MARK: - recentRecordsForAtomViaSQL

    func testRecentRecordsForAtomViaSQLFiltersAndOrders()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let alphaID = BASBrainHistoryAtomID.derive(
            forInput: "alpha")
        let betaID = BASBrainHistoryAtomID.derive(
            forInput: "beta")
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Alpha at t0, t0+1, t0+3
        // Beta at t0+2
        _ = try await tracker.record(
            atomID: alphaID, sessionRef: "S",
            turnRef: "0", permitMode: "safe",
            retrievedAt: t0)
        _ = try await tracker.record(
            atomID: alphaID, sessionRef: "S",
            turnRef: "1", permitMode: "safe",
            retrievedAt: t0.addingTimeInterval(0.1))
        _ = try await tracker.record(
            atomID: betaID, sessionRef: "S",
            turnRef: "2", permitMode: "safe",
            retrievedAt: t0.addingTimeInterval(0.2))
        _ = try await tracker.record(
            atomID: alphaID, sessionRef: "S",
            turnRef: "3", permitMode: "safe",
            retrievedAt: t0.addingTimeInterval(0.3))
        // Query alpha only, newest first
        let alphaRecords = try await tracker
            .recentRecordsForAtomViaSQL(
                atomID: alphaID, limit: 10)
        XCTAssertEqual(alphaRecords.count, 3,
            "WHERE atom_id = alpha filters out beta row")
        XCTAssertEqual(alphaRecords[0].turnRef, "3",
            "ORDER BY DESC → newest first")
        XCTAssertEqual(alphaRecords[1].turnRef, "1")
        XCTAssertEqual(alphaRecords[2].turnRef, "0")
    }

    func testRecentRecordsForAtomViaSQLHonorsLimit()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let id = BASBrainHistoryAtomID.derive(
            forInput: "test")
        for i in 0..<8 {
            _ = try await tracker.record(
                atomID: id, sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: Date(
                    timeIntervalSince1970:
                        1_700_000_000 + Double(i) * 0.01))
        }
        let limited = try await tracker
            .recentRecordsForAtomViaSQL(
                atomID: id, limit: 3)
        XCTAssertEqual(limited.count, 3,
            "LIMIT 3 enforced by SQLite")
        XCTAssertEqual(limited[0].turnRef, "7",
            "Newest first")
    }

    func testRecentRecordsForAtomViaSQLInMemoryFallback()
        async throws
    {
        let tracker = BASMemoryUsageTracker()  // in-memory
        let id = BASBrainHistoryAtomID.derive(
            forInput: "test")
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await tracker.record(
            atomID: id, sessionRef: "S",
            turnRef: "0", permitMode: "safe",
            retrievedAt: t0)
        _ = try await tracker.record(
            atomID: id, sessionRef: "S",
            turnRef: "1", permitMode: "safe",
            retrievedAt: t0.addingTimeInterval(0.1))
        // Other atom interleaved
        _ = try await tracker.record(
            atomID: "other", sessionRef: "S",
            turnRef: "2", permitMode: "safe",
            retrievedAt: t0.addingTimeInterval(0.2))
        let records = try await tracker
            .recentRecordsForAtomViaSQL(
                atomID: id, limit: 5)
        XCTAssertEqual(records.count, 2,
            "Filter excludes other atom")
        XCTAssertEqual(records[0].turnRef, "1",
            "Newest first via Swift fallback")
    }

    // MARK: - Brain-store wrappers

    func testStoreUsageCountViaSQLDelegates() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("repeat")
        _ = await brain.summary("repeat")
        _ = await brain.summary("once")
        let repeatCount = try await store.usageCountViaSQL(
            forInput: "repeat")
        let onceCount = try await store.usageCountViaSQL(
            forInput: "once")
        XCTAssertEqual(repeatCount, 2)
        XCTAssertEqual(onceCount, 1)
    }

    func testStoreRecentRecordsForInputViaSQL() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("target")
        _ = await brain.summary("other")
        _ = await brain.summary("target")
        _ = await brain.summary("target")
        let records = try await store
            .recentRecordsForInputViaSQL(
                forInput: "target", limit: 5)
        XCTAssertEqual(records.count, 3)
        // All records should match the target's atomID
        let targetAtom = BASSQLBrainHistoryStore.atomID(
            forInput: "target")
        for record in records {
            XCTAssertEqual(record.atomID, targetAtom,
                "Filter must exclude other atoms")
        }
    }

    func testStoreDistinctSessionCountViaSQL() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        // Two stores share the tracker → two sessionRefs
        let storeA = BASSQLBrainHistoryStore(tracker: tracker)
        let storeB = BASSQLBrainHistoryStore(tracker: tracker)
        let brainA = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: storeA)
        let brainB = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: storeB)
        _ = await brainA.summary("a")
        _ = await brainB.summary("b")
        let distinct = try await storeA
            .distinctSessionCountViaSQL()
        XCTAssertEqual(distinct, 2,
            "Two distinct sessions (one per store)")
    }

    // MARK: - aggregationSnapshot now carries distinctSessions

    func testAggregationSnapshotIncludesDistinctSessions()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("hello")
        _ = await brain.summary("again")
        let snap = try await store.aggregationSnapshot()
        XCTAssertEqual(snap.distinctSessions, 1,
            "Single brain → single sessionRef → 1 distinct")
    }

    func testAggregationSnapshotBackwardCompatibleDefault() {
        // Snapshots constructed via the legacy initializer
        // (no distinctSessions param) must default to 0
        // for forward-compat with stored historical
        // dashboard data。
        let snap = BASSQLBrainHistoryStoreAggregation(
            totalRecords: 5,
            recordsByPermitMode: ["safe": 5],
            turnsThisSession: 5,
            isSQLBacked: true)
        XCTAssertEqual(snap.distinctSessions, 0)
    }
}
#endif
