// MARK: - BASLLMPromptCacheTests — chapter 四百一 / M937

import XCTest
@testable import BASOrgan
@testable import BASRuntimeCore

final class BASLLMPromptCacheTests: XCTestCase {

    private func makeDraft(
        body: String = "answer"
    ) -> BASOrganDraft {
        BASOrganDraft(
            requestID: "r",
            providerID: "test",
            role: .scout,
            body: body,
            inputTokensEstimated: 0,
            outputTokensEstimated: 0,
            producedAt: Date(),
            traceID: "t")
    }

    private func makeKey(
        prefix: UInt64 = 1,
        suffix: UInt64 = 2
    ) -> BASLLMPromptCacheKey {
        BASLLMPromptCacheKey(
            prefixHash: prefix, suffixHash: suffix)
    }

    // MARK: - Lookup

    func testEmptyCacheMisses() async {
        let cache = BASLLMPromptCache()
        let outcome = await cache.lookup(key: makeKey())
        XCTAssertEqual(outcome, .miss)
    }

    func testInsertThenHit() async {
        let cache = BASLLMPromptCache()
        let key = makeKey()
        let draft = makeDraft(body: "cached")
        await cache.insert(
            key: key, draft: draft, cachedAtMs: 1)
        let outcome = await cache.lookup(key: key)
        if case .hit(let returned) = outcome {
            XCTAssertEqual(returned.body, "cached")
        } else {
            XCTFail("Expected .hit")
        }
    }

    func testPartialOnSamePrefixDifferentSuffix() async {
        let cache = BASLLMPromptCache()
        let key1 = BASLLMPromptCacheKey(
            prefixHash: 100, suffixHash: 1)
        let key2 = BASLLMPromptCacheKey(
            prefixHash: 100, suffixHash: 999)
        await cache.insert(
            key: key1,
            draft: makeDraft(),
            cachedAtMs: 1)
        let outcome = await cache.lookup(key: key2)
        if case .partial(let prefix) = outcome {
            XCTAssertEqual(prefix, 100)
        } else {
            XCTFail("Expected .partial")
        }
    }

    // MARK: - Telemetry

    func testHitRatioCalculation() async {
        let cache = BASLLMPromptCache()
        let key = makeKey()
        await cache.insert(
            key: key, draft: makeDraft(),
            cachedAtMs: 1)
        // 3 hits + 2 misses
        _ = await cache.lookup(key: key)
        _ = await cache.lookup(key: key)
        _ = await cache.lookup(key: key)
        _ = await cache.lookup(
            key: makeKey(prefix: 999, suffix: 999))
        _ = await cache.lookup(
            key: makeKey(prefix: 888, suffix: 888))
        let ratio = await cache.hitRatio
        XCTAssertEqual(ratio, 0.6, accuracy: 0.001)
    }

    func testMissCountTracked() async {
        let cache = BASLLMPromptCache()
        _ = await cache.lookup(key: makeKey())
        _ = await cache.lookup(key: makeKey())
        let misses = await cache.totalMisses
        XCTAssertEqual(misses, 2)
    }

    // MARK: - Eviction

    func testFIFOEvictionAtCap() async {
        let cache = BASLLMPromptCache(maxEntries: 2)
        let k1 = makeKey(prefix: 1, suffix: 1)
        let k2 = makeKey(prefix: 2, suffix: 2)
        let k3 = makeKey(prefix: 3, suffix: 3)
        await cache.insert(
            key: k1, draft: makeDraft(body: "first"),
            cachedAtMs: 1)
        await cache.insert(
            key: k2, draft: makeDraft(body: "second"),
            cachedAtMs: 2)
        // Fills cap (2 entries);next insert evicts oldest
        await cache.insert(
            key: k3, draft: makeDraft(body: "third"),
            cachedAtMs: 3)
        let r1 = await cache.lookup(key: k1)
        XCTAssertEqual(r1, .miss,
            "Oldest entry evicted")
        let r2 = await cache.lookup(key: k2)
        XCTAssertNotEqual(r2, .miss,
            "Second entry still cached")
        let r3 = await cache.lookup(key: k3)
        XCTAssertNotEqual(r3, .miss,
            "Third entry just inserted")
    }

    // MARK: - Reset

    func testResetClearsEntries() async {
        let cache = BASLLMPromptCache()
        await cache.insert(
            key: makeKey(),
            draft: makeDraft(),
            cachedAtMs: 1)
        await cache.reset()
        let outcome = await cache.lookup(key: makeKey())
        XCTAssertEqual(outcome, .miss)
        let total = await cache.totalLookups
        XCTAssertEqual(total, 1,
            "Lookup AFTER reset still counts (only the " +
            "reset itself zeros the counter)")
    }

    // MARK: - Hasher

    func testPrefixHashStable() {
        let h1 = BASLLMPromptCacheHasher.prefixHash(
            instructions: "system",
            contextBlobs: ["c1", "c2"],
            tools: [],
            outputSchema: nil)
        let h2 = BASLLMPromptCacheHasher.prefixHash(
            instructions: "system",
            contextBlobs: ["c1", "c2"],
            tools: [],
            outputSchema: nil)
        XCTAssertEqual(h1, h2,
            "Same inputs → same hash (M892 doctrine)")
    }

    func testPrefixHashChangesOnDifferentInputs() {
        let h1 = BASLLMPromptCacheHasher.prefixHash(
            instructions: "a",
            contextBlobs: [],
            tools: [],
            outputSchema: nil)
        let h2 = BASLLMPromptCacheHasher.prefixHash(
            instructions: "b",
            contextBlobs: [],
            tools: [],
            outputSchema: nil)
        XCTAssertNotEqual(h1, h2)
    }

    func testSuffixHashOrderMatters() {
        let h1 = BASLLMPromptCacheHasher.suffixHash(
            userPrompt: "test",
            riskFlags: ["a", "b"])
        let h2 = BASLLMPromptCacheHasher.suffixHash(
            userPrompt: "test",
            riskFlags: ["b", "a"])
        // Order-sensitive — different hash
        XCTAssertNotEqual(h1, h2)
    }
}
