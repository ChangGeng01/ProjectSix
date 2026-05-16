// MARK: - BASKVCacheTTLEvictorTests
// chapter 六百九十一 / M2134 第一刀 — TTL evictor anti-drift
//                                  PROOF tests

import XCTest
@testable import BASHostKit

final class BASKVCacheTTLEvictorTests: XCTestCase {

    // MARK: - Default TTL pin

    func testDefaultTtlMsIs300000() {
        XCTAssertEqual(
            BASKVCacheTTLEvictor.defaultTtlMs, 300_000)
    }

    // MARK: - No eviction when within TTL

    func testNoEvictionWhenAllFresh() {
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: [
                "s1": 9_999,
                "s2": 9_500
            ],
            nowMs: 10_000,
            ttlMs: 1000)
        // Both s1 (age=1) and s2 (age=500) within 1000ms
        XCTAssertEqual(decision.evictionCount, 0)
        XCTAssertEqual(
            decision.preservedSessionIDs.count, 2)
    }

    func testNoEvictionWhenEmpty() {
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: [:],
            nowMs: 10_000,
            ttlMs: 1000)
        XCTAssertEqual(decision.evictionCount, 0)
        XCTAssertEqual(decision.preEvictionSessionCount, 0)
    }

    // MARK: - Eviction when stale

    func testEvictsStaleSession() {
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: [
                "s_stale": 1_000,     // age=9000 > 1000
                "s_fresh": 9_500      // age=500 < 1000
            ],
            nowMs: 10_000,
            ttlMs: 1000)
        XCTAssertEqual(decision.evictionCount, 1)
        XCTAssertEqual(
            decision.evictedSessionIDs, ["s_stale"])
        XCTAssertEqual(
            decision.preservedSessionIDs, ["s_fresh"])
    }

    func testEvictsMultipleStale() {
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: [
                "s1": 0,       // age=10000 stale
                "s2": 500,     // age=9500 stale
                "s3": 9_500,   // age=500 fresh
                "s4": 9_900    // age=100 fresh
            ],
            nowMs: 10_000,
            ttlMs: 1000)
        XCTAssertEqual(decision.evictionCount, 2)
        XCTAssertEqual(
            Set(decision.evictedSessionIDs),
            ["s1", "s2"])
        XCTAssertEqual(
            Set(decision.preservedSessionIDs),
            ["s3", "s4"])
    }

    // MARK: - Eviction ordering (oldest first)

    func testEvictedListOrderedOldestFirst() {
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: [
                "s_newest_stale": 5000,    // age=5000
                "s_oldest_stale": 1,       // age=9999
                "s_middle_stale": 1000     // age=9000
            ],
            nowMs: 10_000,
            ttlMs: 1000)
        XCTAssertEqual(decision.evictionCount, 3)
        XCTAssertEqual(
            decision.evictedSessionIDs,
            ["s_oldest_stale", "s_middle_stale",
             "s_newest_stale"])
    }

    // MARK: - Preserved ordering (newest first)

    func testPreservedListOrderedNewestFirst() {
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: [
                "s_low": 9_100,
                "s_high": 9_900,
                "s_mid": 9_500
            ],
            nowMs: 10_000,
            ttlMs: 1000)
        XCTAssertEqual(decision.evictionCount, 0)
        XCTAssertEqual(
            decision.preservedSessionIDs,
            ["s_high", "s_mid", "s_low"])
    }

    // MARK: - Boundary: timestamp + ttl == now is NOT stale

    func testBoundaryNonStrictlyGreaterThan() {
        // age = 1000, ttl = 1000 → age > ttl is FALSE
        // → fresh
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: ["s_boundary": 9_000],
            nowMs: 10_000,
            ttlMs: 1000)
        XCTAssertEqual(decision.evictionCount, 0)
    }

    // MARK: - Deterministic tiebreaking

    func testTiedTimestampsBreakBySessionIDAscending() {
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: [
                "s_a": 100,   // stale,age=9900
                "s_b": 100    // stale,age=9900,same ts
            ],
            nowMs: 10_000,
            ttlMs: 1000)
        // Both stale,evicted list should have s_a first
        // (alphabetical tiebreak)
        XCTAssertEqual(
            decision.evictedSessionIDs, ["s_a", "s_b"])
    }

    func testDecisionsAreDeterministic() {
        let ticks: [String: Int64] = [
            "s1": 100, "s2": 5_000, "s3": 9_000
        ]
        let d1 = BASKVCacheTTLEvictor.decide(
            timestamps: ticks,
            nowMs: 10_000,
            ttlMs: 1000)
        let d2 = BASKVCacheTTLEvictor.decide(
            timestamps: ticks,
            nowMs: 10_000,
            ttlMs: 1000)
        XCTAssertEqual(d1, d2)
    }

    // MARK: - Decision fields preserve inputs

    func testDecisionPinsNowMsAndTtlMs() {
        let decision = BASKVCacheTTLEvictor.decide(
            timestamps: ["s1": 100],
            nowMs: 10_000,
            ttlMs: 1000)
        XCTAssertEqual(decision.nowMs, 10_000)
        XCTAssertEqual(decision.ttlMs, 1000)
    }

    // MARK: - isExpired helper

    func testIsExpiredHelperReturnsTrueWhenStale() {
        XCTAssertTrue(
            BASKVCacheTTLEvictor.isExpired(
                timestamp: 100,
                nowMs: 10_000,
                ttlMs: 1000))
    }

    func testIsExpiredHelperReturnsFalseWhenFresh() {
        XCTAssertFalse(
            BASKVCacheTTLEvictor.isExpired(
                timestamp: 9_500,
                nowMs: 10_000,
                ttlMs: 1000))
    }

    // MARK: - Codable round-trip on decision

    func testDecisionCodableRoundTrip() throws {
        let decision = BASKVCacheTTLEvictionDecision(
            evictedSessionIDs: ["a", "b"],
            preservedSessionIDs: ["c"],
            preEvictionSessionCount: 3,
            nowMs: 10_000,
            ttlMs: 1000)
        let data = try JSONEncoder().encode(decision)
        let decoded = try JSONDecoder().decode(
            BASKVCacheTTLEvictionDecision.self,
            from: data)
        XCTAssertEqual(decoded, decision)
    }
}
