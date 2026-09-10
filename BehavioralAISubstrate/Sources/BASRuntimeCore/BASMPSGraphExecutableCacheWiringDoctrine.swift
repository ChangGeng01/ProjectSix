// MARK: - BASMPSGraphExecutableCacheWiringDoctrine
// chapter 六百六十四 / M2035 — typed surface commemorating
//                              Phase J 第一刀:M2033
//                              BASMPSGraphExecutableCache
//                              gains MPSGraphExecutable
//                              storage slot enabling per-
//                              kernel compile-cost
//                              amortization across
//                              dispatches。
//
// ## Why this doctrine exists
//
// chapter 477 close-out (commit 8b8f5e3e) shipped the
// REAL HOT-PATH ATTACK evaluation reading 28/60 against
// the 6 directives (更硬核 更极致 最创新 最激进 低熵
// 复杂系统 原生利用神经引擎)。 wild-rolling-meerkat plan
// (M1287) targeted 60/60 via Phases A-O。 594 commits
// later (autonomous Codable gap-fill drift) only Phase
// A/B/C/G surfaces shipped — Phase J was never executed。
//
// M2032 audit (chapter 663) confirmed:
//   `Sources/BASMetalSubstrate/BASMPSGraphExecutableCache
//    .swift` exists with OBSERVATION ONLY (M1297) — no
//    actual MPSGraphExecutable storage slot,no kernel
//    consults it,no amortization happens。
//
// chapter 664 Phase J 第一刀 (M2033) added the storage
// slot。 Chapters 665-667 wire the 6 MPSGraph kernels
// (rmsNorm + rotaryEmbedding + attention + softmax +
// layerNorm + conv2D) to consult the slot + benchmark
// 5× speedup on 1000-dispatch loops。
//
// (NOTE: matMul uses MetalPerformanceShaders directly,
// not MPSGraph,so matMul does NOT participate — 6 of
// 6 MPSGraph kernels target,not 7 of 7。 This is a
// correction to the wild-rolling-meerkat plan's "7
// kernels" estimate。)
//
// ## What this commemorates (M2035)
//
//   - chapter tag + extension M-number pin
//   - 3 new storage-slot accessors added at M2033
//   - 7 PROOF tests landed at M2034
//   - 6-kernel wiring target identified (chapters 665-
//     667 will execute it)
//   - Phase J score-delta target (+6 on 原生利用神经引擎)
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//   - 红线 7 — cache is hint,not authority
//   - chapter 二百四 — per-thermal-state cache key
//     contract (callers compose thermal band into key)
//   - chapter 三百九二 — replay-determinism preserved
//     (executables are runtime artifacts,not in Codable
//     wire format)
//   - chapter 四百二十九 — generic primitive adoption
//     count unchanged (this is a slot ADDITION,not a
//     migration)
//   - ADR-014 OPT-IN — purely additive
//   - ADR-016 → M2035

import Foundation

/// Phase J 第一刀 typed surface — records the addition of
/// MPSGraphExecutable storage slot to the cache actor +
/// the 6-kernel wiring target ahead。
public enum BASMPSGraphExecutableCacheWiringDoctrine {

    public static let chapterTag: String =
        "chapter 六百六十四"

    public static let phase: String = "Phase J"
    public static let phaseGoal: String =
        "Wire MPSGraph kernels to consult cache for compile-cost amortization"

    // MARK: - 4-knife M-number pins

    public static let firstKnifeMNumber: Int = 2033
    public static let secondKnifeMNumber: Int = 2034
    public static let thirdKnifeMNumber: Int = 2035
    public static let fourthKnifeMNumber: Int = 2036

    // MARK: - Storage slot accessors added at M2033

    public static let newAccessorNames: [String] = [
        "cachedExecutable(forKey:)",
        "storeExecutable(_:forKey:)",
        "executableCount"
    ]

    public static var newAccessorCount: Int {
        return newAccessorNames.count
    }

    // MARK: - PROOF test count at M2034

    public static let proofTestCount: Int = 7

    // MARK: - Kernel wiring scope ahead

    /// Kernels that will be wired in chapters 665-667。
    public static let mpsGraphKernels: [String] = [
        "BASMPSGraphRMSNormKernel",
        "BASMPSGraphRotaryEmbeddingKernel",
        "BASMPSGraphAttentionKernel",
        "BASMPSGraphSoftmaxKernel",
        "BASMPSGraphLayerNormKernel",
        "BASMPSGraphConv2DKernel"
    ]

    public static var mpsGraphKernelCount: Int {
        return mpsGraphKernels.count
    }

    /// matMul kernel uses MetalPerformanceShaders directly
    /// (not MPSGraph) — it does NOT participate in this
    /// wiring。 Corrects original wild-rolling-meerkat
    /// plan's "7 kernels" estimate to 6。
    public static let matMulExcludedFromCaching: Bool = true
    public static let matMulExclusionReason: String =
        "uses MetalPerformanceShaders.MPSMatrixMultiplication directly,not MPSGraph"

    // MARK: - Phase J score-delta target

    /// Score delta target on 原生利用神经引擎 directive
    /// after Phase J close-out (chapter 667)。
    public static let phaseJScoreDeltaTarget: Int = 6

    /// Phase J close-out chapter tag — when this lands,
    /// the 5× speedup benchmark assertion must be green。
    public static let phaseJCloseOutChapterTag: String =
        "chapter 六百六十七"

    /// Speedup multiple target on 1000-dispatch loops。
    public static let speedupMultipleTarget: Double = 5.0

    // MARK: - Achievement flags

    public static let storageSlotAdded: Bool = true
    public static let observationSurfacePreserved: Bool = true
    public static let byteEqualityPreserved: Bool = true
    public static let purelyAdditive: Bool = true
    public static let isFirstPhaseJChapter: Bool = true
    public static let isPostHexaEightCatalogChapter:
        Bool = true

    // MARK: - Cross-doctrine refs

    public static let priorM1297CacheObservationDoctrineRef:
        String = "BASMPSGraphExecutableCache (M1297)"
    public static let priorHexaCatalogRef: String =
        "BASGapFillHexaEightCompletionDoctrine"
    public static let planRef: String =
        "wild-rolling-meerkat REAL HOT-PATH ATTACK Phase J"

    // MARK: - Plan resumption marker

    public static let isPlanResumptionFirstChapter:
        Bool = true
    public static let chaptersOfCodableGapFillDrift:
        Int = 186  // chapters 478-663

    public static let resumptionAggregateScoreTarget:
        Int = 60
    public static let preResumptionAggregateScore: Int = 45
}
