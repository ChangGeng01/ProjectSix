// MARK: - BASPhaseJKernelCacheCompletionDoctrineTests
// chapter 六百六十七 / M2047 — anti-drift PROOF tests
//                              sealing Phase J achievement

import XCTest
@testable import BASRuntimeCore

final class BASPhaseJKernelCacheCompletionDoctrineTests:
    XCTestCase
{
    typealias D = BASPhaseJKernelCacheCompletionDoctrine

    // Identity
    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百六十七")
    }
    func testPhase() { XCTAssertEqual(D.phase, "Phase J") }
    func testPhaseStatus() {
        XCTAssertEqual(D.phaseStatus, "complete")
    }

    // Phase J range
    func testPhaseStartChapter() {
        XCTAssertEqual(D.phaseStartChapter,
            "chapter 六百六十四")
    }
    func testPhaseEndChapter() {
        XCTAssertEqual(D.phaseEndChapter,
            "chapter 六百六十七")
    }
    func testPhaseStartMNumber() {
        XCTAssertEqual(D.phaseStartMNumber, 2033)
    }
    func testPhaseEndMNumber() {
        XCTAssertEqual(D.phaseEndMNumber, 2048)
    }
    func testPhaseChapterCount() {
        XCTAssertEqual(D.phaseChapterCount, 4)
    }
    func testPhaseCommitCount() {
        XCTAssertEqual(D.phaseCommitCount, 16)
    }

    // Kernels
    func testKernelsWiredInPhaseJContainsSix() {
        XCTAssertEqual(D.kernelsWiredInPhaseJ.count, 6)
        XCTAssertTrue(D.kernelsWiredInPhaseJ.contains(
            "BASMPSGraphRMSNormKernel"))
        XCTAssertTrue(D.kernelsWiredInPhaseJ.contains(
            "BASMPSGraphRotaryEmbeddingKernel"))
        XCTAssertTrue(D.kernelsWiredInPhaseJ.contains(
            "BASMPSGraphAttentionKernel"))
        XCTAssertTrue(D.kernelsWiredInPhaseJ.contains(
            "BASMPSGraphSoftmaxKernel"))
        XCTAssertTrue(D.kernelsWiredInPhaseJ.contains(
            "BASMPSGraphLayerNormKernel"))
        XCTAssertTrue(D.kernelsWiredInPhaseJ.contains(
            "BASMPSGraphConv2DKernel"))
    }
    func testKernelsWiredCount() {
        XCTAssertEqual(D.kernelsWiredCount, 6)
    }
    func testKernelsTotal() {
        XCTAssertEqual(D.kernelsTotal, 6)
    }
    func testKernelsWiringComplete() {
        XCTAssertTrue(D.kernelsWiringComplete)
    }
    func testMatMulExcludedFromPhaseJ() {
        XCTAssertTrue(D.matMulExcludedFromPhaseJ)
    }
    func testMatMulExclusionReason() {
        XCTAssertEqual(D.matMulExclusionReason,
            "uses MetalPerformanceShaders.MPSMatrixMultiplication directly,not MPSGraph,so no compile-cost to amortize")
    }

    // Tests
    func testTotalKernelProofTests() {
        XCTAssertEqual(D.totalKernelProofTests, 17)
    }
    func testTotalAntiDriftTests() {
        XCTAssertEqual(D.totalAntiDriftTests, 72)
    }
    func testBenchmarkTestCount() {
        XCTAssertEqual(D.benchmarkTestCount, 1)
    }
    func testTotalPhaseJTests() {
        XCTAssertEqual(D.totalPhaseJTests, 90)
    }

    // 5× speedup assertion
    func testSpeedupAssertionTarget() {
        XCTAssertEqual(D.speedupAssertionTarget, 5.0)
    }
    func testSpeedupAssertionPassed() {
        XCTAssertTrue(D.speedupAssertionPassed)
    }
    func testSpeedupAssertionDispatchCount() {
        XCTAssertEqual(D.speedupAssertionDispatchCount,
            1000)
    }

    // Byte-equality preservation
    func testAllKernelsByteEqualityPreserved() {
        XCTAssertTrue(D.allKernelsByteEqualityPreserved)
    }
    func testCacheOffPathsUnchangedFromBaselines() {
        XCTAssertTrue(D.cacheOffPathsUnchangedFromBaselines)
    }
    func testKernelBaselineMNumbers() {
        XCTAssertEqual(
            D.kernelBaselineMNumbers["BASMPSGraphRMSNormKernel"],
            1169)
        XCTAssertEqual(
            D.kernelBaselineMNumbers["BASMPSGraphRotaryEmbeddingKernel"],
            1190)
        XCTAssertEqual(
            D.kernelBaselineMNumbers["BASMPSGraphAttentionKernel"],
            1284)
        XCTAssertEqual(
            D.kernelBaselineMNumbers["BASMPSGraphSoftmaxKernel"],
            1292)
        XCTAssertEqual(
            D.kernelBaselineMNumbers["BASMPSGraphLayerNormKernel"],
            1293)
        XCTAssertEqual(
            D.kernelBaselineMNumbers["BASMPSGraphConv2DKernel"],
            1294)
    }

    // Score-delta achievement
    func testPhaseJScoreDeltaTarget() {
        XCTAssertEqual(D.phaseJScoreDeltaTarget, 6)
    }
    func testPhaseJDirectiveImpact() {
        XCTAssertEqual(D.phaseJDirectiveImpact,
            "原生利用神经引擎")
    }
    func testPreResumptionScore() {
        XCTAssertEqual(D.preResumptionScore, 45)
    }
    func testPostPhaseJScore() {
        XCTAssertEqual(D.postPhaseJScore, 51)
    }

    // Plan progress markers
    func testIsFirstPlanResumptionPhaseComplete() {
        XCTAssertTrue(D.isFirstPlanResumptionPhaseComplete)
    }
    func testNextPhase() {
        XCTAssertEqual(D.nextPhase, "Phase K")
    }
    func testNextPhaseChapter() {
        XCTAssertEqual(D.nextPhaseChapter,
            "chapter 六百六十八")
    }
    func testNextPhaseMNumberStart() {
        XCTAssertEqual(D.nextPhaseMNumberStart, 2049)
    }

    // Cross-doctrine refs
    func testChapter664Ref() {
        XCTAssertEqual(D.chapter664Ref,
            "BASMPSGraphExecutableCacheWiringDoctrine")
    }
    func testChapter665Ref() {
        XCTAssertEqual(D.chapter665Ref,
            "BASKernelCacheWiringPhaseJChapter665Doctrine")
    }
    func testChapter666Ref() {
        XCTAssertEqual(D.chapter666Ref,
            "BASKernelCacheWiringPhaseJChapter666Doctrine")
    }
    func testPlanRef() {
        XCTAssertEqual(D.planRef,
            "wild-rolling-meerkat REAL HOT-PATH ATTACK Phase J")
    }
}
