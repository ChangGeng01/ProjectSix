// MARK: - BASGapFillHexaCompletionDoctrineTests
// chapter 六百一十四 / M1834 — anti-drift PROOF tests for
//                              the M1833 gap-fill hexa
//                              completion milestone
//
// ## Coverage (35 anti-drift PROOF tests)
//
// Identity (2) + entry counts incl。 5 kind buckets + 2
// nesting buckets (10) + 6 per-entry identity pins (6)
// + 6 aggregate-accessor pins (6) + 7 achievement flags
// (7) + 2 prior-snapshot refs (2) + EntryRecord Codable
// round-trip (1) + run M-number bounds (2) = 36 tests。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:hexa surface in replay-
//     determinism contract
//   - chapter 607 post-octa hexa precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1833 → M1834

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .chapterTag,
            "chapter 六百一十四")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .milestoneMNumber,
            1833)
    }

    // MARK: - Entry count pins

    func testTotalEntries() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .totalEntries,
            6)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .entries.count,
            BASGapFillHexaCompletionDoctrine
                .totalEntries)
    }

    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .entriesCountMatchesTotal)
    }

    // MARK: - Kind bucket pins (5 kinds)

    func testChainDependencySweepCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .chainDependencySweepCount,
            1)
    }

    func testWaveTwoCountIsTwo() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .waveTwoCount,
            2)
    }

    func testWaveThreeCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .waveThreeCount,
            1)
    }

    func testContinuationCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .continuationCount,
            1)
    }

    func testContinuationWaveTwoCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .continuationWaveTwoCount,
            1)
    }

    func testKindBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .kindBucketsSumMatchesTotal)
    }

    // MARK: - Nesting bucket pins

    func testNestedTypesEntryCountIsThree() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .nestedTypesEntryCount,
            3)
    }

    func testTopLevelTypesEntryCountIsThree() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .topLevelTypesEntryCount,
            3)
    }

    func testNestingBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .nestingBucketsSumMatchesTotal)
    }

    // MARK: - Per-entry identity pins

    func testEntry1IsBASHostKitMeshSweep() {
        let e =
            BASGapFillHexaCompletionDoctrine
                .entries[0]
        XCTAssertEqual(e.module, "BASHostKit")
        XCTAssertEqual(e.mNumberFirst, 1809)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.combinedModuleCountAfter, 44)
        XCTAssertEqual(
            e.kind,
            "chain-dependency-sweep")
        XCTAssertFalse(e.typesAreNested)
    }

    func testEntry2IsBASOrganWaveTwo() {
        let e =
            BASGapFillHexaCompletionDoctrine
                .entries[1]
        XCTAssertEqual(e.module, "BASOrgan")
        XCTAssertEqual(e.mNumberFirst, 1813)
        XCTAssertEqual(e.typesExtended, 1)
        XCTAssertEqual(e.combinedModuleCountAfter, 3)
        XCTAssertEqual(e.kind, "wave-2")
        XCTAssertFalse(e.typesAreNested)
    }

    func testEntry3IsBASOrchestrationContinuation() {
        let e =
            BASGapFillHexaCompletionDoctrine
                .entries[2]
        XCTAssertEqual(e.module, "BASOrchestration")
        XCTAssertEqual(e.mNumberFirst, 1817)
        XCTAssertEqual(e.typesExtended, 1)
        XCTAssertEqual(e.combinedModuleCountAfter, 13)
        XCTAssertEqual(e.kind, "continuation")
        XCTAssertFalse(e.typesAreNested)
    }

    func testEntry4IsBASSovereignWaveTwo() {
        let e =
            BASGapFillHexaCompletionDoctrine
                .entries[3]
        XCTAssertEqual(e.module, "BASSovereign")
        XCTAssertEqual(e.mNumberFirst, 1821)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.combinedModuleCountAfter, 6)
        XCTAssertEqual(e.kind, "wave-2")
        XCTAssertTrue(e.typesAreNested)
    }

    func testEntry5IsBASSovereignWaveThree() {
        let e =
            BASGapFillHexaCompletionDoctrine
                .entries[4]
        XCTAssertEqual(e.module, "BASSovereign")
        XCTAssertEqual(e.mNumberFirst, 1825)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.combinedModuleCountAfter, 8)
        XCTAssertEqual(e.kind, "wave-3")
        XCTAssertTrue(e.typesAreNested)
    }

    func testEntry6IsBASOrchestrationContinuationWaveTwo() {
        let e =
            BASGapFillHexaCompletionDoctrine
                .entries[5]
        XCTAssertEqual(e.module, "BASOrchestration")
        XCTAssertEqual(e.mNumberFirst, 1829)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.combinedModuleCountAfter, 15)
        XCTAssertEqual(
            e.kind,
            "continuation-wave-2")
        XCTAssertTrue(e.typesAreNested)
    }

    // MARK: - Aggregate accessor pins

    func testTotalTypesExtendedAcrossEntriesIs11() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            11)
    }

    func testTotalCommitsAcrossEntriesIs24() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .totalCommitsAcrossEntries,
            24)
    }

    func testDistinctModulesTouchedIsFour() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .distinctModulesTouched,
            4)
    }

    func testRunFirstMNumberIs1809() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .runFirstMNumber,
            1809)
    }

    func testRunLastMNumberIs1832() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .runLastMNumber,
            1832)
    }

    // MARK: - Achievement flag pins

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverageFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .allEntriesRealSubstrateChange)
    }

    func testAllEntriesUsedFourKnifeCadenceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .allEntriesUsedFourKnifeCadence)
    }

    func testRunIsContiguousFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .runIsContiguous)
    }

    func testRunCrossesFourHundredMilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .runCrossesFourHundredMilestone)
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .isPastM1800Milestone)
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaCompletionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }

    // MARK: - Reference pins

    func testPriorPostOctaHexaRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .priorPostOctaHexaRef,
            "BASPostOctaModuleExtensionHexaCompletionDoctrine")
    }

    func testPriorOctaMilestoneRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaCompletionDoctrine
                .priorOctaMilestoneRef,
            "BASCodableExtensionOctaMilestoneCompletionDoctrine")
    }

    // MARK: - EntryRecord Codable round-trip

    func testEntryRecordIsCodable() throws {
        let entry =
            BASGapFillHexaCompletionDoctrine
                .entries[5]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASGapFillHexaCompletionDoctrine
                .EntryRecord.self,
            from: data)
        XCTAssertEqual(decoded, entry)
    }
}
