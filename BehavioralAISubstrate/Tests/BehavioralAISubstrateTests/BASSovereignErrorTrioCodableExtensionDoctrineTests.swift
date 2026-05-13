// MARK: - BASSovereignErrorTrioCodableExtensionDoctrineTests
// chapter 六百三十三 / M1911 — anti-drift PROOF tests for
//                              the chapter 633 typed
//                              surface

import XCTest
@testable import BASRuntimeCore

final class BASSovereignErrorTrioCodableExtensionDoctrineTests:
    XCTestCase
{

    func testChapterTagPinned() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .chapterTag,
            "chapter 六百三十三")
    }

    func testExtensionMNumberIs1909() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .extensionMNumber,
            1909)
    }

    func testProofMNumberIs1910() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .proofMNumber,
            1910)
    }

    func testProofTestCountIsThree() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .proofTestCount,
            3)
    }

    func testTotalTypesExtendedIsThree() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .totalTypesExtended,
            3)
    }

    func testTypesGainedCodableListed() {
        let types =
            BASSovereignErrorTrioCodableExtensionDoctrine
                .typesGainedCodable
        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(
            "BASSovereignHostVersionTree.TreeError"))
        XCTAssertTrue(types.contains(
            "BASSovereignFingerprintStore.StoreError"))
        XCTAssertTrue(types.contains(
            "BASSovereignTokenAuthority.AuthorityError"))
    }

    func testModulesListed() {
        let modules =
            BASSovereignErrorTrioCodableExtensionDoctrine
                .modules
        XCTAssertEqual(modules.count, 1)
        XCTAssertTrue(modules.contains("BASSovereign"))
    }

    func testModuleCountIsOne() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .moduleCount,
            1)
    }

    func testNestedInActorCountIsTwo() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .nestedInActorCount,
            2)
    }

    func testNestedInStructCountIsOne() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .nestedInStructCount,
            1)
    }

    func testTopLevelCountIsZero() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .topLevelCount,
            0)
    }

    func testStructAndEnumCounts() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .structCount, 0)
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .enumCount, 3)
    }

    func testAllTypesAreErrorsFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .allTypesAreErrors)
    }

    func testConformancesAddedListed() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .conformancesAdded,
            ["Codable"])
    }

    func testProofMethodPinned() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .proofMethod,
            "compile-time-codable-conformance")
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .byteEqualityPreserved)
    }

    func testNowInReplayDeterminismContractFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .nowInReplayDeterminismContract)
    }

    func testIsGapFillExtensionFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .isGapFillExtension)
    }

    func testKindLabel() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .kindLabel,
            "sovereign-error-trio")
    }

    func testIsFifthPostHexaThreeGapFillFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .isFifthPostHexaThreeGapFill)
    }

    func testIsFirstBASSovereignPostHexaThreeFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .isFirstBASSovereignPostHexaThree)
    }

    func testPriorHexaCatalogRefPinned() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .priorHexaCatalogRef,
            "BASGapFillHexaThreeCompletionDoctrine")
    }

    func testPriorPostHexaThreeChapterRefPinned() {
        XCTAssertEqual(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .priorPostHexaThreeChapterRef,
            "BASCrossModuleBCMHPCScheduleErrorTrioCodableExtensionDoctrine")
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .isPastM1800Milestone)
    }

    func testIsPastM1880MilestoneFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .isPastM1880Milestone)
    }

    func testIsPastM1900MilestoneFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .isPastM1900Milestone)
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASSovereignErrorTrioCodableExtensionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }
}
