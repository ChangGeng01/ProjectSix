// MARK: - BASKernelCacheWiringPhaseJChapter665Doctrine
// chapter 六百六十五 / M2039 — typed surface commemorating
//                              Phase J kernel wiring chapter
//                              665 (rmsNorm + rotary
//                              embedding wired to cache,
//                              byte-equality preserved)
//
// ## What this commemorates
//
// chapter 664 added the MPSGraphExecutable storage slot
// to BASMPSGraphExecutableCache (M2033)。 chapter 665
// wires the FIRST TWO of 6 MPSGraph kernels to consume
// the slot via the cache-on fast path:
//
//   - M2037 第一刀:BASMPSGraphRMSNormKernel
//     (5 PROOF tests including byte-equality)
//   - M2038 第二刀:BASMPSGraphRotaryEmbeddingKernel
//     (4 PROOF tests including byte-equality)
//
// Both kernels use the same wiring pattern:
//   1. init adds optional `cache:
//      BASMPSGraphExecutableCache?` parameter (default
//      nil for back-compat)
//   2. evaluate() branches:cache=nil falls through to
//      baseline graph.run path UNCHANGED;cache=non-nil
//      uses cache-on fast path
//   3. Cache-on path:cachedExecutable(forKey:) lookup,
//      on miss compile+store,run executable.run with
//      ordered inputs/results
//   4. Byte-equality verified between paths via paired
//      cache-off + cache-on tests
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved (both
//     cache=nil baseline AND cache-on fast-path produce
//     IDENTICAL outputs)
//   - 红线 7 — cache is hint,not authority
//   - chapter 三百九二 — replay-determinism preserved
//   - ADR-014 OPT-IN — purely additive (default nil)
//   - ADR-016 → M2039

import Foundation

public enum BASKernelCacheWiringPhaseJChapter665Doctrine {

    public static let chapterTag: String =
        "chapter 六百六十五"

    public static let phase: String = "Phase J"

    public static let firstKnifeMNumber: Int = 2037
    public static let secondKnifeMNumber: Int = 2038
    public static let thirdKnifeMNumber: Int = 2039
    public static let fourthKnifeMNumber: Int = 2040

    /// Kernels wired in this chapter (2 of 6 total in
    /// Phase J)。
    public static let kernelsWiredInThisChapter:
        [String] = [
        "BASMPSGraphRMSNormKernel",
        "BASMPSGraphRotaryEmbeddingKernel"
    ]

    public static var kernelsWiredCount: Int {
        return kernelsWiredInThisChapter.count
    }

    /// Per-kernel PROOF test count。
    public static let rmsNormProofTestCount: Int = 5
    public static let rotaryEmbeddingProofTestCount:
        Int = 4

    public static var totalProofTestsInThisChapter: Int {
        return rmsNormProofTestCount
            + rotaryEmbeddingProofTestCount
    }

    /// Total Phase J kernels wired AFTER this chapter
    /// close-out (2 of 6 done,4 to go in chapters 666-
    /// 667)。
    public static let phaseJKernelsWiredAfterThisChapter:
        Int = 2

    public static let phaseJKernelsTotal: Int = 6

    public static let phaseJKernelsRemainingAfterThisChapter:
        Int = 4

    /// Remaining 4 kernels target list (chapters 666-667
    /// will wire these)。
    public static let phaseJRemainingKernels:
        [String] = [
        "BASMPSGraphAttentionKernel",
        "BASMPSGraphSoftmaxKernel",
        "BASMPSGraphLayerNormKernel",
        "BASMPSGraphConv2DKernel"
    ]

    // MARK: - Byte-equality preservation flags

    /// Both kernels preserve byte-equality between
    /// cache-off (baseline) and cache-on (fast) paths。
    /// PROOF tests assert this directly。
    public static let bothKernelsByteEqualityPreserved:
        Bool = true

    /// Test method name pattern asserting byte-equality:
    /// `testCacheOnIsByteEqualToCacheOffBaseline` /
    /// `testCacheOnFastPathIsByteEqualToCacheOffBaseline`
    public static let byteEqualityTestPattern: String =
        "testCacheOn*IsByteEqualToCacheOff*"

    // MARK: - Pattern preservation

    /// Same wiring pattern applies to both kernels —
    /// init+cache param, evaluate branch, cache-on
    /// compile+run path。 chapter 二百一一 single source
    /// of truth pattern。
    public static let sameWiringPatternAcrossKernels:
        Bool = true

    /// Cache-off path UNCHANGED from M1169 (rmsNorm) and
    /// M1190 (rotaryEmbedding) baselines。 ADR-014 OPT-IN
    /// guarantee preserved。
    public static let cacheOffPathUnchangedFromBaselines:
        Bool = true

    /// Cache-on path uses MPSGraphExecutable +
    /// executable.run instead of graph.run。
    public static let cacheOnPathUsesExecutableRun:
        Bool = true

    // MARK: - Cross-doctrine refs

    public static let priorChapter664Ref: String =
        "BASMPSGraphExecutableCacheWiringDoctrine"

    public static let priorM1297CacheDoctrine: String =
        "BASMPSGraphExecutableCache (M1297)"

    public static let phaseJGoal: String =
        "Wire MPSGraph kernels to consult cache for compile-cost amortization across dispatches"

    public static let phaseJCloseOutChapterTag: String =
        "chapter 六百六十七"

    // MARK: - Achievement flags

    public static let byteEqualityPreserved: Bool = true
    public static let purelyAdditive: Bool = true
    public static let isPlanResumptionSecondChapter:
        Bool = true
    public static let isPhaseJSecondChapter: Bool = true

    public static let preChapterTypedSurfaceCount: Int = 205
    public static let postChapterTypedSurfaceCount: Int = 206
}
