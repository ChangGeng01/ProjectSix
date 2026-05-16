// MARK: - BASMPSGraphKernelCoverageBundle
// chapter 四百七十七 / M1286 — second REAL BASBundle<Item>
// migration in the substrate (sibling of M1281
// BASKernelDispatchOutcomeBundle)。
//
// ## Why this exists (system entropy framing)
//
// M1281 shipped the FIRST real BASBundle<Item> typealias
// adoption in the substrate (BASKernelDispatchOutcomeBundle)。
// One adoption isn't enough to prove the pattern scales —
// it could be a one-off。 M1286 ships a SECOND adoption
// in a different domain (kernel correctness coverage
// rather than dispatch outcomes) to demonstrate the
// generic carries production payload across different
// use sites。
//
// `BASMPSGraphKernelCoverageBundle` aggregates evidence
// of MPSGraph kernel numerical-correctness PROOF tests:
//
//   - which kernel (typed BASNeuralOp)
//   - chapter where PROOF landed
//   - number of test cases
//
// Test fixtures + audit consumers can:
//
//   - Query coverage:"is matMul proven correct?"
//   - Detect regression:"did kernel-correctness drop
//     below 4-of-4 in any chapter?"
//   - Generate compliance reports for downstream
//     consumers wondering "which kernels are safe to
//     ship to production"
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed item struct
//   - chapter 二百一一 — single source-of-truth (one
//     coverage bundle aggregating kernel PROOF
//     status)
//   - chapter 三百九二 — Codable round-trip stable
//   - chapter 四百二十九 entropy class — second real
//     generic adoption (the pattern scales)
//   - ADR-014 OPT-IN — additive only
//   - 红线 7 — hint-only (coverage is observation)

import Foundation
import BASRuntimeCore

// MARK: - Typed item

/// One entry in a `BASMPSGraphKernelCoverageBundle` —
/// pins (kernel op + chapter + test count) for one
/// kernel's numerical-correctness PROOF status。
public struct BASMPSGraphKernelCoverageItem:
    Equatable, Hashable, Codable, Sendable
{

    /// The neural op the kernel implements。
    public let operation: BASNeuralOp

    /// Chapter where numerical-correctness PROOF
    /// landed (e.g. 477 for attention)。
    public let provenInChapter: Int

    /// M-number where PROOF landed (e.g. 1284 for
    /// BASMPSGraphAttentionIntegrationTests)。
    public let provenAtMNumber: Int

    /// Number of XCTestCase methods in the kernel's
    /// integration test class (chapter 一百八十五:
    /// numeric not magic-string)。
    public let testCaseCount: Int

    /// Whether the PROOF includes numerical correctness
    /// (vs construction-only assertions)。 True for
    /// all 4 chapter-475+ kernels。
    public let hasNumericalCorrectnessProof: Bool

    public init(
        operation: BASNeuralOp,
        provenInChapter: Int,
        provenAtMNumber: Int,
        testCaseCount: Int,
        hasNumericalCorrectnessProof: Bool
    ) {
        self.operation = operation
        self.provenInChapter = provenInChapter
        self.provenAtMNumber = provenAtMNumber
        self.testCaseCount = testCaseCount
        self.hasNumericalCorrectnessProof =
            hasNumericalCorrectnessProof
    }
}

// MARK: - Generic bundle alias

/// Second REAL adoption of `BASBundle<Item>` (M1088
/// generic) in the substrate after M1281。 Aggregates
/// MPSGraph kernel numerical-correctness PROOF coverage。
public typealias BASMPSGraphKernelCoverageBundle =
    BASBundle<BASMPSGraphKernelCoverageItem>

// MARK: - Convenience accessors

