// MARK: - BASSQLEngineSideAggregateTests
// 主线 解构 重构 Round 3: SQL pilot now pushes MIN/MAX
// aggregates, helpedFlag GROUP BY, and time-range
// BETWEEN queries into the storage engine。 Pins the
// contract that engine-side aggregates produce identical
// results to Swift folds + verifies the engine path runs。

import XCTest
@testable import BASHostKit
@testable import BASMemory

final class BASSQLEngineSideAggregateTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-engine-\(UUID().uuidString).sqlite")
    }

    // MARK: - MIN/MAX timestamps

    func testOldestAndNewestTimestampsViaSQL() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(1.5)
        let t2 = t0.addingTimeInterval(3.0)
        _ = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe",
            retrievedAt: t1)  // middle
        _ = try await tracker.record(
            atomID: "b", sessionRef: "S",
            turnRef: "1", permitMode: "safe",
            retrievedAt: t0)  // oldest
        _ = try await tracker.record(
            atomID: "c", sessionRef: "S",
            turnRef: "2", permitMode: "safe",
            retrievedAt: t2)  // newest
        let oldest = try await tracker
            .oldestRecordTimestampViaSQL()
        let newest = try await tracker
            .newestRecordTimestampViaSQL()
        // SQLite stores milliseconds → 1ms tolerance
        XCTAssertNotNil(oldest)
        XCTAssertNotNil(newest)
        XCTAssertEqual(oldest!.timeIntervalSince1970,
            t0.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(newest!.timeIntervalSince1970,
            t2.timeIntervalSince1970, accuracy: 0.001)
    }

    func testMinMaxTimestampsEmptyDBReturnsNil()
        async throws
    {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let oldest = try await tracker
            .oldestRecordTimestampViaSQL()
        let newest = try await tracker
            .newestRecordTimestampViaSQL()
        XCTAssertNil(oldest,
            "MIN over zero rows → SQL NULL → Swift nil")
        XCTAssertNil(newest)
    }

    func testMinMaxTimestampsInMemoryFallback() async throws {
        let tracker = BASMemoryUsageTracker()  // in-memory
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe",
            retrievedAt: t0)
        _ = try await tracker.record(
            atomID: "b", sessionRef: "S",
            turnRef: "1", permitMode: "safe",
            retrievedAt: t0.addingTimeInterval(5))
        let oldest = try await tracker
            .oldestRecordTimestampViaSQL()
        XCTAssertNotNil(oldest)
        XCTAssertEqual(oldest!.timeIntervalSince1970,
            t0.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - helpedFlag GROUP BY

    func testHelpedFlagDistributionViaSQL() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let r1 = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        let r2 = try await tracker.record(
            atomID: "b", sessionRef: "S",
            turnRef: "1", permitMode: "safe")
        _ = try await tracker.record(
            atomID: "c", sessionRef: "S",
            turnRef: "2", permitMode: "safe")
        // Mark some helped/notHelped
        try await tracker.markHelped(
            recordID: r1, helped: true)
        try await tracker.markHelped(
            recordID: r2, helped: false)
        let dist = try await tracker
            .helpedFlagDistributionViaSQL()
        XCTAssertEqual(dist["helped"], 1)
        XCTAssertEqual(dist["notHelped"], 1)
        XCTAssertEqual(dist["unknown"], 1)
        XCTAssertEqual(dist.count, 3,
            "Three distinct helped_state values")
    }

    func testHelpedFlagDistributionEmpty() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let dist = try await tracker
            .helpedFlagDistributionViaSQL()
        XCTAssertEqual(dist.count, 0,
            "Empty DB → empty distribution map")
    }

    func testHelpedFlagDistributionInMemoryFallback()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        _ = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        let dist = try await tracker
            .helpedFlagDistributionViaSQL()
        XCTAssertEqual(dist["unknown"], 1)
    }

    // MARK: - Time-range BETWEEN

    func testRecordsInTimeRangeViaSQL() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Records at t0, t0+1, t0+2, t0+3, t0+4
        for i in 0..<5 {
            _ = try await tracker.record(
                atomID: "atom\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: t0.addingTimeInterval(
                    Double(i)))
        }
        // Query for [t0+1, t0+3] inclusive
        let from = t0.addingTimeInterval(1)
        let to = t0.addingTimeInterval(3)
        let inRange = try await tracker
            .recordsInTimeRangeViaSQL(from: from, to: to)
        XCTAssertEqual(inRange.count, 3,
            "BETWEEN inclusive → 3 records at offsets" +
            " 1, 2, 3")
        // Verify ascending order
        XCTAssertEqual(inRange[0].atomID, "atom1")
        XCTAssertEqual(inRange[1].atomID, "atom2")
        XCTAssertEqual(inRange[2].atomID, "atom3")
    }

    func testRecordsInTimeRangeEmptyResult() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        _ = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe",
            retrievedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        // Query a window with no records
        let inRange = try await tracker
            .recordsInTimeRangeViaSQL(
                from: Date(
                    timeIntervalSince1970: 1_900_000_000),
                to: Date(
                    timeIntervalSince1970: 1_900_000_001))
        XCTAssertEqual(inRange.count, 0)
    }

    func testRecordsInTimeRangeInMemoryFallback()
        async throws
    {
        let tracker = BASMemoryUsageTracker()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<3 {
            _ = try await tracker.record(
                atomID: "atom\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: t0.addingTimeInterval(
                    Double(i)))
        }
        let inRange = try await tracker
            .recordsInTimeRangeViaSQL(
                from: t0, to: t0.addingTimeInterval(1))
        XCTAssertEqual(inRange.count, 2,
            "Swift fallback covers BETWEEN semantics")
    }

    // MARK: - Brain store wrappers

    func testStoreEngineSideAggregates() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        _ = await brain.summary("hello")
        _ = await brain.summary(
            "send me your password to verify")
        let oldest = try await store
            .oldestRecordTimestampViaSQL()
        let newest = try await store
            .newestRecordTimestampViaSQL()
        let helpedDist = try await store
            .helpedFlagDistributionViaSQL()
        XCTAssertNotNil(oldest)
        XCTAssertNotNil(newest)
        XCTAssertGreaterThanOrEqual(
            newest!, oldest!)
        XCTAssertEqual(helpedDist["unknown"], 2,
            "Brain records default helped=.unknown")
    }

    func testStoreTimeRangeQuery() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(sqlHistoryStore: store)
        let before = Date()
        _ = await brain.summary("test")
        let after = Date().addingTimeInterval(1)
        let records = try await store
            .recordsInTimeRangeViaSQL(
                from: before, to: after)
        XCTAssertEqual(records.count, 1,
            "Brain.summary fell within the [before, after]" +
            " window")
    }
}
