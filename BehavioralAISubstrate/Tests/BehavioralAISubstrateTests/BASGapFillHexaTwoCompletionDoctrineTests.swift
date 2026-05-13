// MARK: - BASGapFillHexaTwoCompletionDoctrineTests
// chapter 六百二十一 / M1862 — anti-drift PROOF tests for
//                              the M1861 2nd gap-fill
//                              hexa completion milestone
//
// ## Coverage (40 anti-drift PROOF tests)
//
// Identity (2) + entry counts incl。 6 kind buckets +
// 2 nesting buckets (11) + 6 per-entry identity pins
// (6) + 6 aggregate-accessor pins (5) + 8 achievement
// flags (8) + 3 prior-snapshot refs (3) + EntryRecord
// Codable round-trip (1) + run M-number bounds (2) +
// distinctModulesMatchesHexaOne (1) + every kind
// appears exactly once (1) = 40 tests。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:hexa #2 surface in replay-
//     determinism contract
//   - chapter 614 gap-fill hexa #1 precedent
//   - chapter 607 post-octa hexa precedent
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1861 → M1862

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaTwoCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .chapterTag,
            "chapter 六百二十一")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .milestoneMNumber,
            1861)
    }

    // MARK: - Entry count pins

    func testTotalEntries() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .totalEntries,
            6)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .entries.count,
            BASGapFillHexaTwoCompletionDoctrine
                .totalEntries)
    }

    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .entriesCountMatchesTotal)
    }

    // MARK: - 6 kind bucket pins (each appears once)

    func testContinuationCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .continuationCount, 1)
    }

    func testWaveThreeCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .waveThreeCount, 1)
    }

    func testWaveFourCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .waveFourCount, 1)
    }

    func testWaveFiveCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .waveFiveCount, 1)
    }

    func testPostTrilogyCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .postTrilogyCount, 1)
    }

    func testPostMeshSweepCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .postMeshSweepCount, 1)
    }

    func testKindBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .kindBucketsSumMatchesTotal)
    }

    // MARK: - Nesting bucket pins

    func testNestedTypesEntryCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .nestedTypesEntryCount,
            1)
    }

    func testTopLevelTypesEntryCountIsFive() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .topLevelTypesEntryCount,
            5)
    }

    func testNestingBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .nestingBucketsSumMatchesTotal)
    }

    // MARK: - Per-entry identity pins

    func testEntry1IsBASLeaseLifeContinuation() {
        let e =
            BASGapFillHexaTwoCompletionDoctrine
                .entries[0]
        XCTAssertEqual(e.module, "BASLeaseLife")
        XCTAssertEqual(e.mNumberFirst, 1837)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.kind, "continuation")
        XCTAssertTrue(e.typesAreNested)
    }

    func testEntry2IsBASOrganWaveThree() {
        let e =
            BASGapFillHexaTwoCompletionDoctrine
                .entries[1]
        XCTAssertEqual(e.module, "BASOrgan")
        XCTAssertEqual(e.mNumberFirst, 1841)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.kind, "wave-3")
        XCTAssertFalse(e.typesAreNested)
    }

    func testEntry3IsBASOrganWaveFour() {
        let e =
            BASGapFillHexaTwoCompletionDoctrine
                .entries[2]
        XCTAssertEqual(e.module, "BASOrgan")
        XCTAssertEqual(e.mNumberFirst, 1845)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind, "wave-4")
        XCTAssertFalse(e.typesAreNested)
    }

    func testEntry4IsBASOrganWaveFive() {
        let e =
            BASGapFillHexaTwoCompletionDoctrine
                .entries[3]
        XCTAssertEqual(e.module, "BASOrgan")
        XCTAssertEqual(e.mNumberFirst, 1849)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.kind, "wave-5")
        XCTAssertFalse(e.typesAreNested)
    }

    func testEntry5IsBASMemoryPostTrilogy() {
        let e =
            BASGapFillHexaTwoCompletionDoctrine
                .entries[4]
        XCTAssertEqual(e.module, "BASMemory")
        XCTAssertEqual(e.mNumberFirst, 1853)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind, "post-trilogy")
        XCTAssertFalse(e.typesAreNested)
    }

    func testEntry6IsBASHostKitPostMeshSweep() {
        let e =
            BASGapFillHexaTwoCompletionDoctrine
                .entries[5]
        XCTAssertEqual(e.module, "BASHostKit")
        XCTAssertEqual(e.mNumberFirst, 1857)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.kind, "post-mesh-sweep")
        XCTAssertFalse(e.typesAreNested)
    }

    // MARK: - Aggregate accessor pins

    func testTotalTypesExtendedAcrossEntriesIs14() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            14)
    }

    func testTotalCommitsAcrossEntriesIs24() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .totalCommitsAcrossEntries,
            24)
    }

    func testDistinctModulesTouchedIsFour() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .distinctModulesTouched,
            4)
    }

    func testRunFirstMNumberIs1837() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .runFirstMNumber,
            1837)
    }

    func testRunLastMNumberIs1860() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .runLastMNumber,
            1860)
    }

    // MARK: - Achievement flag pins

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverageFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .allEntriesRealSubstrateChange)
    }

    func testAllEntriesUsedFourKnifeCadenceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .allEntriesUsedFourKnifeCadence)
    }

    func testRunIsContiguousFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .runIsContiguous)
    }

    func testEveryKindAppearsExactlyOnceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .everyKindAppearsExactlyOnce)
    }

    func testDistinctModulesMatchesHexaOneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .distinctModulesMatchesHexaOne)
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .isPastM1800Milestone)
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaTwoCompletionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }

    // MARK: - Reference pins

    func testPriorGapFillHexaRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .priorGapFillHexaRef,
            "BASGapFillHexaCompletionDoctrine")
    }

    func testPriorPostOctaHexaRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .priorPostOctaHexaRef,
            "BASPostOctaModuleExtensionHexaCompletionDoctrine")
    }

    func testPriorOctaMilestoneRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaTwoCompletionDoctrine
                .priorOctaMilestoneRef,
            "BASCodableExtensionOctaMilestoneCompletionDoctrine")
    }

    // MARK: - EntryRecord Codable round-trip

    func testEntryRecordIsCodable() throws {
        let entry =
            BASGapFillHexaTwoCompletionDoctrine
                .entries[5]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASGapFillHexaTwoCompletionDoctrine
                .EntryRecord.self,
            from: data)
        XCTAssertEqual(decoded, entry)
    }
}
