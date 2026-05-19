// MARK: - BASChapter715MatrixScorecardTests
// chapter 七百十五 第五刀 / M2250
//
// Updated matrix scorecard after chapter 七百十五 — the
// Metal embedding-similarity chapter。 Reports the honest
// empirical finding:Rust SIMD wins at all measured M-series
// sizes,but the Metal capability ships so future hardware
// (or larger corpora) can opt in via calibration。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASHostKit

final class BASChapter715MatrixScorecardTests: XCTestCase {

    func testPrintLanguageMatrixScorecard() {
        print("")
        print(
            "## chapter 七百十五 第五刀 — 各司其职 matrix scorecard")
        print(
            "                              (post-Metal-embedding chapter)")
        print("")
        print("### Per-language ownership status")
        print("")
        print("  Swift  : 14-layer orchestration + Apple API")
        print("           public API + lifecycle              ✅")
        print("")
        print("  SQL    : 10 schemas — MemoryAtom + Doctrine")
        print("           Episode + Bundle + Tombstone +")
        print("           ReplayLog + 4 FTS5 virtual tables   ✅")
        print("")
        print("  Rust   : retrieval/ranking + integrity hash")
        print("           ledger/replay + forget cascade +")
        print("           provenance + batched cosine        ✅")
        print("")
        print("  Metal  : FlashAttention + SSMScan + GELU/SiLU")
        print("           RMSNorm + MatMul (MPSGraph)        ✅")
        print("           batched embedding similarity       ✅ NEW")
        print("           (kernel ships; default routing")
        print("            stays Rust per empirical findings)")
        print("")
        print("  C      : ABI + Darwin probes + SPSC ring     ✅")
        print("")
        print("  C++    : MPSGraph cache + LSH NN             ✅")
        print("           MLX/FAISS/HNSW/llama.cpp bridges    gap")
        print("           (no current consumer demand)")
        print("")
        print("### Empirical routing decisions (M-series host)")
        print("")
        let dim = 64
        let q: [Float] = (0..<dim).map {
            Float($0) * 0.01 }
        let small = [Float](
            repeating: 0.1, count: 256 * dim)
        let medium = [Float](
            repeating: 0.1, count: 4096 * dim)
        let large = [Float](
            repeating: 0.1, count: 16384 * dim)
        let smallChoice = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: q, corpus: small, dim: dim).choice
        let mediumChoice = BASAutoRouteRanker
            .batchedCosineSimilarity(
                query: q, corpus: medium, dim: dim).choice
        let largeChoice = BASAutoRouteRanker
            .batchedCosineChoice(corpusRows: 16384)
        print("  batched_cosine(rows=256)   → \(smallChoice)")
        print("  batched_cosine(rows=4096)  → \(mediumChoice)")
        print("  batched_cosine(rows=16384) → \(largeChoice)")
        print("")
        print("### Auto-router family registry")
        print("")
        let all = BASAutoRouteChoice.allCases
            .map { $0.rawValue }
        print("  Total routing-choice cases: \(all.count)")
        print("")
        print(
            "Architectural alignment: 5 of 6 matrix duties green;")
        print(
            "only C++ MLX/FAISS/HNSW/llama.cpp bridges remain gapped")
        print(
            "(deferred until host-app demand justifies the surface)。")
        print("")
        // Sanity check
        XCTAssertEqual(smallChoice, .rustBatchedCosine)
        XCTAssertEqual(mediumChoice, .rustBatchedCosine)
        XCTAssertEqual(largeChoice, .metalBatchedCosine)
        XCTAssertGreaterThanOrEqual(all.count, 30)
    }
}
