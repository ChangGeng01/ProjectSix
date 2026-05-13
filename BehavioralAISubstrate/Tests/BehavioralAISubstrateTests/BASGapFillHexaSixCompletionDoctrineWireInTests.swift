// MARK: - BASGapFillHexaSixCompletionDoctrineWireInTests
// chapter 六百四十九 / M1975 — wire-in PROOF tests cross-
//                              checking the M1973 hexa
//                              #6 catalog against the 6
//                              source per-entry
//                              extension doctrines

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaSixCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - Entry 1 — sovereign-clock-tree-typed-trio

    func testEntry1MNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[0]
                .mNumberFirst,
            BASSovereignClockTreeTypedTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry1TypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[0]
                .typesExtended,
            BASSovereignClockTreeTypedTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 2 — sovereign-snapshot-token-struct-trio

    func testEntry2MNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[1]
                .mNumberFirst,
            BASSovereignSnapshotTokenStructTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry2TypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[1]
                .typesExtended,
            BASSovereignSnapshotTokenStructTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 3 — sovereign-contamination-guard-trio

    func testEntry3MNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[2]
                .mNumberFirst,
            BASSovereignContaminationGuardTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry3TypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[2]
                .typesExtended,
            BASSovereignContaminationGuardTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 4 — sovereign-trust-record-trio

    func testEntry4MNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[3]
                .mNumberFirst,
            BASSovereignTrustRecordTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry4TypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[3]
                .typesExtended,
            BASSovereignTrustRecordTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 5 — sovereign-privilege-scan-trio

    func testEntry5MNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[4]
                .mNumberFirst,
            BASSovereignPrivilegeScanTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry5TypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[4]
                .typesExtended,
            BASSovereignPrivilegeScanTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Entry 6 — sovereign-tertiary-error-trio

    func testEntry6MNumberWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[5]
                .mNumberFirst,
            BASSovereignTertiaryErrorTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testEntry6TypesExtendedWiresIn() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine.entries[5]
                .typesExtended,
            BASSovereignTertiaryErrorTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Cross-catalog invariants

    func testHexaSixTotalEntriesMatchesPriorHexas() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalEntries,
            BASGapFillHexaCompletionDoctrine.totalEntries)
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalEntries,
            BASGapFillHexaTwoCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalEntries,
            BASGapFillHexaThreeCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalEntries,
            BASGapFillHexaFourCompletionDoctrine
                .totalEntries)
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalEntries,
            BASGapFillHexaFiveCompletionDoctrine
                .totalEntries)
    }

    func testHexaSixDistinctModulesIsOneAndFewerThanAllPriors() {
        // hexa #6 = 1 (entirely BASSovereign)
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .distinctModulesTouched, 1)
        // All prior hexas had 4+ modules
        XCTAssertLessThan(
            BASGapFillHexaSixCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertLessThan(
            BASGapFillHexaSixCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaTwoCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertLessThan(
            BASGapFillHexaSixCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaThreeCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertLessThan(
            BASGapFillHexaSixCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaFourCompletionDoctrine
                .distinctModulesTouched)
        XCTAssertLessThan(
            BASGapFillHexaSixCompletionDoctrine
                .distinctModulesTouched,
            BASGapFillHexaFiveCompletionDoctrine
                .distinctModulesTouched)
    }

    func testHexaSixTotalTypesMatchesHexaFourFiveAndExceedsEarlier() {
        // hexa #6 = 18 == hexa #4 = 18 == hexa #5 = 18
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaFourCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaFiveCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        // hexa #6 = 18 > hexa #1 = 11, hexa #2 = 14, hexa #3 = 15
        XCTAssertGreaterThan(
            BASGapFillHexaSixCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        XCTAssertGreaterThan(
            BASGapFillHexaSixCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaTwoCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
        XCTAssertGreaterThan(
            BASGapFillHexaSixCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            BASGapFillHexaThreeCompletionDoctrine
                .totalTypesExtendedAcrossEntries)
    }
}
