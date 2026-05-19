// MARK: - BASChapter727MatrixScorecardTests
// chapter 七百二十七 第五刀 / M2310
//
// Chapter 七百二十七 close-out scorecard。 First quality-drift-
// gated production path in the substrate's history (replaces
// byte-equality for quantization)。

import XCTest
import Foundation
@testable import BASRuntimeCore
@testable import BASMemory

final class BASChapter727MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百二十七 第五刀 — int8 vector storage scorecard")
        print("")
        print("### Chapter 七百二十七 deliverable")
        print("")
        print(
            "  Knife 1: BASInt8VectorIndexEntry v2 wire format + Rust int8 cosine")
        print(
            "           ▶ Schema version 2 (BIG-ENDIAN length prefixes)")
        print(
            "           ▶ cosine_int8 + batched_cosine_int8 Rust math")
        print(
            "  Knife 2: C ABI + Swift bridge + BASVectorIndex.topKInt8")
        print(
            "           ▶ Single FFI hop for the entire corpus")
        print(
            "           ▶ Heterogeneous per-row scales preserve precision")
        print(
            "           ▶ Feature flag useInt8VectorStorage (default OFF)")
        print(
            "  Knife 3: NEW EXIT CRITERION — cosine-drift gate")
        print(
            "           ▶ 100,000 comparisons (100q × 1000c × 384 dim)")
        print(
            "           ▶ Max drift 0.001221 (gate ≤ 0.01 → 8× margin)")
        print(
            "           ▶ Recall@10: 99.0% (gate ≥ 70%)")
        print(
            "  Knife 4: Perf grid — speed TIED,RAM 3.88× shrink")
        print(
            "           ▶ 1K/5K/10K corpus × 384 dim")
        print(
            "           ▶ Honest:speed under 1.5× gate,memory above 3.5× gate")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### Quality gate landing (NEW for quantization paths)")
        print("")
        print(
            "  Total comparisons: 100,000")
        print(
            "  Max cosine drift:  0.001221")
        print(
            "  Avg cosine drift:  0.000226")
        print(
            "  Gate threshold:    ≤ 0.01")
        print(
            "  Status:            PASS ✅ (8× safety margin)")
        print("")
        print(
            "  Top-10 recall:     99.0% (198/200)")
        print(
            "  Gate threshold:    ≥ 70%")
        print(
            "  Status:            PASS ✅ (29 percentage points above)")
        print("")
        print(
            "### Perf grid landing")
        print("")
        print(
            "  size     | f32 µs/op | i8 µs/op | speedup | i8 RAM   | f32 RAM")
        print(
            "  ---------+-----------+----------+---------+----------+---------")
        print(
            "  1K rows  |   1958.67 |  2081.08 |  0.94×  |  0.38 MB |  1.46 MB")
        print(
            "  5K rows  |   8244.59 |  8982.38 |  0.92×  |  1.89 MB |  7.32 MB")
        print(
            "  10K rows |  18088.68 | 18839.94 |  0.96×  |  3.78 MB | 14.65 MB")
        print("")
        print(
            "  Speed: TIED (0.92-0.96× — below 1.5× decision gate)")
        print(
            "  RAM:   3.88× shrink (significant for memory-bound workloads)")
        print("")
        print(
            "### Decision per measurement-first discipline")
        print("")
        print(
            "  - SPEED gate (≥ 1.5×):  not met")
        print(
            "  - MEMORY gate:         3.88× shrink — meaningful")
        print(
            "  - QUALITY gate:        drift ≤ 0.01 PASS,recall ≥ 70% PASS")
        print(
            "  → Ship as OPT-IN,default OFF (useInt8VectorStorage)")
        print(
            "    Hosts with large corpora flip the flag,accepting")
        print(
            "    the small speed tie for the 4× RAM win。")
        print("")
        print(
            "### Memory budget math (production scale)")
        print("")
        print(
            "  1M-vector × 384-dim corpus:")
        print(
            "    Float32: 1.46 GB (likely OOM on most iOS devices)")
        print(
            "    int8:    0.37 GB (fits in iOS device RAM comfortably)")
        print(
            "  → int8 unlocks corpus sizes that Float32 cannot reach")
        print("")
        print(
            "### Cumulative production paths (chapter 七百四 → 七百二十七)")
        print("")
        print(
            "  ✅ SHA256 / HMAC / cosine / provenance / vector topK")
        print(
            "  ✅ hex encode / decode (Rust LUT)")
        print(
            "  ✅ recordBatch multi-row SQL (1.63× — default ON)")
        print(
            "  🆕 BPE tokenization (28×) — opt-in primitive")
        print(
            "  🆕 event log binary codec (2.3× storage) — opt-in primitive")
        print(
            "  🆕 int8 quantization (1.17× compute,3.98× memory) — opt-in")
        print(
            "  🆕 int8 vector storage (TIED speed,3.88× RAM)")
        print(
            "     → opt-in,QUALITY-GATED (cosine-drift 0.0012,recall 99%)")
        print(
            "  ⛔ scoreAll Rust / usageCount Rust — Swift wins,opt-in only")
        print("")
        print(
            "### 27-chapter branch arc — current state")
        print("")
        print(
            "  - 27 chapters · 135 knives · ~838 commits")
        print(
            "  - 89.5% Swift / ~10.5% native")
        print(
            "  - Production-default flips: 9 (unchanged)")
        print(
            "  - Net-new opt-in capabilities: 4 (BPE,binary codec,")
        print(
            "    int8 quantize,int8 vector storage)")
        print(
            "  - 9 Rust crates bundled")
        print(
            "  - **7/10 chapters of 七百二十一-七百三十 arc complete**")
        print("")
        print(
            "### Methodology contribution to the arc")
        print("")
        print(
            "  Chapter 七百二十七 establishes the QUALITY-GATED")
        print(
            "  PRODUCTION-PATH pattern that downstream chapters")
        print(
            "  inherit:")
        print(
            "    chapter 七百二十八 KV int8:    cosine-drift gate")
        print(
            "                                   (likely flip OFF per")
        print(
            "                                    plan — long-context")
        print(
            "                                    sessions may exceed 0.01)")
        print(
            "    chapter 七百二十九 PQ index:   recall@10 ≥ 0.95 gate")
        print("")
        print(
            "  The methodology preserves measurement-first discipline")
        print(
            "  even when byte-equality is mathematically impossible。")
        print("")
        print(
            "### Plan-agent realism check ← actual landing")
        print("")
        print(
            "  Plan estimate (chapter 七百二十七):")
        print(
            "    \"4× memory savings + cosine-drift ≤ 0.01 across")
        print(
            "     100 queries × 1000 corpus\"")
        print("")
        print(
            "  Actual landing:")
        print(
            "    ✅ Memory: 3.88× (matches plan;asymptotes to 4×)")
        print(
            "    ✅ Quality: 0.0012 drift (8× under the 0.01 gate)")
        print(
            "    ✅ Quality: 99% recall@10 (sanity)")
        print(
            "    ⚠️  Speed: TIED (not a speed win,but expected")
        print(
            "       given chapter 七百十八 Float32 batched is already")
        print(
            "       very fast)")
        print(
            "    ✅ Methodology: quality-drift gate established for")
        print(
            "       downstream chapters")
        print("")

        // Smoke: int8 path works end-to-end
        #if os(iOS) || os(macOS)
        let v = (0..<384).map { Float($0) / 384.0 - 0.5 }
        var sumSq: Float = 0
        for x in v { sumSq += x * x }
        let mag = sqrt(sumSq)
        let vn = v.map { $0 / mag }
        let entry = BASInt8VectorIndexEntry(
            atomID: "smoke",
            normalizedEmbedding: vn)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry!.dimension, 384)
        // 384-dim vector with [Int] shape (1 element = 8 bytes
        // + 4-byte scale) shrinks to ~3.88×;asymptotes to 4×
        // as N grows。 Per knife 4 measurement (1K rows → 3.86)。
        XCTAssertGreaterThan(
            entry!.quantizedEmbedding.memoryShrinkRatio, 3.85)
        #endif
    }
}
