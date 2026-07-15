// MARK: - BASMultiPilotQuadrupleTests
// 全面 开发: tests for 4 cross-pilot additions:
//   1. Rust: retrievalIntervalPercentiles — traffic
//      rhythm percentiles
//   2. C++: bloom filter "ever seen" negative cache
//   3. SQL: BEGIN TRANSACTION batch insert via
//      recordSummaryBatch
//   4. Brain: exportHealthHistoryJSON NDJSON dump

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASMetalSubstrate
@testable import BASRustCoreBridge
@testable import BASMPSGraphExecutableCacheCxx

final class BASMultiPilotQuadrupleTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "bas-quad-\(UUID().uuidString).sqlite")
    }

    // MARK: - 1. Rust retrieval interval percentiles

    func testIntervalPercentilesEmptyTrackerSentinel()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let p = try await tracker
            .retrievalIntervalPercentiles()
        XCTAssertEqual(p.p50Millis, -1)
        XCTAssertEqual(p.p95Millis, -1)
        XCTAssertEqual(p.p99Millis, -1)
        XCTAssertTrue(p.isEmpty)
    }

    func testIntervalPercentilesSingleRecordSentinel()
        async throws
    {
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        _ = try await tracker.record(
            atomID: "a", sessionRef: "S",
            turnRef: "0", permitMode: "safe")
        let p = try await tracker
            .retrievalIntervalPercentiles()
        XCTAssertTrue(p.isEmpty,
            "Single record → no interval computable")
    }

    func testIntervalPercentilesUniformSpacing()
        async throws
    {
        // 5 records spaced 1000ms apart → all intervals
        // = 1000 → all percentiles = 1000
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<5 {
            _ = try await tracker.record(
                atomID: "atom-\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: t0.addingTimeInterval(
                    Double(i)))
        }
        let p = try await tracker
            .retrievalIntervalPercentiles()
        XCTAssertEqual(p.p50Millis, 1000)
        XCTAssertEqual(p.p95Millis, 1000)
        XCTAssertEqual(p.p99Millis, 1000)
    }

    func testIntervalPercentilesBurstyPattern() async throws {
        // 9 records at 100ms spacing + 1 outlier 60s
        // after → 9 intervals。 Sorted intervals =
        // [100×8, 60000]。 nearest-rank:
        //   p50 idx = ceil(9*0.5) - 1 = 4 → sorted[4]=100
        //   p99 idx = ceil(9*0.99) - 1 = 8 → sorted[8]=60000
        let tracker =
            try BASRustMemoryUsageTrackerActor(
                useRustCore: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<9 {
            _ = try await tracker.record(
                atomID: "atom-\(i)", sessionRef: "S",
                turnRef: String(i), permitMode: "safe",
                retrievedAt: t0.addingTimeInterval(
                    Double(i) * 0.1))
        }
        // Outlier 60s after the last regular record
        // (which sits at index 8 = 0.8s)。 So outlier
        // timestamp = 60.8s,interval = 60.0s = 60000ms
        // exactly。
        _ = try await tracker.record(
            atomID: "outlier", sessionRef: "S",
            turnRef: "9", permitMode: "safe",
            retrievedAt: t0.addingTimeInterval(
                8 * 0.1 + 60))
        let p = try await tracker
            .retrievalIntervalPercentiles()
        XCTAssertEqual(p.p50Millis, 100,
            "Median interval = 100ms (bursty)")
        XCTAssertEqual(p.p99Millis, 60000,
            "p99 picks up the 60-second outlier")
    }

    func testIntervalPercentilesCodable() throws {
        let p = BASRetrievalIntervalPercentiles(
            p50Millis: 100, p95Millis: 500,
            p99Millis: 60000)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(
            BASRetrievalIntervalPercentiles.self,
            from: data)
        XCTAssertEqual(decoded, p)
        XCTAssertFalse(decoded.isEmpty)
    }

    // MARK: - 2. C++ bloom filter

    func testBloomEmptyContainsNothing() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.bloomClear()
        let present = try await bridge.bloomMightContain(
            key: "never-seen-\(UUID().uuidString)")
        XCTAssertFalse(present,
            "Empty bloom → never-seen key is definitely" +
            " not present")
    }

    func testBloomAddThenContains() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.bloomClear()
        let key = "test-key-\(UUID().uuidString)"
        try await bridge.bloomAdd(key: key)
        let present = try await bridge.bloomMightContain(
            key: key)
        XCTAssertTrue(present,
            "Just-added key must be reported present")
    }

    func testBloomSurvivesCacheClear() async throws {
        // The bloom is SEPARATE from the main cache。
        // bas_mps_cache_clear() must not affect the
        // bloom — hosts use bloom to detect "ever seen"
        // even after cache is wiped。
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.bloomClear()
        let key = "survives-key-\(UUID().uuidString)"
        try await bridge.bloomAdd(key: key)
        try await bridge.clear()  // clears MAIN cache
        let present = try await bridge.bloomMightContain(
            key: key)
        XCTAssertTrue(present,
            "Bloom survives main cache clear")
    }

    func testBloomClearDropsAll() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        let key = "x-\(UUID().uuidString)"
        try await bridge.bloomAdd(key: key)
        try await bridge.bloomClear()
        let present = try await bridge.bloomMightContain(
            key: key)
        XCTAssertFalse(present)
    }

    func testBloomSizeReflectsAdds() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.bloomClear()
        let before = await bridge.bloomSize()
        XCTAssertEqual(before, 0)
        for i in 0..<5 {
            try await bridge.bloomAdd(
                key: "key-\(i)-\(UUID().uuidString)")
        }
        let after = await bridge.bloomSize()
        XCTAssertEqual(after, 5)
    }

    func testCacheSummaryAutoAddsToBloom() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        try await bridge.bloomClear()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        let summary = BASCognitiveBrainSummary(
            input: "bloom-test-input",
            taskType: .chat,
            confidence: 0.9, ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1)
        try await cache.cacheSummary(summary)
        let seen = await cache.hasEverBeenCached(
            forInput: "bloom-test-input")
        XCTAssertTrue(seen,
            "cacheSummary auto-registers in the bloom")
        let neverSeen = await cache.hasEverBeenCached(
            forInput: "definitely-not-seen-\(UUID())")
        XCTAssertFalse(neverSeen)
    }

    func testV1BloomNoOps() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: false)
        try await bridge.bloomAdd(key: "k")
        // V1 returns false unconditionally
        let present = try await bridge.bloomMightContain(
            key: "k")
        XCTAssertFalse(present)
        let size = await bridge.bloomSize()
        XCTAssertEqual(size, 0)
    }

    // MARK: - 3. SQL transaction batch insert

    func testRecordBatchEmptyReturnsEmpty() async throws {
        let tracker = BASMemoryUsageTracker()
        let ids = try await tracker.recordBatch([])
        XCTAssertEqual(ids.count, 0)
    }

    func testRecordBatchInMemoryFallback() async throws {
        let tracker = BASMemoryUsageTracker()
        let entries = (0..<5).map { i in
            BASMemoryUsageTracker.BatchEntry(
                atomID: "atom-\(i)",
                sessionRef: "S",
                turnRef: String(i),
                permitMode: "safe")
        }
        let ids = try await tracker.recordBatch(entries)
        XCTAssertEqual(ids.count, 5)
        let count = await tracker.recordCount
        XCTAssertEqual(count, 5)
    }

    func testRecordBatchSQLiteAtomicCommit() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let entries = (0..<10).map { i in
            BASMemoryUsageTracker.BatchEntry(
                atomID: "atom-\(i)",
                sessionRef: "S",
                turnRef: String(i),
                permitMode: "safe",
                retrievedAt: Date(
                    timeIntervalSince1970:
                        1_700_000_000 + Double(i)))
        }
        let ids = try await tracker.recordBatch(entries)
        XCTAssertEqual(ids.count, 10)
        // Verify rows visible to subsequent queries
        let totalCount = try await tracker
            .recentRecordsViaSQL(limit: 100)
        XCTAssertEqual(totalCount.count, 10,
            "All 10 rows committed atomically")
    }

    func testRecordBatchUniqueRecordIDs() async throws {
        let tracker = BASMemoryUsageTracker()
        let entries = (0..<20).map { i in
            BASMemoryUsageTracker.BatchEntry(
                atomID: "atom-\(i)",
                sessionRef: "S",
                turnRef: String(i),
                permitMode: "safe")
        }
        let ids = try await tracker.recordBatch(entries)
        XCTAssertEqual(Set(ids).count, ids.count,
            "All minted recordIDs must be unique")
    }

    func testBrainStoreRecordSummaryBatch() async throws {
        let url = makeTempDBURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let tracker = try BASMemoryUsageTracker(
            databaseURL: url)
        let store = BASSQLBrainHistoryStore(
            tracker: tracker)
        let summaries = (0..<5).map { i in
            BASCognitiveBrainSummary(
                input: "batch-\(i)",
                taskType: .chat,
                confidence: 0.9, ambiguityScore: 0.1,
                safetyVerdict: .safe,
                manipulationHints: [], latencyNanos: 1)
        }
        let ids = try await store.recordSummaryBatch(
            summaries)
        XCTAssertEqual(ids.count, 5)
        let count = await store.recordCount
        XCTAssertEqual(count, 5)
        let turns = await store.turnsThisSession
        XCTAssertEqual(turns, 5,
            "Batch insert increments turn counter once" +
            " per summary")
    }

    // MARK: - 4. brain.exportHealthHistoryJSON

    func testExportHealthHistoryEmptyWhenNotConfigured()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots()
        let ndjson = await brain.exportHealthHistoryJSON()
        XCTAssertEqual(ndjson, "",
            "No history configured → empty string")
    }

    func testExportHealthHistoryEmptyBufferEmptyString()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 10)
        // Never captured anything
        let ndjson = await brain.exportHealthHistoryJSON()
        XCTAssertEqual(ndjson, "",
            "Configured but empty buffer → empty string")
    }

    func testExportHealthHistoryNDJSONFormat() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 5)
        _ = await brain.recordHealthSnapshot()
        _ = await brain.recordHealthSnapshot()
        _ = await brain.recordHealthSnapshot()
        let ndjson = await brain.exportHealthHistoryJSON()
        XCTAssertFalse(ndjson.isEmpty)
        let lines = ndjson.split(separator: "\n")
        XCTAssertEqual(lines.count, 3,
            "NDJSON = one snapshot per line")
        // Each line is valid JSON
        for line in lines {
            let data = String(line).data(using: .utf8)!
            let parsed = try? JSONSerialization
                .jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(parsed,
                "Each NDJSON line must parse as JSON")
        }
    }

    func testExportHealthHistoryRoundTrip() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithAllPilots(
                healthSnapshotHistoryCapacity: 5)
        _ = await brain.summary("test input")
        _ = await brain.recordHealthSnapshot()
        let ndjson = await brain.exportHealthHistoryJSON()
        // Parse each line back as snapshot
        let lines = ndjson.split(separator: "\n")
        XCTAssertEqual(lines.count, 1)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy =
            .millisecondsSince1970
        let data = String(lines[0]).data(using: .utf8)!
        let snap = try decoder.decode(
            BASCognitiveBrainHealthSnapshot.self,
            from: data)
        XCTAssertEqual(snap.pilotStatus.activeCount, 5)
    }
}
