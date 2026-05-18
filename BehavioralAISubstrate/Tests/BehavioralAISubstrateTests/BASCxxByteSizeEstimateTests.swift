// MARK: - BASCxxByteSizeEstimateTests
// 主线 解构 重构: C++ pilot now exposes
// `byteSizeEstimate()` — iterates the cache under ONE
// mutex acquisition,sums every stored key+value length。
// 术业有专攻 example: container iteration where the
// container lives,not over a Swift bridge round-trip。

import XCTest
@testable import BASHostKit
@testable import BASMetalSubstrate
@testable import BASMPSGraphExecutableCacheCxx

final class BASCxxByteSizeEstimateTests: XCTestCase {

    private func makeCleanBridge() async throws
        -> BASMPSGraphExecutableCacheCxxBridge
    {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: true)
        try await bridge.clear()
        return bridge
    }

    // MARK: - Bridge-level surface

    func testEmptyCacheReturnsZero() async throws {
        let bridge = try await makeCleanBridge()
        let bytes = try await bridge.byteSizeEstimate()
        XCTAssertEqual(bytes, 0,
            "Empty cache → 0 bytes content")
        try? await bridge.clear()
    }

    func testSingleEntrySumsKeyAndValueLengths()
        async throws
    {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(
            key: "abc",       // 3 bytes
            value: "12345")   // 5 bytes
        let bytes = try await bridge.byteSizeEstimate()
        XCTAssertEqual(bytes, 8,
            "Single entry → 3 + 5 = 8 bytes")
        try? await bridge.clear()
    }

    func testMultipleEntriesSumAllKeysAndValues()
        async throws
    {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(
            key: "k1", value: "v1")           // 2 + 2 = 4
        try await bridge.insert(
            key: "key2", value: "value2")     // 4 + 6 = 10
        try await bridge.insert(
            key: "k", value: "longer-value")  // 1 + 12 = 13
        let bytes = try await bridge.byteSizeEstimate()
        XCTAssertEqual(bytes, 27,
            "Three entries → 4 + 10 + 13 = 27 bytes")
        try? await bridge.clear()
    }

    func testOverwriteReflectsNewValueSize() async throws {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(
            key: "key", value: "x")          // 3 + 1 = 4
        let firstBytes = try await bridge
            .byteSizeEstimate()
        XCTAssertEqual(firstBytes, 4)
        // Overwrite with larger value
        try await bridge.insert(
            key: "key", value: "much-longer-value")
        let secondBytes = try await bridge
            .byteSizeEstimate()
        XCTAssertEqual(secondBytes, 3 + 17,
            "Overwrite → 3 (key) + 17 (new value)")
        try? await bridge.clear()
    }

    func testClearResetsByteSizeToZero() async throws {
        let bridge = try await makeCleanBridge()
        try await bridge.insert(key: "a", value: "b")
        let beforeBytes = try await bridge
            .byteSizeEstimate()
        XCTAssertEqual(beforeBytes, 2)
        try await bridge.clear()
        let afterBytes = try await bridge
            .byteSizeEstimate()
        XCTAssertEqual(afterBytes, 0)
    }

    // MARK: - V1 path (useCxxCache false)

    func testV1PathReturnsZero() async throws {
        let bridge =
            BASMPSGraphExecutableCacheCxxBridge(
                useCxxCache: false)
        let bytes = try await bridge.byteSizeEstimate()
        XCTAssertEqual(bytes, 0,
            "V1 path returns 0 without consulting cache")
    }

    // MARK: - Telemetry snapshot integration

    func testTelemetrySnapshotIncludesByteSize()
        async throws
    {
        let bridge = try await makeCleanBridge()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        let summary = BASCognitiveBrainSummary(
            input: "hello world",
            taskType: .chat,
            confidence: 0.9,
            ambiguityScore: 0.1,
            safetyVerdict: .safe,
            manipulationHints: [],
            latencyNanos: 1)
        try await cache.cacheSummary(summary)
        let snap = await cache.telemetrySnapshot()
        XCTAssertEqual(snap.cacheSize, 1)
        XCTAssertGreaterThan(snap.contentByteSizeEstimate,
            0,
            "Telemetry snapshot must surface byte size")
        XCTAssertGreaterThan(snap.averageBytesPerEntry, 0)
        try? await bridge.clear()
    }

    func testTelemetryAverageBytesPerEntryEmpty()
        async throws
    {
        let bridge = try await makeCleanBridge()
        let cache = BASCxxBrainSummaryCache(bridge: bridge)
        let snap = await cache.telemetrySnapshot()
        XCTAssertEqual(snap.cacheSize, 0)
        XCTAssertEqual(snap.contentByteSizeEstimate, 0)
        XCTAssertEqual(snap.averageBytesPerEntry, 0,
            "averageBytesPerEntry returns 0 on empty cache" +
            " (no division by zero)")
        try? await bridge.clear()
    }

    func testTelemetryCodableRoundTripWithByteSize()
        throws
    {
        let snap = BASCxxBrainSummaryCacheTelemetry(
            hits: 5, misses: 3, cacheSize: 4,
            contentByteSizeEstimate: 512)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(
            BASCxxBrainSummaryCacheTelemetry.self,
            from: data)
        XCTAssertEqual(decoded, snap)
        XCTAssertEqual(decoded.contentByteSizeEstimate, 512)
        XCTAssertEqual(decoded.averageBytesPerEntry, 128,
            "512 / 4 entries = 128")
    }

    func testTelemetryBackwardCompatDefaultZero() {
        // Legacy initializer (no byte-size param) defaults
        // to 0 for forward-compat with stored historical
        // telemetry data。
        let snap = BASCxxBrainSummaryCacheTelemetry(
            hits: 10, misses: 0, cacheSize: 5)
        XCTAssertEqual(snap.contentByteSizeEstimate, 0)
    }

    // MARK: - Raw C function

    func testRawCFunctionVersionPin() {
        XCTAssertEqual(
            bas_mps_cache_byte_size_estimate_version(),
            1)
    }
}
