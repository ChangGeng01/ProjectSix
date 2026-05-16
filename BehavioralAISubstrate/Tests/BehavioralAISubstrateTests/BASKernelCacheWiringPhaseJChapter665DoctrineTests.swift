// MARK: - BASKernelCacheWiringPhaseJChapter665DoctrineTests
// chapter 六百六十五 / M2039 — anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class BASKernelCacheWiringPhaseJChapter665DoctrineTests:
    XCTestCase
{
    typealias D = BASKernelCacheWiringPhaseJChapter665Doctrine

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百六十五")
    }
    func testPhase() { XCTAssertEqual(D.phase, "Phase J") }

    // 4-knife M-numbers
    func testFirstKnifeMNumber() {
        XCTAssertEqual(D.firstKnifeMNumber, 2037)
    }
    func testSecondKnifeMNumber() {
        XCTAssertEqual(D.secondKnifeMNumber, 2038)
    }
    func testThirdKnifeMNumber() {
        XCTAssertEqual(D.thirdKnifeMNumber, 2039)
    }
    func testFourthKnifeMNumber() {
        XCTAssertEqual(D.fourthKnifeMNumber, 2040)
    }

    // Kernels wired
    func testKernelsWiredInThisChapterCount() {
        XCTAssertEqual(D.kernelsWiredCount, 2)
        XCTAssertTrue(D.kernelsWiredInThisChapter
            .contains("BASMPSGraphRMSNormKernel"))
        XCTAssertTrue(D.kernelsWiredInThisChapter
            .contains("BASMPSGraphRotaryEmbeddingKernel"))
    }
    func testRmsNormProofTestCount() {
        XCTAssertEqual(D.rmsNormProofTestCount, 5)
    }
    func testRotaryEmbeddingProofTestCount() {
        XCTAssertEqual(D.rotaryEmbeddingProofTestCount, 4)
    }
    func testTotalProofTestsInThisChapter() {
        XCTAssertEqual(D.totalProofTestsInThisChapter, 9)
    }

    // Phase J progress
    func testPhaseJKernelsWiredAfterThisChapter() {
        XCTAssertEqual(D.phaseJKernelsWiredAfterThisChapter,
            2)
    }
    func testPhaseJKernelsTotal() {
        XCTAssertEqual(D.phaseJKernelsTotal, 6)
    }
    func testPhaseJKernelsRemainingAfterThisChapter() {
        XCTAssertEqual(D.phaseJKernelsRemainingAfterThisChapter,
            4)
    }
    func testPhaseJRemainingKernelsContainsFour() {
        XCTAssertEqual(D.phaseJRemainingKernels.count, 4)
        XCTAssertTrue(D.phaseJRemainingKernels.contains(
            "BASMPSGraphAttentionKernel"))
        XCTAssertTrue(D.phaseJRemainingKernels.contains(
            "BASMPSGraphSoftmaxKernel"))
        XCTAssertTrue(D.phaseJRemainingKernels.contains(
            "BASMPSGraphLayerNormKernel"))
        XCTAssertTrue(D.phaseJRemainingKernels.contains(
            "BASMPSGraphConv2DKernel"))
    }

    // Byte-equality preservation flags
    func testBothKernelsByteEqualityPreserved() {
        XCTAssertTrue(D.bothKernelsByteEqualityPreserved)
    }
    func testByteEqualityTestPattern() {
        XCTAssertEqual(D.byteEqualityTestPattern,
            "testCacheOn*IsByteEqualToCacheOff*")
    }
    func testSameWiringPatternAcrossKernels() {
        XCTAssertTrue(D.sameWiringPatternAcrossKernels)
    }
    func testCacheOffPathUnchangedFromBaselines() {
        XCTAssertTrue(D.cacheOffPathUnchangedFromBaselines)
    }
    func testCacheOnPathUsesExecutableRun() {
        XCTAssertTrue(D.cacheOnPathUsesExecutableRun)
    }

    // Cross-doctrine refs
    func testPriorChapter664Ref() {
        XCTAssertEqual(D.priorChapter664Ref,
            "BASMPSGraphExecutableCacheWiringDoctrine")
    }
    func testPriorM1297CacheDoctrine() {
        XCTAssertEqual(D.priorM1297CacheDoctrine,
            "BASMPSGraphExecutableCache (M1297)")
    }
    func testPhaseJGoal() {
        XCTAssertEqual(D.phaseJGoal,
            "Wire MPSGraph kernels to consult cache for compile-cost amortization across dispatches")
    }
    func testPhaseJCloseOutChapterTag() {
        XCTAssertEqual(D.phaseJCloseOutChapterTag,
            "chapter 六百六十七")
    }

    // Achievement flags
    func testByteEqualityPreserved() {
        XCTAssertTrue(D.byteEqualityPreserved)
    }
    func testPurelyAdditive() {
        XCTAssertTrue(D.purelyAdditive)
    }
    func testIsPlanResumptionSecondChapter() {
        XCTAssertTrue(D.isPlanResumptionSecondChapter)
    }
    func testIsPhaseJSecondChapter() {
        XCTAssertTrue(D.isPhaseJSecondChapter)
    }
    func testPreChapterTypedSurfaceCount() {
        XCTAssertEqual(D.preChapterTypedSurfaceCount, 205)
    }
    func testPostChapterTypedSurfaceCount() {
        XCTAssertEqual(D.postChapterTypedSurfaceCount, 206)
    }
}
