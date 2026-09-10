// MARK: - BASGapFillHexaThreeCompletionDoctrineWireInTests
// chapter 六百二十八 / M1891 — wire-in PROOF tests cross-
//                              checking the M1889 hexa
//                              #3 catalog against the 6
//                              source per-entry
//                              extension doctrines
//
// ## Coverage (15 wire-in PROOF tests)
//
// For each of the 6 entries:
//   1. hexa #3's mNumberFirst matches source
//      doctrine's extensionMNumber
//   2. hexa #3's typesExtended matches source
//      doctrine's totalTypesExtended
//
// = 12 per-entry wire-in tests。
//
// Plus 3 cross-catalog invariants:
//   - hexa #3 totalEntries (6) matches hexa #1 + #2 (6)
//   - hexa #3 distinctModulesTouched (7) EXCEEDS hexa
//     #1 + #2 (4 each)
//   - hexa #3 totalTypesExtendedAcrossEntries (15)
//     exceeds hexa #1 (11) and hexa #2 (14)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1890 → M1891

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaThreeCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - Entry 1 — cross-module trio

    func testEntry1CrossModuleTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[0].mNumberFirst,
            BASCrossModuleTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry1CrossModuleTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[0].typesExtended,
            BASCrossModuleTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 2 — BASObservability nested pair

    func testEntry2ObservabilityNestedPairMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[1].mNumberFirst,
            BASObservabilityNestedPairCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry2ObservabilityNestedPairTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[1].typesExtended,
            BASObservabilityNestedPairCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 3 — BASRuntimeCore solo enum

    func testEntry3RuntimeCoreSoloEnumMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[2].mNumberFirst,
            BASRuntimeCoreSoloEnumCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry3RuntimeCoreSoloEnumTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[2].typesExtended,
            BASRuntimeCoreSoloEnumCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 4 — BASHostKit error trio

    func testEntry4HostKitErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[3].mNumberFirst,
            BASHostKitErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry4HostKitErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[3].typesExtended,
            BASHostKitErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 5 — BASMetalSubstrate metal error trio

    func testEntry5MetalErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[4].mNumberFirst,
            BASMetalSubstrateMetalErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry5MetalErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[4].typesExtended,
            BASMetalSubstrateMetalErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 6 — cross-module error trio

    func testEntry6CrossModuleErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[5].mNumberFirst,
            BASCrossModuleErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry6CrossModuleErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries[5].typesExtended,
            BASCrossModuleErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Cross-catalog invariants

    func testHexaThreeTotalEntriesMatchesPriorHexas() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .totalEntries,
            BASGapFillHexaCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .totalEntries,
            BASGapFillHexaTwoCompletionDoctrine
                .totalEntries)
    }

    func testHexaThreeDistinctModulesExceedsPriorHexas() {
        XCTAssertGreaterThan(
            BASGapFillHexaThreeCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertGreaterThan(
            BASGapFillHexaThreeCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaTwoCompletionDoctrine
                .distinctModulesTouched)
    }

    func testHexaThreeTotalTypesExceedsPriorHexas() {
        XCTAssertGreaterThan(
            BASGapFillHexaThreeCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        XCTAssertGreaterThan(
            BASGapFillHexaThreeCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaTwoCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
    }
}
