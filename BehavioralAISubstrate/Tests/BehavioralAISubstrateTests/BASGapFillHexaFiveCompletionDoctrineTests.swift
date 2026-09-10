// MARK: - BASGapFillHexaFiveCompletionDoctrineTests
// chapter 六百四十二 / M1946 — anti-drift PROOF tests for
//                              the M1945 5th gap-fill
//                              hexa completion milestone
//
// ## Coverage (~46 anti-drift PROOF tests)
//
// Identity (2) + entry counts incl。 6 kind buckets
// (10) + 6 per-entry identity pins (6) + aggregate
// accessor pins (8) + achievement flag pins (13) + ref
// pins (6) + EntryRecord Codable round-trip (1).
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - chapter 三百九二:hexa #5 surface in replay-
//     determinism contract
//   - chapter 614 + 621 + 628 + 635 hexa #1+#2+#3+#4
//     precedents
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1945 → M1946

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaFiveCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .chapterTag,
            "chapter 六百四十二")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .milestoneMNumber,
            1945)
    }

    // MARK: - Entry count pins

    func testTotalEntries() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .totalEntries,
            6)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .entries.count,
            BASGapFillHexaFiveCompletionDoctrine
                .totalEntries)
    }

    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .entriesCountMatchesTotal)
    }

    // MARK: - 6 kind bucket pins

    func testWorldPriorCoreMLErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .worldPriorCoreMLErrorTrioCount, 1)
    }

    func testRuntimeCoreSQLiteErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .runtimeCoreSQLiteErrorTrioCount, 1)
    }

    func testSovereignSecondaryErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .sovereignSecondaryErrorTrioCount, 1)
    }

    func testOrganToolFeatureErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .organToolFeatureErrorTrioCount, 1)
    }

    func testRuntimeStepEnumTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .runtimeStepEnumTrioCount, 1)
    }

    func testCategorizationEnumTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .categorizationEnumTrioCount, 1)
    }

    func testKindBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .kindBucketsSumMatchesTotal)
    }

    // MARK: - Per-entry identity pins

    func testEntry1IsWorldPriorCoreMLErrorTrio() {
        let e =
            BASGapFillHexaFiveCompletionDoctrine
                .entries[0]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十六")
        XCTAssertEqual(e.mNumberFirst, 1921)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "world-prior-coreml-error-trio")
        XCTAssertEqual(e.modulesTouched.count, 2)
    }

    func testEntry2IsRuntimeCoreSQLiteErrorTrio() {
        let e =
            BASGapFillHexaFiveCompletionDoctrine
                .entries[1]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十七")
        XCTAssertEqual(e.mNumberFirst, 1925)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "runtime-core-sqlite-error-trio")
        XCTAssertEqual(
            e.modulesTouched, ["BASRuntimeCore"])
    }

    func testEntry3IsSovereignSecondaryErrorTrio() {
        let e =
            BASGapFillHexaFiveCompletionDoctrine
                .entries[2]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十八")
        XCTAssertEqual(e.mNumberFirst, 1929)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "sovereign-secondary-error-trio")
        XCTAssertEqual(
            e.modulesTouched, ["BASSovereign"])
    }

    func testEntry4IsOrganToolFeatureErrorTrio() {
        let e =
            BASGapFillHexaFiveCompletionDoctrine
                .entries[3]
        XCTAssertEqual(e.chapterTag, "chapter 六百三十九")
        XCTAssertEqual(e.mNumberFirst, 1933)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "organ-tool-feature-error-trio")
        XCTAssertEqual(e.modulesTouched.count, 2)
    }

    func testEntry5IsRuntimeStepEnumTrio() {
        let e =
            BASGapFillHexaFiveCompletionDoctrine
                .entries[4]
        XCTAssertEqual(e.chapterTag, "chapter 六百四十")
        XCTAssertEqual(e.mNumberFirst, 1937)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "runtime-step-enum-trio")
        XCTAssertEqual(e.modulesTouched.count, 3)
    }

    func testEntry6IsCategorizationEnumTrio() {
        let e =
            BASGapFillHexaFiveCompletionDoctrine
                .entries[5]
        XCTAssertEqual(e.chapterTag, "chapter 六百四十一")
        XCTAssertEqual(e.mNumberFirst, 1941)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(
            e.kind, "categorization-enum-trio")
        XCTAssertEqual(e.modulesTouched.count, 2)
    }

    // MARK: - Aggregate accessor pins

    func testTotalTypesExtendedAcrossEntriesIs18() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            18)
    }

    func testTotalCommitsAcrossEntriesIs24() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .totalCommitsAcrossEntries,
            24)
    }

    func testDistinctModulesTouchedIs6() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .distinctModulesTouched,
            6)
    }

    func testCrossModuleEntryCountIs4() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .crossModuleEntryCount,
            4)
    }

    func testErrorTrioVariantCountIs4() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .errorTrioVariantCount,
            4)
    }

    func testNonErrorTrioVariantCountIs2() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .nonErrorTrioVariantCount,
            2)
    }

    func testRunFirstMNumberIs1921() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .runFirstMNumber,
            1921)
    }

    func testRunLastMNumberIs1944() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .runLastMNumber,
            1944)
    }

    // MARK: - Achievement flag pins

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverageFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .allEntriesRealSubstrateChange)
    }

    func testAllEntriesUsedFourKnifeCadenceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .allEntriesUsedFourKnifeCadence)
    }

    func testRunIsContiguousFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .runIsContiguous)
    }

    func testEveryKindAppearsExactlyOnceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .everyKindAppearsExactlyOnce)
    }

    func testIsFirstMixedErrorAndNonErrorHexaFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .isFirstMixedErrorAndNonErrorHexa)
    }

    func testIsFirstBASWorldPriorHexaCoverageFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .isFirstBASWorldPriorHexaCoverage)
    }

    func testDistinctModulesOneFewerThanHexaFourFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .distinctModulesOneFewerThanHexaFour)
    }

    func testRunCrosses500ByteEqualityMilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .runCrosses500ByteEqualityMilestone)
    }

    func testIsPastM1900MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .isPastM1900Milestone)
    }

    func testIsPastFiveHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .isPastFiveHundredConsecutiveByteEqual)
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    // MARK: - Reference pins

    func testPriorGapFillHexaOneRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .priorGapFillHexaOneRef,
            "BASGapFillHexaCompletionDoctrine")
    }

    func testPriorGapFillHexaTwoRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .priorGapFillHexaTwoRef,
            "BASGapFillHexaTwoCompletionDoctrine")
    }

    func testPriorGapFillHexaThreeRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .priorGapFillHexaThreeRef,
            "BASGapFillHexaThreeCompletionDoctrine")
    }

    func testPriorGapFillHexaFourRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .priorGapFillHexaFourRef,
            "BASGapFillHexaFourCompletionDoctrine")
    }

    func testPriorPostOctaHexaRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .priorPostOctaHexaRef,
            "BASPostOctaModuleExtensionHexaCompletionDoctrine")
    }

    func testPriorOctaMilestoneRefPointsCorrectly() {
        XCTAssertEqual(
            BASGapFillHexaFiveCompletionDoctrine
                .priorOctaMilestoneRef,
            "BASCodableExtensionOctaMilestoneCompletionDoctrine")
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .isPastM1800Milestone)
    }

    func testIsPastM1880MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .isPastM1880Milestone)
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaFiveCompletionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }

    // MARK: - EntryRecord Codable round-trip

    func testEntryRecordIsCodable() throws {
        let entry =
            BASGapFillHexaFiveCompletionDoctrine
                .entries[5]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASGapFillHexaFiveCompletionDoctrine
                .EntryRecord.self,
            from: data)
        XCTAssertEqual(decoded, entry)
    }
}
