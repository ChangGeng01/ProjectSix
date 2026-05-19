// MARK: - BASChapter715BatchedCosineTournamentTests
// chapter 七百十五 第三刀 / M2248
//
// Tournament across (Rust SIMD batched_cosine,Metal batched
// cosine) at the (corpus_rows × dim) grid。 Output identifies
// the empirical crossover where Metal pipeline-launch overhead
// starts paying off。
//
// Hypothesis:
//   - At small corpora (n_rows ≤ 16) Rust SIMD wins — Metal
//     pipeline launch ≈ 100µs dominates the actual work
//   - At medium corpora (64 ≤ n_rows ≤ 1024) the crossover
//     depends on dim:lower dim → Rust still wins; higher dim
//     → Metal pays off
//   - At large corpora (n_rows ≥ 4096) Metal wins regardless
//     of dim,since the per-row Rust SIMD loop is the bottleneck
//
// Use this output to pick the threshold field for the auto-
// router in Knife 4。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter715BatchedCosineTournamentTests:
    XCTestCase
{
    #if os(iOS) || os(macOS)

    private static func makeDispatcher()
        -> BASMetalBatchedCosineSimilarityDispatcher
    {
        return BASMetalBatchedCosineSimilarityDispatcher(
            loader: BASMetalKernelLibraryLoader(
                useMetalKernelV2: true))
    }

    private func makeQuery(dim: Int) -> [Float] {
        return (0..<dim).map {
            Float($0) * 0.01 - 0.5 }
    }

    private func makeCorpus(
        nRows: Int, dim: Int
    ) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(nRows * dim)
        for r in 0..<nRows {
            for d in 0..<dim {
                out.append(
                    Float((r * 17 + d) % 41) * 0.02 - 0.4)
            }
        }
        return out
    }

    private func batchedCosineTournament(
        nRows: Int, dim: Int
    ) async throws {
        let dispatcher = Self.makeDispatcher()
        let query = makeQuery(dim: dim)
        let corpus = makeCorpus(nRows: nRows, dim: dim)
        // Warm Metal pipeline cache
        for _ in 0..<3 {
            _ = try await dispatcher.dispatch(
                query: query, corpus: corpus, dim: dim)
        }
        var rustScores = [Float](
            repeating: 0, count: nRows)
        var rustSink: Float = 0
        var metalSink: Float = 0

        let iters = nRows >= 4096
            ? 5 : (nRows >= 256 ? 30 : 200)

        // Rust SIMD timing
        let rustStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            _ = query.withUnsafeBufferPointer { qp in
                corpus.withUnsafeBufferPointer { cp in
                    rustScores
                        .withUnsafeMutableBufferPointer
                            { op in
                        bas_ranker_batched_cosine_simd(
                            qp.baseAddress, dim,
                            cp.baseAddress, corpus.count,
                            dim,
                            op.baseAddress)
                    }
                }
            }
            rustSink = rustSink + rustScores[0]
        }
        let rustEnd =
            DispatchTime.now().uptimeNanoseconds
        let rustNs =
            Double(rustEnd - rustStart) / Double(iters)

        // Metal timing
        let metalStart =
            DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iters {
            let metalScores = try await dispatcher
                .dispatch(
                    query: query, corpus: corpus,
                    dim: dim)
            metalSink = metalSink + metalScores[0]
        }
        let metalEnd =
            DispatchTime.now().uptimeNanoseconds
        let metalNs =
            Double(metalEnd - metalStart) / Double(iters)

        let winner = rustNs < metalNs ? "Rust SIMD" : "Metal"
        print(
            "BENCH batched_cosine(rows=\(nRows),dim=\(dim)) — " +
            "winner: \(winner)")
        print(String(
            format: "  Rust SIMD: %10.0f ns/iter",
            rustNs))
        print(String(
            format: "  Metal:     %10.0f ns/iter (%.2fx vs Rust)",
            metalNs, rustNs / metalNs))
        _ = (rustSink, metalSink)
    }

    // Small corpora — expect Rust win
    func testBatched16x128() async throws {
        try await batchedCosineTournament(
            nRows: 16, dim: 128)
    }

    func testBatched16x512() async throws {
        try await batchedCosineTournament(
            nRows: 16, dim: 512)
    }

    // Medium corpora — crossover region
    func testBatched256x128() async throws {
        try await batchedCosineTournament(
            nRows: 256, dim: 128)
    }

    func testBatched256x512() async throws {
        try await batchedCosineTournament(
            nRows: 256, dim: 512)
    }

    // Large corpora — expect Metal win
    func testBatched4096x128() async throws {
        try await batchedCosineTournament(
            nRows: 4096, dim: 128)
    }

    func testBatched4096x512() async throws {
        try await batchedCosineTournament(
            nRows: 4096, dim: 512)
    }
    #endif
}
