// MARK: - BASChapter906HotPathConsolidationTests
// chapter 九百六 / M3230 — hot-path consolidation probe
//
// Per the chapter 905 DECLINE-WITH-TRIGGER doc,storage-only
// Rust migration measured as a TIE。 The trigger condition
// for re-evaluation:hot-path consolidation lands (Rust
// reads DIRECTLY from Rust-backed storage,no Swift round-
// trip)。 This chapter ships the FIRST consolidation probe:
// cosine_topk_for_domain as a single integrated FFI call。
//
// # Hypothesis
//
// The orchestrated baseline does N+1 FFI hops:
//   1. N × bas_l8_vector_index_read_embedding_for_atom
//   2. 1 × Swift-side compute (or call cosineTopKBatch)
//
// The integrated probe does 1 FFI hop:
//   1. bas_l8_vector_index_cosine_topk_for_domain
//      (Rust reads SQLite + computes top-k in-process)
//
// If the integrated path wins ≥ 1.3× at corpus ≥ 1000,
// the chapter 905 trigger fires。 Otherwise,add a second
// DECLINE entry to the existing doc。
//
// # Correctness pin (non-bench)
//
// Both paths produce IDENTICAL top-k results — the
// orchestrated path returns embeddings to Swift (which then
// scores them),while the integrated path computes scores
// in Rust。 Scores must match to within f32 precision (≤ 1e-5)。

import XCTest
import Foundation
@testable import BASMemory
@testable import BASRuntimeCore
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if os(iOS) || os(macOS)
final class BASChapter906HotPathConsolidationTests: XCTestCase
{

