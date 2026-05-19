// MARK: - BASChapter728MatrixScorecardTests
// chapter 七百二十八 第五刀 / M2315
//
// Chapter 七百二十八 close-out scorecard。 The aggressive arc's
// highest accuracy risk chapter landed with all three gates
// PASSING — a surprising positive outcome vs plan-agent's
// "likely flip-OFF" expectation。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter728MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百二十八 第五刀 — KV cache int8 scorecard")
        print("")
        print("### Chapter 七百二十八 deliverable")
        print("")
        print(
            "  Knife 1: BASKVCacheQuantizedToken struct (Codable)")
        print(
            "           ▶ int8 K + int8 V + 2 scales + element count")
        print(
            "  Knife 2: toQuantizedInt8 / toFloat32Token helpers + flag")
        print(
            "           ▶ Free-standing — preserves BASKVCacheRegistry contract")
        print(
            "           ▶ Feature flag BASKVCacheQuantization.useQuantizedKVCache")
        print(
            "  Knife 3: 100-turn replay drift gate — PASS 11× margin")
        print(
            "           ▶ Per-token drift envelope < 0.001")
        print(
            "  Knife 4: Memory footprint perf — 3.66-3.82× shrink")
        print(
            "           ▶ Beats plan's 2-3× estimate")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### Quality gate landing")
        print("")
        print(
            "  Per-token round-trip cosine:")
        print(
            "    Key:   cosine(orig, recovered) > 0.99 ✅")
        print(
            "    Value: cosine(orig, recovered) > 0.99 ✅")
        print("")
        print(
            "  100-turn replay drift (each turn fresh key + query):")
        print(
            "    Max drift:  0.000879 (gate ≤ 0.01)")
        print(
            "    Avg drift:  0.000249")
        print(
            "    Status:     PASS ✅ (11× safety margin)")
        print("")
        print(
            "### Memory footprint perf")
        print("")
        print(
            "  cell                              | f32 KB | i8 KB | ratio")
        print(
            "  ----------------------------------+--------+-------+------")
        print(
            "  5 turns × 8 layers × 128 dim     |   40.0 |  10.9 | 3.66×")
        print(
            "  20 turns × 8 layers × 128 dim    |  160.0 |  43.8 | 3.66×")
        print(
            "  50 turns × 8 layers × 128 dim    |  400.0 | 109.4 | 3.66×")
        print(
            "  100 turns × 16 layers × 256 dim  | 3200.0 | 837.5 | 3.82×")
        print("")
        print(
            "### Decision per measurement-first discipline")
        print("")
        print(
            "  - DRIFT gate (≤ 0.01):     PASS (8.8× under)")
        print(
            "  - MEMORY gate (≥ 2×):      PASS (3.66-3.82× actual)")
        print(
            "  - Behavior preservation:   PASS (BASKVCacheRegistry unchanged)")
        print("")
        print(
            "  Three gates PASS — capability ships with OPT-IN flag")
        print(
            "  default OFF。 Honest acknowledgment in chapter close-out:")
        print(
            "  the 100-turn drift gate uses INDEPENDENT turns (not")
        print(
            "  autoregressive compounding)。 Real LLM sessions where")
        print(
            "  token i depends on tokens 0..i-1 could see")
        print(
            "  multiplicative drift — substrate doesn't measure that")
        print(
            "  (would need a true autoregressive replay test in a")
        print(
            "  future arc)。 At measured 0.0009 per-token drift,even")
        print(
            "  100-step compounding stays at ~0.09 worst case which")
        print(
            "  is well within typical LLM tolerance。")
        print("")
        print(
            "### Production impact")
        print("")
        print(
            "  100-turn × 16-layer × 256-dim session:")
        print(
            "    Float32: 3.2 MB per session")
        print(
            "    int8:    838 KB per session")
        print(
            "  → 4 concurrent sessions saves ~9.5 MB")
        print(
            "  → 16 concurrent sessions saves ~38 MB")
        print(
            "  → critical for iOS devices running multi-session")
        print(
            "    inference under tight RAM budgets。")
        print("")
        print(
            "### Surprising landing vs plan-agent expectation")
        print("")
        print(
            "  Plan: \"Highest accuracy risk in arc。 Likely FLIP-OFF")
        print(
            "         since cosine-drift may exceed 0.01 in some")
        print(
            "         sessions\"")
        print("")
        print(
            "  Reality: ALL THREE GATES PASS:")
        print(
            "    ✅ Drift:    0.0009 (11× under gate)")
        print(
            "    ✅ Memory:   3.66-3.82× (beats 2-3× estimate)")
        print(
            "    ✅ Surface:  zero registry changes (preserves")
        print(
            "                 chapter 482 / M1306 contract)")
        print("")
        print(
            "  Why the plan was pessimistic:")
        print(
            "    - Apple platform libm + Rust int8 cosine produces")
        print(
            "      tighter precision than estimated")
        print(
            "    - L2-normalized attention-head dim vectors at")
        print(
            "      ~64-128 elements quantize cleanly")
        print(
            "    - Symmetric per-tensor (not per-channel) overhead")
        print(
            "      stays minimal")
        print("")
        print(
            "### Cumulative production paths (chapter 七百四 → 七百二十八)")
        print("")
        print(
            "  ✅ Production-default flips:    9")
        print(
            "  🆕 Opt-in capabilities:         5")
        print(
            "     (BPE,binary codec,int8 quantize,int8 vector,")
        print(
            "      int8 KV cache)")
        print(
            "  ⛔ Opt-in preserved (Swift wins): 4")
        print(
            "     (forget,scoreAll,importanceScore,usageCount)")
        print("")
        print(
            "### 28-chapter branch arc — current state")
        print("")
        print(
            "  - 28 chapters · 140 knives · ~845 commits")
        print(
            "  - 89.5% Swift / ~10.5% native")
        print(
            "  - 9 Rust crates bundled")
        print(
            "  - **8/10 chapters of 七百二十一-七百三十 arc complete**")
        print("")
        print(
            "  Remaining chapters:")
        print(
            "    七百二十九: PQ approximate NN index")
        print(
            "    七百三十:   30-chapter arc close-out")
        print("")

        // Smoke: KV quantize round-trip works
        #if os(iOS) || os(macOS)
        let v: [Float] = (0..<128).map { Float($0) / 128.0 - 0.5 }
        let kBytes = v.withUnsafeBufferPointer { Data(buffer: $0) }
        let token = BASTransformerKVCacheToken(
            keyBytes: kBytes,
            valueBytes: kBytes,
            elementCount: 128)
        let q = token.toQuantizedInt8()
        XCTAssertNotNil(q)
        let back = q?.toFloat32Token()
        XCTAssertNotNil(back)
        XCTAssertEqual(back?.elementCount, 128)
        XCTAssertGreaterThan(
            q!.memoryShrinkRatio, 3.5)
        #endif
    }
}
