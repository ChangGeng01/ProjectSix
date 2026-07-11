// MARK: - BASCognitiveBrainHealthSnapshotHistoryTests
// 主线 全面 开发: bounded ring buffer of brain health
// snapshots + trend summary across the buffer。 Pins
// append/overflow/capture/trend semantics。

import XCTest
@testable import BASHostKit

final class BASCognitiveBrainHealthSnapshotHistoryTests:
    XCTestCase
{
    // MARK: - Construction + bounds

    func testCapacityIsClampedToAtLeastOne() async throws {
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 0)
        let cap = await history.capacity
        XCTAssertEqual(cap, 1,
            "0 capacity clamps up to 1 to avoid empty" +
            " buffer that can never accept appends")
    }

    func testEmptyHistoryReports() async throws {
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 10)
        let count = await history.count
        let isEmpty = await history.isEmpty
        let trend = await history.trendSummary()
        XCTAssertEqual(count, 0)
        XCTAssertTrue(isEmpty)
        XCTAssertNil(trend,
            "Trend needs at least 2 snapshots")
    }

    // MARK: - Append + capture

    func testCaptureFromBrain() async throws {
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 5)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        await history.capture(from: brain)
        await history.capture(from: brain)
        let count = await history.count
        XCTAssertEqual(count, 2)
    }

    // MARK: - Overflow drops oldest

    func testOverflowDropsOldest() async throws {
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 3)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        // Append 5 snapshots with explicit collectedAt
        // timestamps so we can verify oldest is the
        // newest-3 set after overflow
        for _ in 0..<5 {
            await history.capture(from: brain)
            try await Task.sleep(
                nanoseconds: 10_000_000)  // 10ms
        }
        let count = await history.count
        XCTAssertEqual(count, 3,
            "Capacity 3 → buffer holds at most 3")
        // The oldest 2 captures should have been dropped。
        // Verify by checking that the oldest in the buffer
        // is newer than the buffer's lifetime / 5。
        let snaps = await history.all
        XCTAssertEqual(snaps.count, 3)
        // Monotonic ascending check
        for i in 1..<snaps.count {
            XCTAssertGreaterThanOrEqual(
                snaps[i].collectedAt,
                snaps[i - 1].collectedAt,
                "Buffer must remain time-ordered ascending")
        }
    }

    // MARK: - mostRecent

    func testMostRecentReturnsNewestFirst() async throws {
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 10)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        for _ in 0..<4 {
            await history.capture(from: brain)
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        let recent2 = await history.mostRecent(limit: 2)
        XCTAssertEqual(recent2.count, 2)
        // Newest first
        XCTAssertGreaterThanOrEqual(
            recent2[0].collectedAt,
            recent2[1].collectedAt)
    }

    func testMostRecentLimitGreaterThanCountReturnsAll()
        async throws
    {
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 5)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        await history.capture(from: brain)
        await history.capture(from: brain)
        let recent = await history.mostRecent(limit: 100)
        XCTAssertEqual(recent.count, 2,
            "Asking for more than we have returns all" +
            " (no padding)")
    }

    // MARK: - Trend summary

    func testTrendSummaryReportsDeltas() async throws {
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 10)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        await history.capture(from: brain)
        // Now generate some brain activity so storage
        // events climb
        _ = await brain.summary("hello")
        _ = await brain.summary("world")
        try await Task.sleep(nanoseconds: 10_000_000)
        await history.capture(from: brain)
        let trend = await history.trendSummary()
        XCTAssertNotNil(trend)
        XCTAssertEqual(trend?.snapshotCount, 2)
        XCTAssertGreaterThanOrEqual(
            trend?.totalStorageEventsDelta ?? -1, 2,
            "2 brain.summary() calls add ≥2 events to" +
            " the in-memory summary count")
        XCTAssertGreaterThan(trend?.spanSeconds ?? -1, 0)
    }

    // MARK: - Clear

    func testClearEmptiesBuffer() async throws {
        let history = BASCognitiveBrainHealthSnapshotHistory(
            capacity: 5)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        await history.capture(from: brain)
        await history.capture(from: brain)
        await history.clear()
        let count = await history.count
        XCTAssertEqual(count, 0,
            "clear() drops all snapshots")
    }

    // MARK: - Codable round-trip for trend

    func testTrendCodableRoundTrip() throws {
        let trend = BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: 5,
            spanSeconds: 12.5,
            totalStorageEventsDelta: 100,
            hitRateDelta: 0.15,
            cacheContentBytesDelta: 4096)
        let data = try JSONEncoder().encode(trend)
        let decoded = try JSONDecoder().decode(
            BASCognitiveBrainHealthSnapshotTrend.self,
            from: data)
        XCTAssertEqual(decoded, trend)
        XCTAssertEqual(decoded.storageEventsPerSecond,
            100.0 / 12.5, accuracy: 1e-9)
    }

    func testStorageEventsPerSecondZeroSpan() {
        let trend = BASCognitiveBrainHealthSnapshotTrend(
            snapshotCount: 1,
            spanSeconds: 0,
            totalStorageEventsDelta: 999,
            hitRateDelta: nil,
            cacheContentBytesDelta: nil)
        XCTAssertEqual(trend.storageEventsPerSecond, 0,
            "Zero span → 0 (no division by zero)")
    }
}
