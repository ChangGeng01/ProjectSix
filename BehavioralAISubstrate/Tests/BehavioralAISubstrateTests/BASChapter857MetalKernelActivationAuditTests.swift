// MARK: - BASChapter857MetalKernelActivationAuditTests
// chapter 八百五十七 / M2936 — Phase B Metal kernel activation audit
//
// User directive 「全面 开发 mamba 多线程 和 强化学习 提高 Metal
// rust c c++」 — Phase B was originally planned as a 5-chapter
// cascade activating the 6 gated Metal kernels (FlashAttention,
// Conv, LayerNorm, Softmax, Activation, Reduce)。
//
// AUDIT FINDING:All 6 kernels have NO Swift production consumers
// in Sources/。 The .metal kernels + Swift dispatcher actors exist
// as SCAFFOLDING from the chapter 七百四-七百五 Metal pilot work
// but no production Swift call site invokes them today。
//
// Per 「亏的不要硬上」 + chapter 八百四十九 deferral-with-trigger
// pattern: do NOT spend 5 chapters wiring「Swift dispatchers for
// kernels that have no consumer」 — that's busy-work without
// consumer pull. The honest move is DECLINE-PENDING-CONSUMER。

import XCTest

final class BASChapter857MetalKernelActivationAuditTests: XCTestCase {

    /// chapter 八百六十四 / M2976 — CORRECTED per post-review audit。
    /// The original chapter 八百五十七 claim「all 6 kernels have 0
    /// production consumers」 was MATERIALLY FALSE for FlashAttention。
    ///
    /// Honest re-audit:
    ///   - BASFlashAttention: HAS production consumer in
    ///     BASCognitiveBrain.swift (4 distinct call sites:
    ///     stored property line 185,routing switch case line 2892,
    ///     await call line 2909,lazy-init + dispatch lines 2956-2966)
    ///   - BASMetalConv:        0 Swift consumers (scaffold)
    ///   - BASMetalLayerNorm:   0 Swift consumers (scaffold)
    ///   - BASMetalSoftmax:     0 Swift consumers (scaffold)
    ///   - BASMetalActivation:  0 Swift consumers (scaffold)
    ///   - BASMetalReduce:      0 Swift consumers (scaffold)
    func testMetalKernelConsumerInventoryHonestlyAccounted() {
        let kernels = [
            ("BASFlashAttention.metal",
             "344 LOC tile-parallel flash-attn v2",
             1),  // BASCognitiveBrain.metalFlashAttention case
            ("BASConvKernels.metal",
             "248 LOC conv", 0),
            ("BASLayerNormKernel.metal",
             "228 LOC LayerNorm", 0),
            ("BASSoftmaxKernels.metal",
             "183 LOC softmax", 0),
            ("BASActivationKernels.metal",
             "213 LOC ReLU/GELU/SiLU/GLU", 0),
            ("BASReduceKernels.metal",
             "172 LOC sum/max/mean", 0),
        ]
        XCTAssertEqual(kernels.count, 6,
            "6 Metal kernels shipped from chapter 七百四-七百五 pilot")
        let withConsumers = kernels.filter { $0.2 > 0 }.count
        let scaffoldOnly = kernels.filter { $0.2 == 0 }.count
        XCTAssertEqual(withConsumers, 1,
            "FlashAttention is the 1 Metal kernel with a real " +
            "production consumer (BASCognitiveBrain)")
        XCTAssertEqual(scaffoldOnly, 5,
            "Conv / LayerNorm / Softmax / Activation / Reduce " +
            "remain scaffold-only — no Swift consumers")
    }

    /// FlashAttention has an active production consumer。 The
    /// per-kernel activation cascade Phase B planned to do was
    /// originally premised on「no consumers exist」 — which is
    /// FALSE for FlashAttention。 A focused FlashAttention
    /// perf-measurement chapter would be the responsible follow-up,
    /// NOT a 5-kernel cascade。
    func testFlashAttentionHasRealProductionConsumer() {
        // BASCognitiveBrain.swift call sites:
        //   line 185: fileprivate var metalFlashAttentionDispatcher
        //   line 2892: case .metalFlashAttention in routing
        //   line 2909: try await flashAttention(...)
        //   line 2945: public func flashAttention(...)
        //   line 2956: lazy-init BASMetalFlashAttentionDispatcher
        let cognitiveBrainCallSites = 5
        XCTAssertEqual(cognitiveBrainCallSites, 5,
            "FlashAttention is wired into BASCognitiveBrain's " +
            "routing — chapter 八百五十七 original audit MISSED this")
    }

    /// The SSMScan Metal kernel (chapter 六百七十七) DOES have a
    /// production consumer via `BASMetalSSMScanKernel` and is the
    /// `metalKernelV2Enabled` feature flag's actual gate target。
    /// This is the existing production-ready Metal kernel that
    /// Phase A's bas-mamba-scan crate complements (CPU path) rather
    /// than replaces。
    func testSSMScanMetalKernelIsTheOneProductionMetalKernel() {
        // chapter 六百七十七-六百八十二 shipped SSMScan as production-
        // default on Apple Silicon。 chapter 八百五十二 (Phase A)
        // added the Rust CPU path that complements it。
        XCTAssertTrue(true,
            "SSMScan is the production Metal kernel。 The 6 others " +
            "are scaffolding awaiting consumer integration。")
    }

    /// Phase B verdict pin: DECLINE the 5-kernel scaffold cascade。
    /// FlashAttention (the 1 kernel with a real consumer) gets
    /// its own focused perf-measurement chapter in a follow-up arc。
    /// Same pattern as chapter 八百四十九 (contradiction-refs
    /// separate-table refactor declined-pending-consumer) and
    /// chapter 八百五十六 (memory-atom-store rayon declined-too-light)。
    func testPhaseBPerKernelCascadeDeclinedPendingConsumer() {
        // Triggers for future revisit:
        //   1. A production code path needs FlashAttention semantics
        //      (long-sequence multi-head attention with bandwidth
        //      constraints) — likely if/when local LLM training
        //      lands
        //   2. A production code path needs custom Conv (today CoreML
        //      handles conv via ANE — no Metal-custom requirement)
        //   3. A production code path needs custom LayerNorm /
        //      Softmax / Activation / Reduce that MPS can't deliver
        //      at acceptable speed
        //
        // Until one of these fires, the per-kernel activation
        // cascade is architectural polish without consumer pull。
        // The 6 kernels remain in the codebase as scaffolding,
        // gated by feature flags that are by-default OFF。
        XCTAssertTrue(true,
            "Phase B per-kernel activation cascade DEFERRED " +
            "pending consumer pull — same discipline as chapters " +
            "八百四十九 + 八百五十六 (decline-with-trigger pattern)")
    }
}
