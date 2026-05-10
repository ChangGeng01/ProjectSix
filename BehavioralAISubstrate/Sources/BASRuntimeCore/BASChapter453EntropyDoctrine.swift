// MARK: - BASChapter453EntropyDoctrine — chapter 四百五十三 / M1191
// 系统熵 reduction
//
// **POST-SWEEP REAL EXECUTION** chapter — adds the 4th
// substrate-level transformer kernel (attention),
// closing the kernel quartet (matMul + rmsNorm +
// rotaryEmbedding + attention)。 Substrate now has
// every primitive a modern attention block needs。
//
// ## What this ships (M1188-M1191)
//
//   - **M1188** — Design BASAttentionKernel CPU
//     reference + BASMPSGraphAttentionKernel GPU
//     sibling。 No source change
//
//   - **M1189** — Two new files:
//     - `BASAttentionKernel` struct conforming to
//       BASMetalKernel with key
//       (attention, float32, cpuBytes)。 Scaled
//       dot-product attention CPU impl:
//         scores = Q · K^T / sqrt(dim)
//         attn   = softmax(scores) (row-wise with
//                  max-shift for numerical stability)
//         output = attn · V
//       Single-head;multihead = batched single-head
//     - `BASMPSGraphAttentionKernel` actor under key
//       (attention, float32, metalBuffer)。 MPSGraph
//       composition with transpose + matMul + softMax
//       + scale。 First MPSGraph composition that
//       includes softMax + matMul on real tensors
//
//   - **M1190** — 5 PROOF tests in
//     `BASAttentionKernelTests`:
//     - testCPUSingleTokenIsIdentity:single-token
//       attention degenerate case (softmax=[1.0])
//     - testCPUUniformKeyProducesUniformAttention:
//       identical K rows → uniform attn weights →
//       output is mean of V rows
//     - testCPUDominantKeyConcentrates:Q strongly
//       aligned with K[0] → attn ≈ [1, 0] → output
//       ≈ V[0]
//     - testGPUKernelConstructsOrSkips
//     - testGPUMatchesCPUAttention:GPU agrees with
//       CPU on 3-query, 5-key attention within 1e-4
//
//   - **M1191** — chapter 453 close-out + Phase 2
//     bump (chapter 50→51,mNumberLast 1187→1191,
//     commits 233→237) + ADR-016.M1187 → M1191
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed errors + typed key;
//     softmax scale derived from dim (sqrt(dim));
//     CPU softmax with max-shift numerical stability
//   - chapter 二百一一 — one attention kernel pair
//     (CPU + GPU) under typed keys
//   - chapter 三百九二 — replay-determinism (CPU
//     softmax via max-shift produces byte-stable
//     IEEE Float32;GPU agrees within 1e-4 tolerance)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//   - 红线 7 — observation/computation only
//   - ADR-014 OPT-IN — additive
//
// ## Significance — transformer kernel quartet complete
//
// 「原生利用神经引擎」 progress:3/3 → **4/4** (added
// attention to the matMul + rmsNorm + rotaryEmbedding
// triad)。 Substrate now has all 4 primitives a modern
// transformer attention block needs。 Future chapters
// can compose these into full transformer blocks via
// host-side BASAppleAdapters integration。

import Foundation

public enum BASChapter453EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百五十三"
    public static let mNumberFirst: Int = 1188
    public static let mNumberLast: Int = 1191

    public static let v1MilestoneMNumber: Int = 1191
    public static let v1MilestoneStatus: String =
        "chapter-453-v1-attention-quartet-complete"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1188, "第一刀",
            "Design BASAttentionKernel CPU + GPU." +
            " Scaled dot-product attention:scores =" +
            " Q·K^T/sqrt(D),attn = softmax(scores)," +
            " output = attn·V。 Single-head;multihead" +
            " = batched single-head"),
        (1189, "第二刀",
            "BASAttentionKernel (CPU,struct,struct" +
            " Sendable) + BASMPSGraphAttentionKernel" +
            " (GPU,actor)。 CPU softmax via row-wise" +
            " max-shift for numerical stability。 GPU" +
            " MPSGraph composition with transpose +" +
            " matMul + softMax + scale。 First MPSGraph" +
            " composition combining softMax + matMul" +
            " on real tensors"),
        (1190, "第三刀",
            "5 PROOF tests:CPU single-token identity" +
            " (softmax=[1.0]) + uniform-K produces" +
            " uniform attn + dominant-K concentrates" +
            " + GPU construction probe + GPU matches" +
            " CPU on 3×5 attention within 1e-4"),
        (1191, "第四刀",
            "chapter 453 close-out + Phase 2 bump" +
            " (commits 233 → 237,chapter count 50 → 51)" +
            " + ADR-016.M1187 → M1191 +" +
            " postSweepRealExecutionEntries entry。" +
            " 「原生利用神经引擎」 3/3 → 4/4 (transformer" +
            " kernel quartet complete)")
    ]

    public static let entropyClassesAttacked: [String] = [
        "no-attention-kernel-entropy",                // M1188
        "no-softmax-on-real-tensors-entropy",         // M1189
        "attention-numerical-unverified-entropy",     // M1190
        "doctrine-pin-entropy"                        // M1191
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7",
        "chapter 一百八十五",
        "chapter 二百一一",
        "chapter 三百九二",
        "ADR-014 OPT-IN preserved (additive kernels;" +
        " no existing path touched)",
        "ADR-016 (advanced M1187 → M1191)",
        "系统熵 reduction",
        "POST-SWEEP REAL EXECUTION chapter — transformer" +
        " kernel quartet complete (attention added)"
    ]

    public static let plannedFutureCuts: [String] = [
        "chapter 454:BASPlasticityFold (substrate-" +
        "level learning from outcomes)",
        "chapter 455:cross-turn state persistence" +
        " (Mamba + predictive-coding probe via event" +
        " log)",
        "chapter 456:wire BASPredictiveCodingProbe" +
        " into turn runtime",
        "chapter 457:multihead attention variant" +
        " (chapter 453 single-head extended with H" +
        " batched heads)",
        "chapter 458:flash-attention-style fused" +
        " softmax + matMul kernel for memory efficiency"
    ]

    public static let summary: String =
        "POST-SWEEP REAL EXECUTION chapter 453 adds" +
        " attention to the substrate kernel triad" +
        " (matMul + rmsNorm + rotaryEmbedding) →" +
        " QUARTET。 4 cuts (M1188-M1191):design + CPU" +
        " baseline + MPSGraph GPU sibling + 5 PROOF" +
        " tests + close-out。 CPU softmax with row-wise" +
        " max-shift numerical stability;GPU composes" +
        " transpose + matMul + softMax + scale in one" +
        " MPSGraph executable。 「原生利用神经引擎」 3/3" +
        " → 4/4 (substrate has every primitive a" +
        " modern transformer attention block needs)。" +
        " ADR-016 → M1191。 V1 byte-equality preserved。"
}
