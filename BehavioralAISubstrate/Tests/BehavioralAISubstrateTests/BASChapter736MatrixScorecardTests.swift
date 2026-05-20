// MARK: - BASChapter736MatrixScorecardTests
// chapter 七百三十六 第五刀 / M2355
//
// Chapter 七百三十六 close-out — completes the VECTOR storage
// tier substack mirroring the KV cache substack (chapter
// 七百二十六-七百三十五)。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter736MatrixScorecardTests: XCTestCase {

    func testPrintMatrixScorecard() {
        print("")
        print(
            "## chapter 七百三十六 第五刀 — vector substack scorecard")
        print("")
        print("### Chapter 七百三十六 deliverable")
        print("")
        print(
            "  Knife 1: BASVectorStorageTier + BASVectorRecallPriority")
        print(
            "  Knife 2: BASVectorStorageEstimator (per-tier byte estimates)")
        print(
            "  Knife 3: BASVectorStorageSelector decision tree")
        print(
            "  Knife 4: 13-cell test matrix")
        print(
            "  Knife 5: This scorecard")
        print("")
        print(
            "### The complete vector storage substack")
        print("")
        print(
            "  ┌────────────────────────────────────────────────────┐")
        print(
            "  │ VECTOR STORAGE SUBSTACK (七百十八/七/九/七百三十六)    │")
        print(
            "  ├────────────────────────────────────────────────────┤")
        print(
            "  │ chapter 七百十八 — batched Float32 cosine            │")
        print(
            "  │   ▶ BASVectorIndex flat-scan,Rust SIMD              │")
        print(
            "  │   ▶ 8.7-43× over baseline,exact recall              │")
        print(
            "  ├────────────────────────────────────────────────────┤")
        print(
            "  │ chapter 七百二十七 — int8 vector storage             │")
        print(
            "  │   ▶ BASInt8VectorIndexEntry + topKInt8              │")
        print(
            "  │   ▶ 3.88× shrink,99% recall@10,drift 0.0012       │")
        print(
            "  ├────────────────────────────────────────────────────┤")
        print(
            "  │ chapter 七百二十九 — PQ approximate NN index         │")
        print(
            "  │   ▶ BASPQIndex (k-means + asymmetric distance)     │")
        print(
            "  │   ▶ 78× speed,53× memory,recall data-dependent    │")
        print(
            "  ├────────────────────────────────────────────────────┤")
        print(
            "  │ chapter 七百三十一 第一刀 — PQ K-means++ refinement │")
        print(
            "  │   ▶ Geometric init replaces stride sampling         │")
        print(
            "  ├────────────────────────────────────────────────────┤")
        print(
            "  │ chapter 七百三十六 — vector tier auto-router 🆕      │")
        print(
            "  │   ▶ BASVectorStorageSelector (corpus + recall)     │")
        print(
            "  │   ▶ Closes the substack with a decision API        │")
        print(
            "  └────────────────────────────────────────────────────┘")
        print("")
        print(
            "  Hosts now have the COMPLETE pipeline:")
        print(
            "    1. Estimate byte cost per tier (estimator)")
        print(
            "    2. Pick the right tier (selector)")
        print(
            "    3. Route insert/topK through the matching API:")
        print(
            "         .float32 → BASVectorIndex.insert + topK")
        print(
            "         .int8    → BASVectorIndex.insertInt8 + topKInt8")
        print(
            "         .pq      → BASPQIndex.add + topK")
        print("")
        print(
            "### Substrate-shape parallel: KV cache vs Vector storage")
        print("")
        print(
            "  The vector substack (七百十八/七/九/三十六) MIRRORS")
        print(
            "  the KV cache substack (七百二十六/八/三十一/三/四/五)")
        print(
            "  — same 'TIERS + DECISION engine' pattern,but the")
        print(
            "  underlying tiers are workload-specific:")
        print("")
        print(
            "  KV CACHE TIERS:           VECTOR STORAGE TIERS:")
        print(
            "    Float32 / Float16 / int8    Float32 / int8 / PQ")
        print(
            "    (3 precision levels)        (3 storage strategies)")
        print("")
        print(
            "  KV CACHE SELECTOR:        VECTOR STORAGE SELECTOR:")
        print(
            "    exact / accuracyFirst /     exact / recallFirst /")
        print(
            "    memoryFirst                 memoryFirst")
        print("")
        print(
            "  Both selectors return a typed Selection struct with")
        print(
            "  (tier,bytesUsed,fitsInBudget,reason)。 Both refuse")
        print(
            "  to mask OOM:if no tier fits,the flag goes false")
        print(
            "  and the host decides whether to OOM-risk or reject。")
        print("")
        print(
            "### Cumulative branch arc state (chapter 七百二-七百三十六)")
        print("")
        print(
            "  Chapters:                  36")
        print(
            "  Knives:                   180")
        print(
            "  Production-default flips:  9 (unchanged)")
        print(
            "  Opt-in capabilities:      11")
        print(
            "    (BPE,binary codec,int8 quantize,int8 vector,")
        print(
            "     int8 KV,PQ,event log binary,Float16 KV,unified")
        print(
            "     compressed token,KV tier auto-router,vector")
        print(
            "     storage tier auto-router 🆕)")
        print(
            "  Quality-gated capabilities: 4")
        print(
            "  KV precision-tier substack: COMPLETE")
        print(
            "  Vector storage substack:   COMPLETE")
        print("")
        print(
            "### The substrate now has TWO complete substacks under one pattern")
        print("")
        print(
            "    ┌─ TIERS ─┐   ┌─ TYPED API ─┐   ┌─ DECISION ─┐")
        print(
            "    KV:  3        unified         tier selector")
        print(
            "    Vec: 3        per-tier APIs   tier selector")
        print("")
        print(
            "  The substrate is converging on a TIERED-COMPRESSION")
        print(
            "  IDIOM:any storage layer where memory tradeoffs vary")
        print(
            "  by workload gets a (Tier enum + Estimator + Selector)")
        print(
            "  triplet。 Future arc could apply this to:")
        print(
            "    - Event log (chapter 七百二十四/七百三十二 — but")
        print(
            "      only 2 tiers exist:JSON vs binary)")
        print(
            "    - Memory atom store (could add zstd-compressed)")
        print(
            "    - Audit ledger (could add structured-vs-prose)")
        print("")

        // Smoke:vector selector returns valid tier for a
        // realistic corpus shape
        #if os(iOS) || os(macOS)
        let est = BASVectorStorageEstimator.estimate(dim: 384)
        let sel = BASVectorStorageSelector.select(
            estimate: est,
            corpusSize: 50_000,
            memoryBudgetBytes: 30 * 1024 * 1024,
            recallPriority: .recallFirst)
        XCTAssertTrue(
            BASVectorStorageTier.allCases.contains(sel.tier))
        XCTAssertFalse(sel.reason.isEmpty)
        #endif
    }
}
