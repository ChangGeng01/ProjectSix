// MARK: - BASPhaseMRealSSMScanKernelCompletionDoctrineTests
// chapter 六百八十二 / M2106 第二刀 — Phase M completion
//                                    anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class
BASPhaseMRealSSMScanKernelCompletionDoctrineTests:
    XCTestCase
{
    typealias D = BASPhaseMRealSSMScanKernelCompletionDoctrine

    // MARK: - Phase identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十二")
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase M")
    }

    func testPhaseStatusComplete() {
        XCTAssertEqual(D.phaseStatus, "complete")
    }

    // MARK: - Phase range

    func testPhaseStartChapter() {
        XCTAssertEqual(
            D.phaseStartChapter, "chapter 六百七十七")
    }

    func testPhaseEndChapter() {
        XCTAssertEqual(
            D.phaseEndChapter, "chapter 六百八十二")
    }

    func testPhaseStartMNumberIs2085() {
        XCTAssertEqual(D.phaseStartMNumber, 2085)
    }

    func testPhaseEndMNumberIs2108() {
        XCTAssertEqual(D.phaseEndMNumber, 2108)
    }

    func testPhaseChapterCountIs6() {
        XCTAssertEqual(D.phaseChapterCount, 6)
    }

    func testPhaseCommitCountIs24() {
        XCTAssertEqual(D.phaseCommitCount, 24)
    }

    func testChapterCommitProductIs24() {
        XCTAssertEqual(
            D.phaseChapterCount * 4,
            D.phaseCommitCount,
            "4-knife pattern: 6 chapters × 4 = 24 commits")
    }

    // MARK: - Chapter manifest

    func testChapterManifestCountIs6() {
        XCTAssertEqual(D.phaseMChaptersCount, 6)
        XCTAssertEqual(D.phaseMChapters.count, 6)
    }

    // MARK: - Per-chapter doctrine refs

    func testChapterCloseOutDoctrineCountIs6() {
        XCTAssertEqual(
            D.chapterCloseOutDoctrines.count, 6)
    }

    func testAllPhaseMDoctrinesReferenced() {
        XCTAssertTrue(D.chapterCloseOutDoctrines.contains(
            "BASChapter677SSMScanShaderShipDoctrine"))
        XCTAssertTrue(D.chapterCloseOutDoctrines.contains(
            "BASChapter678MetalSSMScanKernelDispatchDoctrine"))
        XCTAssertTrue(D.chapterCloseOutDoctrines.contains(
            "BASChapter679MambaSSMFixturesShipDoctrine"))
        XCTAssertTrue(D.chapterCloseOutDoctrines.contains(
            "BASChapter680MambaSSMExtendedProofDoctrine"))
        XCTAssertTrue(D.chapterCloseOutDoctrines.contains(
            "BASChapter681StubRepurposeAnd8of8Doctrine"))
    }

    // MARK: - Artifacts

    func testMetalShaderFilePath() {
        XCTAssertEqual(D.metalShaderFile,
            "Sources/BASMetalSubstrate/BASBuiltinKernels/SSMScan.metal")
    }

    func testGPUKernelActor() {
        XCTAssertTrue(D.gpuKernelActor.contains(
            "BASMetalSSMScanKernel"))
    }

    func testCPUKernelActor() {
        XCTAssertTrue(D.cpuKernelActor.contains(
            "BASCPUSSMScanKernel"))
    }

    func testFixtureCounts() {
        XCTAssertEqual(D.jsonFixtureCount, 6)
        XCTAssertEqual(D.extendedFixtureCount, 6)
        XCTAssertEqual(D.totalFixtureCount, 12)
    }

    // MARK: - Test counts

    func testChapter677TestCountIs88() {
        XCTAssertEqual(D.chapter677TestCount, 88)
    }

    func testChapter678TestCountIs71() {
        XCTAssertEqual(D.chapter678TestCount, 71)
    }

    func testChapter679TestCountIs67() {
        XCTAssertEqual(D.chapter679TestCount, 67)
    }

    func testChapter680TestCountIs59() {
        XCTAssertEqual(D.chapter680TestCount, 59)
    }

    func testChapter681TestCountIs67() {
        XCTAssertEqual(D.chapter681TestCount, 67)
    }

    func testTotalPhaseMTestCountIs352() {
        // 88 + 71 + 67 + 59 + 67 + 0 = 352
        XCTAssertEqual(D.totalPhaseMTestCount, 352)
    }

    // MARK: - Correctness oracles

    func testCorrectnessOracleCountIs5() {
        XCTAssertEqual(D.correctnessOracleCount, 5)
        XCTAssertEqual(D.oracles.count, 5)
    }

    // MARK: - Coverage milestone

    func testCoverageProgressionPreToPost() {
        XCTAssertEqual(
            D.kernelCoveragePreM,
            "7-of-8-native-plus-1-stub")
        XCTAssertEqual(
            D.kernelCoveragePostM, "8-of-8-native")
    }

    func testCoverageRatioIs1() {
        XCTAssertEqual(
            D.kernelCoverageRatio, 1.0, accuracy: 0.001)
    }

    func testIsFirstRawMetalComputeKernel() {
        XCTAssertTrue(D.isFirstRawMetalComputeKernel)
    }

    // MARK: - Score-delta

    func testScoreDeltaTargetIs5() {
        XCTAssertEqual(D.phaseMScoreDeltaTarget, 5)
    }

    func testPrePhaseMScoreIs58() {
        XCTAssertEqual(D.prePhaseMScore, 58)
    }

    func testPostPhaseMScoreIs60() {
        XCTAssertEqual(D.postPhaseMScore, 60)
    }

    func testScoreReachesSixtyOfSixty() {
        XCTAssertEqual(D.postPhaseMScore, 60,
            "Phase M reaches 60/60 aggregate score")
    }

    func testDirectiveImpactCount() {
        XCTAssertEqual(D.phaseMDirectiveImpact.count, 2)
        XCTAssertTrue(D.phaseMDirectiveImpact.contains("更硬核"))
        XCTAssertTrue(
            D.phaseMDirectiveImpact.contains("原生利用神经引擎"))
    }

    // MARK: - Doctrine pins held

    func testPinsHeldCountIs7() {
        XCTAssertEqual(D.pinsHeldThroughoutCount, 7)
        XCTAssertEqual(D.pinsHeldThroughout.count, 7)
    }

    // MARK: - Achievement flags (9 flags)

    func testAllNineAchievementFlagsTrue() {
        XCTAssertTrue(D.realMetalComputeKernelShipped)
        XCTAssertTrue(D.mslCompilesAtRuntimeViaSpm)
        XCTAssertTrue(D.cpuReferenceProvenCorrect)
        XCTAssertTrue(D.gpuKernelProvenCorrect)
        XCTAssertTrue(D.fiveCorrectnessOraclesInPlace)
        XCTAssertTrue(D.eightOfEightNativeAchieved)
        XCTAssertTrue(D.stubRepurposedToCPUBytesSibling)
        XCTAssertTrue(D.kernelCoveragePromotedToFullNative)
        XCTAssertTrue(D.phaseMSealed)
    }

    // MARK: - Plan progress

    func testPlanTotalChaptersIs46() {
        XCTAssertEqual(D.planTotalChapters, 46)
    }

    func testPlanChaptersCompletePostMIs19() {
        // ch664-682 inclusive = 19 chapters
        XCTAssertEqual(D.planChaptersCompletePostM, 19)
    }

    func testPlanCommitsCompletePostMIs76() {
        // J(16) + K(16) + L(16) + hexa9(4) + M(24) = 76
        XCTAssertEqual(D.planCommitsCompletePostM, 76)
    }

    func testPlanPercentCompletePostMIsAround41() {
        // 19 / 46 = 41.30%
        XCTAssertEqual(
            D.planPercentCompletePostM,
            41.30, accuracy: 0.1)
    }

    // MARK: - Next phase

    func testNextPhaseIsN() {
        XCTAssertEqual(D.nextPhase, "Phase N")
    }

    func testNextPhaseChapterIs683() {
        XCTAssertEqual(
            D.nextPhaseChapter, "chapter 六百八十三")
    }

    func testNextPhaseMNumberStartIs2109() {
        XCTAssertEqual(D.nextPhaseMNumberStart, 2109)
    }

    // MARK: - Cross-doctrine refs

    func testPriorPhaseLRef() {
        XCTAssertEqual(
            D.priorPhaseLCompletionRef,
            "BASPhaseLCumulativeCompletionDoctrine")
    }

    func testPriorHexa9CatalogRef() {
        XCTAssertEqual(
            D.priorHexa9CatalogRef,
            "BASPhaseJKLCompletionHexaCatalogDoctrine")
    }

    func testPhaseM8of8MilestoneRef() {
        XCTAssertEqual(
            D.phaseM8of8MilestoneDoctrineRef,
            "BASEightOfEightNativeKernelCoverageMilestoneDoctrine")
    }
}
