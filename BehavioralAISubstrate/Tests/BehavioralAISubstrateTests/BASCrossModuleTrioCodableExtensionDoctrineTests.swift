// MARK: - BASCrossModuleTrioCodableExtensionDoctrineTests
// chapter 六百二十二 / M1867 — anti-drift PROOF tests for
//                              the chapter 622 typed
//                              surface

import XCTest
@testable import BASRuntimeCore

final class BASCrossModuleTrioCodableExtensionDoctrineTests:
    XCTestCase
{

    func testChapterTagPinned() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .chapterTag,
            "chapter 六百二十二")
    }

    func testExtensionMNumberIs1865() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .extensionMNumber,
            1865)
    }

    func testProofMNumberIs1866() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .proofMNumber,
            1866)
    }

    func testProofTestCountIsThree() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .proofTestCount,
            3)
    }

    func testTotalTypesExtendedIsThree() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .totalTypesExtended,
            3)
    }

    func testTypesGainedCodableListed() {
        let types =
            BASCrossModuleTrioCodableExtensionDoctrine
                .typesGainedCodable
        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(
            "BASPromptStateValue"))
        XCTAssertTrue(types.contains(
            "BASTurnRuntimePlanLedgerCoherence"))
        XCTAssertTrue(types.contains(
            "BASTurnRuntimePlanLedgerCoherenceIssue"))
    }

    func testModulesListed() {
        let modules =
            BASCrossModuleTrioCodableExtensionDoctrine
                .modules
        XCTAssertEqual(modules.count, 2)
        XCTAssertTrue(modules.contains("BASOrchestration"))
        XCTAssertTrue(modules.contains("BASHostKit"))
    }

    func testModuleCountIsTwo() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .moduleCount,
            2)
    }

    func testStructAndEnumCounts() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .structCount, 1)
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .enumCount, 2)
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .structCount
            + BASCrossModuleTrioCodableExtensionDoctrine
                .enumCount,
            BASCrossModuleTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    func testTypesAreTopLevelFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .typesAreTopLevel)
    }

    func testConformancesAddedListed() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .conformancesAdded,
            ["Codable"])
    }

    func testProofMethodPinned() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .proofMethod,
            "compile-time-codable-conformance")
    }

    func testByteEqualityPreservedFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .byteEqualityPreserved)
    }

    func testNowInReplayDeterminismContractFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .nowInReplayDeterminismContract)
    }

    func testIsGapFillExtensionFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .isGapFillExtension)
    }

    func testKindLabelIsCrossModuleTrio() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .kindLabel,
            "cross-module-trio")
    }

    func testIsFirstCrossModuleWaveFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .isFirstCrossModuleWave)
    }

    func testIsFirstPostHexaTwoGapFillFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .isFirstPostHexaTwoGapFill)
    }

    func testPriorHexaCatalogRefPinned() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .priorHexaCatalogRef,
            "BASGapFillHexaTwoCompletionDoctrine")
    }

    func testPriorHexaCatalogOneRefPinned() {
        XCTAssertEqual(
            BASCrossModuleTrioCodableExtensionDoctrine
                .priorHexaCatalogOneRef,
            "BASGapFillHexaCompletionDoctrine")
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .isPastM1800Milestone)
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASCrossModuleTrioCodableExtensionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }
}
