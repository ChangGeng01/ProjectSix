// MARK: - BASGapFillHexaSixCompletionDoctrineTests
// chapter 六百四十九 / M1974 — anti-drift PROOF tests for
//                              the M1973 hexa #6 catalog

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaSixCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .chapterTag, "chapter 六百四十九")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .milestoneMNumber, 1973)
    }

    // MARK: - Entry count pins

    func testTotalEntries() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalEntries, 6)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .entries.count,
            BASGapFillHexaSixCompletionDoctrine.totalEntries)
    }

    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .entriesCountMatchesTotal)
    }

    // MARK: - 6 kind bucket pins

    func testSovereignClockTreeTypedTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .sovereignClockTreeTypedTrioCount, 1)
    }

    func testSovereignSnapshotTokenStructTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .sovereignSnapshotTokenStructTrioCount, 1)
    }

    func testSovereignContaminationGuardTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .sovereignContaminationGuardTrioCount, 1)
    }

    func testSovereignTrustRecordTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .sovereignTrustRecordTrioCount, 1)
    }

    func testSovereignPrivilegeScanTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .sovereignPrivilegeScanTrioCount, 1)
    }

    func testSovereignTertiaryErrorTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .sovereignTertiaryErrorTrioCount, 1)
    }

    func testKindBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .kindBucketsSumMatchesTotal)
    }

    // MARK: - Per-entry identity pins

    func testEntry1IsSovereignClockTreeTypedTrio() {
        let e = BASGapFillHexaSixCompletionDoctrine.entries[0]
        XCTAssertEqual(e.chapterTag, "chapter 六百四十三")
        XCTAssertEqual(e.mNumberFirst, 1949)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind,
            "sovereign-clock-tree-typed-trio")
        XCTAssertEqual(e.modulesTouched, ["BASSovereign"])
    }

    func testEntry2IsSovereignSnapshotTokenStructTrio() {
        let e = BASGapFillHexaSixCompletionDoctrine.entries[1]
        XCTAssertEqual(e.chapterTag, "chapter 六百四十四")
        XCTAssertEqual(e.mNumberFirst, 1953)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind,
            "sovereign-snapshot-token-struct-trio")
        XCTAssertEqual(e.modulesTouched, ["BASSovereign"])
    }

    func testEntry3IsSovereignContaminationGuardTrio() {
        let e = BASGapFillHexaSixCompletionDoctrine.entries[2]
        XCTAssertEqual(e.chapterTag, "chapter 六百四十五")
        XCTAssertEqual(e.mNumberFirst, 1957)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind,
            "sovereign-contamination-guard-trio")
        XCTAssertEqual(e.modulesTouched, ["BASSovereign"])
    }

    func testEntry4IsSovereignTrustRecordTrio() {
        let e = BASGapFillHexaSixCompletionDoctrine.entries[3]
        XCTAssertEqual(e.chapterTag, "chapter 六百四十六")
        XCTAssertEqual(e.mNumberFirst, 1961)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind,
            "sovereign-trust-record-trio")
        XCTAssertEqual(e.modulesTouched, ["BASSovereign"])
    }

    func testEntry5IsSovereignPrivilegeScanTrio() {
        let e = BASGapFillHexaSixCompletionDoctrine.entries[4]
        XCTAssertEqual(e.chapterTag, "chapter 六百四十七")
        XCTAssertEqual(e.mNumberFirst, 1965)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind,
            "sovereign-privilege-scan-trio")
        XCTAssertEqual(e.modulesTouched, ["BASSovereign"])
    }

    func testEntry6IsSovereignTertiaryErrorTrio() {
        let e = BASGapFillHexaSixCompletionDoctrine.entries[5]
        XCTAssertEqual(e.chapterTag, "chapter 六百四十八")
        XCTAssertEqual(e.mNumberFirst, 1969)
        XCTAssertEqual(e.typesExtended, 3)
        XCTAssertEqual(e.kind,
            "sovereign-tertiary-error-trio")
        XCTAssertEqual(e.modulesTouched, ["BASSovereign"])
    }

    // MARK: - Aggregate accessor pins

    func testTotalTypesExtendedAcrossEntriesIs18() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalTypesExtendedAcrossEntries, 18)
    }

    func testTotalCommitsAcrossEntriesIs24() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .totalCommitsAcrossEntries, 24)
    }

    func testDistinctModulesTouchedIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .distinctModulesTouched, 1)
    }

    func testIsEntirelySingleModuleHexaFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .isEntirelySingleModuleHexa)
    }

    func testErrorTrioVariantCountIs1() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .errorTrioVariantCount, 1)
    }

    func testNonErrorTrioVariantCountIs5() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .nonErrorTrioVariantCount, 5)
    }

    func testRunFirstMNumberIs1949() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .runFirstMNumber, 1949)
    }

    func testRunLastMNumberIs1972() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .runLastMNumber, 1972)
    }

    // MARK: - Achievement flag pins

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverageFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .allEntriesRealSubstrateChange)
    }

    func testAllEntriesUsedFourKnifeCadenceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .allEntriesUsedFourKnifeCadence)
    }

    func testRunIsContiguousFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .runIsContiguous)
    }

    func testEveryKindAppearsExactlyOnceFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .everyKindAppearsExactlyOnce)
    }

    func testHasDeepestRecursiveCodableProofFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .hasDeepestRecursiveCodableProof)
    }

    func testDemonstratesSetCodableCompositionFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .demonstratesSetCodableComposition)
    }

    func testBASSovereignCumulativeAtCycleStartIs8() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .basSovereignCumulativeAtCycleStart, 8)
    }

    func testBASSovereignCumulativeAtCycleEndIs26() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .basSovereignCumulativeAtCycleEnd, 26)
    }

    func testBASSovereignCumulativeDeltaIs18() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .basSovereignCumulativeDelta, 18)
    }

    func testRunCrossesThousandPhase2CommitsMilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .runCrossesThousandPhase2CommitsMilestone)
    }

    func testRunCrossesTwentyFiveBASSovereignSurfacesMilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .runCrossesTwentyFiveBASSovereignSurfacesMilestone)
    }

    func testRunCrossesTwentyBASSovereignSurfacesMilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .runCrossesTwentyBASSovereignSurfacesMilestone)
    }

    // MARK: - Reference pins

    func testPriorGapFillHexaOneRefPinned() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .priorGapFillHexaOneRef,
            "BASGapFillHexaCompletionDoctrine")
    }

    func testPriorGapFillHexaTwoRefPinned() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .priorGapFillHexaTwoRef,
            "BASGapFillHexaTwoCompletionDoctrine")
    }

    func testPriorGapFillHexaThreeRefPinned() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .priorGapFillHexaThreeRef,
            "BASGapFillHexaThreeCompletionDoctrine")
    }

    func testPriorGapFillHexaFourRefPinned() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .priorGapFillHexaFourRef,
            "BASGapFillHexaFourCompletionDoctrine")
    }

    func testPriorGapFillHexaFiveRefPinned() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .priorGapFillHexaFiveRef,
            "BASGapFillHexaFiveCompletionDoctrine")
    }

    func testPriorPostOctaHexaRefPinned() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .priorPostOctaHexaRef,
            "BASPostOctaModuleExtensionHexaCompletionDoctrine")
    }

    func testPriorOctaMilestoneRefPinned() {
        XCTAssertEqual(
            BASGapFillHexaSixCompletionDoctrine
                .priorOctaMilestoneRef,
            "BASCodableExtensionOctaMilestoneCompletionDoctrine")
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .isPastM1800Milestone)
    }

    func testIsPastM1880MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .isPastM1880Milestone)
    }

    func testIsPastM1900MilestoneFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .isPastM1900Milestone)
    }

    func testIsPastFourHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }

    func testIsPastFiveHundredConsecutiveByteEqualFlagSet() {
        XCTAssertTrue(
            BASGapFillHexaSixCompletionDoctrine
                .isPastFiveHundredConsecutiveByteEqual)
    }

    // MARK: - EntryRecord Codable round-trip

    func testEntryRecordIsCodable() throws {
        let entry =
            BASGapFillHexaSixCompletionDoctrine.entries[5]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASGapFillHexaSixCompletionDoctrine
                .EntryRecord.self, from: data)
        XCTAssertEqual(decoded, entry)
    }
}
