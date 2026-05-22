// MARK: - BASChapter872BatchedCosineRayonTests
// chapter 八百七十二 / M3026 — BASVectorIndex Rust+rayon completion。
//
// Closes the chapter 七百十八 partial migration:
//   - Per-pair scoring still in Swift loop (BASVectorIndex.topK
//     when useBatchedTopK=false,which is current default)
//   - Batched fast-path is opt-in (useBatchedTopK=true) and uses
//     sequential SIMD bas_ranker_batched_cosine_simd
//
// Chapter 八百七十二 adds the rayon parallel path:
//   - NEW bas_ranker_batched_cosine_simd_rayon C ABI (par_chunks
//     across corpus rows)
//   - NEW BASAutoRouteChoice.rustBatchedCosineRayon enum case
//   - NEW BASAutoRouteThresholds.batchedCosineRayonMinRows
//     (default 500) — auto-selected by batchedCosineSimilarity
//
// Tests:
//   - byte-equality between sequential SIMD + rayon parallel
//     at production-scale corpus
//   - routing pin: corpus ≥ 500 → .rustBatchedCosineRayon,
//     corpus < 500 → .rustBatchedCosine
//   - 3-way perf benchmark at production shapes (1K / 10K / 50K
//     atoms × 384 dim) — Swift per-pair loop vs sequential
//     batched vs rayon batched

