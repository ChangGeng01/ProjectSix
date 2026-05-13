// MARK: - BASGapFillHexaFourCompletionDoctrineTests
// chapter 六百三十五 / M1918 — anti-drift PROOF tests for
//                              the M1917 4th gap-fill
//                              hexa completion milestone
//
// ## Coverage (~42 anti-drift PROOF tests)
//
// Identity (2) + entry counts incl。 6 kind buckets
// (10) + 6 per-entry identity pins (6) + aggregate
// accessor pins (7) + achievement flag pins (12) + ref
// pins (5) + EntryRecord Codable round-trip (1) = 43.
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:hexa #4 surface in replay-
//     determinism contract
//   - chapter 614 hexa #1 + 621 hexa #2 + 628 hexa #3
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1917 → M1918

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaFourCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .chapterTag,
            "chapter 六百三十五")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .milestoneMNumber,
            1917)
    }

    // MARK: - Entry count pins

    func testTotalEntries() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .totalEntries,
            6)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .entries.count,
            BASGapFillHexaFourCompletionDoctrine
                .totalEntries)
    }

    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .entriesCountMatchesTotal)
    }

    // MARK: - 6 kind bucket pins

    func testMemorySQLiteErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .memorySQLiteErrorTrioCount, 1)
    }

    func testMetalBiomimeticErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .metalBiomimeticErrorTrioCount, 1)
    }

    func testMemoryPipelineErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .memoryPipelineErrorTrioCount, 1)
    }

    func testCrossModuleBCMHPCScheduleErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .crossModuleBCMHPCScheduleErrorTrioCount,
            1)
    }

    func testSovereignErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .sovereignErrorTrioCount, 1)
    }

    func testOrganObservabilityOrchestrationErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .organObservabilityOrchestrationErrorTrioCount,
            1)
    }

    func testKindBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .kindBucketsSumMatchesTotal)
    }

    // MARK: - Per-entry identity pins

    func testEntry1IsMemorySQLiteErrorTrio() {
        let e =
            BASGapFillHexaFourCompletionDoctrine
                .entries[0]
        XCTAssertEqual(e.chapterTag, "chapter 六百二十九")
        XCTAssertEqual(e.mNumberFirst, 1893)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "memory-sqlite-error-trio")
        XCTAssertEqual(e.modulesTouched, ["BASMemory"])
    }

    func testEntry2IsMetalBiomimeticErrorTrio() {
        let e =
            BASGapFillHexaFourCompletionDoctrine
                .entries[1]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十")
        XCTAssertEqual(e.mNumberFirst, 1897)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "metal-biomimetic-error-trio")
        XCTAssertEqual(
            e.modulesTouched, ["BASMetalSubstrate"])
    }

    func testEntry3IsMemoryPipelineErrorTrio() {
        let e =
            BASGapFillHexaFourCompletionDoctrine
                .entries[2]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十一")
        XCTAssertEqual(e.mNumberFirst, 1901)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "memory-pipeline-error-trio")
        XCTAssertEqual(e.modulesTouched, ["BASMemory"])
    }

    func testEntry4IsCrossModuleBCMHPCScheduleErrorTrio() {
        let e =
            BASGapFillHexaFourCompletionDoctrine
                .entries[3]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十二")
        XCTAssertEqual(e.mNumberFirst, 1905)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind,
            "cross-module-bcm-hpc-schedule-error-trio")
        XCTAssertEqual(e.modulesTouched.count, 2)
    }

    func testEntry5IsSovereignErrorTrio() {
        let e =
            BASGapFillHexaFourCompletionDoctrine
                .entries[4]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十三")
        XCTAssertEqual(e.mNumberFirst, 1909)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind, "sovereign-error-trio")
        XCTAssertEqual(
            e.modulesTouched, ["BASSovereign"])
    }

    func testEntry6IsOrganObservabilityOrchestrationErrorTrio() {
        let e =
            BASGapFillHexaFourCompletionDoctrine
                .entries[5]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十四")
        XCTAssertEqual(e.mNumberFirst, 1913)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind,
            "organ-observability-orchestration-error-trio")
        XCTAssertEqual(e.modulesTouched.count, 3)
    }

    // MARK: - Aggregate accessor pins

    func testTotalTypesExtendedAcrossEntriesIs18() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            18)
    }

    func testTotalCommitsAcrossEntriesIs24() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .totalCommitsAcrossEntries,
            24)
    }

    func testDistinctModulesTouchedIs7() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .distinctModulesTouched,
            7)
    }

    func testCrossModuleEntryCountIs2() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .crossModuleEntryCount,
            2)
    }

    func testErrorClusterEntryCountIs6() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .errorClusterEntryCount,
            6)
    }

    func testRunFirstMNumberIs1893() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .runFirstMNumber,
            1893)
    }

    func testRunLastMNumberIs1916() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .runLastMNumber,
            1916)
    }

    // MARK: - Achievement flag pins

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverageFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .allEntriesRealSubstrateChange)
    }

    func testAllEntriesUsedFourKnifeCadenceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .allEntriesUsedFourKnifeCadence)
    }

    func testRunIsContiguousFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .runIsContiguous)
    }

    func testEveryKindAppearsExactlyOnceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .everyKindAppearsExactlyOnce)
    }

    func testIsAllErrorTrioHexaFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .isAllErrorTrioHexa)
    }

    func testDistinctModulesMatchesPriorHexaThreeFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .distinctModulesMatchesPriorHexaThree)
    }

    func testRunCrossesM1900RoundMilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .runCrossesM1900RoundMilestone)
    }

    func testRunCrosses500ByteEqualityMilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .runCrosses500ByteEqualityMilestone)
    }

    func testIsPastM1900MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .isPastM1900Milestone)
    }

    func testIsPastFiveHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .isPastFiveHundredConsecutiveByteEqual)
    }

    // MARK: - Reference pins

    func testPriorGapFillHexaOneRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .priorGapFillHexaOneRef,
            "BASGapFillHexaCompletionDoctrine")
    }

    func testPriorGapFillHexaTwoRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .priorGapFillHexaTwoRef,
            "BASGapFillHexaTwoCompletionDoctrine")
    }

    func testPriorGapFillHexaThreeRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .priorGapFillHexaThreeRef,
            "BASGapFillHexaThreeCompletionDoctrine")
    }

    func testPriorPostOctaHexaRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .priorPostOctaHexaRef,
            "BASPostOctaModuleExtensionHexaCompletionDoctrine")
    }

    func testPriorOctaMilestoneRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFourCompletionDoctrine
                .priorOctaMilestoneRef,
            "BASCodableExtensionOctaMilestoneCompletionDoctrine")
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFourCompletionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }

    // MARK: - EntryRecord Codable round-trip

    func testEntryRecordIsCodable() throws {
        let entry =
            BASGapFillHexaFourCompletionDoctrine
                .entries[5]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASGapFillHexaFourCompletionDoctrine
                .EntryRecord.self,
            from: data)
        XCTAssertEqual(decoded, entry)
    }
}
