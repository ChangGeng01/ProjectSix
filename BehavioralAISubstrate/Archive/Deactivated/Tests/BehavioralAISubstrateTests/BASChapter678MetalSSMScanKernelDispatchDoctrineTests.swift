// MARK: - BASChapter678MetalSSMScanKernelDispatchDoctrineTests
// chapter 六百七十八 / M2092 第四刀 — anti-drift PROOF tests
//                                    for chapter 678 close-
//                                    out doctrine

import XCTest
@testable import BASRuntimeCore

final class
BASChapter678MetalSSMScanKernelDispatchDoctrineTests:
    XCTestCase
{
    typealias D = BASChapter678MetalSSMScanKernelDispatchDoctrine

    // MARK: - Chapter identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百七十八")
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase M")
    }

    func testPhaseStatus() {
        XCTAssertEqual(D.phaseStatus, "in-progress")
    }

    // MARK: - M-number range

    func testFirstKnifeMNumber() {
        XCTAssertEqual(D.firstKnifeMNumber, 2089)
    }

    func testFourthKnifeMNumber() {
        XCTAssertEqual(D.fourthKnifeMNumber, 2092)
    }

    func testMNumberRangeIsContiguous() {
        XCTAssertEqual(
            D.secondKnifeMNumber,
            D.firstKnifeMNumber + 1)
        XCTAssertEqual(
            D.thirdKnifeMNumber,
            D.firstKnifeMNumber + 2)
        XCTAssertEqual(
            D.fourthKnifeMNumber,
            D.firstKnifeMNumber + 3)
    }

    func testKnivesCountIsFour() {
        XCTAssertEqual(D.knivesCount, 4)
    }

    // MARK: - Artifacts

    func testProductionArtifactCountIsTwo() {
        XCTAssertEqual(D.productionArtifactCount, 2)
    }

    func testTestArtifactCountIsThree() {
        XCTAssertEqual(D.testArtifactCount, 3)
    }

    func testActorArtifactPresent() {
        XCTAssertTrue(D.productionArtifacts.contains(
            "Sources/BASMetalSubstrate/BASBuiltinKernels/BASMetalSSMScanKernel.swift"))
    }

    func testCPUReferenceArtifactPresent() {
        XCTAssertTrue(D.productionArtifacts.contains(
            "Sources/BASMetalSubstrate/BASBuiltinKernels/BASSSMScanCPUReference.swift"))
    }

    // MARK: - New types

    func testNewTypesCountIsThree() {
        XCTAssertEqual(D.newTypesCount, 3)
    }

    func testNewTypesIncludeActorAndReference() {
        for typeName in [
            "BASMetalSSMScanKernel",
            "BASSSMScanCPUReference",
            "BASSSMScanCPUReferenceError"
        ] {
            XCTAssertTrue(D.newTypes.contains(typeName))
        }
    }

    // MARK: - Test counts

    func testBasicKernelTestCountIs5() {
        XCTAssertEqual(D.basicKernelTestCount, 5)
    }

    func testCPUReferenceTestCountIs11() {
        XCTAssertEqual(D.cpuReferenceTestCount, 11)
    }

    func testCrossValidationTestCountIs9() {
        XCTAssertEqual(D.crossValidationTestCount, 9)
    }

    func testTotalChapter678TestCountIs25() {
        XCTAssertEqual(D.totalChapter678TestCount, 25)
    }

    func testTotalIsSumOfPerSuiteCounts() {
        XCTAssertEqual(
            D.totalChapter678TestCount,
            D.basicKernelTestCount
                + D.cpuReferenceTestCount
                + D.crossValidationTestCount)
    }

    // MARK: - Kernel actor facts

    func testActorName() {
        XCTAssertEqual(
            D.actorName, "BASMetalSSMScanKernel")
    }

    func testActorRenamedFromPlanName() {
        XCTAssertTrue(D.actorRenamedFromPlanName)
        XCTAssertEqual(
            D.planTimeName, "BASMPSGraphSSMScanKernel")
    }

    func testActorRenameReasonNonEmpty() {
        XCTAssertFalse(D.actorRenameReason.isEmpty)
    }

    func testIsFirstRawMetalComputeKernel() {
        XCTAssertTrue(D.isFirstRawMetalComputeKernel)
    }

    func testKernelOperation() {
        XCTAssertEqual(D.kernelOperation, "ssmScan")
    }

    func testKernelDataType() {
        XCTAssertEqual(D.kernelDataType, "float32")
    }

    func testKernelBackingKind() {
        XCTAssertEqual(D.kernelBackingKind, "metalBuffer")
    }

    func testComputePipelineStateCachedInActor() {
        XCTAssertTrue(D.computePipelineStateCachedInActor)
    }

    // MARK: - Cross-validation facts

    func testCrossValidationMaeToleranceIs1eMinus5() {
        XCTAssertEqual(
            D.crossValidationMaeToleranceFloat32,
            1.0e-5, accuracy: 1.0e-10)
    }

    func testCrossValidationFixtureCountIs8() {
        XCTAssertEqual(D.crossValidationFixtureCount, 8)
    }

    func testCrossValidationFixtureShapesListSizeIs8() {
        XCTAssertEqual(
            D.crossValidationFixtureShapesCount, 8)
    }

    func testAllCrossValidationFixturesPass() {
        XCTAssertTrue(D.allCrossValidationFixturesPass)
    }

    func testGPUDispatchBitStableAcrossRepeatCalls() {
        XCTAssertTrue(
            D.gpuDispatchBitStableAcrossRepeatCalls)
    }

    // MARK: - Math correctness

    func testRecurrenceFormulaContainsKeyTerms() {
        XCTAssertTrue(D.recurrenceFormula.contains("h_t"))
        XCTAssertTrue(D.recurrenceFormula.contains("exp"))
        XCTAssertTrue(
            D.recurrenceFormula.contains("h_{t-1}"))
        XCTAssertTrue(D.recurrenceFormula.contains("y_t"))
    }

    func testInitialStateIsZero() {
        XCTAssertEqual(D.initialState, "h_0 = 0")
    }

    func testDiscretization() {
        XCTAssertTrue(
            D.discretization.contains("zero-order-hold"))
    }

    // MARK: - Failure modes

    func testTypedFailureModeCountIs7() {
        XCTAssertEqual(D.typedFailureModeCount, 7)
    }

    func testTypedFailureModesListSizeMatchesCount() {
        XCTAssertEqual(
            D.typedFailureModes.count,
            D.typedFailureModeCount)
    }

    // MARK: - Achievement flags

    func testRealGpuDispatchProven() {
        XCTAssertTrue(D.realGpuDispatchProven)
    }

    func testCPUReferenceShipped() {
        XCTAssertTrue(D.cpuReferenceShipped)
    }

    func testGPUCPUAgreementProvenWithinMaeBound() {
        XCTAssertTrue(
            D.gpuCpuAgreementProvenWithinMaeBound)
    }

    func testDeterminismProven() {
        XCTAssertTrue(D.determinismProven)
    }

    func testPhaseMHardestChallengeResolved() {
        XCTAssertTrue(D.phaseMHardestChallengeResolved)
    }

    // MARK: - Next chapter

    func testNextChapterIs679() {
        XCTAssertEqual(
            D.nextChapter, "chapter 六百七十九")
    }

    func testNextChapterMNumberStartIs2093() {
        XCTAssertEqual(D.nextChapterMNumberStart, 2093)
    }

    // MARK: - Phase M progress

    func testPhaseMChaptersCompleteIs2() {
        XCTAssertEqual(D.phaseMChaptersComplete, 2)
    }

    func testPhaseMCommitsCompleteIs8() {
        XCTAssertEqual(D.phaseMCommitsComplete, 8)
    }

    // MARK: - Cross-doctrine refs

    func testPriorChapter677Ref() {
        XCTAssertEqual(
            D.priorChapter677ShipRef,
            "BASChapter677SSMScanShaderShipDoctrine")
    }
}