extension BASBundle
    where Item == BASMPSGraphKernelCoverageItem
{

    /// Count of items with numerical-correctness PROOF。
    public var provenCount: Int {
        items.filter {
            $0.hasNumericalCorrectnessProof
        }.count
    }

    /// Total test case count across all items in the
    /// bundle。 Used by quality dashboards reporting
    /// substrate coverage growth chapter-by-chapter。
    public var totalTestCaseCount: Int {
        items.reduce(0) { $0 + $1.testCaseCount }
    }

    /// Lookup coverage for a specific neural op,or
    /// nil if no PROOF exists yet。
    public func coverage(
        for op: BASNeuralOp
    ) -> BASMPSGraphKernelCoverageItem? {
        items.first { $0.operation == op }
    }
}

// MARK: - Chapter 四百七十七 / M1286 canonical bundle

/// Canonical coverage bundle at chapter 477 close-out。
/// Pins the 4-of-4 MPSGraph kernels with PROOF tests
/// (matMul / rmsNorm / rotaryEmbedding / attention)。
/// Future chapters extend this list when they prove
/// additional kernels。
public enum BASCanonicalKernelCoverage {

    /// Snapshot of MPSGraph kernel coverage at chapter
    /// 477 close-out (M1287)。
    public static let chapter477Snapshot:
        BASMPSGraphKernelCoverageBundle =
    BASMPSGraphKernelCoverageBundle(
        bundleID: "mpsgraph-coverage-chapter-477",
        schemaVersion: "1.0.0",
        items: [
            BASMPSGraphKernelCoverageItem(
                operation: .matMul,
                provenInChapter: 475,
                provenAtMNumber: 1277,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .rmsNorm,
                provenInChapter: 476,
                provenAtMNumber: 1280,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .rotaryEmbedding,
                provenInChapter: 476,
                provenAtMNumber: 1282,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .attention,
                provenInChapter: 477,
                provenAtMNumber: 1284,
                testCaseCount: 4,
                hasNumericalCorrectnessProof: true)
        ],
        metadata: [
            "coverage-target": "4-of-4-mpsgraph-kernels",
            "evaluation-doctrine":
                "BASRealHotPathAttackEvaluationDoctrine"
        ],
        recordedAt:
            Date(timeIntervalSince1970: 1_810_000_000))

    /// Snapshot of MPSGraph kernel coverage at chapter
    /// 496 close-out (M1363) — Tier 2 entry。
    ///
    /// 7 of 8 BASNeuralOp cases have native MPSGraph
    /// kernels with PROOF tests:
    ///   - matMul、rmsNorm、rotaryEmbedding、attention
    ///     (chapter 477)
    ///   - softmax、layerNorm、conv2D (chapter 479)
    ///
    /// 1 of 8 is stubbed at the protocol level with HONEST
    /// scope acknowledgment:
    ///   - ssmScan (chapter 496 — stub-identity-scan;
    ///     production requires external Metal shader OR
    ///     MLX bridge OR CoreML ML Program work scheduled
    ///     for Tier 2 phase K)
    public static let chapter496Snapshot:
        BASMPSGraphKernelCoverageBundle =
    BASMPSGraphKernelCoverageBundle(
        bundleID: "mpsgraph-coverage-chapter-496",
        schemaVersion: "1.0.0",
        items: [
            BASMPSGraphKernelCoverageItem(
                operation: .matMul,
                provenInChapter: 475,
                provenAtMNumber: 1277,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .rmsNorm,
                provenInChapter: 476,
                provenAtMNumber: 1280,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .rotaryEmbedding,
                provenInChapter: 476,
                provenAtMNumber: 1282,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .attention,
                provenInChapter: 477,
                provenAtMNumber: 1284,
                testCaseCount: 4,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .softmax,
                provenInChapter: 479,
                provenAtMNumber: 1292,
                testCaseCount: 4,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .layerNorm,
                provenInChapter: 479,
                provenAtMNumber: 1293,
                testCaseCount: 4,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .conv2D,
                provenInChapter: 479,
                provenAtMNumber: 1294,
                testCaseCount: 3,
                hasNumericalCorrectnessProof: true),
            // ssmScan — STUB ONLY at chapter 496。 PROOF
            // tests cover the stub's identity-scan +
            // typed contract;NUMERICAL correctness against
            // a reference Mamba implementation is NOT
            // proven (production Metal shader required —
            // Tier 2 phase K)。 hasNumericalCorrectness
            // Proof: false acknowledges this honestly。
            BASMPSGraphKernelCoverageItem(
                operation: .ssmScan,
                provenInChapter: 496,
                provenAtMNumber: 1361,
                testCaseCount: 7,
                hasNumericalCorrectnessProof: false)
        ],
        metadata: [
            "coverage-target":
                "7-of-8-native-plus-1-stub",
            "ssm-scan-status":
                "stub-identity-scan-tier-2-phase-K-deferred",
            "evaluation-doctrine":
                "BASRealHotPathAttackEvaluationDoctrine"
        ],
        recordedAt:
            Date(timeIntervalSince1970: 1_812_000_000))

