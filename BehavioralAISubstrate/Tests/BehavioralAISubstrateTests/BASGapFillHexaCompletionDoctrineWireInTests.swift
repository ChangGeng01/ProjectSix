// MARK: - BASGapFillHexaCompletionDoctrineWireInTests
// chapter 六百一十四 / M1835 — wire-in PROOF tests cross-
//                              checking the M1833 gap-
//                              fill hexa catalog against
//                              the 6 source per-entry
//                              extension doctrines +
//                              chapter 607 post-octa
//                              hexa precedent
//
// ## Coverage (20 wire-in PROOF tests)
//
// For each of the 6 entries:
//   1. hexa's mNumberFirst matches source doctrine's
//      extensionMNumber
//   2. hexa's typesExtended matches source doctrine's
//      totalTypesExtended
//   3. hexa's combinedModuleCountAfter matches source
//      doctrine's combinedXxxCount
//
// = 18 per-entry wire-in tests。
//
// Plus 2 cross-catalog invariants:
//   - hexa.entries[5].mNumberFirst == 1829 (chapter
//     613 entry,the latest)
//   - hexa.entries[0].mNumberFirst == hexa.runFirstMNumber
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1834 → M1835

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - Entry 1 — BASHostKit mesh-sweep wire-ins

    func testEntry1HostKitMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[0].mNumberFirst,
            BASHostKitMeshSweepCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry1HostKitTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[0].typesExtended,
            BASHostKitMeshSweepCodableExtensionDoctrine
                .totalTypesExtended)
    }

    func testEntry1HostKitCombinedCountWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[0].combinedModuleCountAfter,
            BASHostKitMeshSweepCodableExtensionDoctrine
                .combinedHostKitCount)
    }

    // MARK: - Entry 2 — BASOrgan wave 2 wire-ins

    func testEntry2OrganWaveTwoMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[1].mNumberFirst,
            BASOrganCodableExtensionWaveTwoDoctrine
                .extensionMNumber)
    }

    func testEntry2OrganWaveTwoTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[1].typesExtended,
            BASOrganCodableExtensionWaveTwoDoctrine
                .totalTypesExtended)
    }

    func testEntry2OrganWaveTwoCombinedCountWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[1].combinedModuleCountAfter,
            BASOrganCodableExtensionWaveTwoDoctrine
                .combinedOrganCount)
    }

    // MARK: - Entry 3 — BASOrchestration continuation wire-ins

    func testEntry3OrchestrationContinuationMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[2].mNumberFirst,
            BASOrchestrationCodableExtensionContinuationDoctrine
                .extensionMNumber)
    }

    func testEntry3OrchestrationContinuationTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[2].typesExtended,
            BASOrchestrationCodableExtensionContinuationDoctrine
                .totalTypesExtended)
    }

    func testEntry3OrchestrationContinuationCombinedCountWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[2].combinedModuleCountAfter,
            BASOrchestrationCodableExtensionContinuationDoctrine
                .combinedOrchestrationCount)
    }

    // MARK: - Entry 4 — BASSovereign wave 2 wire-ins

    func testEntry4SovereignWaveTwoMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[3].mNumberFirst,
            BASSovereignCodableExtensionWaveTwoDoctrine
                .extensionMNumber)
    }

    func testEntry4SovereignWaveTwoTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[3].typesExtended,
            BASSovereignCodableExtensionWaveTwoDoctrine
                .totalTypesExtended)
    }

    func testEntry4SovereignWaveTwoCombinedCountWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[3].combinedModuleCountAfter,
            BASSovereignCodableExtensionWaveTwoDoctrine
                .combinedSovereignCount)
    }

    // MARK: - Entry 5 — BASSovereign wave 3 wire-ins

    func testEntry5SovereignWaveThreeMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[4].mNumberFirst,
            BASSovereignCodableExtensionWaveThreeDoctrine
                .extensionMNumber)
    }

    func testEntry5SovereignWaveThreeTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[4].typesExtended,
            BASSovereignCodableExtensionWaveThreeDoctrine
                .totalTypesExtended)
    }

    func testEntry5SovereignWaveThreeCombinedCountWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[4].combinedModuleCountAfter,
            BASSovereignCodableExtensionWaveThreeDoctrine
                .combinedSovereignCount)
    }

    // MARK: - Entry 6 — BASOrchestration continuation wave 2 wire-ins

    func testEntry6OrchestrationContinuationWaveTwoMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[5].mNumberFirst,
            BASOrchestrationCodableExtensionContinuationWaveTwoDoctrine
                .extensionMNumber)
    }

    func testEntry6OrchestrationContinuationWaveTwoTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[5].typesExtended,
            BASOrchestrationCodableExtensionContinuationWaveTwoDoctrine
                .totalTypesExtended)
    }

    func testEntry6OrchestrationContinuationWaveTwoCombinedCountWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[5].combinedModuleCountAfter,
            BASOrchestrationCodableExtensionContinuationWaveTwoDoctrine
                .combinedOrchestrationCount)
    }

    // MARK: - Cross-catalog invariants

    func testFirstEntryMNumberMatchesRunStart() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries[0].mNumberFirst,
            BASGapFillHexaCompletionDoctrine
                .runFirstMNumber)
    }

    func testLastEntryMNumberIsChapter613EntryStart() {
        // Chapter 613 = M1829 entry,which is the
        // latest entry's first M-number。
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries.last!.mNumberFirst,
            1829)
    }
}
