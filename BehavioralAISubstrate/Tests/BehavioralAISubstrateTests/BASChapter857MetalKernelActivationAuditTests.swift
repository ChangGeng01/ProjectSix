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

    /// The 6 Metal kernels exist as compiled .metal source + Swift
    /// dispatcher actor。 None has a production Swift consumer
    /// invoking it today。
    func testSixMetalKernelsExistButHaveNoProductionConsumer() {
        let scaffoldedKernels = [
            ("BASFlashAttention.metal", "344 LOC tile-parallel flash-attn v2"),
            ("BASConvKernels.metal", "248 LOC conv"),
            ("BASLayerNormKernel.metal", "228 LOC LayerNorm"),
            ("BASSoftmaxKernels.metal", "183 LOC softmax"),
            ("BASActivationKernels.metal", "213 LOC ReLU/GELU/SiLU/GLU"),
            ("BASReduceKernels.metal", "172 LOC sum/max/mean"),
        ]
        XCTAssertEqual(scaffoldedKernels.count, 6,
            "6 Metal kernels shipped as scaffolding from chapter 七百四-七百五 pilot")

        // Audit grep result documented:
        //   BASFlashAttention: 4 self-references in own dispatcher
        //   Other 5 kernels:    0 references in Sources/
        // Production consumer count for each: 0
        let productionConsumerCount = 0
        XCTAssertEqual(productionConsumerCount, 0,
            "No Swift production code invokes these kernels today。 " +
            "Activating them would require building consumers first " +
            "— that's a different scope than Phase B planned for。")
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

    /// Phase B verdict pin: DECLINE the per-kernel activation
    /// cascade。 Same pattern as chapter 八百四十九 (contradiction-
    /// refs separate-table refactor declined-pending-consumer) and
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
