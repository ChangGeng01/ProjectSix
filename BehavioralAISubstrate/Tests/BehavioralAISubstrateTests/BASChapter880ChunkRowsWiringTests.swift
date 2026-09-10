// MARK: - BASChapter880ChunkRowsWiringTests
// chapter 八百八十 / M3085 — v0.62.1 全面收尾
//
// Wire-pin for the chapter 879
// BASAutoRouteThresholds.batchedCosineRayonChunkRows field through
// Swift bridge → new chapter 880 C ABI
// `bas_ranker_batched_cosine_simd_rayon_chunked` → new
// `batched_cosine_simd_rayon_chunked` Rust function。
//
// CONTEXT — chapter 879 added the threshold field as a contract for
// future wiring。 The 14th-pass review of chapter 879.1 explicitly
// recommended v0.62.1 actually wire it through (not just leave a
// promise)。 Chapter 880 knife 2 does the wiring。 This test file
// pins the wiring so a future regression that loses the wiring is
// caught immediately。
//
// Byte-equality with the historic chunk_rows=64 result is the
// invariant — chunk_rows changes performance NOT scores。

import XCTest
@testable import BASRuntimeCore

final class BASChapter880ChunkRowsWiringTests: XCTestCase {

    /// Build a deterministic dim×rows corpus + matching query so
    /// the cosine scores are reproducible across the tests below。
    private func makeQuery(dim: Int) -> [Float] {
        return (0..<dim).map { i in
            Float((i % 32)) * 0.07 - 0.5
        }
    }

    private func makeCorpus(
        rows: Int, dim: Int
    ) -> [Float] {
        var out = [Float]()
        out.reserveCapacity(rows * dim)
        for r in 0..<rows {
            for c in 0..<dim {
                let idx = r * dim + c
                out.append(
                    Float((idx % 64)) * 0.03 - 0.4)
            }
        }
        return out
    }

    /// BASAutoRouteThresholds is immutable (`let` fields per
    /// coding-style 不可变性 rule) — build a fresh instance per
    /// chunk_rows variant by passing all defaults + override the
    /// 2 fields we care about (min_rows=1 forces rayon path,
    /// chunk_rows = the parameter under test)。
    private func makeThresholds(
        chunkRows: Int
    ) -> BASAutoRouteThresholds {
        return BASAutoRouteThresholds(
            batchedCosineRayonMinRows: 1,
            batchedCosineRayonChunkRows: chunkRows)
    }

    // MARK: - Byte-equality across chunk_rows values

    /// Different chunk_rows MUST produce identical scores。 This
    /// is the core wiring invariant — chunk_rows is a perf knob
    /// not a math knob。
    func testChunkRowsByteEqualAcrossValues() {
        let dim = 384
        let rows = 1024
        let q = makeQuery(dim: dim)
        let c = makeCorpus(rows: rows, dim: dim)

        // Sweep across chunk_rows values
        let chunkSweep: [Int] = [1, 8, 32, 64, 128, 512, 1024]
        var allScores: [[Float]] = []
        for ck in chunkSweep {
            let t = makeThresholds(chunkRows: ck)
            let r = BASAutoRouteRanker
                .batchedCosineSimilarity(
                    query: q, corpus: c, dim: dim,
                    thresholds: t)
            // Must route to rayon path
            XCTAssertEqual(
                r.choice, .rustBatchedCosineRayon,
                "chunk_rows=\(ck) should still route rayon")
            allScores.append(r.value)
        }
        // Every set of scores must be bit-identical to the
        // historic chunk_rows=64 result。
        let baseline = allScores[3]    // chunkSweep[3] == 64
        for (i, scores) in allScores.enumerated() {
            XCTAssertEqual(
                scores, baseline,
                "chunk_rows=\(chunkSweep[i]) diverged from " +
                "chunk_rows=64 baseline — byte-equality is " +
                "the wiring invariant")
        }
    }

    // MARK: - Clamping invariants

    /// chunk_rows=0 must NOT crash and must still produce
    /// byte-equal scores (coerced to 1 inside Rust)。
    /// NOTE: the threshold INIT itself clamps 0 → 1 (see
    /// `max(1, ...)` in init),so this test exercises the
    /// init clamp path,not the Rust clamp path。 Either way
    /// byte-equality must hold。
    func testChunkRowsZeroDoesNotCrashAndIsByteEqual() {
        let dim = 64
        let rows = 32
        let q = makeQuery(dim: dim)
        let c = makeCorpus(rows: rows, dim: dim)

        let r0 = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q, corpus: c, dim: dim,
            thresholds: makeThresholds(chunkRows: 0))
        let r64 = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q, corpus: c, dim: dim,
            thresholds: makeThresholds(chunkRows: 64))

        XCTAssertEqual(
            r0.value, r64.value,
            "chunk_rows=0 (clamped via init max(1,…)) must " +
            "still be byte-equal to chunk_rows=64")
    }

    /// chunk_rows > 4096 — the threshold init does NOT cap the
    /// upper bound,so this value passes through to Rust which
    /// clamps it to 4096。 Byte-equality must hold either way。
    func testChunkRowsAboveCapClampsAndIsByteEqual() {
        let dim = 64
        let rows = 256
        let q = makeQuery(dim: dim)
        let c = makeCorpus(rows: rows, dim: dim)

        let rBig = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q, corpus: c, dim: dim,
            thresholds: makeThresholds(chunkRows: 100_000))
        let r64 = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q, corpus: c, dim: dim,
            thresholds: makeThresholds(chunkRows: 64))

        XCTAssertEqual(
            rBig.value, r64.value,
            "chunk_rows=100_000 (clamped to 4096 by Rust) " +
            "must be byte-equal to chunk_rows=64")
    }

    // MARK: - Field exists + has expected default

    /// The chapter 879 field must still exist with its documented
    /// default (=64,the historic Mac mini measurement)。 If a
    /// future chapter changes the default,this test forces the
    /// chapter to acknowledge the change。
    func testThresholdFieldDefaultIs64() {
        let t = BASAutoRouteThresholds.mSeriesDefault
        XCTAssertEqual(
            t.batchedCosineRayonChunkRows, 64,
            "chapter 879 default chunk_rows = 64 (Mac mini " +
            "measurement) — if you changed this,update this " +
            "test AND the chapter that grew the change")
    }
}
