// MARK: - BASChapter681StubRepurposeAnd8of8DoctrineTests
// chapter 六百八十一 / M2104 第四刀 — close-out anti-drift

import XCTest
@testable import BASRuntimeCore

final class
BASChapter681StubRepurposeAnd8of8DoctrineTests: XCTestCase
{
    typealias D = BASChapter681StubRepurposeAnd8of8Doctrine

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十一")
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase M")
    }

    func testMNumberRange() {
        XCTAssertEqual(D.firstKnifeMNumber, 2101)
        XCTAssertEqual(D.fourthKnifeMNumber, 2104)
        XCTAssertEqual(D.mNumberFirst, 2101)
        XCTAssertEqual(D.mNumberLast, 2104)
        XCTAssertEqual(D.knivesCount, 4)
    }

    func testModifiedArtifactCountIs2() {
        XCTAssertEqual(D.modifiedArtifacts.count, 2)
    }

    func testNewArtifactCountIs1() {
        XCTAssertEqual(D.newArtifacts.count, 1)
    }

    func testTestArtifactCountIs3() {
        XCTAssertEqual(D.testArtifacts.count, 3)
    }

    func testNewTypesIncludeTypealias() {
        XCTAssertTrue(D.newTypes.contains { $0.contains(
            "BASCPUSSMScanKernel") })
    }

    // MARK: - Stub repurpose facts

    func testStubBackingMovedFromMetalBufferToCPUBytes() {
        XCTAssertEqual(
            D.stubKeyBackingKindPreRepurpose,
            "metalBuffer")
        XCTAssertEqual(
            D.stubKeyBackingKindPostRepurpose,
            "cpuBytes")
        XCTAssertNotEqual(
            D.stubKeyBackingKindPreRepurpose,
            D.stubKeyBackingKindPostRepurpose)
    }

    func testStubStatusFlippedFromStubToCPURef() {
        XCTAssertEqual(
            D.stubImplementationStatusPreRepurpose,
            "stubIdentityScan")
        XCTAssertEqual(
            D.stubImplementationStatusPostRepurpose,
            "cpuSwiftReferenceProduction")
    }

    func testIsProductionReadyFlippedTrue() {
        XCTAssertFalse(D.stubIsProductionReadyPreRepurpose)
        XCTAssertTrue(D.stubIsProductionReadyPostRepurpose)
    }

    // MARK: - Coverage milestone facts

    func testCoverageTargetBumped() {
        XCTAssertEqual(
            D.coverageTargetPreRepurpose,
            "7-of-8-native-plus-1-stub")
        XCTAssertEqual(
            D.coverageTargetPostRepurpose,
            "8-of-8-native")
    }

    func testKernelsWithProofBumped7To8() {
        XCTAssertEqual(
            D.kernelsWithNumericalProofPreRepurpose, 7)
        XCTAssertEqual(
            D.kernelsWithNumericalProofPostRepurpose, 8)
    }

    // MARK: - Test counts

    func testTotalChapter681TestCountIs45() {
        XCTAssertEqual(D.totalChapter681TestCount, 45)
    }

    func testTestCountBreakdown() {
        XCTAssertEqual(D.updatedStubTestCount, 9)
        XCTAssertEqual(D.newCoverageTestCount, 13)
        XCTAssertEqual(D.newMilestoneTestCount, 23)
    }

    // MARK: - Achievement flags

    func testAllSixAchievementFlagsTrue() {
        XCTAssertTrue(D.stubRepurposedToCPUBytes)
        XCTAssertTrue(D.cpuSiblingDelegatesToProvenRef)
        XCTAssertTrue(D.typealiasCPUSSMScanKernelShipped)
        XCTAssertTrue(D.chapter681SnapshotShipped)
        XCTAssertTrue(
            D.historicalChapter496SnapshotPreserved)
        XCTAssertTrue(
            D.eightOfEightMilestoneDoctrineShipped)
    }

    // MARK: - Next chapter

    func testNextChapterIs682() {
        XCTAssertEqual(
            D.nextChapter, "chapter 六百八十二")
    }

    func testNextChapterMNumberStartIs2105() {
        XCTAssertEqual(D.nextChapterMNumberStart, 2105)
    }

    // MARK: - Phase M progress

    func testPhaseMChaptersCompleteIs5() {
        XCTAssertEqual(D.phaseMChaptersComplete, 5)
    }

    func testPhaseMCommitsCompleteIs20() {
        XCTAssertEqual(D.phaseMCommitsComplete, 20)
    }

    func testPhaseMAtEightyThreePercent() {
        XCTAssertEqual(
            D.phaseMPercentComplete,
            83.33, accuracy: 0.1)
    }

    // MARK: - Cross-doctrine refs

    func testMilestoneDoctrineRef() {
        XCTAssertEqual(
            D.milestoneDoctrineRef,
            "BASEightOfEightNativeKernelCoverageMilestoneDoctrine")
    }

    func testChapter496And681SnapshotRefs() {
        XCTAssertTrue(
            D.priorChapter496SnapshotRef.contains(
                "chapter496Snapshot"))
        XCTAssertTrue(
            D.newChapter681SnapshotRef.contains(
                "chapter681Snapshot"))
    }
}
