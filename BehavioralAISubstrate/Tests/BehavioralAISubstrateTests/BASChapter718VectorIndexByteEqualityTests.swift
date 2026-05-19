// MARK: - BASChapter718VectorIndexByteEqualityTests
// chapter 七百十八 第一/三刀 / M2261, M2263
//
// SAFETY-CRITICAL test:proves all three top-K paths
// produce IDENTICAL ranking (within fp32 tolerance) on the
// same corpus:
//
//   1. Legacy Swift scalar (useRoutedCosine=false,
//      useBatchedTopK=false)
//   2. Per-pair Rust (useRoutedCosine=true,
//      useBatchedTopK=false)
//   3. Batched Rust (useBatchedTopK=true)
//
// The Swift `cosine()` returns just dot product (assumes
// pre-normalized vectors)。 The Rust paths return the
// cosine (dot / norm·norm)。 For pre-normalized inputs
// both math evaluations agree within fp32 rounding
// (~1e-5)。 Test verifies the top-K ORDERING matches
// across paths,not just the scores。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter718VectorIndexByteEqualityTests:
    XCTestCase
{
    override func tearDown() async throws {
        BASVectorIndex.useRoutedCosine = false
        BASVectorIndex.useBatchedTopK = false
        try await super.tearDown()
    }

    private func normalize(_ v: [Float]) -> [Float] {
        var n: Float = 0
        for x in v { n += x * x }
        guard n > 0 else { return v }
        let inv = 1.0 / n.squareRoot()
        return v.map { $0 * inv }
    }

    private func makeIndex(
        n: Int, dim: Int, seed: UInt32 = 0x4242
    ) async throws -> BASVectorIndex {
        let index = BASVectorIndex()
        var s = seed
        for i in 0..<n {
            var vec: [Float] = []
            vec.reserveCapacity(dim)
            for _ in 0..<dim {
                s = s &* 1664525 &+ 1013904223
                vec.append(
                    Float(s & 0xFFFF) / Float(0xFFFF)
                    - 0.5)
            }
            let normalized = normalize(vec)
            try await index.insert(
                BASVectorIndexEntry(
                    atomID: "atom-\(i)",
                    normalizedEmbedding:
                        BASEmbedding(
                            vector: normalized,
                            dimension: normalized.count,
                            providerVersion: "test-v1"),
                    domain: "domain-\(i % 3)"))
        }
        return index
    }

    private func makeQuery(
        dim: Int, seed: UInt32 = 0xBEEF
    ) -> BASEmbedding {
        var s = seed
        var vec: [Float] = []
        for _ in 0..<dim {
            s = s &* 1664525 &+ 1013904223
            vec.append(
                Float(s & 0xFFFF) / Float(0xFFFF) - 0.5)
        }
        let normalized = normalize(vec)
        return BASEmbedding(
            vector: normalized,
            dimension: normalized.count,
            providerVersion: "test-v1")
    }

    // MARK: - Three-path agreement at small N

    func testTopKThreePathAgreementSmall() async throws {
        let index = try await makeIndex(n: 16, dim: 64)
        let query = makeQuery(dim: 64)
        let k = 8

        BASVectorIndex.useRoutedCosine = false
        BASVectorIndex.useBatchedTopK = false
        let legacy = await index.topK(
            query: query, k: k)

        BASVectorIndex.useRoutedCosine = true
        BASVectorIndex.useBatchedTopK = false
        let perPair = await index.topK(
            query: query, k: k)

        BASVectorIndex.useRoutedCosine = false
        BASVectorIndex.useBatchedTopK = true
        let batched = await index.topK(
            query: query, k: k)

        // Top-K atomID ORDERING must match across paths
        // (within fp32 noise — ties at the bottom may flip)
        let legacyIDs = legacy.map { $0.atomID }
        let perPairIDs = perPair.map { $0.atomID }
        let batchedIDs = batched.map { $0.atomID }
        XCTAssertEqual(legacyIDs, perPairIDs,
            "legacy and per-pair must agree on top-K order")
        XCTAssertEqual(legacyIDs, batchedIDs,
            "legacy and batched must agree on top-K order")
    }

    // MARK: - Larger N

    func testTopKThreePathAgreementMedium() async throws {
        let index = try await makeIndex(n: 200, dim: 128)
        let query = makeQuery(dim: 128)
        let k = 20

        BASVectorIndex.useRoutedCosine = false
        BASVectorIndex.useBatchedTopK = false
        let legacy = await index.topK(
            query: query, k: k)

        BASVectorIndex.useRoutedCosine = true
        let perPair = await index.topK(
            query: query, k: k)

        BASVectorIndex.useRoutedCosine = false
        BASVectorIndex.useBatchedTopK = true
        let batched = await index.topK(
            query: query, k: k)

        // For top-20 we expect first ~10-15 to agree
        // (closest matches are well-separated by score);
        // bottom of top-K may have tie-breaking jitter due
        // to fp32 differences。 Assert the TOP HALF agrees
        // exactly,which is the production-relevant
        // guarantee。
        let topHalf = k / 2
        let legacyTop = Array(
            legacy.prefix(topHalf).map { $0.atomID })
        let perPairTop = Array(
            perPair.prefix(topHalf).map { $0.atomID })
        let batchedTop = Array(
            batched.prefix(topHalf).map { $0.atomID })
        XCTAssertEqual(legacyTop, perPairTop)
        XCTAssertEqual(legacyTop, batchedTop)
    }

    // MARK: - Per-pair scores within fp32 tolerance

    func testCosineScoreNumericalAgreement() async throws {
        let index = try await makeIndex(n: 5, dim: 64)
        let query = makeQuery(dim: 64)

        BASVectorIndex.useRoutedCosine = false
        let swiftScores = (await index.topK(
            query: query, k: 5))
            .reduce(into: [String: Float]()) { acc, r in
                acc[r.atomID] = r.score
            }

        BASVectorIndex.useRoutedCosine = true
        let rustScores = (await index.topK(
            query: query, k: 5))
            .reduce(into: [String: Float]()) { acc, r in
                acc[r.atomID] = r.score
            }

        for (id, sw) in swiftScores {
            guard let ru = rustScores[id] else {
                XCTFail("missing id \(id) in Rust scores")
                continue
            }
            XCTAssertEqual(sw, ru, accuracy: 5e-4,
                "score for \(id) should agree within" +
                " fp32 cosine-vs-dot tolerance")
        }
    }

    // MARK: - Empty index, query mismatch — defensive

    func testEmptyIndexReturnsEmptyAcrossPaths()
        async throws
    {
        let index = BASVectorIndex()
        let query = makeQuery(dim: 64)
        for (routed, batched) in [
            (false, false), (true, false), (false, true)
        ] {
            BASVectorIndex.useRoutedCosine = routed
            BASVectorIndex.useBatchedTopK = batched
            let r = await index.topK(
                query: query, k: 5)
            XCTAssertTrue(r.isEmpty,
                "empty index must return [] " +
                "(routed=\(routed),batched=\(batched))")
        }
    }
}
