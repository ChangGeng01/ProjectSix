// MARK: - BASChapter718VectorIndexPerfTests
// chapter 七百十八 第二/四刀 / M2262, M2264
//
// Tournament across three top-K paths × (N entries × dim)
// grid:
//
//   1. Legacy Swift scalar (useRoutedCosine=false,
//      useBatchedTopK=false)
//   2. Per-pair Rust (useRoutedCosine=true)
//   3. Batched Rust (useBatchedTopK=true)
//
// Realistic RAG corpus sizes:
//   - Small  (100 entries × 128 dim)
//   - Medium (1000 entries × 384 dim) — typical sentence embedding
//   - Large  (5000 entries × 768 dim) — multilingual embedding

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter718VectorIndexPerfTests: XCTestCase {

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
                    atomID: "a\(i)",
                    normalizedEmbedding:
                        BASEmbedding(
                            vector: normalized,
                            dimension: normalized.count,
                            providerVersion: "test-v1"),
                    domain: "d"))
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

    private func measureTopK(
        index: BASVectorIndex,
        query: BASEmbedding,
        k: Int,
        useRouted: Bool, useBatched: Bool,
        iters: Int
    ) async -> Double {
        BASVectorIndex.useRoutedCosine = useRouted
        BASVectorIndex.useBatchedTopK = useBatched
        for _ in 0..<3 {
            _ = await index.topK(query: query, k: k)
        }
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = await index.topK(query: query, k: k)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / Double(iters)
    }

    private func tournament(
        n: Int, dim: Int, iters: Int
    ) async throws {
        let index = try await makeIndex(n: n, dim: dim)
        let query = makeQuery(dim: dim)
        let k = 20

        let legacyNs = await measureTopK(
            index: index, query: query, k: k,
            useRouted: false, useBatched: false,
            iters: iters)
        let perPairNs = await measureTopK(
            index: index, query: query, k: k,
            useRouted: true, useBatched: false,
            iters: iters)
        let batchedNs = await measureTopK(
            index: index, query: query, k: k,
            useRouted: false, useBatched: true,
            iters: iters)

        let perPairSpeedup = legacyNs / perPairNs
        let batchedSpeedup = legacyNs / batchedNs

        let winner: String
        if batchedNs < perPairNs && batchedNs < legacyNs {
            winner = "Batched Rust"
        } else if perPairNs < legacyNs
            && perPairNs < batchedNs
        {
            winner = "Per-pair Rust"
        } else {
            winner = "Swift legacy"
        }

        print(String(
            format:
                "BENCH topK(n=%d,dim=%d) — winner: %@\n" +
                "  Swift legacy:    %9.0f ns/iter\n" +
                "  Per-pair Rust:   %9.0f ns/iter (%.2fx)\n" +
                "  Batched Rust:    %9.0f ns/iter (%.2fx)",
            n, dim, winner,
            legacyNs,
            perPairNs, perPairSpeedup,
            batchedNs, batchedSpeedup))
    }

    func testTopK100x128() async throws {
        try await tournament(
            n: 100, dim: 128, iters: 200)
    }

    func testTopK1000x384() async throws {
        try await tournament(
            n: 1000, dim: 384, iters: 50)
    }

    func testTopK5000x768() async throws {
        try await tournament(
            n: 5000, dim: 768, iters: 20)
    }
}
