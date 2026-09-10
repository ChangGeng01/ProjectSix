// MARK: - BASKVCacheRegistryTTLTests
// chapter 六百九十一 / M2135 第二刀 — TTL integration tests
//                                  for BASKVCacheRegistry

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASKVCacheRegistryTTLTests: XCTestCase {

    // MARK: - Default init has no TTL

    func testDefaultInitHasNoTtlMs() async {
        let registry = BASKVCacheRegistry()
        XCTAssertNil(registry.ttlMs)
    }

    // MARK: - TTL init carries policy + ttlMs

    func testTTLInitCarriesPolicyAndTtlMs() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .ttl,
            capacity: nil,
            ttlMs: 1000,
            clockMillisProvider: nil)
        XCTAssertEqual(
            registry.invalidationPolicy, .ttl)
        XCTAssertEqual(registry.ttlMs, 1000)
    }

    func testTTLInitDoesNotEvictBeforeStorage() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .ttl,
            ttlMs: 1000)
        let evictions = await registry.totalTTLEvictions
        XCTAssertEqual(evictions, 0)
    }

    // MARK: - TTL eviction with controlled clock

    func testTTLEvictsExpiredSession() async {
        // Use a controllable clock — start at 1_000_000
        // and advance manually
        actor ControllableClock {
            var nowMs: Int64 = 1_000_000
            func advance(by ms: Int64) { nowMs += ms }
            func current() -> Int64 { nowMs }
        }
        _ = ControllableClock()
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .ttl,
            capacity: nil,
            ttlMs: 1000,
            clockMillisProvider: { @Sendable in
                // Block on actor read via concurrent
                // suspension — for test purposes the
                // synchronous call uses a snapshot
                return ControllableClockReader.lastSet
            })
        ControllableClockReader.lastSet = 1_000_000

        // Store s1 at t=1_000_000
        await registry.storeSession(makeSession("s1"))

        // Advance clock by 2 seconds (2000ms) > 1000ms TTL
        ControllableClockReader.lastSet = 1_000_000 + 2000

        // Store s2 — this triggers sweep evicting s1
        await registry.storeSession(makeSession("s2"))

        let evictions = await registry.totalTTLEvictions
        XCTAssertEqual(evictions, 1)
        let s1 = await registry.cachedSession(for: "s1")
        XCTAssertNil(s1, "s1 should be evicted (stale)")
        let s2 = await registry.cachedSession(for: "s2")
        XCTAssertNotNil(s2)
    }

    func testTTLPreservesFreshSessions() async {
        ControllableClockReader.lastSet = 5_000_000

        let registry = BASKVCacheRegistry(
            invalidationPolicy: .ttl,
            capacity: nil,
            ttlMs: 1000,
            clockMillisProvider: { @Sendable in
                return ControllableClockReader.lastSet
            })

        await registry.storeSession(makeSession("s1"))
        // Advance by 500ms — within TTL
        ControllableClockReader.lastSet = 5_000_500
        await registry.storeSession(makeSession("s2"))

        let evictions = await registry.totalTTLEvictions
        XCTAssertEqual(evictions, 0)
        let count = await registry.sessionCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - cachedSession refreshes timestamp under .ttl

    func testCachedSessionRefreshesTimestamp() async {
        ControllableClockReader.lastSet = 10_000_000

        let registry = BASKVCacheRegistry(
            invalidationPolicy: .ttl,
            capacity: nil,
            ttlMs: 1000,
            clockMillisProvider: { @Sendable in
                return ControllableClockReader.lastSet
            })

        await registry.storeSession(makeSession("s1"))
        // Advance just under TTL — access s1 to refresh
        ControllableClockReader.lastSet = 10_000_900
        _ = await registry.cachedSession(for: "s1")
        // Advance again — without refresh,s1 would now
        // be at age=1100>1000;but the refresh at t=900
        // reset its timestamp,so age at t=1700 is 800
        // < 1000 → fresh
        ControllableClockReader.lastSet = 10_001_700
        await registry.storeSession(makeSession("s2"))
        // s1 should survive because access refreshed it
        let s1 = await registry.cachedSession(for: "s1")
        XCTAssertNotNil(s1,
            "s1 should survive — access refreshed " +
            "its timestamp")
    }

    // MARK: - .explicitOnly + ttlMs is INERT

    func testExplicitOnlyDoesNotApplyTTL() async {
        ControllableClockReader.lastSet = 20_000_000

        let registry = BASKVCacheRegistry(
            invalidationPolicy: .explicitOnly,
            capacity: nil,
            ttlMs: 1000,
            clockMillisProvider: { @Sendable in
                return ControllableClockReader.lastSet
            })

        await registry.storeSession(makeSession("s1"))
        ControllableClockReader.lastSet = 20_005_000
        await registry.storeSession(makeSession("s2"))

        // No TTL eviction because policy != .ttl
        let evictions = await registry.totalTTLEvictions
        XCTAssertEqual(evictions, 0)
        let count = await registry.sessionCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - .never policy semantic — no auto-eviction

    func testNeverPolicyDoesNotEvict() async {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .never,
            capacity: 1,
            ttlMs: 1)

        // Even with capacity=1 + ttlMs=1,storing
        // multiple sessions should NOT evict
        await registry.storeSession(makeSession("s1"))
        await registry.storeSession(makeSession("s2"))
        await registry.storeSession(makeSession("s3"))

        // .never semantic preserves all sessions
        let count = await registry.sessionCount
        XCTAssertEqual(count, 3,
            ".never policy must NOT auto-evict regardless" +
            " of capacity or ttlMs hints")
        let lruEvictions =
            await registry.totalLRUEvictions
        XCTAssertEqual(lruEvictions, 0)
        let ttlEvictions =
            await registry.totalTTLEvictions
        XCTAssertEqual(ttlEvictions, 0)
    }

    // MARK: - invalidateAll clears timestamps

    func testInvalidateAllClearsTimestamps() async {
        ControllableClockReader.lastSet = 30_000_000

        let registry = BASKVCacheRegistry(
            invalidationPolicy: .ttl,
            capacity: nil,
            ttlMs: 1000,
            clockMillisProvider: { @Sendable in
                return ControllableClockReader.lastSet
            })

        await registry.storeSession(makeSession("s1"))
        await registry.invalidateAll()
        let count = await registry.sessionCount
        XCTAssertEqual(count, 0)
        // After invalidateAll storing new sessions
        // should not trigger stale-timestamp eviction
        ControllableClockReader.lastSet = 30_005_000
        await registry.storeSession(makeSession("s2"))
        let evictions = await registry.totalTTLEvictions
        XCTAssertEqual(evictions, 0,
            "After invalidateAll, timestamps reset — no " +
            "TTL eviction from old timestamps")
    }

    // MARK: - Helpers

    private func makeSession(_ id: String)
        -> BASTransformerKVCacheSession
    {
        return BASTransformerKVCacheSession(
            sessionID: id)
    }
}

/// Test-only Sendable wrapper for a controllable clock。
/// Uses a static atomic write to bridge non-Sendable
/// actor state across @Sendable closure boundaries。 In
/// production code this pattern would be replaced with
/// a proper Clock abstraction;for tests it's sufficient。
enum ControllableClockReader {
    /// Thread-safe static for test purposes only。 Tests
    /// must serialize their clock writes — XCTest runs
    /// tests sequentially within a single suite so this
    /// is safe here。
    nonisolated(unsafe) static var lastSet: Int64 = 0
}
