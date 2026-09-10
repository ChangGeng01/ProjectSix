// MARK: - BASCxxCacheTelemetryTests
// 主线 全面 提升: C++ pilot now exposes hit/miss
// telemetry for cache-effectiveness dashboards。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate

final class BASCxxCacheTelemetryTests: XCTestCase {

    private func makeCleanCache() async throws
        -> (BASMPSGraphExecutableCacheCxxBridge,
            BASCxxBrainSummaryCache)
    {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        let cache = BASCxxBrainSummaryCache(
            bridge: bridge)
        return (bridge, cache)
    }

    private func makeSummary(
        input: String
    ) -> BASCognitiveBrainSummary {
        return BASCognitiveBrainSummary(
            input: input,
            taskType: .chat,
            confidence: 0.9,
            ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [],
            latencyNanos: 1)
    }

    // MARK: - Initial telemetry is zero

    func testInitialTelemetryAllZero() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let hits = await cache.cumulativeHits
        let misses = await cache.cumulativeMisses
        let lookups = await cache.cumulativeLookups
        let rate = await cache.hitRate
        XCTAssertEqual(hits, 0)
        XCTAssertEqual(misses, 0)
        XCTAssertEqual(lookups, 0)
        XCTAssertEqual(rate, 0.0,
            "hitRate must be 0 (not NaN) when no" +
            " lookups have happened")
        try? await bridge.clear()
    }

    // MARK: - Miss increments missCount

    func testLookupOnEmptyCacheIncrementsMisses()
        async throws
    {
        let (bridge, cache) = try await makeCleanCache()
        _ = await cache.cachedSummary(
            forInput: "never-cached")
        let hits = await cache.cumulativeHits
        let misses = await cache.cumulativeMisses
        XCTAssertEqual(hits, 0)
        XCTAssertEqual(misses, 1)
        try? await bridge.clear()
    }

    // MARK: - Hit increments hitCount

    func testCachedLookupIncrementsHits() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let s = makeSummary(input: "cached-key")
        try await cache.cacheSummary(s)
        _ = await cache.cachedSummary(
            forInput: "cached-key")
        let hits = await cache.cumulativeHits
        let misses = await cache.cumulativeMisses
        XCTAssertEqual(hits, 1)
        XCTAssertEqual(misses, 0)
        try? await bridge.clear()
    }

    // MARK: - Hit rate computation

    func testHitRateAfterMixedLookups() async throws {
        let (bridge, cache) = try await makeCleanCache()
        try await cache.cacheSummary(
            makeSummary(input: "cached-1"))
        try await cache.cacheSummary(
            makeSummary(input: "cached-2"))
        // 2 hits, 3 misses → rate = 2/5 = 0.4
        _ = await cache.cachedSummary(
            forInput: "cached-1")  // hit
        _ = await cache.cachedSummary(
            forInput: "cached-2")  // hit
        _ = await cache.cachedSummary(
            forInput: "miss-1")    // miss
        _ = await cache.cachedSummary(
            forInput: "miss-2")    // miss
        _ = await cache.cachedSummary(
            forInput: "miss-3")    // miss
        let rate = await cache.hitRate
        XCTAssertEqual(rate, 0.4, accuracy: 1e-9)
        try? await bridge.clear()
    }

    // MARK: - clear() resets counters

    func testClearResetsTelemetryCounters() async throws {
        let (bridge, cache) = try await makeCleanCache()
        try await cache.cacheSummary(
            makeSummary(input: "k"))
        _ = await cache.cachedSummary(forInput: "k")
        _ = await cache.cachedSummary(forInput: "miss")
        try await cache.clear()
        let hits = await cache.cumulativeHits
        let misses = await cache.cumulativeMisses
        XCTAssertEqual(hits, 0)
        XCTAssertEqual(misses, 0)
        try? await bridge.clear()
    }

    // MARK: - Telemetry snapshot

    func testTelemetrySnapshotCarriesAllFields() async throws {
        let (bridge, cache) = try await makeCleanCache()
        try await cache.cacheSummary(
            makeSummary(input: "k"))
        _ = await cache.cachedSummary(forInput: "k")
        _ = await cache.cachedSummary(forInput: "miss")
        let snap = await cache.telemetrySnapshot()
        XCTAssertEqual(snap.hits, 1)
        XCTAssertEqual(snap.misses, 1)
        XCTAssertEqual(snap.cacheSize, 1)
        XCTAssertEqual(snap.totalLookups, 2)
        XCTAssertEqual(snap.hitRate, 0.5,
            accuracy: 1e-9)
        try? await bridge.clear()
    }

    func testTelemetrySnapshotCodableRoundTrip()
        async throws
    {
        let snap = BASCxxBrainSummaryCacheTelemetry(
            hits: 42, misses: 7, cacheSize: 100)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(
            BASCxxBrainSummaryCacheTelemetry.self,
            from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.totalLookups, 49)
        XCTAssertEqual(decoded.hitRate,
            42.0 / 49.0, accuracy: 1e-9)
    }

    // MARK: - End-to-end via brain (real cascade)

    func testEndToEndHitRateAfterCacheHit() async throws {
        let (bridge, cache) = try await makeCleanCache()
        let brain = try await BASCognitiveBrain
            .makeWithDefaults(
                cxxSummaryCache: cache)
        // First call → miss
        _ = await brain.summary("end-to-end test")
        // Second call → hit
        _ = await brain.summary("end-to-end test")
        let snap = await cache.telemetrySnapshot()
        XCTAssertEqual(snap.hits, 1,
            "Second identical call must register as a" +
            " hit in cache telemetry")
        XCTAssertEqual(snap.misses, 1,
            "First call must register as a miss")
        XCTAssertEqual(snap.hitRate, 0.5,
            accuracy: 1e-9)
        try? await bridge.clear()
    }
}
