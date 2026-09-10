// MARK: - BASKVCacheLRUEvictorTests
// chapter 六百九十 / M2130 第一刀 — anti-drift PROOF tests
//                                for LRU eviction
//                                algorithm

import XCTest
@testable import BASHostKit

final class BASKVCacheLRUEvictorTests: XCTestCase {

    // MARK: - Default capacity pin

    func testDefaultCapacityIs64() {
        XCTAssertEqual(
            BASKVCacheLRUEvictor.defaultCapacity, 64)
    }

    // MARK: - No eviction when within capacity

    func testNoEvictionWhenEmpty() {
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: [:],
            capacity: 10)
        XCTAssertEqual(decision.evictionCount, 0)
        XCTAssertEqual(
            decision.preservedSessionIDs.count, 0)
        XCTAssertEqual(
            decision.preEvictionSessionCount, 0)
        XCTAssertEqual(
            decision.postEvictionSessionCount, 0)
    }

    func testNoEvictionWhenExactlyAtCapacity() {
        let ticks: [String: Int] = [
            "s1": 1, "s2": 2, "s3": 3
        ]
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 3)
        XCTAssertEqual(decision.evictionCount, 0)
        XCTAssertEqual(
            decision.preservedSessionIDs.count, 3)
    }

    func testNoEvictionWhenUnderCapacity() {
        let ticks: [String: Int] = [
            "s1": 1, "s2": 2
        ]
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 10)
        XCTAssertEqual(decision.evictionCount, 0)
        XCTAssertEqual(
            decision.preservedSessionIDs.count, 2)
    }

    // MARK: - Eviction when over capacity

    func testEvictsSingleOldestWhenOneOverCapacity() {
        let ticks: [String: Int] = [
            "s1": 1,  // oldest — should be evicted
            "s2": 5,
            "s3": 10
        ]
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 2)
        XCTAssertEqual(decision.evictionCount, 1)
        XCTAssertEqual(
            decision.evictedSessionIDs, ["s1"])
        XCTAssertEqual(decision.preEvictionSessionCount, 3)
        XCTAssertEqual(
            decision.postEvictionSessionCount, 2)
    }

    func testEvictsMultipleWhenManyOverCapacity() {
        let ticks: [String: Int] = [
            "s1": 1,   // oldest
            "s2": 2,
            "s3": 3,
            "s4": 4,
            "s5": 5    // newest
        ]
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 2)
        XCTAssertEqual(decision.evictionCount, 3)
        // Evicted: s1, s2, s3 (3 oldest)
        XCTAssertEqual(
            Set(decision.evictedSessionIDs),
            ["s1", "s2", "s3"])
        // Preserved: s4, s5
        XCTAssertEqual(
            Set(decision.preservedSessionIDs),
            ["s4", "s5"])
    }

    // MARK: - Eviction ordering (oldest first)

    func testEvictedListOrderedByAccessTickAscending() {
        let ticks: [String: Int] = [
            "s_newest": 100,
            "s_middle": 50,
            "s_oldest": 1
        ]
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 1)
        // 2 evicted,1 preserved
        XCTAssertEqual(decision.evictionCount, 2)
        // Evicted list ordered oldest-first
        XCTAssertEqual(
            decision.evictedSessionIDs,
            ["s_oldest", "s_middle"])
        XCTAssertEqual(
            decision.preservedSessionIDs,
            ["s_newest"])
    }

    func testPreservedListOrderedByAccessTickDescending() {
        let ticks: [String: Int] = [
            "s1": 1,
            "s2": 5,
            "s3": 3,
            "s4": 10
        ]
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 4)
        // No eviction needed,but preserved list should
        // be ordered descending by tick
        XCTAssertEqual(decision.evictionCount, 0)
        XCTAssertEqual(
            decision.preservedSessionIDs,
            ["s4", "s2", "s3", "s1"])
    }

    // MARK: - Deterministic tiebreaking

    func testTiedAccessTicksBreakBySessionIDAscending() {
        // s_a and s_b have same tick — s_a should be
        // evicted first by ID alphabetical tiebreak
        let ticks: [String: Int] = [
            "s_a": 5,
            "s_b": 5,
            "s_z": 10
        ]
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 2)
        XCTAssertEqual(
            decision.evictedSessionIDs, ["s_a"])
        XCTAssertEqual(
            Set(decision.preservedSessionIDs),
            ["s_b", "s_z"])
    }

    func testDecisionsAreDeterministic() {
        let ticks: [String: Int] = [
            "s1": 10, "s2": 5, "s3": 1, "s4": 7
        ]
        let d1 = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 2)
        let d2 = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 2)
        XCTAssertEqual(d1, d2)
    }

    // MARK: - Helper:sortedByAccessTickDescending

    func testSortedDescendingOrdersByTick() {
        let ticks: [String: Int] = [
            "s1": 1, "s2": 100, "s3": 50
        ]
        let sorted = BASKVCacheLRUEvictor
            .sortedByAccessTickDescending(ticks)
        XCTAssertEqual(sorted, ["s2", "s3", "s1"])
    }

    func testSortedDescendingDeterministicTiebreak() {
        let ticks: [String: Int] = [
            "s_a": 5, "s_b": 5
        ]
        let sorted = BASKVCacheLRUEvictor
            .sortedByAccessTickDescending(ticks)
        // Same tick → ascending sessionID tiebreak
        XCTAssertEqual(sorted, ["s_a", "s_b"])
    }

    // MARK: - Codable round-trip on decision

    func testDecisionCodableRoundTrip() throws {
        let decision = BASKVCacheLRUEvictionDecision(
            evictedSessionIDs: ["a", "b"],
            preservedSessionIDs: ["c", "d"],
            preEvictionSessionCount: 4)
        let data = try JSONEncoder().encode(decision)
        let decoded = try JSONDecoder().decode(
            BASKVCacheLRUEvictionDecision.self,
            from: data)
        XCTAssertEqual(decoded, decision)
    }

    // MARK: - Edge case:capacity 0 evicts all

    func testZeroCapacityEvictsAll() {
        let ticks: [String: Int] = [
            "s1": 1, "s2": 2, "s3": 3
        ]
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 0)
        XCTAssertEqual(decision.evictionCount, 3)
        XCTAssertEqual(
            Set(decision.evictedSessionIDs),
            ["s1", "s2", "s3"])
        XCTAssertEqual(
            decision.preservedSessionIDs, [])
    }

    // MARK: - Edge case:large fixtures

    func testLargeFixtureOneHundredSessionsTo10() {
        var ticks: [String: Int] = [:]
        for i in 0..<100 {
            ticks["s\(i)"] = i  // s0 oldest, s99 newest
        }
        let decision = BASKVCacheLRUEvictor.decide(
            accessTicks: ticks, capacity: 10)
        XCTAssertEqual(decision.evictionCount, 90)
        // Preserved should be s90..s99 (10 newest)
        XCTAssertEqual(
            Set(decision.preservedSessionIDs),
            Set((90..<100).map { "s\($0)" }))
    }
}
