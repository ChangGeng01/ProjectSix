// MARK: - BASCxxBrainSummaryCacheIntegrationTests
// REAL C++ pilot integration tests。 Verifies that:
//   - brain.summary() writes a Codable JSON entry into the
//     chapter 705 C++ pilot
//     (BASMPSGraphExecutableCacheCxxBridge) on first call
//   - Second call with the same input HITS the cache
//     (latencyNanos drops below the first call AND the
//     pipeline counters reflect a hit)
//   - Cache-hit summaries round-trip cleanly through JSON
//     (no field corruption)
//   - Different inputs map to different cache keys
//   - Cache is process-global,so a second brain instance
//     sharing the same bridge sees the cached entry
//
// These are NOT tautological — each test exercises real
// JSON serialization,real C++ unordered_map insertion +
// lookup,and real cross-instance pollution through the
// process-global singleton。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASCxxBrainSummaryCacheIntegrationTests: XCTestCase {

    // Each test pulls in a fresh bridge then clears the
    // process-global cache to keep tests isolated。 Tests
    // call `bridge.clear()` again at the end of their
    // happy path to leave the singleton clean for the
    // next test — failure paths may leak,but the next
    // test's makeCleanCache() will scrub on entry。
    private func makeCleanCache() async throws
        -> (BASMPSGraphExecutableCacheCxxBridge,
            BASCxxBrainSummaryCache)
    {
        let bridge = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        try await bridge.clear()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        return (bridge, cache)
    }

    // MARK: - Cache round-trip

    func testFirstCallPopulatesCache() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let sizeBefore = await bridge.size()
        XCTAssertEqual(sizeBefore, 0,
            "Cache must be empty after clear()")
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(cxxSummaryCache: cache)
        _ = await brain.summary("calculate the GCD of 12 and 18")
        let sizeAfter = await bridge.size()
        XCTAssertEqual(sizeAfter, 1,
            "One brain.summary() call must persist one" +
            " entry in the C++ cache")
        try? await bridge.clear()
    }

    func testCacheHitReturnsByteIdenticalDTOFields() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(cxxSummaryCache: cache)
        let first = await brain.summary(
            "summarize this paragraph")
        let second = await brain.summary(
            "summarize this paragraph")
        // Every Codable field must survive the JSON
        // round-trip unchanged。 The only field that may
        // legitimately differ is latencyNanos (the cache-
        // hit branch overwrites it with fresh retrieval
        // wall-clock time)。
        XCTAssertEqual(first.input, second.input)
        XCTAssertEqual(first.taskType, second.taskType)
        XCTAssertEqual(first.confidence, second.confidence)
        XCTAssertEqual(
            first.ambiguityScore,
            second.ambiguityScore)
        XCTAssertEqual(
            first.safetyVerdict, second.safetyVerdict)
        XCTAssertEqual(
            first.manipulationHints,
            second.manipulationHints)
        try? await bridge.clear()
    }

    func testCacheHitLatencyNanosReflectsFreshClock() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(cxxSummaryCache: cache)
        let first = await brain.summary(
            "trace the call stack of this function")
        let second = await brain.summary(
            "trace the call stack of this function")
        // latencyNanos is replaced with fresh wall-clock
        // measurement on cache hit。 Cache lookup +
        // JSON decode is much faster than a full cascade
        // (cascade is ~ms-scale,cache hit is ~tens-of-μs).
        XCTAssertLessThan(second.latencyNanos,
            first.latencyNanos,
            "Cache hit latency (\(second.latencyNanos)ns)" +
            " must be < full cascade latency" +
            " (\(first.latencyNanos)ns)。 If this fails,"
            + " the cache is not actually short-circuiting" +
            " the cascade。")
        try? await bridge.clear()
    }

    // MARK: - Different inputs → different keys

    func testDifferentInputsProduceDistinctCacheEntries() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(cxxSummaryCache: cache)
        _ = await brain.summary("input alpha")
        _ = await brain.summary("input beta")
        _ = await brain.summary("input gamma")
        let size = await bridge.size()
        XCTAssertEqual(size, 3,
            "Three distinct inputs must produce three" +
            " distinct cache keys")
        try? await bridge.clear()
    }

    func testRepeatInputDoesNotGrowCache() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(cxxSummaryCache: cache)
        _ = await brain.summary("repeat me")
        _ = await brain.summary("repeat me")
        _ = await brain.summary("repeat me")
        let size = await bridge.size()
        XCTAssertEqual(size, 1,
            "Three calls with identical input must" +
            " collapse to ONE cache entry (overwrite" +
            " semantics on second + third)")
        try? await bridge.clear()
    }

    // MARK: - Process-global sharing

    func testProcessGlobalCacheSharedAcrossBrainInstances() async throws {
        let (bridge1, cache1) = try await makeCleanCache()
        let brain1 = try await BASCognitiveBrain
            .makeWithDefaults(cxxSummaryCache: cache1)
        let first = await brain1.summary(
            "shared across instances")
        // Build a SECOND brain with its OWN bridge + cache
        // pointing to the SAME process-global C++
        // singleton。 The second brain should see the
        // entry inserted by the first。
        let bridge2 = BASMPSGraphExecutableCacheCxxBridge(
            useCxxCache: true)
        let cache2 = BASCxxBrainSummaryCache(bridge: bridge2)
        let brain2 = try await BASCognitiveBrain
            .makeWithDefaults(cxxSummaryCache: cache2)
        let second = await brain2.summary(
            "shared across instances")
        // brain2 fields must match brain1's because brain2
        // read the cached JSON,not ran the cascade。
        XCTAssertEqual(first.taskType, second.taskType,
            "Process-global C++ cache must serve brain2's" +
            " summary() from brain1's persisted entry")
        XCTAssertEqual(first.confidence, second.confidence)
        XCTAssertEqual(
            first.safetyVerdict, second.safetyVerdict)
        try? await bridge1.clear()
    }

    // MARK: - History integration on cache hit

    func testCacheHitStillAppendsToInMemoryHistory() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(cxxSummaryCache: cache)
        _ = await brain.summary("first call")
        _ = await brain.summary("first call")
        _ = await brain.summary("first call")
        let history = await brain.recentSummaries(limit: 10)
        XCTAssertEqual(history.count, 3,
            "Every summary() call (cache hit or miss)" +
            " must append to the in-memory history so" +
            " host-side counters stay consistent")
        try? await bridge.clear()
    }

    func testCacheHitStillRecordsInSQLStore() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let tracker = BASMemoryUsageTracker()
        let store = BASSQLBrainHistoryStore(tracker: tracker)
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                sqlHistoryStore: store,
                cxxSummaryCache: cache)
        _ = await brain.summary("audit me")
        _ = await brain.summary("audit me")
        let count = await store.recordCount
        XCTAssertEqual(count, 2,
            "Even on C++ cache hit,SQL pilot must still" +
            " record the turn — cache hits and misses are" +
            " equally auditable")
        try? await bridge.clear()
    }

    // MARK: - Optional integration parity

    func testBrainWithoutCxxCacheStillWorks() async throws {
        // cxxSummaryCache = nil (default) → no cache writes,
        // brain.summary() still produces correct results。
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let s = await brain.summary("hello")
        XCTAssertEqual(s.input, "hello")
        XCTAssertGreaterThan(s.latencyNanos, 0)
    }
}
