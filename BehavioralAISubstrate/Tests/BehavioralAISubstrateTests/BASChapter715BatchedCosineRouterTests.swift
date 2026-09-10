// MARK: - BASChapter715BatchedCosineRouterTests
// chapter 七百十五 第四刀 / M2249
//
// Verifies BASAutoRouteRanker.batchedCosineSimilarity +
// BASCognitiveBrain.batchedCosineAuto + the routing-decision
// policy with the empirical 16384-row threshold from chapter
// 七百十五 第三刀。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter715BatchedCosineRouterTests:
    XCTestCase
{
    // MARK: - Routing decision

    func testRoutesToRustBelowThreshold() {
        for corpusRows in [16, 256, 1024, 4096, 8192] {
            let choice = BASAutoRouteRanker
                .batchedCosineChoice(
                    corpusRows: corpusRows)
            XCTAssertEqual(choice, .rustBatchedCosine,
                "rows=\(corpusRows) must route to Rust")
        }
    }

    func testRoutesToMetalAtOrAboveThreshold() {
        for corpusRows in [16384, 32768, 100_000] {
            let choice = BASAutoRouteRanker
                .batchedCosineChoice(
                    corpusRows: corpusRows)
            XCTAssertEqual(choice, .metalBatchedCosine,
                "rows=\(corpusRows) must route to Metal")
        }
    }

    func testCustomThresholdOverride() {
        // Force Metal at any positive row count
        let custom = BASAutoRouteThresholds(
            batchedCosineMetalMinRows: 1)
        let choice = BASAutoRouteRanker
            .batchedCosineChoice(
                corpusRows: 1,
                thresholds: custom)
        XCTAssertEqual(choice, .metalBatchedCosine)
    }

    // MARK: - Numerical correctness

    func testSyncDispatchReturnsCorrectShape() {
        let dim = 64
        let nRows = 16
        let q: [Float] = (0..<dim).map {
            Float($0) * 0.01 }
        let corpus: [Float] = (0..<(nRows * dim)).map {
            Float($0) * 0.001 }
        let r = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: q, corpus: corpus, dim: dim)
        XCTAssertEqual(r.value.count, nRows)
        #if os(iOS) || os(macOS)
        XCTAssertEqual(r.choice, .rustBatchedCosine)
        #endif
    }

    func testIdentityCorpusYieldsOne() {
        let dim = 32
        let q: [Float] = (0..<dim).map { Float($0 + 1) }
        let r = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: q, corpus: q, dim: dim)
        XCTAssertEqual(r.value.count, 1)
        XCTAssertEqual(r.value[0], 1.0, accuracy: 1e-5)
    }

    func testOrthogonalCorpusYieldsZero() {
        let dim = 4
        let q: [Float] = [1, 0, 0, 0]
        let c: [Float] = [0, 1, 0, 0]
        let r = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: q, corpus: c, dim: dim)
        XCTAssertEqual(r.value[0], 0.0, accuracy: 1e-6)
    }

    func testZeroCorpusRowReturnsZero() {
        let dim = 4
        let q: [Float] = [1, 2, 3, 4]
        let c: [Float] = [0, 0, 0, 0]
        let r = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: q, corpus: c, dim: dim)
        XCTAssertEqual(r.value[0], 0.0,
            "zero-norm row must return 0,not NaN")
    }

    func testMultiRowAgainstReferenceCosine() {
        let dim = 32
        let nRows = 8
        let q: [Float] = (0..<dim).map {
            Float($0) * 0.02 - 0.3 }
        var corpus: [Float] = []
        for r in 0..<nRows {
            for d in 0..<dim {
                corpus.append(
                    Float((r * 7 + d) % 13) * 0.05 - 0.3)
            }
        }
        let result = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: q, corpus: corpus, dim: dim)
        for r in 0..<nRows {
            let row = Array(
                corpus[r * dim..<(r + 1) * dim])
            let expected = referenceCosine(q, row)
            XCTAssertEqual(result.value[r], expected,
                accuracy: 1e-5,
                "row \(r) got=\(result.value[r])" +
                " expected=\(expected)")
        }
    }

    private func referenceCosine(
        _ a: [Float], _ b: [Float]
    ) -> Float {
        var dot: Float = 0
        var nA: Float = 0
        var nB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            nA += a[i] * a[i]
            nB += b[i] * b[i]
        }
        if nA == 0 || nB == 0 { return 0 }
        return dot / (nA.squareRoot() * nB.squareRoot())
    }

    // MARK: - Brain helper parity

    func testBrainHelperMatchesRanker() {
        let dim = 16
        let nRows = 4
        let q: [Float] = (0..<dim).map {
            Float($0) * 0.05 }
        let c: [Float] = (0..<(nRows * dim)).map {
            Float($0) * 0.01 }
        let viaRanker = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: q, corpus: c, dim: dim)
        let viaBrain = BASCognitiveBrain
            .batchedCosineAuto(
                query: q, corpus: c, dim: dim)
        XCTAssertEqual(viaBrain.choice, viaRanker.choice)
        XCTAssertEqual(viaBrain.value.count,
            viaRanker.value.count)
        for i in 0..<viaRanker.value.count {
            XCTAssertEqual(
                viaBrain.value[i],
                viaRanker.value[i],
                accuracy: 1e-7)
        }
    }

    // MARK: - Threshold field defaults

    func testDefaultBatchedCosineThresholdIs16384() {
        let t = BASAutoRouteThresholds.mSeriesDefault
        XCTAssertEqual(t.batchedCosineMetalMinRows, 16384,
            "Default Metal-route threshold is 16384 per" +
            " chapter 七百十五 第三刀 tournament finding")
    }
}
