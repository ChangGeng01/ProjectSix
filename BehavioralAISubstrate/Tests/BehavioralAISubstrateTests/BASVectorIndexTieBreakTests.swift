import XCTest
@testable import BASMemory

/// deep-audit MED: BASVectorIndex.topK/topKBatched/topKInt8 sorted by score with NO secondary key, so
/// at an exact score tie (orthogonal or identical embeddings) the top-K membership leaked insertion
/// order (Swift's sort is not stable) — a non-deterministic result across devices / replays. The fix
/// adds the content-derived tie-break (atomID ASC), mirroring the routed sibling
/// BASRoutedVectorIndexStorage (score DESC, atom_id ASC).
final class BASVectorIndexTieBreakTests: XCTestCase {

    private func emb(_ v: [Float]) -> BASEmbedding {
        BASEmbedding(vector: v, dimension: v.count, providerVersion: "tiebreak-v1")
    }
    private func entry(_ id: String, _ v: [Float]) -> BASVectorIndexEntry {
        BASVectorIndexEntry(atomID: id, normalizedEmbedding: emb(v))
    }

    /// Two atoms with IDENTICAL embeddings (exact fp32 score tie vs the query) inserted in OPPOSITE
    /// orders must both pick "a1" (lowest atomID). Unfixed: index B's unstable sort keeps "a2" → RED.
    func testScoreTieBreaksByAtomIDRegardlessOfInsertionOrder() async throws {
        let query = emb([1, 0, 0, 0])
        let shared: [Float] = [0, 1, 0, 0]   // both atoms identical → exact score tie vs query

        let idxA = BASVectorIndex()
        try await idxA.insert(entry("a1", shared))
        try await idxA.insert(entry("a2", shared))

        let idxB = BASVectorIndex()
        try await idxB.insert(entry("a2", shared))   // reversed insertion order
        try await idxB.insert(entry("a1", shared))

        let aTop = await idxA.topK(query: query, k: 1).first?.atomID
        let bTop = await idxB.topK(query: query, k: 1).first?.atomID
        XCTAssertEqual(aTop, "a1")
        XCTAssertEqual(bTop, "a1",
            "reversed insertion order must still pick a1 (atomID tie-break); unfixed unstable sort returns a2")

        // The full tie-group order must also be deterministic (a1 before a2) for both indices.
        let aOrder = await idxA.topK(query: query, k: 2).map(\.atomID)
        let bOrder = await idxB.topK(query: query, k: 2).map(\.atomID)
        XCTAssertEqual(aOrder, ["a1", "a2"])
        XCTAssertEqual(bOrder, ["a1", "a2"])
    }
}
