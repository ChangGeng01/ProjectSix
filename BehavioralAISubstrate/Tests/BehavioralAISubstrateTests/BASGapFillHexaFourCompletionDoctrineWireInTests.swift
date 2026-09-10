// MARK: - BASGapFillHexaFourCompletionDoctrineWireInTests
// chapter 六百三十五 / M1919 — wire-in PROOF tests cross-
//                              checking the M1917 hexa
//                              #4 catalog against the 6
//                              source per-entry
//                              extension doctrines
//
// ## Coverage (15 wire-in PROOF tests)
//
// For each of the 6 entries:
//   1. hexa #4's mNumberFirst matches source
//      doctrine's extensionMNumber
//   2. hexa #4's typesExtended matches source
//      doctrine's totalTypesExtended
//
// = 12 per-entry wire-in tests。
//
// Plus 3 cross-catalog invariants:
//   - hexa #4 totalEntries (6) matches hexa #1+#2+#3 (6
//     each)
//   - hexa #4 distinctModulesTouched (7) MATCHES hexa #3
//     (7) and EXCEEDS hexa #1+#2 (4 each)
//   - hexa #4 totalTypesExtendedAcrossEntries (18)
//     EXCEEDS hexa #1 (11) + hexa #2 (14) + hexa #3 (15)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1918 → M1919

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaFourCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - Entry 1 — memory-sqlite-error-trio

    func testEntry1MemorySQLiteErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[0].mNumberFirst,
            BASMemorySQLiteErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry1MemorySQLiteErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[0].typesExtended,
            BASMemorySQLiteErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 2 — metal-biomimetic-error-trio

    func testEntry2MetalBiomimeticErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[1].mNumberFirst,
            BASMetalSubstrateMetalBiomimeticErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry2MetalBiomimeticErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[1].typesExtended,
            BASMetalSubstrateMetalBiomimeticErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 3 — memory-pipeline-error-trio

    func testEntry3MemoryPipelineErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[2].mNumberFirst,
            BASMemoryPipelineErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry3MemoryPipelineErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[2].typesExtended,
            BASMemoryPipelineErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 4 — cross-module-bcm-hpc-schedule-error-trio

    func testEntry4CrossModuleBCMHPCScheduleErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[3].mNumberFirst,
            BASCrossModuleBCMHPCScheduleErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry4CrossModuleBCMHPCScheduleErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[3].typesExtended,
            BASCrossModuleBCMHPCScheduleErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 5 — sovereign-error-trio

    func testEntry5SovereignErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[4].mNumberFirst,
            BASSovereignErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry5SovereignErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[4].typesExtended,
            BASSovereignErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 6 — organ-observability-orchestration-error-trio

    func testEntry6OrganObservabilityOrchestrationErrorTrioMNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[5].mNumberFirst,
            BASOrganObservabilityOrchestrationErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry6OrganObservabilityOrchestrationErrorTrioTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries[5].typesExtended,
            BASOrganObservabilityOrchestrationErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Cross-catalog invariants

    func testHexaFourTotalEntriesMatchesPriorHexas() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .totalEntries,
            BASGapFillHexaCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .totalEntries,
            BASGapFillHexaTwoCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .totalEntries,
            BASGapFillHexaThreeCompletionDoctrine
                .totalEntries)
    }

    func testHexaFourDistinctModulesMatchesHexaThreeAndExceedsPriors() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaThreeCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertGreaterThan(
            BASGapFillHexaFourCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertGreaterThan(
            BASGapFillHexaFourCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaTwoCompletionDoctrine
                .distinctModulesTouched)
    }

    func testHexaFourTotalTypesExceedsAllPriorHexas() {
        XCTAssertGreaterThan(
            BASGapFillHexaFourCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        XCTAssertGreaterThan(
            BASGapFillHexaFourCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaTwoCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        XCTAssertGreaterThan(
            BASGapFillHexaFourCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaThreeCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
    }
}
