// chapter 一千〇六十二 / WS3 — correctness proof for the L8 retrieve cosineTopK hot-path takeover.
//
// Verifies the new SYNC accessor `BASRoutedVectorIndexStorage.cosineTopKAtomIDsSync` and the new
// `bas_l8_vector_index_atom_id_for_rowid` FFI (the rowid→atom_id resolution that makes the takeover
// possible — cosineTopK returns rowids, retrieve needs atoms). Deterministic embeddings give
// strictly-distinct scores so a swap can't hide.

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter1062CosineTopKAtomIDsTests: XCTestCase {

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ch1062-\(UUID().uuidString).db")
    }
    private func cleanup(_ url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// The sync accessor returns the top-K by score AND resolves each rowid back to its atom_id
    /// (the new FFI). rowid 5→ord-4, 4→ord-3, 3→ord-2 (sqlite assigns rowids 1..5 in insert order).
    func testCosineTopKAtomIDsSyncResolvesAtomIDs() async throws {
        let url = makeTempDBURL(); defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(databaseURL: url)
        let dim = 4
        let embeddings: [[Float]] = [
            [0.1, 0, 0, 0], [0.3, 0, 0, 0], [0.5, 0, 0, 0],
            [0.7, 0, 0, 0], [0.9, 0, 0, 0]]
        for (i, emb) in embeddings.enumerated() {
            _ = try await store.upsert(BASVectorIndexEntry(
                atomID: "ord-\(i)",
                normalizedEmbedding: BASEmbedding(
                    vector: emb, dimension: dim, providerVersion: "p"),
                domain: "ord-dom", metadata: [:]))
        }
        // The new SYNC accessor — the ch883-compliant retrieve hot-path entry (nonisolated, no await).
        let top = try store.cosineTopKAtomIDsSync(
            forDomain: "ord-dom", query: [1, 0, 0, 0], k: 3)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top.map(\.atomID), ["ord-4", "ord-3", "ord-2"],
            "rowid→atom_id resolution must map the ranked rowids to the right atoms")
        XCTAssertEqual(top[0].score, 0.9, accuracy: 1e-5)
        XCTAssertEqual(top[1].score, 0.7, accuracy: 1e-5)
        XCTAssertEqual(top[2].score, 0.5, accuracy: 1e-5)
    }

    /// Score parity with the async `cosineTopK` path (same ranking) — the sync accessor only adds
    /// the atom_id resolution; the scores come from the same FFI.
    func testSyncMatchesAsyncScores() async throws {
        let url = makeTempDBURL(); defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(databaseURL: url)
        let dim = 8
        var rng = SystemRandomNumberGenerator()
        for i in 0..<40 {
            let emb = (0..<dim).map { _ in Float(rng.next() % 1000) / 1000.0 - 0.5 }
            _ = try await store.upsert(BASVectorIndexEntry(
                atomID: "a-\(i)",
                normalizedEmbedding: BASEmbedding(
                    vector: emb, dimension: dim, providerVersion: "p"),
                domain: "d", metadata: [:]))
        }
        let q = Array(repeating: Float(0.1), count: dim)
        let asyncTop = try await store.cosineTopK(forDomain: "d", query: q, k: 5)
        let syncTop = try store.cosineTopKAtomIDsSync(forDomain: "d", query: q, k: 5)
        XCTAssertEqual(syncTop.count, asyncTop.count)
        for i in 0..<syncTop.count {
            XCTAssertEqual(syncTop[i].score, asyncTop[i].score, accuracy: 1e-5,
                "sync vs async score parity at rank \(i)")
        }
    }

    /// Empty domain → empty result (no crash, no resolution attempt).
    func testEmptyDomainReturnsEmpty() throws {
        let url = makeTempDBURL(); defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(databaseURL: url)
        let empty = try store.cosineTopKAtomIDsSync(
            forDomain: "nonexistent", query: [1, 0, 0, 0], k: 5)
        XCTAssertTrue(empty.isEmpty)
    }
}
#endif
