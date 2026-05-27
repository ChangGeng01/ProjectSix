// MARK: - BASChapter715BatchedCosineDispatcherTests
// chapter 七百十五 第二刀 / M2247
//
// Verifies the new BASMetalBatchedCosineSimilarityDispatcher:
//
//   1. Single corpus row: dispatcher matches per-row CPU cosine
//   2. Multi-row corpus: every score matches Rust SIMD
//      batched_cosine within fp32 tolerance
//   3. Zero-norm row returns 0.0 (NaN guard)
//   4. Shape errors throw the right typed error

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

#if !os(iOS)  // ch 1022 source-gate
final class BASChapter715BatchedCosineDispatcherTests:
    XCTestCase
{
    #if os(iOS) || os(macOS)

    private func makeLoader() -> BASMetalKernelLibraryLoader {
        // chapter 七百四 第二刀 — explicit V2 opt-in so the
        // loader actually compiles SSMScan.metal at runtime。
        return BASMetalKernelLibraryLoader(
            useMetalKernelV2: true)
    }

    /// Reference CPU cosine for comparison。 Same algorithm
    /// as Rust SIMD batched_cosine but written directly in
    /// Swift so the test stays decoupled from the FFI surface。
    private func cpuCosine(
        _ q: [Float], _ r: [Float]
    ) -> Float {
        var dot: Float = 0
        var nQ: Float = 0
        var nR: Float = 0
        for i in 0..<q.count {
            dot += q[i] * r[i]
            nQ += q[i] * q[i]
            nR += r[i] * r[i]
        }
        if nQ <= 0 || nR <= 0 { return 0 }
        return dot / (nQ.squareRoot() * nR.squareRoot())
    }

    func testSingleRowMatchesCPU() async throws {
        let dispatcher =
            BASMetalBatchedCosineSimilarityDispatcher(
                loader: makeLoader())
        let dim = 128
        let q: [Float] = (0..<dim).map {
            Float($0) * 0.01 }
        let r: [Float] = (0..<dim).map {
            Float(dim - $0) * 0.01 }
        let scores = try await dispatcher.dispatch(
            query: q, corpus: r, dim: dim)
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0], cpuCosine(q, r),
            accuracy: 1e-5)
    }

    func testMultiRowMatchesCPU() async throws {
        let dispatcher =
            BASMetalBatchedCosineSimilarityDispatcher(
                loader: makeLoader())
        let dim = 64
        let nRows = 16
        let q: [Float] = (0..<dim).map {
            Float($0) * 0.02 - 0.5 }
        var corpus: [Float] = []
        corpus.reserveCapacity(nRows * dim)
        for r in 0..<nRows {
            for d in 0..<dim {
                corpus.append(
                    Float((r * 17 + d) % 31) * 0.03 - 0.4)
            }
        }
        let scores = try await dispatcher.dispatch(
            query: q, corpus: corpus, dim: dim)
        XCTAssertEqual(scores.count, nRows)
        // Per-row CPU comparison
        for r in 0..<nRows {
            let row = Array(
                corpus[r * dim..<(r + 1) * dim])
            let expected = cpuCosine(q, row)
            XCTAssertEqual(scores[r], expected,
                accuracy: 1e-4,
                "row \(r) gpu=\(scores[r]) cpu=\(expected)")
        }
    }

    func testIdentityCorpusYieldsOne() async throws {
        let dispatcher =
            BASMetalBatchedCosineSimilarityDispatcher(
                loader: makeLoader())
        let dim = 32
        let q: [Float] = (0..<dim).map {
            Float($0 + 1) }
        // Corpus = exactly the query
        let scores = try await dispatcher.dispatch(
            query: q, corpus: q, dim: dim)
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0], 1.0, accuracy: 1e-4)
    }

    func testZeroNormRowReturnsZero() async throws {
        let dispatcher =
            BASMetalBatchedCosineSimilarityDispatcher(
                loader: makeLoader())
        let dim = 8
        let q: [Float] = [1, 2, 3, 4, 5, 6, 7, 8]
        // Corpus row of all zeros
        let r: [Float] = [Float](
            repeating: 0, count: dim)
        let scores = try await dispatcher.dispatch(
            query: q, corpus: r, dim: dim)
        XCTAssertEqual(scores[0], 0.0,
            "zero-norm row must return 0,not NaN")
    }

    func testEmptyQueryThrows() async throws {
        let dispatcher =
            BASMetalBatchedCosineSimilarityDispatcher(
                loader: makeLoader())
        do {
            _ = try await dispatcher.dispatch(
                query: [], corpus: [1.0, 2.0], dim: 0)
            XCTFail("empty query must throw")
        } catch BASMetalBatchedCosineDispatcherError
            .zeroLengthQuery
        {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testShapeMismatchThrows() async throws {
        let dispatcher =
            BASMetalBatchedCosineSimilarityDispatcher(
                loader: makeLoader())
        do {
            _ = try await dispatcher.dispatch(
                query: [1, 2, 3, 4],
                corpus: [1, 2, 3, 4, 5], // not divisible by 4
                dim: 4)
            XCTFail("shape mismatch must throw")
        } catch BASMetalBatchedCosineDispatcherError
            .shapeMismatch
        {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testDispatcherMatchesRustSIMD() async throws {
        let dispatcher =
            BASMetalBatchedCosineSimilarityDispatcher(
                loader: makeLoader())
        let dim = 256
        let nRows = 64
        let q: [Float] = (0..<dim).map {
            Float($0) * 0.005 - 0.1 }
        var corpus: [Float] = []
        corpus.reserveCapacity(nRows * dim)
        for r in 0..<nRows {
            for d in 0..<dim {
                corpus.append(
                    Float((r * 23 + d) % 41) * 0.01 - 0.2)
            }
        }
        let metalScores = try await dispatcher.dispatch(
            query: q, corpus: corpus, dim: dim)
        var rustScores = [Float](
            repeating: 0, count: nRows)
        let rc = q.withUnsafeBufferPointer { qp in
            corpus.withUnsafeBufferPointer { cp in
                rustScores
                    .withUnsafeMutableBufferPointer { op in
                    bas_ranker_batched_cosine_simd(
                        qp.baseAddress, q.count,
                        cp.baseAddress, corpus.count,
                        dim,
                        op.baseAddress)
                }
            }
        }
        XCTAssertEqual(rc, 0)
        for i in 0..<nRows {
            XCTAssertEqual(metalScores[i], rustScores[i],
                accuracy: 1e-4,
                "row \(i) metal=\(metalScores[i]) " +
                "rust=\(rustScores[i])")
        }
    }
    #endif
}
#endif
