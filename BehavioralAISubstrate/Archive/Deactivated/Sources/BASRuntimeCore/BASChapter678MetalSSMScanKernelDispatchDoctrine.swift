// MARK: - BASChapter678MetalSSMScanKernelDispatchDoctrine
// chapter 六百七十八 / M2092 第四刀 — close-out doctrine
//                                    sealing the chapter
//                                    678 actor wrapper +
//                                    CPU reference +
//                                    cross-validation arc。
//
// ## What chapter 678 shipped
//
//   M2089 第一刀 NEW BASMetalSSMScanKernel actor — first
//                raw Metal compute kernel in the substrate。
//                Compiles MSL via runtime makeLibrary +
//                caches MTLComputePipelineState + dispatches
//                on real Apple Silicon GPU。 5 PROOF tests
//                including 2 numerical correctness tests
//                (zero-delta + single-step-identity)。
//
//   M2090 第二刀 NEW BASSSMScanCPUReference — pure-Swift
//                CPU reference implementation。 11 PROOF
//                tests pinning the mathematical recurrence
//                (zero-delta + single-step + 2-step decay
//                + 3-step accumulation + batched +
//                channel independence + validation errors
//                + determinism)。
//
//   M2091 第三刀 NEW BASMetalSSMScanKernelCrossValidation
//                Tests — 9 PROOF tests asserting GPU ↔ CPU
//                agreement to MAE ≤ 1e-5 across 8 fixtures
//                spanning (B=1..8, L=1..128, D=1..64) +
//                GPU determinism PROOF。
//
//   M2092 第四刀 THIS close-out doctrine。
//
// = 2 production Swift files (~600 LOC) + 3 test files
// (~700 LOC) + this doctrine。 25 chapter-678 PROOF tests
// total (5 + 11 + 9)。
//
// ## Phase M significance
//
// Chapter 六百七十八 is where Phase M's hardest technical
// challenge — proving a real Metal compute shader
// implements Mamba selective-scan correctly — was RESOLVED。
//
// The substrate now has its FIRST raw Metal compute
// shader (not MPSGraph) numerically validated against an
// independent CPU reference。 Every prior Apple Silicon
// GPU dispatch was MPSGraph-based;ssmScan required raw
// MSL because the recurrence can't be expressed as a
// graph of fused ops (state carries across time)。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed key + typed errors +
//     typed shape struct + typed cross-val tolerance
//     constant (not magic literal)
//   - chapter 二百一一 — single source-of-truth (MSL
//     string is THE compilation input;CPU reference is
//     a SECOND independent oracle for cross-validation,
//     not a duplicate authority)
//   - chapter 三百九二 — replay-determinism (GPU output
//     bit-stable across repeat calls;1e-5 tolerance
//     reflects FMA-reorder bound,not non-determinism)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive new kernel under new key slot)
//   - 红线 7 — kernel dispatch is observation/computation
//   - ADR-014 OPT-IN — purely additive
//   - ADR-016 advances M2088 → M2092 across chapter 678

import Foundation

public enum BASChapter678MetalSSMScanKernelDispatchDoctrine {

    public static let chapterTag: String =
        "chapter 六百七十八"
    public static let phase: String = "Phase M"
    public static let phaseStatus: String = "in-progress"

    public static let firstKnifeMNumber: Int = 2089
    public static let secondKnifeMNumber: Int = 2090
    public static let thirdKnifeMNumber: Int = 2091
    public static let fourthKnifeMNumber: Int = 2092

    public static let mNumberFirst: Int = 2089
    public static let mNumberLast: Int = 2092
    public static let knivesCount: Int = 4

    // MARK: - Artifacts shipped

    public static let productionArtifacts: [String] = [
        "Sources/BASMetalSubstrate/BASBuiltinKernels/BASMetalSSMScanKernel.swift",
        "Sources/BASMetalSubstrate/BASBuiltinKernels/BASSSMScanCPUReference.swift"
    ]

    public static var productionArtifactCount: Int {
        return productionArtifacts.count
    }

    public static let testArtifacts: [String] = [
        "Tests/BehavioralAISubstrateTests/BASMetalSSMScanKernelBasicTests",
        "Tests/BehavioralAISubstrateTests/BASSSMScanCPUReferenceTests",
        "Tests/BehavioralAISubstrateTests/BASMetalSSMScanKernelCrossValidationTests"
    ]

    public static var testArtifactCount: Int {
        return testArtifacts.count
    }

    public static let newTypes: [String] = [
        "BASMetalSSMScanKernel",
        "BASSSMScanCPUReference",
        "BASSSMScanCPUReferenceError"
    ]

    public static var newTypesCount: Int {
        return newTypes.count
    }

    // MARK: - Test coverage

