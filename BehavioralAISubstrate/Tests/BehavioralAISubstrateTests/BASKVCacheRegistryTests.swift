// MARK: - BASKVCacheRegistryTests
// chapter 四百八十二 / M1306

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASKVCacheRegistryTests: XCTestCase {

    private func sampleToken() -> BASTransformerKVCacheToken {
        return BASTransformerKVCacheToken(
            keyBytes: Data([0, 0, 0, 0]),
            valueBytes: Data([1, 1, 1, 1]),
            elementCount: 1)
    }

    func testEmptyRegistryHasZeroLookups() async {
        let registry = BASKVCacheRegistry()
        let sessionCount = await registry.sessionCount
        let hits = await registry.totalHits
        let misses = await registry.totalMisses
        XCTAssertEqual(sessionCount, 0)
        XCTAssertEqual(hits, 0)
        XCTAssertEqual(misses, 0)
    }

    func testMissOnUncachedSessionRecordsObservation()
        async
    {
        let registry = BASKVCacheRegistry()
        let result = await registry.cachedSession(
            for: "unknown")
        XCTAssertNil(result)
        let misses = await registry.totalMisses
        XCTAssertEqual(misses, 1)
    }

    func testStoreAndLookupRoundTripRecordsHit() async {
        let registry = BASKVCacheRegistry()
        var session = BASTransformerKVCacheSession(
            sessionID: "test")
        session = session.appending(
            token: sampleToken(), atLayer: 0)
        await registry.storeSession(session)
        let retrieved = await registry.cachedSession(
            for: "test")
        XCTAssertEqual(retrieved, session)
        let hits = await registry.totalHits
        XCTAssertEqual(hits, 1)
    }

    func testAppendTokenCreatesSessionImplicitly() async {
        let registry = BASKVCacheRegistry()
        await registry.appendToken(
            sampleToken(),
            atLayer: 0,
            sessionID: "new")
        let session = await registry.cachedSession(
            for: "new")
        XCTAssertNotNil(session)
        XCTAssertEqual(
            session?.tokensByLayer[0]?.count, 1)
    }

    func testInvalidateRemovesSpecificSession() async {
        let registry = BASKVCacheRegistry()
        await registry.appendToken(
            sampleToken(), atLayer: 0, sessionID: "a")
        await registry.appendToken(
            sampleToken(), atLayer: 0, sessionID: "b")
        await registry.invalidate(sessionID: "a")
        let aResult = await registry.cachedSession(
            for: "a")
        let bResult = await registry.cachedSession(
            for: "b")
        XCTAssertNil(aResult)
        XCTAssertNotNil(bResult)
    }

    func testHitRatioCalculation() async {
        let registry = BASKVCacheRegistry()
        await registry.appendToken(
            sampleToken(), atLayer: 0, sessionID: "s")
        // 2 hits + 1 miss
        _ = await registry.cachedSession(for: "s")
        _ = await registry.cachedSession(for: "s")
        _ = await registry.cachedSession(for: "x")
        let ratio = await registry.hitRatio
        XCTAssertEqual(
            ratio, 2.0 / 3.0, accuracy: 0.001)
    }

    func testTotalCachedBytesAggregatesAcrossSessions()
        async
    {
        let registry = BASKVCacheRegistry()
        for sessionID in ["a", "b", "c"] {
            await registry.appendToken(
                sampleToken(),
                atLayer: 0,
                sessionID: sessionID)
        }
        let bytes = await registry.totalCachedBytes
        // 3 sessions × (4 key + 4 value) = 24
        XCTAssertEqual(bytes, 24)
        let tokens = await registry.totalCachedTokens
        XCTAssertEqual(tokens, 3)
    }
}
