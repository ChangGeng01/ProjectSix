// MARK: - BASGapFillHexaSevenCompletionDoctrineTests
// chapter 六百五十六 / M2002 — anti-drift PROOF tests for
//                              the M2001 hexa #7 catalog

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaSevenCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .chapterTag, "chapter 六百五十六")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .milestoneMNumber, 2001)
    }

    // MARK: - Entry count pins

    func testTotalEntries() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .totalEntries, 6)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries.count,
            BASGapFillHexaSevenCompletionDoctrine
                .totalEntries)
    }

    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .entriesCountMatchesTotal)
    }

    // MARK: - 6 kind bucket pins

    func testRuntimeCoreKnowledgeMeshTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .runtimeCoreKnowledgeMeshTrioCount, 1)
    }

    func testSovereignRebootVerdictLockTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .sovereignRebootVerdictLockTrioCount, 1)
    }

    func testMambaFederatedStorageTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .mambaFederatedStorageTrioCount, 1)
    }

    func testOrganLLMCacheMockTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .organLLMCacheMockTrioCount, 1)
    }

    func testValidationResultTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .validationResultTrioCount, 1)
    }

    func testValidationIssueTrioCountIsOne() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .validationIssueTrioCount, 1)
    }

    func testEveryKindAppearsExactlyOnce() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .everyKindAppearsExactlyOnce)
    }

    func testKindBucketsSumMatchesTotal() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .kindBucketsSumMatchesTotal)
    }

    // MARK: - Aggregate computed pins

    func testTotalTypesExtendedAcrossEntries() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .totalTypesExtendedAcrossEntries, 18)
    }

    func testTotalCommitsAcrossEntries() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .totalCommitsAcrossEntries, 24)
    }

    func testDistinctModulesTouchedIsFive() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .distinctModulesTouched, 5)
    }

    func testIsEntirelySingleModuleHexaIsFalse() {
        XCTAssertFalse(
            BASGapFillHexaSevenCompletionDoctrine
                .isEntirelySingleModuleHexa)
    }

    func testErrorTrioVariantCountIsZero() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .errorTrioVariantCount, 0)
    }

    func testNonErrorTrioVariantCountIsSix() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .nonErrorTrioVariantCount, 6)
    }

    func testRunFirstMNumber() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .runFirstMNumber, 1977)
    }

    func testRunLastMNumber() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .runLastMNumber, 2000)
    }

    // MARK: - Achievement flag pins

    func testByteEqualityPreservedThroughout() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverage() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChange() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .allEntriesRealSubstrateChange)
    }

    func testAllEntriesUsedFourKnifeCadence() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .allEntriesUsedFourKnifeCadence)
    }

    func testRunIsContiguous() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .runIsContiguous)
    }

    // MARK: - DISTINCTIVE FEATURE pins (hexa #7-specific)

    func testHasExplicitThemeContinuation() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .hasExplicitThemeContinuation)
    }

    func testContainsRoundNumberChapter() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .containsRoundNumberChapter)
    }

    func testCrossesRoundNumberMMilestone() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .crossesRoundNumberMMilestone)
    }

    func testDemonstratesDictCodableComposition() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .demonstratesDictCodableComposition)
    }

    func testDemonstratesOptionalCodableComposition() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .demonstratesOptionalCodableComposition)
    }

    func testDemonstratesParallelStructuralShape() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .demonstratesParallelStructuralShape)
    }

    func testDemonstratesThemeContinuation() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .demonstratesThemeContinuation)
    }

    // MARK: - Substrate cumulative growth pins

    func testSubstrateCumulativeAtCycleStartIs190() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .substrateCumulativeAtCycleStart, 190)
    }

    func testSubstrateCumulativeAtCycleEndIs196() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .substrateCumulativeAtCycleEnd, 196)
    }

    func testSubstrateCumulativeDeltaIsSix() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .substrateCumulativeDelta, 6)
    }

    // MARK: - Cross-doctrine ref pins

    func testPriorGapFillHexaOneRef() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .priorGapFillHexaOneRef,
            "BASGapFillHexaCompletionDoctrine")
    }

    func testPriorGapFillHexaTwoRef() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .priorGapFillHexaTwoRef,
            "BASGapFillHexaTwoCompletionDoctrine")
    }

    func testPriorGapFillHexaThreeRef() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .priorGapFillHexaThreeRef,
            "BASGapFillHexaThreeCompletionDoctrine")
    }

    func testPriorGapFillHexaFourRef() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .priorGapFillHexaFourRef,
            "BASGapFillHexaFourCompletionDoctrine")
    }

    func testPriorGapFillHexaFiveRef() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .priorGapFillHexaFiveRef,
            "BASGapFillHexaFiveCompletionDoctrine")
    }

    func testPriorGapFillHexaSixRef() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .priorGapFillHexaSixRef,
            "BASGapFillHexaSixCompletionDoctrine")
    }

    func testPriorPostOctaHexaRef() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .priorPostOctaHexaRef,
            "BASPostOctaModuleExtensionHexaCompletionDoctrine")
    }

    func testPriorOctaMilestoneRef() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .priorOctaMilestoneRef,
            "BASCodableExtensionOctaMilestoneCompletionDoctrine")
    }

    // MARK: - Milestone flag pins

    func testIsBeyondM1700NarrativeArc() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    func testIsPastM1800Milestone() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .isPastM1800Milestone)
    }

    func testIsPastM1880Milestone() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .isPastM1880Milestone)
    }

    func testIsPastM1900Milestone() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .isPastM1900Milestone)
    }

    func testIsPastM2000Milestone() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .isPastM2000Milestone)
    }

    func testIsPastFourHundredConsecutiveByteEqual() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .isPastFourHundredConsecutiveByteEqual)
    }

    func testIsPastFiveHundredConsecutiveByteEqual() {
        XCTAssertTrue(
            BASGapFillHexaSevenCompletionDoctrine
                .isPastFiveHundredConsecutiveByteEqual)
    }

    // MARK: - Per-entry chapter tag pins

    func testEntry1ChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[0].chapterTag,
            "chapter 六百五十")
    }

    func testEntry2ChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[1].chapterTag,
            "chapter 六百五十一")
    }

    func testEntry3ChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[2].chapterTag,
            "chapter 六百五十二")
    }

    func testEntry4ChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[3].chapterTag,
            "chapter 六百五十三")
    }

    func testEntry5ChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[4].chapterTag,
            "chapter 六百五十四")
    }

    func testEntry6ChapterTag() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[5].chapterTag,
            "chapter 六百五十五")
    }

    // MARK: - Per-entry mNumberFirst pins

    func testEntry1MNumberFirst() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[0].mNumberFirst, 1977)
    }

    func testEntry2MNumberFirst() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[1].mNumberFirst, 1981)
    }

    func testEntry3MNumberFirst() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[2].mNumberFirst, 1985)
    }

    func testEntry4MNumberFirst() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[3].mNumberFirst, 1989)
    }

    func testEntry5MNumberFirst() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[4].mNumberFirst, 1993)
    }

    func testEntry6MNumberFirst() {
        XCTAssertEqual(
            BASGapFillHexaSevenCompletionDoctrine
                .entries[5].mNumberFirst, 1997)
    }

    // MARK: - Codable round-trip on EntryRecord

    func testEntriesAreCodable() throws {
        let entries =
            BASGapFillHexaSevenCompletionDoctrine.entries
        let encoded = try JSONEncoder().encode(entries)
        let decoded = try JSONDecoder().decode(
            [BASGapFillHexaSevenCompletionDoctrine
                .EntryRecord].self, from: encoded)
        XCTAssertEqual(decoded, entries)
    }
}
