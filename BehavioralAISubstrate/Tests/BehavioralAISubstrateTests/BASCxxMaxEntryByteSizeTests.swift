// MARK: - BASCxxMaxEntryByteSizeTests
// 主线 解构 重构 Round 3: C++ pilot now exposes
// `maxEntryByteSize()` — single-pass scan returning the
// largest (key.size + value.size) sum。 Hosts use this
// to detect oversized-entry abuse。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASMPSGraphExecutableCacheCxx

final class BASCxxMaxEntryByteSizeTests: XCTestCase {

    private func makeCleanBridge() async throws
        -> BASMPSGraphExecutableCacheCxxBridge
    {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        return bridge
    }

    // MARK: - Empty cache

    func testEmptyCacheReturnsZero() async throws {
        let bridge = try await makeCleanBridge()
        let max = try await bridge.maxEntryByteSize()
        XCTAssertEqual(max, 0)
        try? await bridge.clear()
    }

    // MARK: - Single entry

    func testSingleEntryReturnsItsSize() async throws {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(
            key: "key", value: "value")  // 3 + 5 = 8
        let max = try await bridge.maxEntryByteSize()
        XCTAssertEqual(max, 8)
        try? await bridge.clear()
    }

    // MARK: - Multiple entries — find the largest

    func testMultipleEntriesReturnsLargest() async throws {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(
            key: "a", value: "b")          // 1 + 1 = 2
        try await bridge.insert(
            key: "k", value: "longest-value-here")
                                            // 1 + 18 = 19
        try await bridge.insert(
            key: "mid", value: "midval")   // 3 + 6 = 9
        let max = try await bridge.maxEntryByteSize()
        XCTAssertEqual(max, 19,
            "Single-pass max picks the largest of the 3" +
            " entries")
        try? await bridge.clear()
    }

    func testMaxOnTie() async throws {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(
            key: "aa", value: "bb")  // 2 + 2 = 4
        try await bridge.insert(
            key: "cc", value: "dd")  // 2 + 2 = 4
        let max = try await bridge.maxEntryByteSize()
        XCTAssertEqual(max, 4,
            "Tie → either entry's size is correct")
        try? await bridge.clear()
    }

    // MARK: - V1 path

    func testV1PathReturnsZero() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: false)
        let max = try await bridge.maxEntryByteSize()
        XCTAssertEqual(max, 0)
    }

    // MARK: - Clear semantics

    func testClearResetsMaxToZero() async throws {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(
            key: "key", value: "value")
        let maxBefore = try await bridge.maxEntryByteSize()
        XCTAssertEqual(maxBefore, 8)
        try await bridge.clear()
        let maxAfter = try await bridge.maxEntryByteSize()
        XCTAssertEqual(maxAfter, 0)
    }

    // MARK: - Telemetry snapshot

    func testTelemetrySnapshotIncludesMaxEntryByteSize()
        async throws
    {
        let bridge = try await makeCleanBridge()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        let small = BASCognitiveBrainSummary(
            input: "x",
            taskType: .chat,
            confidence: 0.9, ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1)
        let larger = BASCognitiveBrainSummary(
            input: String(repeating: "long-input-", count: 5),
            taskType: .chat,
            confidence: 0.9, ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [], latencyNanos: 1)
        try await cache.cacheSummary(small)
        try await cache.cacheSummary(larger)
        let snap = await cache.telemetrySnapshot()
        XCTAssertEqual(snap.cacheSize, 2)
        XCTAssertGreaterThan(snap.maxEntryByteSize, 0)
        XCTAssertGreaterThanOrEqual(
            snap.maxEntryByteSize,
            snap.contentByteSizeEstimate / 2,
            "Max entry must be at least the average")
        try? await bridge.clear()
    }

    func testTelemetryEntrySkewRatio() async throws {
        // Skew = max / average。 With uniform entries
        // skew ≈ 1。 With one huge entry + many tiny,
        // skew >> 1。
        let bridge = try await makeCleanBridge()
        // Uniform: 3 entries each key+value = 6 bytes
        try await bridge.insert(key: "aa", value: "bb")
        try await bridge.insert(key: "cc", value: "dd")
        try await bridge.insert(key: "ee", value: "ff")
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        let snap = await cache.telemetrySnapshot()
        XCTAssertEqual(snap.entrySkewRatio, 1.0,
            accuracy: 0.001,
            "Uniform entries → skew = 1.0")
        try? await bridge.clear()
    }

    func testTelemetryEntrySkewEmptyCache() async throws {
        let bridge = try await makeCleanBridge()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        let snap = await cache.telemetrySnapshot()
        XCTAssertEqual(snap.entrySkewRatio, 0.0,
            "Empty cache → skew = 0 (no div by zero)")
        try? await bridge.clear()
    }

    // MARK: - Codable round-trip

    func testTelemetryCodableRoundTripWithMaxField()
        throws
    {
        let snap = BASCxxBrainSummaryCacheTelemetry(
            hits: 10, misses: 5,
            cacheSize: 4,
            contentByteSizeEstimate: 400,
            maxEntryByteSize: 250)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(
            BASCxxBrainSummaryCacheTelemetry.self,
            from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.maxEntryByteSize, 250)
        XCTAssertEqual(decoded.entrySkewRatio,
            250.0 / 100.0, accuracy: 0.001,
            "Skew = 250 / (400/4) = 2.5")
    }

    func testTelemetryBackwardCompatDefaultZero() {
        let snap = BASCxxBrainSummaryCacheTelemetry(
            hits: 0, misses: 0, cacheSize: 0)
        XCTAssertEqual(snap.maxEntryByteSize, 0)
        XCTAssertEqual(snap.entrySkewRatio, 0.0)
    }

    // MARK: - Raw C function

    func testRawCFunctionVersionPin() {
        XCTAssertEqual(
            bas_mps_cache_max_entry_byte_size_version(), 1)
    }
}
