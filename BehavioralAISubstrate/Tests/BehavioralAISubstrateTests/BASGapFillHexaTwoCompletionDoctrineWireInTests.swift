// MARK: - BASGapFillHexaTwoCompletionDoctrineWireInTests
// chapter 六百二十一 / M1863 — wire-in PROOF tests cross-
//                              checking the M1861 hexa
//                              #2 catalog against the 6
//                              source per-entry
//                              extension doctrines
//
// ## Coverage (14 wire-in PROOF tests)
//
// For each of the 6 entries:
//   1. hexa #2's mNumberFirst matches source
//      doctrine's extensionMNumber
//   2. hexa #2's typesExtended matches source
//      doctrine's totalTypesExtended
//
// = 12 per-entry wire-in tests。
//
// Plus 2 cross-catalog invariants:
//   - hexa #2's distinctModulesTouched (4) matches
//     hexa #1's distinctModulesTouched (4)
//   - hexa #2 totalEntries (6) matches hexa #1
//     totalEntries (6) — both are HEXA catalogs
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1862 → M1863

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaTwoCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - Entry 1 — BASLeaseLife continuation

    func testEntry1LeaseLifeMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[0].mNumberFirst,
            BASLeaseLifeCodableExtensionContinuationDoctrine
                .extensionMNumber)
    }

    func testEntry1LeaseLifeTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[0].typesExtended,
            BASLeaseLifeCodableExtensionContinuationDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 2 — BASOrgan wave 3

    func testEntry2OrganWaveThreeMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[1].mNumberFirst,
            BASOrganCodableExtensionWaveThreeDoctrine
                .extensionMNumber)
    }

    func testEntry2OrganWaveThreeTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[1].typesExtended,
            BASOrganCodableExtensionWaveThreeDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 3 — BASOrgan wave 4

    func testEntry3OrganWaveFourMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[2].mNumberFirst,
            BASOrganCodableExtensionWaveFourDoctrine
                .extensionMNumber)
    }

    func testEntry3OrganWaveFourTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[2].typesExtended,
            BASOrganCodableExtensionWaveFourDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 4 — BASOrgan wave 5

    func testEntry4OrganWaveFiveMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[3].mNumberFirst,
            BASOrganCodableExtensionWaveFiveDoctrine
                .extensionMNumber)
    }

    func testEntry4OrganWaveFiveTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[3].typesExtended,
            BASOrganCodableExtensionWaveFiveDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 5 — BASMemory post-trilogy

    func testEntry5MemoryPostTrilogyMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[4].mNumberFirst,
            BASMemoryCodableExtensionPostTrilogyDoctrine
                .extensionMNumber)
    }

    func testEntry5MemoryPostTrilogyTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[4].typesExtended,
            BASMemoryCodableExtensionPostTrilogyDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 6 — BASHostKit post-mesh-sweep

    func testEntry6HostKitPostMeshSweepMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[5].mNumberFirst,
            BASHostKitCodableExtensionPostMeshSweepDoctrine
                .extensionMNumber)
    }

    func testEntry6HostKitPostMeshSweepTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries[5].typesExtended,
            BASHostKitCodableExtensionPostMeshSweepDoctrine
                .totalTypesExtended)
    }

    // MARK: - Cross-catalog invariants

    func testHexaTwoDistinctModulesMatchesHexaOne() {
        // PROOF — hexa #2 must touch the same number
        // of distinct modules as hexa #1 (both = 4)。
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaCompletionDoctrine
                .distinctModulesTouched)
    }

    func testHexaTwoTotalEntriesMatchesHexaOne() {
        // PROOF — both catalogs are HEXA (6 entries)。
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .totalEntries,
            BASGapFillHexaCompletionDoctrine
                .totalEntries)
    }
}
