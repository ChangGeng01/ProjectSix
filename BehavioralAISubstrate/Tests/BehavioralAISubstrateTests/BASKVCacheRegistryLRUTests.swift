// MARK: - BASKVCacheRegistryLRUTests
// chapter 六百九十 / M2131 第二刀 — LRU integration tests
//                                for BASKVCacheRegistry

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASKVCacheRegistryLRUTests: XCTestCase {

    // MARK: - Default init preserves M1306 behavior

    func testDefaultInitHasNoCapacity() async {
        let registry = BASKVCacheRegistry()
        XCTAssertNil(registry.capacity)
        XCTAssertEqual(
            registry.invalidationPolicy,
            .explicitOnly)
    }

    func testDefaultInitHasNoLRUEvictions() async {
        let registry = BASKVCacheRegistry()
        let evictions = await registry.totalLRUEvictions
        XCTAssertEqual(evictions, 0)
    }

    // MARK: - LRU init carries policy + capacity

    func testLRUInitCarriesPolicyAndCapacity() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru,
            capacity: 5)
        XCTAssertEqual(
            registry.invalidationPolicy, .lru)
        XCTAssertEqual(registry.capacity, 5)
    }

    func testLRUInitDoesNotEvictBeforeStorage() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru,
            capacity: 5)
        let evictions = await registry.totalLRUEvictions
        XCTAssertEqual(evictions, 0)
    }

    // MARK: - LRU eviction when capacity exceeded

    func testLRUEvictsOldestWhenCapacityExceeded() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru,
            capacity: 2)

        // Store 3 sessions in order — first one (s1)
        // should be evicted when s3 is stored
        await registry.storeSession(
            makeSession("s1"))
        await registry.storeSession(
            makeSession("s2"))
        await registry.storeSession(
            makeSession("s3"))

        let count = await registry.sessionCount
        XCTAssertEqual(count, 2)
        let evictions = await registry.totalLRUEvictions
        XCTAssertEqual(evictions, 1)
        // s1 should be gone,s2 + s3 preserved
        let s1 = await registry.cachedSession(
            for: "s1")
        XCTAssertNil(s1)
        let s2 = await registry.cachedSession(
            for: "s2")
        XCTAssertNotNil(s2)
        let s3 = await registry.cachedSession(
            for: "s3")
        XCTAssertNotNil(s3)
    }

    func testLRUEvictsMultipleWhenStorageExceedsCap() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru,
            capacity: 1)

        // Store 4 sessions — 3 evicted leaving only s4
        await registry.storeSession(
            makeSession("s1"))
        await registry.storeSession(
            makeSession("s2"))
        await registry.storeSession(
            makeSession("s3"))
        await registry.storeSession(
            makeSession("s4"))

        let count = await registry.sessionCount
        XCTAssertEqual(count, 1)
        let evictions = await registry.totalLRUEvictions
        XCTAssertEqual(evictions, 3)
        let s4 = await registry.cachedSession(
            for: "s4")
        XCTAssertNotNil(s4)
    }

    // MARK: - Access updates LRU ordering

    func testAccessingSessionUpdatesLRUOrdering() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru,
            capacity: 2)

        await registry.storeSession(
            makeSession("s_oldest"))
        await registry.storeSession(
            makeSession("s_middle"))

        // Access s_oldest — promotes it to most-recent
        _ = await registry.cachedSession(
            for: "s_oldest")

        // Store s_new — should evict s_middle (now
        // oldest after s_oldest was accessed) NOT
        // s_oldest
        await registry.storeSession(
            makeSession("s_new"))

        let count = await registry.sessionCount
        XCTAssertEqual(count, 2)
        // s_middle should be evicted
        let middle = await registry.cachedSession(
            for: "s_middle")
        XCTAssertNil(middle)
        // s_oldest preserved (was promoted by access)
        let oldest = await registry.cachedSession(
            for: "s_oldest")
        XCTAssertNotNil(oldest)
        let newSession = await registry.cachedSession(
            for: "s_new")
        XCTAssertNotNil(newSession)
    }

    // MARK: - .explicitOnly does NOT evict (back-compat)

    func testExplicitOnlyWithCapacityDoesNotEvict() async {
        // Constructing with .explicitOnly + capacity
        // should STORE capacity but NOT auto-evict
        // (per honest scope:LRU only triggers when
        // policy == .lru)
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .explicitOnly,
            capacity: 2)

        await registry.storeSession(
            makeSession("s1"))
        await registry.storeSession(
            makeSession("s2"))
        await registry.storeSession(
            makeSession("s3"))

        // No eviction — .explicitOnly is not LRU
        let count = await registry.sessionCount
        XCTAssertEqual(count, 3)
        let evictions = await registry.totalLRUEvictions
        XCTAssertEqual(evictions, 0)
    }

    // MARK: - appendToken triggers LRU correctly

    func testAppendTokenTriggersLRUEviction() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru,
            capacity: 2)

        let token = makeToken()
        // Create 3 sessions via appendToken
        await registry.appendToken(
            token, atLayer: 0, sessionID: "s1")
        await registry.appendToken(
            token, atLayer: 0, sessionID: "s2")
        await registry.appendToken(
            token, atLayer: 0, sessionID: "s3")

        let count = await registry.sessionCount
        XCTAssertEqual(count, 2)
        let s1 = await registry.cachedSession(for: "s1")
        XCTAssertNil(s1)
    }

    // MARK: - Invalidate cleans up access ticks

    func testInvalidateAllClearsAccessTicks() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru,
            capacity: 10)

        await registry.storeSession(makeSession("s1"))
        await registry.storeSession(makeSession("s2"))
        await registry.invalidateAll()
        let count = await registry.sessionCount
        XCTAssertEqual(count, 0)
        // After invalidateAll,LRU state should be reset
        // — storing new sessions should not trigger
        // eviction
        await registry.storeSession(makeSession("s3"))
        let evictions = await registry.totalLRUEvictions
        XCTAssertEqual(evictions, 0)
    }

    func testInvalidateSpecificClearsItsAccessTick() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru,
            capacity: 2)

        await registry.storeSession(makeSession("s1"))
        await registry.storeSession(makeSession("s2"))
        // Explicitly invalidate s1
        await registry.invalidate(sessionID: "s1")
        // Storing s3 should NOT trigger eviction
        // (only 1 session before, +1 = 2 = capacity)
        await registry.storeSession(makeSession("s3"))
        let evictions = await registry.totalLRUEvictions
        XCTAssertEqual(evictions, 0)
        let count = await registry.sessionCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - Helpers

    private func makeSession(_ id: String)
        -> BASTransformerKVCacheSession
    {
        return BASTransformerKVCacheSession(
            sessionID: id)
    }

    private func makeToken()
        -> BASTransformerKVCacheToken
    {
        return BASTransformerKVCacheToken(
            keyBytes: Data(repeating: 0, count: 16),
            valueBytes: Data(repeating: 0, count: 16),
            elementCount: 4)
    }
}