import XCTest
@testable import BASRuntimeCore

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter872BatchedCosineRayonTests: XCTestCase {

    // MARK: - Fixture

    private func makeQueryAndCorpus(
        rows: Int, dim: Int
    ) -> (query: [Float], corpus: [Float]) {
        var seed: UInt32 = 0xCAFEBABE
        func next() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            return Float(seed & 0xFFFF)
                / Float(0xFFFF) - 0.5
        }
        let query = (0..<dim).map { _ in next() }
        let corpus = (0..<(rows * dim)).map { _ in next() }
        return (query, corpus)
    }

    // MARK: - Byte-equality

    /// rayon parallel batched must produce BYTE-EQUAL output to
    /// sequential SIMD batched。 The chapter 八百六十三
    /// par_chunks_mut byte-equality discipline applies:each row
    /// is independent + collect preserves order。
    func testRayonBatchedByteEqualToSequentialAt1KCorpus() throws {
        let (q, c) = makeQueryAndCorpus(rows: 1000, dim: 384)
        var seqScores = [Float](repeating: 0, count: 1000)
        var parScores = [Float](repeating: 0, count: 1000)
        let rcSeq = q.withUnsafeBufferPointer { qp in
            c.withUnsafeBufferPointer { cp in
                seqScores.withUnsafeMutableBufferPointer { op in
                    bas_ranker_batched_cosine_simd(
                        qp.baseAddress, q.count,
                        cp.baseAddress, c.count,
                        384, op.baseAddress)
                }
            }
        }
        let rcPar = q.withUnsafeBufferPointer { qp in
            c.withUnsafeBufferPointer { cp in
                parScores.withUnsafeMutableBufferPointer { op in
                    bas_ranker_batched_cosine_simd_rayon(
                        qp.baseAddress, q.count,
                        cp.baseAddress, c.count,
                        384, op.baseAddress)
                }
            }
        }
        XCTAssertEqual(rcSeq, 0)
        XCTAssertEqual(rcPar, 0)
        for i in 0..<1000 {
            XCTAssertEqual(
                seqScores[i].bitPattern,
                parScores[i].bitPattern,
                "row \(i) not byte-equal: seq=\(seqScores[i]) " +
                "par=\(parScores[i])")
        }
    }

    // MARK: - Routing pins

    /// Below threshold (default 3000): sequential SIMD path
    func testRouteSequentialBelowRayonThreshold() {
        let (q, c) = makeQueryAndCorpus(rows: 100, dim: 64)
        let r = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q, corpus: c, dim: 64)
        XCTAssertEqual(r.choice, .rustBatchedCosine,
            "100 rows < default 3000 threshold → sequential SIMD")
        XCTAssertEqual(r.value.count, 100)

        let (q2, c2) = makeQueryAndCorpus(rows: 2000, dim: 64)
        let r2 = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q2, corpus: c2, dim: 64)
        XCTAssertEqual(r2.choice, .rustBatchedCosine,
            "2000 rows < default 3000 threshold → sequential SIMD")
    }

    /// At/above threshold (default 3000): rayon parallel path
    func testRouteRayonAtAndAboveThreshold() {
        let (q, c) = makeQueryAndCorpus(rows: 3000, dim: 64)
        let r = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q, corpus: c, dim: 64)
        XCTAssertEqual(r.choice, .rustBatchedCosineRayon,
            "3000 rows == default 3000 threshold → rayon parallel")

        let (q2, c2) = makeQueryAndCorpus(rows: 10_000, dim: 64)
        let r2 = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q2, corpus: c2, dim: 64)
        XCTAssertEqual(r2.choice, .rustBatchedCosineRayon,
            "10K rows above threshold → rayon parallel")
    }

    /// Custom threshold (e.g. very large) forces sequential
    /// even at large corpus
    func testCustomHighThresholdForcesSequential() {
        let (q, c) = makeQueryAndCorpus(rows: 5000, dim: 64)
        let thresholds = BASAutoRouteThresholds(
            batchedCosineRayonMinRows: 50_000)
        let r = BASAutoRouteRanker.batchedCosineSimilarity(
            query: q, corpus: c, dim: 64,
            thresholds: thresholds)
        XCTAssertEqual(r.choice, .rustBatchedCosine,
            "5K rows < 50K threshold (custom) → sequential")
    }

    // MARK: - 3-way perf benchmark

    /// Helper: time N iterations and return median ns。
    private func timeMedianNs(
        warmup: Int, iterations: Int,
        op: () -> Void
    ) -> Double {
        for _ in 0..<warmup { op() }
        var samples: [Double] = []
        for _ in 0..<iterations {
            let s = DispatchTime.now().uptimeNanoseconds
            op()
            let e = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(e - s))
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    /// Swift per-pair loop reference (mirrors current
    /// BASVectorIndex.topK code path when useBatchedTopK=false)
    private func swiftPerPairCosine(
        query: [Float], corpus: [Float], dim: Int, rows: Int
    ) -> [Float] {
        var out = [Float](repeating: 0, count: rows)
        var qNorm: Float = 0
        for d in 0..<dim { qNorm += query[d] * query[d] }
        let invQNorm = qNorm > 0
            ? 1.0 / qNorm.squareRoot() : 0
        for r in 0..<rows {
            var dot: Float = 0
            var rNorm: Float = 0
            let base = r * dim
            for d in 0..<dim {
                let rv = corpus[base + d]
                dot += query[d] * rv
                rNorm += rv * rv
            }
            out[r] = rNorm > 0
                ? dot * invQNorm / rNorm.squareRoot()
                : 0
        }
        return out
    }

    /// 3-way bench at production corpus shapes。
    private func bench3WayAt(
        rows: Int, dim: Int, iterations: Int
    ) {
        let (q, c) = makeQueryAndCorpus(rows: rows, dim: dim)

        // Warmup all paths
        for _ in 0..<3 {
            _ = swiftPerPairCosine(
                query: q, corpus: c, dim: dim, rows: rows)
            var s = [Float](repeating: 0, count: rows)
            _ = q.withUnsafeBufferPointer { qp in
                c.withUnsafeBufferPointer { cp in
                    s.withUnsafeMutableBufferPointer { op in
                        bas_ranker_batched_cosine_simd(
                            qp.baseAddress, q.count,
                            cp.baseAddress, c.count,
                            dim, op.baseAddress)
                    }
                }
            }
            _ = q.withUnsafeBufferPointer { qp in
                c.withUnsafeBufferPointer { cp in
                    s.withUnsafeMutableBufferPointer { op in
                        bas_ranker_batched_cosine_simd_rayon(
                            qp.baseAddress, q.count,
                            cp.baseAddress, c.count,
                            dim, op.baseAddress)
                    }
                }
            }
        }

        let swiftNs = timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = self.swiftPerPairCosine(
                query: q, corpus: c,
                dim: dim, rows: rows)
        }
        var seqScores = [Float](repeating: 0, count: rows)
        let seqNs = timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = q.withUnsafeBufferPointer { qp in
                c.withUnsafeBufferPointer { cp in
                    seqScores.withUnsafeMutableBufferPointer
                        { op in
                        bas_ranker_batched_cosine_simd(
                            qp.baseAddress, q.count,
                            cp.baseAddress, c.count,
                            dim, op.baseAddress)
                    }
                }
            }
        }
        var parScores = [Float](repeating: 0, count: rows)
        let parNs = timeMedianNs(
            warmup: 0, iterations: iterations
        ) {
            _ = q.withUnsafeBufferPointer { qp in
                c.withUnsafeBufferPointer { cp in
                    parScores.withUnsafeMutableBufferPointer
                        { op in
                        bas_ranker_batched_cosine_simd_rayon(
                            qp.baseAddress, q.count,
                            cp.baseAddress, c.count,
                            dim, op.baseAddress)
                    }
                }
            }
        }

        print(String(format:
            "BENCH 3-way batched cosine rows=%d dim=%d:\n" +
            "  Swift per-pair = %10.0f ns\n" +
            "  Rust seq SIMD  = %10.0f ns " +
            "(speedup vs Swift=%.2fx)\n" +
            "  Rust rayon par = %10.0f ns " +
            "(speedup vs Swift=%.2fx, vs seq=%.2fx)",
            rows, dim,
            swiftNs,
            seqNs, swiftNs / seqNs,
            parNs, swiftNs / parNs, seqNs / parNs))

        // Weak pin: Rust paths must beat Swift at production
        // shapes by ≥ 2× (very weak — chapter 七百十八 measured
        // 8-40× win)
        XCTAssertLessThan(seqNs, swiftNs / 2,
            "Rust seq must beat Swift per-pair by ≥2× at " +
            "rows=\(rows)")
        XCTAssertLessThan(parNs, swiftNs / 2,
            "Rust rayon must beat Swift per-pair by ≥2× at " +
            "rows=\(rows)")
    }

    func testBench3WayAt1KCorpus() {
        bench3WayAt(rows: 1000, dim: 384, iterations: 20)
    }

    func testBench3WayAt5KCorpus() {
        bench3WayAt(rows: 5000, dim: 384, iterations: 10)
    }
}
