// MARK: - BASChapter680MambaSSMExtendedProofDoctrineTests
// chapter 六百八十 / M2100 第四刀 — anti-drift PROOF tests
//                                  for chapter 680 close-out

import XCTest
@testable import BASRuntimeCore

final class
BASChapter680MambaSSMExtendedProofDoctrineTests:
    XCTestCase
{
    typealias D = BASChapter680MambaSSMExtendedProofDoctrine

    // MARK: - Chapter identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百八十")
    }

    func testPhase() {
        XCTAssertEqual(D.phase, "Phase M")
    }

    // MARK: - M-number range

    func testMNumberRange() {
        XCTAssertEqual(D.firstKnifeMNumber, 2097)
        XCTAssertEqual(D.fourthKnifeMNumber, 2100)
        XCTAssertEqual(D.mNumberFirst, 2097)
        XCTAssertEqual(D.mNumberLast, 2100)
        XCTAssertEqual(D.knivesCount, 4)
    }

    // MARK: - Artifacts

    func testProductionArtifactCountIsOne() {
        XCTAssertEqual(D.productionArtifacts.count, 1)
    }

    func testTestArtifactCountIsThree() {
        XCTAssertEqual(D.testArtifacts.count, 3)
    }

    func testNewTypesCountIsTwo() {
        XCTAssertEqual(D.newTypes.count, 2)
    }

    // MARK: - Extended fixtures

    func testExtendedFixtureCountIs6() {
        XCTAssertEqual(D.extendedFixtureCount, 6)
    }

    func testAllExtendedFixturesNamed() {
        XCTAssertEqual(
            D.extendedFixtureNames.count, 6)
        XCTAssertEqual(
            Set(D.extendedFixtureNames).count, 6,
            "fixture names must be unique")
    }

    func testExtendedFixtureCategoriesPresent() {
        XCTAssertEqual(
            D.extendedFixtureCategories.count, 5)
    }

    // MARK: - Test counts

    func testRegistryTestCountIs13() {
        XCTAssertEqual(D.registryTestCount, 13)
    }

    func testWallclockTestCountIs4() {
        XCTAssertEqual(D.wallclockTestCount, 4)
    }

    func testNumericalStabilityTestCountIs8() {
        XCTAssertEqual(
            D.numericalStabilityTestCount, 8)
    }

    func testTotalChapter680TestCountIs25() {
        XCTAssertEqual(
            D.totalChapter680TestCount, 25)
    }

    func testTotalIsSumOfComponentCounts() {
        XCTAssertEqual(
            D.totalChapter680TestCount,
            D.registryTestCount
                + D.wallclockTestCount
                + D.numericalStabilityTestCount)
    }

    // MARK: - Wallclock characterization

    func testGpuAdvantageIsScaleDependent() {
        XCTAssertTrue(
            D.gpuWallclockAdvantageIsScaleDependent)
    }

    func testSmallFixtureCpuWinsOverGpu() {
        XCTAssertTrue(D.smallFixtureCpuWinsOverGpu)
    }

    func testApproximateBreakEvenIs256() {
        XCTAssertEqual(
            D.approximateBreakEvenBChannelProduct, 256)
    }

    func testMeasuredGpuPerDispatchAmortizedMs() {
        XCTAssertEqual(
            D.measuredGpuPerDispatchAmortizedMs,
            0.25, accuracy: 0.1)
    }

    // MARK: - Numerical stability

    func testStabilityScenariosCountIs5() {
        XCTAssertEqual(D.stabilityScenariosCount, 5)
    }

    func testStabilityScenariosListMatchesCount() {
        XCTAssertEqual(
            D.stabilityScenariosCovered.count,
            D.stabilityScenariosCount)
    }

    func testToleranceFloat32Is1eMinus5() {
        XCTAssertEqual(
            D.toleranceFloat32, 1e-5, accuracy: 1e-10)
    }

    func testAllStabilityScenariosCrossValidate() {
        XCTAssertTrue(
            D.allStabilityScenariosCrossValidate)
    }

    // MARK: - Triangulation tier

    func testPriorOracleCountIs3() {
        XCTAssertEqual(D.priorOracleCount, 3)
    }

    func testNewOracleCountIs2() {
        XCTAssertEqual(D.newOracleCount, 2)
    }

    func testTotalOracleCountIs5() {
        XCTAssertEqual(D.totalOracleCount, 5)
    }

    // MARK: - Achievement flags

    func testExtendedFixturesShipped() {
        XCTAssertTrue(D.extendedFixturesShipped)
    }

    func testWallclockCharacterizationHonest() {
        XCTAssertTrue(D.wallclockCharacterizationHonest)
    }

    func testNumericalStabilityProven() {
        XCTAssertTrue(D.numericalStabilityProven)
    }

    func testPhaseMAtTwoThirdsComplete() {
        XCTAssertTrue(D.phaseMAtTwoThirdsComplete)
    }

    // MARK: - Phase M progress

    func testPhaseMChaptersCompleteIs4() {
        XCTAssertEqual(D.phaseMChaptersComplete, 4)
    }

    func testPhaseMCommitsCompleteIs16() {
        XCTAssertEqual(D.phaseMCommitsComplete, 16)
    }

    func testPhaseMPercentCompleteIsTwoThirds() {
        XCTAssertEqual(
            D.phaseMPercentComplete,
            66.67, accuracy: 0.1)
    }

    // MARK: - Next chapter

    func testNextChapterIs681() {
        XCTAssertEqual(
            D.nextChapter, "chapter 六百八十一")
    }

    func testNextChapterMNumberStartIs2101() {
        XCTAssertEqual(D.nextChapterMNumberStart, 2101)
    }
}
