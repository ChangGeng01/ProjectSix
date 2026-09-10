// MARK: - BASEightOfEightNativeKernelCoverageMilestoneDoctrineTests
// chapter 六百八十一 / M2103 第三刀 — milestone doctrine
//                                    anti-drift PROOF tests

import XCTest
@testable import BASRuntimeCore

final class
BASEightOfEightNativeKernelCoverageMilestoneDoctrineTests:
    XCTestCase
{
    typealias D = BASEightOfEightNativeKernelCoverageMilestoneDoctrine

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十一")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2103)
    }

    func testTotalKernelOperationsIs8() {
        XCTAssertEqual(D.totalKernelOperations, 8)
    }

    func testNativeProductionGradeKernelCountIs8() {
        XCTAssertEqual(
            D.nativeProductionGradeKernelCount, 8)
        XCTAssertEqual(
            D.nativeProductionGradeKernels.count, 8)
    }

    func testCoverageRatioIs1() {
        XCTAssertEqual(
            D.nativeCoverageRatio, 1.0, accuracy: 0.001)
    }

    func testCoverageHasNumericalProof() {
        XCTAssertTrue(D.nativeCoverageHasNumericalProof)
    }

    func testSSMScanOracleCountIs5() {
        XCTAssertEqual(
            D.ssmScanCorrectnessOracleCount, 5)
        XCTAssertEqual(D.ssmScanOracles.count, 5)
    }

    func testProgressionHistoryHas3Entries() {
        XCTAssertEqual(D.progressionHistory.count, 3)
    }

    func testProgressionHistoryReferences477_496_681() {
        XCTAssertTrue(D.progressionHistory[0]
            .contains("chapter 477"))
        XCTAssertTrue(D.progressionHistory[1]
            .contains("chapter 496"))
        XCTAssertTrue(D.progressionHistory[2]
            .contains("chapter 681"))
    }

    func testPhaseMChapterContributionsCountIs5() {
        XCTAssertEqual(
            D.phaseMChapterContributionsCount, 5)
        XCTAssertEqual(
            D.phaseMChapterContributions.count, 5)
    }

    func testScoreDeltaTargetIs5() {
        XCTAssertEqual(D.scoreDeltaTarget, 5)
    }

    func testScoreDeltaImpactsTwoDirectives() {
        XCTAssertEqual(
            D.scoreDeltaDirectiveImpact.count, 2)
        XCTAssertTrue(
            D.scoreDeltaDirectiveImpact.contains("更硬核"))
        XCTAssertTrue(
            D.scoreDeltaDirectiveImpact.contains(
                "原生利用神经引擎"))
    }

    func testPreMilestoneScoreIs58() {
        XCTAssertEqual(D.preMilestoneAggregateScore, 58)
    }

    func testPostMilestoneScoreIs60() {
        XCTAssertEqual(D.postMilestoneAggregateScore, 60)
    }

    func testSubstrateScopeOnly() {
        XCTAssertTrue(D.substrateScopeOnly)
    }

    func testPythonCrossValidationDownscoped() {
        XCTAssertTrue(D.pythonCrossValidationDowncoped)
    }

    func testEightOfEightAchieved() {
        XCTAssertTrue(D.eightOfEightAchieved)
    }

    func testAllKernelsHaveNumericalProof() {
        XCTAssertTrue(D.allKernelsHaveNumericalProof)
    }

    func testStubRepurposeComplete() {
        XCTAssertTrue(D.stubRepurposeComplete)
    }

    func testCoverageProgressionDocumented() {
        XCTAssertTrue(D.coverageProgressionDocumented)
    }

    func testPriorChapter496Ref() {
        XCTAssertEqual(
            D.priorChapter496StubDoctrineRef,
            "BASCanonicalKernelCoverage.chapter496Snapshot")
    }

    func testPostRepurposeSnapshotRef() {
        XCTAssertEqual(
            D.postRepurposeSnapshotRef,
            "BASCanonicalKernelCoverage.chapter681Snapshot")
    }

    func testFivePriorPhaseMChapterRefs() {
        // 4 individual chapter refs (677-680)
        XCTAssertEqual(
            D.priorPhaseMChapter677Ref,
            "BASChapter677SSMScanShaderShipDoctrine")
        XCTAssertEqual(
            D.priorPhaseMChapter678Ref,
            "BASChapter678MetalSSMScanKernelDispatchDoctrine")
        XCTAssertEqual(
            D.priorPhaseMChapter679Ref,
            "BASChapter679MambaSSMFixturesShipDoctrine")
        XCTAssertEqual(
            D.priorPhaseMChapter680Ref,
            "BASChapter680MambaSSMExtendedProofDoctrine")
    }
}
