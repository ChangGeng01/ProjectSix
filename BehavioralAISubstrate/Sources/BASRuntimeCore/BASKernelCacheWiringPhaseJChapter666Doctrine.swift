// MARK: - BASKernelCacheWiringPhaseJChapter666Doctrine
// chapter 六百六十六 / M2043 — typed surface commemorating
//                              Phase J ch666 cache wiring
//                              (attention + softmax +
//                              layerNorm — 3 more kernels)

import Foundation

public enum BASKernelCacheWiringPhaseJChapter666Doctrine {
    public static let chapterTag: String =
        "chapter 六百六十六"
    public static let phase: String = "Phase J"

    public static let firstKnifeMNumber: Int = 2041
    public static let secondKnifeMNumber: Int = 2042
    public static let thirdKnifeMNumber: Int = 2043
    public static let fourthKnifeMNumber: Int = 2044

    public static let kernelsWiredInThisChapter:
        [String] = [
        "BASMPSGraphAttentionKernel",
        "BASMPSGraphSoftmaxKernel",
        "BASMPSGraphLayerNormKernel"
    ]

    public static var kernelsWiredCount: Int {
        return kernelsWiredInThisChapter.count
    }

    public static let attentionProofTestCount: Int = 2
    public static let softmaxProofTestCount: Int = 2
    public static let layerNormProofTestCount: Int = 2

    public static var totalProofTestsInThisChapter: Int {
        return attentionProofTestCount
            + softmaxProofTestCount
            + layerNormProofTestCount
    }

    public static let phaseJKernelsWiredAfterThisChapter:
        Int = 5
    public static let phaseJKernelsTotal: Int = 6
    public static let phaseJKernelsRemainingAfterThisChapter:
        Int = 1

    public static let phaseJRemainingKernels: [String] = [
        "BASMPSGraphConv2DKernel"
    ]

    public static let bothByteEqualityAndCacheHitPreserved:
        Bool = true

    public static let priorChapter665Ref: String =
        "BASKernelCacheWiringPhaseJChapter665Doctrine"

    public static let phaseJCloseOutChapterTag: String =
        "chapter 六百六十七"

    public static let isPhaseJPenultimateChapter: Bool = true
}
