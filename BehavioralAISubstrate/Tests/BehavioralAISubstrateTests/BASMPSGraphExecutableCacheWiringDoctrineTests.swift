// MARK: - BASMPSGraphExecutableCacheWiringDoctrineTests
// chapter 六百六十四 / M2035 — anti-drift PROOF tests for
//                              the Phase J 第一刀 doctrine

import XCTest
@testable import BASRuntimeCore

final class BASMPSGraphExecutableCacheWiringDoctrineTests:
    XCTestCase
{
    typealias D = BASMPSGraphExecutableCacheWiringDoctrine

    // Identity
    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百六十四")
    }
    func testPhase() { XCTAssertEqual(D.phase, "Phase J") }
    func testPhaseGoal() {
        XCTAssertEqual(D.phaseGoal,
            "Wire MPSGraph kernels to consult cache for compile-cost amortization")
    }

    // 4-knife M-number pins
    func testFirstKnifeMNumber() {
        XCTAssertEqual(D.firstKnifeMNumber, 2033)
    }
    func testSecondKnifeMNumber() {
        XCTAssertEqual(D.secondKnifeMNumber, 2034)
    }
    func testThirdKnifeMNumber() {
        XCTAssertEqual(D.thirdKnifeMNumber, 2035)
    }
    func testFourthKnifeMNumber() {
        XCTAssertEqual(D.fourthKnifeMNumber, 2036)
    }

    // Storage-slot accessors
    func testNewAccessorNamesContainThree() {
        XCTAssertEqual(D.newAccessorNames.count, 3)
        XCTAssertTrue(D.newAccessorNames.contains(
            "cachedExecutable(forKey:)"))
        XCTAssertTrue(D.newAccessorNames.contains(
            "storeExecutable(_:forKey:)"))
        XCTAssertTrue(D.newAccessorNames.contains(
            "executableCount"))
    }
    func testNewAccessorCount() {
        XCTAssertEqual(D.newAccessorCount, 3)
    }

    // PROOF test count
    func testProofTestCount() {
        XCTAssertEqual(D.proofTestCount, 7)
    }

    // Kernel wiring scope
    func testMpsGraphKernelsContainsSix() {
        XCTAssertEqual(D.mpsGraphKernels.count, 6)
        XCTAssertTrue(D.mpsGraphKernels.contains(
            "BASMPSGraphRMSNormKernel"))
        XCTAssertTrue(D.mpsGraphKernels.contains(
            "BASMPSGraphRotaryEmbeddingKernel"))
        XCTAssertTrue(D.mpsGraphKernels.contains(
            "BASMPSGraphAttentionKernel"))
        XCTAssertTrue(D.mpsGraphKernels.contains(
            "BASMPSGraphSoftmaxKernel"))
        XCTAssertTrue(D.mpsGraphKernels.contains(
            "BASMPSGraphLayerNormKernel"))
        XCTAssertTrue(D.mpsGraphKernels.contains(
            "BASMPSGraphConv2DKernel"))
    }
    func testMpsGraphKernelCount() {
        XCTAssertEqual(D.mpsGraphKernelCount, 6)
    }
    func testMatMulExcludedFromCaching() {
        XCTAssertTrue(D.matMulExcludedFromCaching)
    }
    func testMatMulExclusionReason() {
        XCTAssertEqual(D.matMulExclusionReason,
            "uses MetalPerformanceShaders.MPSMatrixMultiplication directly,not MPSGraph")
    }

    // Phase J score-delta target
    func testPhaseJScoreDeltaTargetIsSix() {
        XCTAssertEqual(D.phaseJScoreDeltaTarget, 6)
    }
    func testPhaseJCloseOutChapterTag() {
        XCTAssertEqual(D.phaseJCloseOutChapterTag,
            "chapter 六百六十七")
    }
    func testSpeedupMultipleTarget() {
        XCTAssertEqual(D.speedupMultipleTarget, 5.0)
    }

    // Achievement flags
    func testStorageSlotAdded() {
        XCTAssertTrue(D.storageSlotAdded)
    }
    func testObservationSurfacePreserved() {
        XCTAssertTrue(D.observationSurfacePreserved)
    }
    func testByteEqualityPreserved() {
        XCTAssertTrue(D.byteEqualityPreserved)
    }
    func testPurelyAdditive() { XCTAssertTrue(D.purelyAdditive) }
    func testIsFirstPhaseJChapter() {
        XCTAssertTrue(D.isFirstPhaseJChapter)
    }
    func testIsPostHexaEightCatalogChapter() {
        XCTAssertTrue(D.isPostHexaEightCatalogChapter)
    }

    // Cross-doctrine refs
    func testPriorM1297Ref() {
        XCTAssertEqual(D.priorM1297CacheObservationDoctrineRef,
            "BASMPSGraphExecutableCache (M1297)")
    }
    func testPriorHexaCatalogRef() {
        XCTAssertEqual(D.priorHexaCatalogRef,
            "BASGapFillHexaEightCompletionDoctrine")
    }
    func testPlanRef() {
        XCTAssertEqual(D.planRef,
            "wild-rolling-meerkat REAL HOT-PATH ATTACK Phase J")
    }

    // Plan resumption marker
    func testIsPlanResumptionFirstChapter() {
        XCTAssertTrue(D.isPlanResumptionFirstChapter)
    }
    func testChaptersOfCodableGapFillDrift() {
        // chapters 478-663 inclusive = 186 chapters
        XCTAssertEqual(D.chaptersOfCodableGapFillDrift, 186)
    }
    func testResumptionAggregateScoreTarget() {
        XCTAssertEqual(D.resumptionAggregateScoreTarget, 60)
    }
    func testPreResumptionAggregateScore() {
        XCTAssertEqual(D.preResumptionAggregateScore, 45)
    }
}
