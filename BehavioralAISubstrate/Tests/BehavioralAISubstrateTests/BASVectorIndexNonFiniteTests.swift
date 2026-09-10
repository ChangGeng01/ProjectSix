// ch1044 深入 audit — poisoned-atom NaN/Inf → vector-index sort-trap DoS guard.
//
// A stored embedding with a non-finite component yields NaN cosine scores, and a NaN
// score violates strict-weak-ordering in `sort(by:)` → undefined behavior / potential
// trap (a one-poisoned-atom DoS). The fix rejects non-finite embeddings at insert AND
// maps non-finite scores to -infinity in the top-K sort (defense-in-depth).

import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BASVectorIndexNonFiniteTests: XCTestCase {

    private func entry(_ id: String, _ vector: [Float]) -> BASVectorIndexEntry {
        BASVectorIndexEntry(
            atomID: id,
            normalizedEmbedding: BASEmbedding(
                vector: vector, dimension: vector.count, providerVersion: "test"),
            domain: "d", metadata: [:])
    }

    func testInsertRejectsNaNEmbedding() async {
        let index = BASVectorIndex()
        do {
            try await index.insert(entry("nan", [0.1, .nan, 0.3, 0.4]))
            XCTFail("NaN embedding must be rejected")
        } catch BASVectorIndex.BASVectorIndexError.nonFiniteEmbedding {
            // expected
        } catch {
            XCTFail("expected nonFiniteEmbedding, got \(error)")
        }
    }

    func testUpsertRejectsInfEmbedding() async {
        let index = BASVectorIndex()
        do {
            try await index.upsert(entry("inf", [0.1, 0.2, .infinity, 0.4]))
            XCTFail("Inf embedding must be rejected")
        } catch { /* expected */ }
    }

    /// Finite embeddings still insert + rank correctly — the guard doesn't break the
    /// happy path, and the NaN-safe sort produces a valid ordering.
    func testFiniteEmbeddingsInsertAndRank() async throws {
        let index = BASVectorIndex()
        try await index.insert(entry("a", [1, 0, 0, 0]))
        try await index.insert(entry("b", [0, 1, 0, 0]))
        let results = await index.topK(
            query: BASEmbedding(vector: [1, 0, 0, 0], dimension: 4, providerVersion: "test"),
            k: 2)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.atomID, "a")
    }
}
