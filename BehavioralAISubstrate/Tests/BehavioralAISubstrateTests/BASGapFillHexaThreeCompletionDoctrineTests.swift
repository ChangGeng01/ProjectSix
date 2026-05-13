// MARK: - BASGapFillHexaThreeCompletionDoctrineTests
// chapter 六百二十八 / M1890 — anti-drift PROOF tests for
//                              the M1889 3rd gap-fill
//                              hexa completion milestone
//
// ## Coverage (40 anti-drift PROOF tests)
//
// Identity (2) + entry counts incl。 6 kind buckets
// (10) + 6 per-entry identity pins (6) + aggregate
// accessor pins (7) + achievement flag pins (9) + ref
// pins (4) + EntryRecord Codable round-trip (1) +
// distinctModules cross-comparisons (1) = 40 tests。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:hexa #3 surface in replay-
//     determinism contract
//   - chapter 614 hexa #1 + 621 hexa #2 precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1889 → M1890

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaThreeCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .chapterTag,
            "chapter 六百二十八")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .milestoneMNumber,
            1889)
    }

    // MARK: - Entry count pins

    func testTotalEntries() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .totalEntries,
            6)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .entries.count,
            BASGapFillHexaThreeCompletionDoctrine
                .totalEntries)
    }

    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .entriesCountMatchesTotal)
    }

    // MARK: - 6 kind bucket pins

    func testCrossModuleTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .crossModuleTrioCount, 1)
    }

    func testNestedInActorPairCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .nestedInActorPairCount, 1)
    }

    func testRuntimeCoreSoloEnumCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .runtimeCoreSoloEnumCount, 1)
    }

    func testErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .errorTrioCount, 1)
    }

    func testMetalErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .metalErrorTrioCount, 1)
    }

    func testCrossModuleErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .crossModuleErrorTrioCount, 1)
    }

    func testKindBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .kindBucketsSumMatchesTotal)
    }

    // MARK: - Per-entry identity pins

    func testEntry1IsCrossModuleTrio() {
        let e =
            BASGapFillHexaThreeCompletionDoctrine
                .entries[0]
        XCTAssertEqual(e.chapterTag, "chapter 六百二十二")
        XCTAssertEqual(e.mNumberFirst, 1865)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind, "cross-module-trio")
        XCTAssertEqual(e.modulesTouched.count, 2)
    }

    func testEntry2IsObservabilityNestedPair() {
        let e =
            BASGapFillHexaThreeCompletionDoctrine
                .entries[1]
        XCTAssertEqual(e.chapterTag, "chapter 六百二十三")
        XCTAssertEqual(e.mNumberFirst, 1869)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.kind, "nested-in-actor-pair")
        XCTAssertEqual(
            e.modulesTouched, ["BASObservability"])
    }

    func testEntry3IsRuntimeCoreSoloEnum() {
        let e =
            BASGapFillHexaThreeCompletionDoctrine
                .entries[2]
        XCTAssertEqual(e.chapterTag, "chapter 六百二十四")
        XCTAssertEqual(e.mNumberFirst, 1873)
        XCTAssertEqual(e.typesExtended, 1)
        XCTAssertEqual(
            e.kind, "runtime-core-solo-enum")
        XCTAssertEqual(
            e.modulesTouched, ["BASRuntimeCore"])
    }

    func testEntry4IsHostKitErrorTrio() {
        let e =
            BASGapFillHexaThreeCompletionDoctrine
                .entries[3]
        XCTAssertEqual(e.chapterTag, "chapter 六百二十五")
        XCTAssertEqual(e.mNumberFirst, 1877)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind, "error-trio")
        XCTAssertEqual(
            e.modulesTouched, ["BASHostKit"])
    }

    func testEntry5IsMetalErrorTrio() {
        let e =
            BASGapFillHexaThreeCompletionDoctrine
                .entries[4]
        XCTAssertEqual(e.chapterTag, "chapter 六百二十六")
        XCTAssertEqual(e.mNumberFirst, 1881)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind, "metal-error-trio")
        XCTAssertEqual(
            e.modulesTouched, ["BASMetalSubstrate"])
    }

    func testEntry6IsCrossModuleErrorTrio() {
        let e =
            BASGapFillHexaThreeCompletionDoctrine
                .entries[5]
        XCTAssertEqual(e.chapterTag, "chapter 六百二十七")
        XCTAssertEqual(e.mNumberFirst, 1885)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "cross-module-error-trio")
        XCTAssertEqual(e.modulesTouched.count, 2)
    }

    // MARK: - Aggregate accessor pins

    func testTotalTypesExtendedAcrossEntriesIs15() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            15)
    }

    func testTotalCommitsAcrossEntriesIs24() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .totalCommitsAcrossEntries,
            24)
    }

    func testDistinctModulesTouchedIs7() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .distinctModulesTouched,
            7)
    }

    func testCrossModuleEntryCountIs2() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .crossModuleEntryCount,
            2)
    }

    func testErrorClusterEntryCountIs3() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .errorClusterEntryCount,
            3)
    }

    func testRunFirstMNumberIs1865() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .runFirstMNumber,
            1865)
    }

    func testRunLastMNumberIs1888() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .runLastMNumber,
            1888)
    }

    // MARK: - Achievement flag pins

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverageFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .allEntriesRealSubstrateChange)
    }

    func testAllEntriesUsedFourKnifeCadenceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .allEntriesUsedFourKnifeCadence)
    }

    func testRunIsContiguousFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .runIsContiguous)
    }

    func testEveryKindAppearsExactlyOnceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .everyKindAppearsExactlyOnce)
    }

    func testDistinctModulesExceedsPriorHexasFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .distinctModulesExceedsPriorHexas)
    }

    func testRunCrossesM1880RoundMilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .runCrossesM1880RoundMilestone)
    }

    func testIsPastM1880MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .isPastM1880Milestone)
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .isPastM1800Milestone)
    }

    // MARK: - Reference pins

    func testPriorGapFillHexaOneRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .priorGapFillHexaOneRef,
            "BASGapFillHexaCompletionDoctrine")
    }

    func testPriorGapFillHexaTwoRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .priorGapFillHexaTwoRef,
            "BASGapFillHexaTwoCompletionDoctrine")
    }

    func testPriorPostOctaHexaRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .priorPostOctaHexaRef,
            "BASPostOctaModuleExtensionHexaCompletionDoctrine")
    }

    func testPriorOctaMilestoneRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaThreeCompletionDoctrine
                .priorOctaMilestoneRef,
            "BASCodableExtensionOctaMilestoneCompletionDoctrine")
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaThreeCompletionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }

    // MARK: - EntryRecord Codable round-trip

    func testEntryRecordIsCodable() throws {
        let entry =
            BASGapFillHexaThreeCompletionDoctrine
                .entries[5]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASGapFillHexaThreeCompletionDoctrine
                .EntryRecord.self,
            from: data)
        XCTAssertEqual(decoded, entry)
    }
}
