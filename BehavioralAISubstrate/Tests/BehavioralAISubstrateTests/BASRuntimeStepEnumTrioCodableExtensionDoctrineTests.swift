// MARK: - BASRuntimeStepEnumTrioCodableExtensionDoctrineTests
// chapter 六百四十 / M1939 — anti-drift PROOF tests for
//                            the chapter 640 typed
//                            surface

import XCTest
@testable import BASRuntimeCore

final class BASRuntimeStepEnumTrioCodableExtensionDoctrineTests:
    XCTestCase
{

    func testChapterTagPinned() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .chapterTag,
            "chapter 六百四十")
    }

    func testExtensionMNumberIs1937() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .extensionMNumber,
            1937)
    }

    func testProofMNumberIs1938() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .proofMNumber,
            1938)
    }

    func testProofTestCountIsThree() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .proofTestCount,
            3)
    }

    func testTotalTypesExtendedIsThree() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .totalTypesExtended,
            3)
    }

    func testTypesGainedCodableListed() {
        let types =
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .typesGainedCodable
        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(
            "BASEventReplayRange"))
        XCTAssertTrue(types.contains(
            "BASToolCallingPlanStep"))
        XCTAssertTrue(types.contains(
            "BASShadowTrialCoordinator.FinalizeOutcome"))
    }

    func testModulesListed() {
        let modules =
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .modules
        XCTAssertEqual(modules.count, 3)
        XCTAssertTrue(modules.contains("BASRuntimeCore"))
        XCTAssertTrue(modules.contains("BASOrgan"))
        XCTAssertTrue(modules.contains("BASMemory"))
    }

    func testModuleCountIsThree() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .moduleCount,
            3)
    }

    func testTopLevelCountIsTwo() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .topLevelCount,
            2)
    }

    func testNestedInActorCountIsOne() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .nestedInActorCount,
            1)
    }

    func testStructAndEnumCounts() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .structCount, 0)
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .enumCount, 3)
    }

    func testAllTypesAreErrorsFlagIsFalse() {
        XCTAssertFalse(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .allTypesAreErrors)
    }

    func testConformancesAddedListed() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .conformancesAdded,
            ["Codable"])
    }

    func testProofMethodPinned() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .proofMethod,
            "compile-time-codable-conformance")
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .byteEqualityPreserved)
    }

    func testNowInReplayDeterminismContractFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .nowInReplayDeterminismContract)
    }

    func testIsGapFillExtensionFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isGapFillExtension)
    }

    func testKindLabel() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .kindLabel,
            "runtime-step-enum-trio")
    }

    func testIsFifthPostHexaFourGapFillFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isFifthPostHexaFourGapFill)
    }

    func testIsFirstNonErrorTrioPostHexaFourFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isFirstNonErrorTrioPostHexaFour)
    }

    func testIsThirdBASRuntimeCoreTouchOverallFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isThirdBASRuntimeCoreTouchOverall)
    }

    func testIsThirdBASOrganTouchOverallFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isThirdBASOrganTouchOverall)
    }

    func testIsThirdBASMemoryTouchOverallFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isThirdBASMemoryTouchOverall)
    }

    func testCumulativeBASRuntimeCoreTypedSurfacesIsFive() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .cumulativeBASRuntimeCoreTypedSurfaces,
            5)
    }

    func testCumulativeBASOrganTypedSurfacesIsFour() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .cumulativeBASOrganTypedSurfaces,
            4)
    }

    func testCumulativeBASMemoryTypedSurfacesIsSeven() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .cumulativeBASMemoryTypedSurfaces,
            7)
    }

    func testPriorHexaCatalogRefPinned() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .priorHexaCatalogRef,
            "BASGapFillHexaFourCompletionDoctrine")
    }

    func testPriorPostHexaFourChapterRefPinned() {
        XCTAssertEqual(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .priorPostHexaFourChapterRef,
            "BASOrganToolFeatureErrorTrioCodableExtensionDoctrine")
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isPastM1800Milestone)
    }

    func testIsPastM1880MilestoneFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isPastM1880Milestone)
    }

    func testIsPastM1900MilestoneFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isPastM1900Milestone)
    }

    func testIsPast180TypedSurfacesMilestoneFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isPast180TypedSurfacesMilestone)
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }

    func testIsPastFiveHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .isPastFiveHundredConsecutiveByteEqual)
    }
}