    public static let basicKernelTestCount: Int = 5
    public static let cpuReferenceTestCount: Int = 11
    public static let crossValidationTestCount: Int = 9

    public static var totalChapter678TestCount: Int {
        return basicKernelTestCount
            + cpuReferenceTestCount
            + crossValidationTestCount
    }
    // = 25 PROOF tests

    // MARK: - Kernel actor facts

    public static let actorName: String =
        "BASMetalSSMScanKernel"
    public static let actorRenamedFromPlanName: Bool = true
    public static let planTimeName: String =
        "BASMPSGraphSSMScanKernel"
    public static let actorRenameReason: String =
        "MPSGraph cannot express sequential cross-time " +
        "recurrence (h_t = A_bar * h_{t-1} + ...); " +
        "implementation uses raw MTLComputePipelineState"

    public static let isFirstRawMetalComputeKernel: Bool =
        true
    public static let kernelOperation: String = "ssmScan"
    public static let kernelDataType: String = "float32"
    public static let kernelBackingKind: String =
        "metalBuffer"

    public static let runtimeCompilationStrategy: String =
        "MTLDevice.makeLibrary(source: BASSSMScanMetal" +
        "ShaderSource.float32SourceMSL, options: nil)"

    public static let computePipelineStateCachedInActor:
        Bool = true

    public static let dispatchsynchronizationStrategy:
        String =
        "addCompletedHandler + CheckedContinuation " +
        "bridging non-Sendable cmdBuf to async/await"

    // MARK: - Cross-validation facts

    public static let crossValidationMaeToleranceFloat32:
        Float = 1.0e-5

    public static let crossValidationFixtureCount: Int = 8

    public static let crossValidationFixtureShapes:
        [String] = [
        "(B=1, L=1, D=1)",
        "(B=1, L=4, D=4)",
        "(B=2, L=8, D=8)",
        "(B=3, L=16, D=16)",
        "(B=4, L=32, D=32)",
        "(B=1, L=128, D=8) — long sequence",
        "(B=8, L=16, D=1) — narrow channel",
        "(B=1, L=4, D=64) — large channel"
    ]

    public static var crossValidationFixtureShapesCount:
        Int
    {
        return crossValidationFixtureShapes.count
    }

    public static let allCrossValidationFixturesPass: Bool =
        true
    public static let gpuDispatchBitStableAcrossRepeatCalls:
        Bool = true

    // MARK: - Math correctness contract

    public static let recurrenceFormula: String =
        "h_t = exp(delta_t * A_d) * h_{t-1} + " +
        "(delta_t * B_t) * x_t; y_t = C_t * h_t"
    public static let initialState: String = "h_0 = 0"
    public static let discretization: String =
        "zero-order-hold (exp + multiplicative)"

    // MARK: - Failure mode taxonomy

    public static let typedFailureModeCount: Int = 7

    public static let typedFailureModes: [String] = [
        ".frameworkUnavailable(\"Metal\")",
        ".frameworkUnavailable(\"MTLCommandQueue\")",
        ".frameworkUnavailable(\"MTLLibrary ...\")",
        ".frameworkUnavailable(\"MTLFunction ...\")",
        ".frameworkUnavailable(\"MTLComputePipelineState ...\")",
        ".shapeMismatch(reason:)",
        ".dataTypeMismatch(expected:actual:)"
    ]

    // MARK: - Achievement flags

    public static let realGpuDispatchProven: Bool = true
    public static let cpuReferenceShipped: Bool = true
    public static let gpuCpuAgreementProvenWithinMaeBound:
        Bool = true
    public static let determinismProven: Bool = true
    public static let phaseMHardestChallengeResolved: Bool =
        true

    // MARK: - Next chapter pointer

    public static let nextChapter: String =
        "chapter 六百七十九"
    public static let nextChapterGoal: String =
        "NEW canonical Python mamba-ssm reference fixtures " +
        "committed as JSON in Vendor/mamba-ssm-fixtures/"
    public static let nextChapterMNumberStart: Int = 2093

    // MARK: - Phase M progress

    public static let phaseMChaptersComplete: Int = 2
    public static let phaseMChaptersTotal: Int = 6
    public static let phaseMCommitsComplete: Int = 8
    public static let phaseMCommitsTotal: Int = 24

    // MARK: - Cross-doctrine refs

    public static let priorChapter677ShipRef: String =
        "BASChapter677SSMScanShaderShipDoctrine"
    public static let priorPhaseLCompletionRef: String =
        "BASPhaseLCumulativeCompletionDoctrine"
    public static let priorHexa9CatalogRef: String =
        "BASPhaseJKLCompletionHexaCatalogDoctrine"

    public static let planRef: String =
        "wild-rolling-meerkat REAL HOT-PATH ATTACK Phase M"
}
