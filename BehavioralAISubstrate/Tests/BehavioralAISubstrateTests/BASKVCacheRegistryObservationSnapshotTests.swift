// MARK: - BASKVCacheRegistryObservationSnapshotTests
// chapter 五百二 / M1387 — typed registry snapshot tests

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore

final class BASKVCacheRegistryObservationSnapshotTests:
    XCTestCase
{

    private func sampleToken()
        -> BASTransformerKVCacheToken
    {
        return BASTransformerKVCacheToken(
            keyBytes: Data([0, 1, 2, 3]),
            valueBytes: Data([4, 5, 6, 7]),
            elementCount: 1)
    }

    // MARK: - 1) Empty-registry snapshot has zero aggregates

    func testEmptyRegistrySnapshotIsZero() async {
        let registry = BASKVCacheRegistry()
        let snapshot = await registry.snapshot(
            recordedAtMs: 1_700_000_000_000)
        XCTAssertEqual(snapshot.sessionCount, 0)
        XCTAssertEqual(snapshot.totalHits, 0)
        XCTAssertEqual(snapshot.totalMisses, 0)
        XCTAssertEqual(snapshot.totalCachedBytes, 0)
        XCTAssertEqual(snapshot.totalCachedTokens, 0)
        XCTAssertEqual(snapshot.totalLookups, 0)
        XCTAssertEqual(snapshot.hitRatio, 0.0)
        XCTAssertEqual(snapshot.recordedAtMs,
                       1_700_000_000_000)
    }

    // MARK: - 2) Snapshot captures invalidation policy

    func testSnapshotCapturesInvalidationPolicy()
        async
    {
        let registry = BASKVCacheRegistry(
            invalidationPolicy: .lru)
        let snapshot = await registry.snapshot(
            recordedAtMs: 0)
        XCTAssertEqual(snapshot.invalidationPolicy,
                       .lru,
            "snapshot MUST capture host-declared policy" +
            " (M1385 wire-in proof)")
    }

    // MARK: - 3) Snapshot reflects active aggregates

    func testSnapshotReflectsActiveAggregates() async {
        let registry = BASKVCacheRegistry()
        // Append 2 tokens across 2 sessions
        for sessionID in ["s1", "s2"] {
            await registry.appendToken(
                sampleToken(),
                atLayer: 0,
                sessionID: sessionID)
        }
        // 1 hit + 1 miss
        _ = await registry.cachedSession(for: "s1")
        _ = await registry.cachedSession(for: "missing")
        let snapshot = await registry.snapshot(
            recordedAtMs: 42)
        XCTAssertEqual(snapshot.sessionCount, 2)
        XCTAssertEqual(snapshot.totalHits, 1)
        XCTAssertEqual(snapshot.totalMisses, 1)
        XCTAssertEqual(snapshot.totalLookups, 2)
        XCTAssertEqual(snapshot.hitRatio, 0.5)
        // 2 sessions × (4 key + 4 value) = 16
        XCTAssertEqual(snapshot.totalCachedBytes, 16)
        XCTAssertEqual(snapshot.totalCachedTokens, 2)
        XCTAssertEqual(snapshot.recordedAtMs, 42)
    }

    // MARK: - 4) Snapshot is read-only (no state mutation)

    func testSnapshotDoesNotMutateRegistryState()
        async
    {
        let registry = BASKVCacheRegistry()
        await registry.appendToken(
            sampleToken(),
            atLayer: 0,
            sessionID: "s")
        let before = await registry.snapshot(
            recordedAtMs: 1)
        let after = await registry.snapshot(
            recordedAtMs: 2)
        XCTAssertEqual(before.sessionCount,
                       after.sessionCount)
        XCTAssertEqual(before.totalHits,
                       after.totalHits)
        XCTAssertEqual(before.totalCachedBytes,
                       after.totalCachedBytes)
    }

    // MARK: - 5) hitRatio in [0, 1] for all configurations

    func testHitRatioWithinRange() async {
        let registry = BASKVCacheRegistry()
        await registry.appendToken(
            sampleToken(),
            atLayer: 0,
            sessionID: "s")
        // 10 hits, 5 misses
        for _ in 0..<10 {
            _ = await registry.cachedSession(for: "s")
        }
        for i in 0..<5 {
            _ = await registry.cachedSession(
                for: "missing-\(i)")
        }
        let snapshot = await registry.snapshot(
            recordedAtMs: 0)
        XCTAssertEqual(snapshot.totalHits, 10)
        XCTAssertEqual(snapshot.totalMisses, 5)
        XCTAssertEqual(snapshot.hitRatio,
                       10.0 / 15.0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(
            snapshot.hitRatio, 0.0)
        XCTAssertLessThanOrEqual(
            snapshot.hitRatio, 1.0)
    }

    // MARK: - 6) Codable round-trip

    func testSnapshotCodableRoundTrip() throws {
        let original =
            BASKVCacheRegistryObservationSnapshot(
                invalidationPolicy: .ttl,
                sessionCount: 7,
                totalHits: 100,
                totalMisses: 50,
                totalCachedBytes: 1024,
                totalCachedTokens: 256,
                recordedAtMs: 1_700_000_000_000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASKVCacheRegistryObservationSnapshot.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 7) Multiple snapshots at different timestamps

    func testMultipleSnapshotsAtDifferentTimestamps()
        async
    {
        let registry = BASKVCacheRegistry()
        let s1 = await registry.snapshot(
            recordedAtMs: 1_000)
        let s2 = await registry.snapshot(
            recordedAtMs: 2_000)
        XCTAssertNotEqual(s1, s2,
            "snapshots at different timestamps MUST" +
            " not compare equal (recordedAtMs is part" +
            " of the typed identity)")
        XCTAssertEqual(s1.invalidationPolicy,
                       s2.invalidationPolicy)
    }
}
