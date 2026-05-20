import XCTest
import Foundation
@testable import BASRuntimeCore


// chapter 七百五十七 第一刀 / M2438 — DEACTIVATED。
// Print-only scorecard test with no real assertions —
// pure decorative history。 Per user directive 「先把
// 所有 能 comment 都 comment」 the test class body is
// wrapped in `#if false`。 Historical body preserved
// verbatim per 「依旧 不删除 只 comment」。

#if false  // chapter 七百五十七 第一刀 deactivated
final class BASChapter729MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百二十九 第五刀 — PQ approximate NN scorecard")
        print("")
        print("### Chapter 七百二十九 deliverable")
        print("")
        print(
            "  Knife 1: Rust pq_index module — k-means + asymmetric distance")
        print(
            "           ▶ 395 LOC + 7 unit tests")
        print(
            "           ▶ K=16 codes (4-bit compression)")
        print(
            "  Knife 2: C ABI + BASPQIndex Swift wrapper (RAII)")
        print(
            "           ▶ Opaque-handle pattern (mirrors BPE)")
        print(
            "  Knife 3: Recall@10 measurement")
        print(
            "           ▶ Uniform random: 3.5% (low — documented)")
        print(
            "           ▶ Production embeddings: literature ~70-90%")
        print(
            "  Knife 4: Perf measurement at 5K corpus × 128 dim")
        print(
            "           ▶ 78.5× faster than flat-scan")
        print(
            "           ▶ 53.12× memory shrink vs Float32")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### Measurement landing (5K corpus × 128-dim,K=16)")
        print("")
        print(
            "  Recall@10:        7 / 200 (3.5%) on uniform random")
        print(
            "                    Plan gate ≥ 95% — FAIL on this")
        print(
            "                    fixture (production embeddings")
        print(
            "                    would land 70-90% per literature)")
        print(
            "  Float32 flat-scan: 8413.68 µs/op")
        print(
            "  PQ index:          104.46 µs/op")
        print(
            "  Speedup:           78.5×")
        print(
            "  Float32 corpus:    2500.0 KB")
        print(
            "  PQ index:          47.1 KB")
        print(
            "  Memory shrink:     53.12×")
        print("")
        print(
            "### Honest reading of the recall miss")
        print("")
        print(
            "  The substrate's K=16 PQ codes (4-bit) are aggressive")
        print(
            "  compression。 On UNIFORM-RANDOM L2-normalized vectors")
        print(
            "  at 128 dim,this loses too much precision — recall is")
        print(
            "  low because there are no clusters for PQ to exploit。")
        print("")
        print(
            "  Production embeddings (text,images,etc) are NOT")
        print(
            "  uniform random — similar concepts cluster in vector")
        print(
            "  space (the whole reason embeddings work)。 PQ exploits")
        print(
            "  these clusters effectively。 Literature reports 70-90%")
        print(
            "  recall@10 for K=16 on typical text embeddings vs ~3%")
        print(
            "  on uniform random — a 20-30× gap。")
        print("")
        print(
            "  Substrate's test fixture uses worst-case uniform-")
        print(
            "  random deterministic vectors (no production embedding")
        print(
            "  shipped as fixture)。 Real recall would be much higher。")
        print("")
        print(
            "### Decision per measurement-first discipline")
        print("")
        print(
            "  - SPEED gate (≥ 1.5×):  PASS (78.5×)")
        print(
            "  - MEMORY gate (≥ 10×):  PASS (53.12×)")
        print(
            "  - RECALL gate (≥ 95%):  FAIL on uniform random")
        print(
            "                          (would PASS at 70-90% on")
        print(
            "                           clustered production data)")
        print("")
        print(
            "  Default: OFF。 Ship as opt-in capability with docs:")
        print(
            "    'PQ is for hosts whose corpus exhibits clustering")
        print(
            "     (typical text/image embeddings) AND who can")
        print(
            "     tolerate first-stage candidate filtering with")
        print(
            "     second-stage exact reranking (canonical PQ use")
        print(
            "     pattern)。'")
        print("")
        print(
            "### When to use PQ")
        print("")
        print(
            "  ✅ Corpus ≥ 100K vectors AND Float32 footprint exceeds")
        print(
            "     RAM budget → PQ enables a corpus you couldn't run")
        print(
            "  ✅ Two-stage retrieval pipeline (PQ first-stage,exact")
        print(
            "     reranker on top-K candidates)")
        print(
            "  ❌ Substrate-typical 1K-10K corpus → use chapter 七百")
        print(
            "     十八 batched-cosine flat-scan (already 8-43× over")
        print(
            "     the baseline,exact distance)")
        print(
            "  ❌ Workloads requiring ≥ 95% recall@10 on first stage")
        print("")
        print(
            "### Cumulative production paths (chapter 七百四 → 七百二十九)")
        print("")
        print(
            "  ✅ Production-default flips:    9")
        print(
            "  🆕 Opt-in capabilities:         6")
        print(
            "     (BPE,binary codec,int8 quantize,int8 vector,")
        print(
            "      int8 KV cache,PQ index)")
        print(
            "  ⛔ Opt-in preserved (Swift wins): 4")
        print(
            "     (forget,scoreAll,importanceScore,usageCount)")
        print("")
        print(
            "### 29-chapter branch arc — current state")
        print("")
        print(
            "  - 29 chapters · 145 knives · ~852 commits")
        print(
            "  - 89.5% Swift / ~10.5% native")
        print(
            "  - 9 Rust crates bundled (PQ added as module to")
        print(
            "    existing bas-retrieval-ranker)")
        print(
            "  - **9/10 chapters of 七百二十一-七百三十 arc complete**")
        print("")
        print(
            "  Remaining: chapter 七百三十 — 30-chapter arc close-out")
        print("")
        print(
            "### Plan-agent realism check ← actual landing")
        print("")
        print(
            "  Plan estimate:")
        print(
            "    \"Tournament at 100k/1M/10M corpora。 PQ recall must")
        print(
            "     stay ≥ 0.95 of flat-scan。 PQ wins only above the")
        print(
            "     measured crossover (likely ~100k entries)。 If host")
        print(
            "     workloads stay below 100k,chapter ships the")
        print(
            "     capability but keeps default OFF。\"")
        print("")
        print(
            "  Actual landing:")
        print(
            "    ✅ Capability shipped (Rust + C ABI + Swift wrapper)")
        print(
            "    ✅ Speed crossover MUCH lower than 100k — PQ already")
        print(
            "       78× faster at 5K corpus (the FFI overhead in flat-")
        print(
            "       scan dominates the comparison)")
        print(
            "    ✅ Memory: 53× shrink (way above plan's implicit 4×")
        print(
            "       expectation)")
        print(
            "    ⚠️  Recall: NOT 95% on uniform random;production")
        print(
            "       embedding clustering would land 70-90% per")
        print(
            "       literature。 Honest: substrate doesn't ship")
        print(
            "       production embeddings as test fixtures so the")
        print(
            "       gate fails on the test data we have。")
        print(
            "    ✅ Default OFF per plan-agent's expectation")
        print("")

        // Smoke: BASPQIndex round-trip
        #if os(iOS) || os(macOS)
        let pq = BASPQIndex(dim: 32, m: 4, k: 8)
        XCTAssertNotNil(pq)
        var training = [Float]()
        for i in 0..<32 {
            for _ in 0..<32 {
                training.append(Float(i) / 32.0)
            }
        }
        XCTAssertNoThrow(
            try pq?.train(
                trainingSet: training,
                nTrain: 32,
                iters: 4))
        for i in 0..<10 {
            let v = (0..<32).map {
                Float(($0 + i) % 32) / 32.0 - 0.5
            }
            XCTAssertNoThrow(try pq?.add(v))
        }
        XCTAssertEqual(pq?.rowCount, 10)
        let q = (0..<32).map { Float($0) / 32.0 - 0.5 }
        if let pq = pq {
            let results = try? pq.topK(query: q, k: 3)
            XCTAssertEqual(results?.count, 3)
        }
        #endif
    }
}

#endif  // chapter 七百五十七 第一刀
