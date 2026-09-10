// MARK: - BASGapFillHexaFiveCompletionDoctrineWireInTests
// chapter 六百四十二 / M1947 — wire-in PROOF tests cross-
//                              checking the M1945 hexa
//                              #5 catalog against the 6
//                              source per-entry
//                              extension doctrines
//
// ## Coverage (15 wire-in PROOF tests)
//
// For each of the 6 entries:
//   1. hexa #5's mNumberFirst matches source
//      doctrine's extensionMNumber
//   2. hexa #5's typesExtended matches source
//      doctrine's totalTypesExtended
//
// = 12 per-entry wire-in tests。
//
// Plus 3 cross-catalog invariants:
//   - hexa #5 totalEntries (6) matches hexa #1+#2+#3+#4
//     (6 each)
//   - hexa #5 distinctModulesTouched (6) is ONE FEWER
//     than hexa #3+#4 (7 each) and EXCEEDS hexa #1+#2
//     (4 each)
//   - hexa #5 totalTypesExtendedAcrossEntries (18)
//     MATCHES hexa #4 (18) and EXCEEDS hexa #1 (11) +
//     hexa #2 (14) + hexa #3 (15)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1946 → M1947

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaFiveCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - Entry 1 — world-prior-coreml-error-trio

    func testEntry1WorldPriorCoreMLErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[0].mNumberFirst,
            BASWorldPriorCoreMLErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry1WorldPriorCoreMLErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[0].typesExtended,
            BASWorldPriorCoreMLErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 2 — runtime-core-sqlite-error-trio

    func testEntry2RuntimeCoreSQLiteErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[1].mNumberFirst,
            BASRuntimeCoreSQLiteErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry2RuntimeCoreSQLiteErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[1].typesExtended,
            BASRuntimeCoreSQLiteErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 3 — sovereign-secondary-error-trio

    func testEntry3SovereignSecondaryErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[2].mNumberFirst,
            BASSovereignSecondaryErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry3SovereignSecondaryErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[2].typesExtended,
            BASSovereignSecondaryErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 4 — organ-tool-feature-error-trio

    func testEntry4OrganToolFeatureErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[3].mNumberFirst,
            BASOrganToolFeatureErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry4OrganToolFeatureErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[3].typesExtended,
            BASOrganToolFeatureErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 5 — runtime-step-enum-trio

    func testEntry5RuntimeStepEnumTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[4].mNumberFirst,
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry5RuntimeStepEnumTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[4].typesExtended,
            BASRuntimeStepEnumTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 6 — categorization-enum-trio

    func testEntry6CategorizationEnumTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[5].mNumberFirst,
            BASCategorizationEnumTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry6CategorizationEnumTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries[5].typesExtended,
            BASCategorizationEnumTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Cross-catalog invariants

    func testHexaFiveTotalEntriesMatchesPriorHexas() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .totalEntries,
            BASGapFillHexaCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .totalEntries,
            BASGapFillHexaTwoCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .totalEntries,
            BASGapFillHexaThreeCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .totalEntries,
            BASGapFillHexaFourCompletionDoctrine
                .totalEntries)
    }

    func testHexaFiveDistinctModulesIsOneFewerThanHexaFourAndThreeButExceedsHexaOneAndTwo() {
        // hexa #5 = 6, hexa #4 = 7, hexa #3 = 7
        XCTAssertLessThan(
            BASGapFillHexaFiveCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaFourCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertLessThan(
            BASGapFillHexaFiveCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaThreeCompletionDoctrine
                .distinctModulesTouched)
        // hexa #5 = 6 > hexa #1 = 4, hexa #2 = 4
        XCTAssertGreaterThan(
            BASGapFillHexaFiveCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertGreaterThan(
            BASGapFillHexaFiveCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaTwoCompletionDoctrine
                .distinctModulesTouched)
    }

    func testHexaFiveTotalTypesMatchesHexaFourAndExceedsHexaOneTwoAndThree() {
        // hexa #5 = 18 == hexa #4 = 18
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaFourCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        // hexa #5 = 18 > hexa #1 = 11, hexa #2 = 14, hexa #3 = 15
        XCTAssertGreaterThan(
            BASGapFillHexaFiveCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        XCTAssertGreaterThan(
            BASGapFillHexaFiveCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaTwoCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        XCTAssertGreaterThan(
            BASGapFillHexaFiveCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaThreeCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
    }
}