    /// Snapshot of MPSGraph kernel coverage at chapter
    /// 六百八十一 / M2102 — 8-of-8 native coverage
    /// milestone post-Phase-M-stub-repurpose。
    ///
    /// All 8 BASNeuralOp cases now have native production-
    /// grade implementations with numerical correctness
    /// proof:
    ///   - matMul、rmsNorm、rotaryEmbedding、attention
    ///     (chapter 477)
    ///   - softmax、layerNorm、conv2D (chapter 479)
    ///   - ssmScan via real Metal compute shader
    ///     (chapter 678 / M2089) + CPU sibling
    ///     (chapter 681 / M2101) — 5 correctness oracles
    ///     proven (CPU↔GPU cross-val + CPU↔analytic +
    ///     GPU↔analytic + extended-fixture cross-val +
    ///     numerical-stability cross-val)
    public static let chapter681Snapshot:
        BASMPSGraphKernelCoverageBundle =
    BASMPSGraphKernelCoverageBundle(
        bundleID: "mpsgraph-coverage-chapter-681",
        schemaVersion: "1.0.0",
        items: [
            BASMPSGraphKernelCoverageItem(
                operation: .matMul,
                provenInChapter: 475,
                provenAtMNumber: 1277,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .rmsNorm,
                provenInChapter: 476,
                provenAtMNumber: 1280,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .rotaryEmbedding,
                provenInChapter: 476,
                provenAtMNumber: 1282,
                testCaseCount: 5,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .attention,
                provenInChapter: 477,
                provenAtMNumber: 1284,
                testCaseCount: 4,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .softmax,
                provenInChapter: 479,
                provenAtMNumber: 1292,
                testCaseCount: 4,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .layerNorm,
                provenInChapter: 479,
                provenAtMNumber: 1293,
                testCaseCount: 4,
                hasNumericalCorrectnessProof: true),
            BASMPSGraphKernelCoverageItem(
                operation: .conv2D,
                provenInChapter: 479,
                provenAtMNumber: 1294,
                testCaseCount: 3,
                hasNumericalCorrectnessProof: true),
            // ssmScan — chapter 678 / M2089 shipped REAL
            // Metal compute kernel + chapter 679-680
            // fixture validation + chapter 681 / M2101
            // CPU sibling repurpose。 39 PROOF tests
            // covering the kernel:5 basic + 11 CPU ref
            // + 9 cross-val + 14 fixture-validation。
            BASMPSGraphKernelCoverageItem(
                operation: .ssmScan,
                provenInChapter: 678,
                provenAtMNumber: 2089,
                testCaseCount: 39,
                hasNumericalCorrectnessProof: true)
        ],
        metadata: [
            "coverage-target":
                "8-of-8-native",
            "ssm-scan-status":
                "metal-shader-production-plus-cpu-sibling",
            "ssm-scan-gpu-impl":
                "BASMetalSSMScanKernel (chapter 678 / M2089)",
            "ssm-scan-cpu-impl":
                "BASCPUSSMScanKernel (chapter 681 / M2101)",
            "ssm-scan-correctness-oracle-count":
                "5",
            "evaluation-doctrine":
                "BASRealHotPathAttackEvaluationDoctrine"
        ],
        recordedAt:
            Date(timeIntervalSince1970: 1_820_000_000))
}
