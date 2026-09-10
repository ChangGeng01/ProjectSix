// MARK: - BASChapter715BatchedCosineTournamentTests
// chapter 七百十五 第三刀 / M2248
//
// DEPRECATED post chapter 八百七十八 / M3070 — superseded by
// `BASChapter872BatchedCosineRayonTests` which has ASSERTED
// 3-way bench (Swift per-pair vs Rust seq SIMD vs Rust rayon
// chunked v2) at production corpus shapes (1K + 5K rows)。
// The chapter 872 bench wins live measurement 268-490× over
// Swift baseline and is the production routing source。
// Chapter 715 stays in tree as live-data reference layer。
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

// ## ARCHIVE MARKER (skip triage, 2026-07-14) — CORRECTED SUPERSESSION CLAIM
//
// This file's skip previously read "superseded by BASChapter872BatchedCosine
// RayonTests". That claim is FALSE as written, and it was the only stale
// supersession in the six-file archive cluster. Verified 2026-07-14:
//   - `grep -ci metal BASChapter872BatchedCosineRayonTests.swift` = 0. 872 is a
//     Swift-vs-Rust(-rayon) bench with no Metal contestant, and its only
//     assertions are self-labelled "Weak pin" in-source. This file is a
//     Rust-SIMD-vs-METAL crossover tournament (rows 16/256/4096 x dim 128/512).
//   - ★ this tournament is the ONLY measurement that ever backed the production
//     threshold `batchedCosineMetalMinRows = 16384`, which is STILL asserted by
//     two RUNNING tests: BASChapter715BatchedCosineRouterTests.swift:170 and
//     BASQINAOSubstrateGatesBatch11Tests.swift:438. Deleting this file would
//     leave those two asserting a number with no measurement behind it anywhere
//     in the repo.
//
// So: DO NOT DELETE, and do not re-label as superseded. To retire it honestly,
// ship an asserted Metal-crossover bench that actually pins 16384 first.
// Dispatcher correctness remains covered by BASChapter715BatchedCosine
// DispatcherTests (runs). This file has no XCTAssert, so it cannot itself go
// red — it is a stale gate + doc-lie, not a suppressed red test.

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
    /// Chapter 八百七十八.5 / M3076 — deprecation-skip per chapter
    /// 707 pattern。 Chapter 872 has asserted-bench replacement
    /// (BASChapter872BatchedCosineRayonTests with 268-490× win
    /// over Swift per-pair)。
    override func setUp() async throws {
        try await super.setUp()
        throw XCTSkip(
            "Chapter 八百七十八.5 archive skip — BASChapter872BatchedCosine" +
            "RayonTests supersedes only the SWIFT-vs-RUST lane, NOT this " +
            "file's Rust-SIMD-vs-METAL crossover: 872 has ZERO Metal " +
            "contestant (verified 2026-07-14). The crossover this file " +
            "measures — the sole evidence behind the production threshold " +
            "batchedCosineMetalMinRows = 16384 — has NO asserted replacement。")
    }

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