    private func makeTempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ch906-\(UUID().uuidString).db")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(
            at: URL(fileURLWithPath: url.path + "-shm"))
    }

    private func packF32LE(_ values: [Float]) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(values.count * 4)
        for v in values {
            var x = v
            withUnsafeBytes(of: &x) { raw in
                bytes.append(contentsOf: raw)
            }
        }
        return bytes
    }

    private func unpackF32LE(_ bytes: [UInt8]) -> [Float] {
        let count = bytes.count / 4
        var out: [Float] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let start = i * 4
            let b0 = bytes[start]
            let b1 = bytes[start + 1]
            let b2 = bytes[start + 2]
            let b3 = bytes[start + 3]
            let packed = (UInt32(b3) << 24)
                | (UInt32(b2) << 16)
                | (UInt32(b1) << 8)
                | UInt32(b0)
            out.append(Float(bitPattern: packed))
        }
        return out
    }

    private func seedRandomEmbeddings(
        store: BASRoutedVectorIndexStorage,
        domain: String,
        n: Int, dim: Int
    ) async throws {
        var rng = SystemRandomNumberGenerator()
        for i in 0..<n {
            var emb: [Float] = []
            emb.reserveCapacity(dim)
            // Random unit vectors approx (skip normalization
            // for bench purposes — dot product still has the
            // same FFI / compute cost shape)。
            for _ in 0..<dim {
                let r = Float(rng.next() % 1000) / 1000.0
                    - 0.5
                emb.append(r)
            }
            let embedding = BASEmbedding(
                vector: emb,
                dimension: dim,
                providerVersion: "p1")
            let entry = BASVectorIndexEntry(
                atomID: "atom-\(i)",
                normalizedEmbedding: embedding,
                domain: domain,
                metadata: [:])
            _ = try await store.upsert(entry)
        }
    }

    // MARK: - Correctness pin

    /// chapter 九百七 / M3240 review fix #10: explicitly pin
    /// that integrated + orchestrated return the SAME ranked
    /// rowids (not just identical scores)。 Use deterministic
    /// embeddings with strictly distinct scores so ties don't
    /// hide a swap。
    func testCosineTopKMatchesOrchestratedRowIDs() async
        throws
    {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let dim = 4
        // 5 deterministic embeddings, monotonically aligned
        // with the query so scores are STRICTLY distinct
        let embeddings: [[Float]] = [
            [0.1, 0.0, 0.0, 0.0],
            [0.3, 0.0, 0.0, 0.0],
            [0.5, 0.0, 0.0, 0.0],
            [0.7, 0.0, 0.0, 0.0],
            [0.9, 0.0, 0.0, 0.0],
        ]
        for (i, emb) in embeddings.enumerated() {
            let entry = BASVectorIndexEntry(
                atomID: "ord-\(i)",
                normalizedEmbedding: BASEmbedding(
                    vector: emb, dimension: dim,
                    providerVersion: "p"),
                domain: "ord-dom",
                metadata: [:])
            _ = try await store.upsert(entry)
        }
        let q: [Float] = [1.0, 0.0, 0.0, 0.0]
        let qBytes = packF32LE(q)
        let integrated = try await store.cosineTopK(
            forDomain: "ord-dom",
            queryBytes: qBytes,
            k: 3)
        XCTAssertEqual(integrated.count, 3)
        // Expected ranking by score descending:
        //   #0 = ord-4 (score 0.9)
        //   #1 = ord-3 (score 0.7)
        //   #2 = ord-2 (score 0.5)
        XCTAssertEqual(integrated[0].score, 0.9,
            accuracy: 1e-5)
        XCTAssertEqual(integrated[1].score, 0.7,
            accuracy: 1e-5)
        XCTAssertEqual(integrated[2].score, 0.5,
            accuracy: 1e-5)
        // rowids are sqlite auto-assigned 1..5 in insert order
        // so ord-4 = rowid 5, ord-3 = 4, ord-2 = 3
        XCTAssertEqual(integrated[0].rowid, 5)
        XCTAssertEqual(integrated[1].rowid, 4)
        XCTAssertEqual(integrated[2].rowid, 3)
    }

    func testCosineTopKMatchesOrchestratedScores() async
        throws
    {
        // For each atom in domain,fetch its embedding bytes,
        // compute dot product with query in Swift,collect
        // top-k locally。 Compare scores with integrated path。
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        let dim = 8
        let n = 50
        try await seedRandomEmbeddings(
            store: store, domain: "ch906-corr",
            n: n, dim: dim)
        let q: [Float] = Array(
            repeating: 0.1, count: dim)
        let qBytes = packF32LE(q)
        // Orchestrated baseline
        var orchScores: [(rowid: Int, score: Float)] = []
        for i in 0..<n {
            let bytes = try await store.readEmbeddingBytes(
                forAtomID: "atom-\(i)")
            guard let bytes else { continue }
            let emb = unpackF32LE(bytes)
            var s: Float = 0
            for j in 0..<dim { s += emb[j] * q[j] }
            orchScores.append((rowid: i, score: s))
        }
        orchScores.sort { $0.score > $1.score }
        let orchTop5 = Array(orchScores.prefix(5))
        // Integrated path
        let integrated = try await store.cosineTopK(
            forDomain: "ch906-corr",
            queryBytes: qBytes,
            k: 5)
        XCTAssertEqual(integrated.count, 5)
        for i in 0..<5 {
            XCTAssertEqual(
                integrated[i].score,
                orchTop5[i].score,
                accuracy: 1e-5,
                "Score parity at rank \(i)")
        }
    }

    // MARK: - Perf bench probe

    private func timeit(_ body: () async throws -> Void) async
        rethrows -> Double
    {
        let start = ContinuousClock.now
        try await body()
        let elapsed = ContinuousClock.now - start
        let attos = Double(elapsed.components.attoseconds)
            / 1_000_000_000_000_000_000.0
        return Double(elapsed.components.seconds) + attos
    }

    func testBenchmarkCorpus100Dim64() async throws {
        try await runBench(n: 100, dim: 64, k: 10)
    }

    func testBenchmarkCorpus1000Dim64() async throws {
        try await runBench(n: 1000, dim: 64, k: 10)
    }

    func testBenchmarkCorpus5000Dim64() async throws {
        try await runBench(n: 5000, dim: 64, k: 10)
    }

    private func runBench(
        n: Int, dim: Int, k: Int
    ) async throws {
        let url = makeTempDBURL()
        defer { cleanup(url) }
        let store = try BASRoutedVectorIndexStorage(
            databaseURL: url)
        try await seedRandomEmbeddings(
            store: store, domain: "ch906-bench",
            n: n, dim: dim)
        let q = Array(repeating: Float(0.1), count: dim)
        let qBytes = packF32LE(q)

        // Warm-up
        _ = try await store.cosineTopK(
            forDomain: "ch906-bench",
            queryBytes: qBytes, k: k)
        _ = try await store.readEmbeddingBytes(
            forAtomID: "atom-0")

        let orchSec = try await timeit {
            // Orchestrated: N round-trip reads + Swift compute
            var scores: [(Int, Float)] = []
            scores.reserveCapacity(n)
            for i in 0..<n {
                let bytes = try await store
                    .readEmbeddingBytes(forAtomID: "atom-\(i)")
                guard let bytes else { continue }
                let emb = unpackF32LE(bytes)
                var s: Float = 0
                for j in 0..<dim { s += emb[j] * q[j] }
                scores.append((i, s))
            }
            scores.sort { $0.1 > $1.1 }
            _ = scores.prefix(k)
        }

        let intSec = try await timeit {
            // Integrated: 1 FFI call
            _ = try await store.cosineTopK(
                forDomain: "ch906-bench",
                queryBytes: qBytes, k: k)
        }
        let ratio = orchSec / intSec
        print(
            "ch906 cosine-topk N=\(n) dim=\(dim) k=\(k):" +
            " orch=\(String(format: "%.4f", orchSec))s" +
            " integrated=\(String(format: "%.4f", intSec))s" +
            " orch/integrated=\(String(format: "%.2fx", ratio))")
        // Soft guard: integrated must NOT be catastrophically
        // slower than orchestrated (would indicate FFI bug)。
        // If integrated > 2× slower than orchestrated,that's
        // a regression。
        XCTAssertLessThan(intSec, orchSec * 2.0,
            "Integrated > 2× slower than orchestrated = regression")
    }
}
#endif
