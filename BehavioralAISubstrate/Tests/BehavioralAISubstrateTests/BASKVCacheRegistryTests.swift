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

    // MARK: - chapter 五百二 / M1385 — typed policy wire-in

    func testDefaultInitPicksExplicitOnlyPolicy() {
        let registry = BASKVCacheRegistry()
        XCTAssertEqual(
            registry.invalidationPolicy,
            .explicitOnly,
            "chapter 502 wire-in pin:default registry" +
            " MUST report .explicitOnly policy" +
            " (preserves chapter 482 behavior)")
    }

    func testExplicitPolicyInitStoresLRU() {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru)
        XCTAssertEqual(
            registry.invalidationPolicy, .lru,
            "registry MUST store the host-declared" +
            " policy even when not yet implemented" +
            " (honest typed contract)")
    }

    func testExplicitPolicyInitStoresAllFourCases() {
        for policy in BASKVCacheInvalidationPolicy
            .allCases
        {
            let registry = BASKVCacheRegistry(
                invalidationPolicy: policy)
            XCTAssertEqual(
                registry.invalidationPolicy, policy)
        }
    }

    func testRuntimeBehaviorMatchesActiveDoctrine() async
    {
        // HONEST scope:registries constructed with
        // non-explicit-only policies STORE the value
        // but still behave per the active implemented
        // policy (.explicitOnly)。 Tested:LRU-tagged
        // registry retains entries across many appends
        // (no eviction fires)。
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru)
        for sessionID in ["s1", "s2", "s3"] {
            await registry.appendToken(
                sampleToken(),
                atLayer: 0,
                sessionID: sessionID)
        }
        let count = await registry.sessionCount
        XCTAssertEqual(count, 3,
            "non-explicit policy stored but NOT active:" +
            " LRU-tagged registry MUST retain all 3" +
            " entries (matches .explicitOnly behavior" +
            " until follow-up arc wires LRU impl)")
    }
}
