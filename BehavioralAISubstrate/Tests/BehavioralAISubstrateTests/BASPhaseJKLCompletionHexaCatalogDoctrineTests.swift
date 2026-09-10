// MARK: - BASPhaseJKLCompletionHexaCatalogDoctrineTests
// chapter 六百七十六 / M2082 — anti-drift PROOF tests for
//                              the M2081 hexa #9 catalog
//                              (first phase-catalog,4-entry,
//                              mid-plan anti-drift checkpoint)

import XCTest
@testable import BASRuntimeCore

final class BASPhaseJKLCompletionHexaCatalogDoctrineTests:
    XCTestCase
{
    typealias D = BASPhaseJKLCompletionHexaCatalogDoctrine

    // MARK: - Catalog identity

    func testChapterTag() {
        XCTAssertEqual(D.chapterTag, "chapter 六百七十六")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(D.milestoneMNumber, 2081)
    }

    // MARK: - Entry list size

    func testTotalEntries() {
        XCTAssertEqual(D.totalEntries, 4)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(D.entries.count, D.totalEntries)
    }

    // MARK: - Entry kind counts

    func testPhaseCompletionEntryCountIsThree() {
        XCTAssertEqual(D.phaseCompletionEntryCount, 3)
    }

    func testDefaultFlipMilestoneEntryCountIsOne() {
        XCTAssertEqual(D.defaultFlipMilestoneEntryCount, 1)
    }

    func testEntryKindCountsSumToTotal() {
        XCTAssertEqual(
            D.phaseCompletionEntryCount
                + D.defaultFlipMilestoneEntryCount,
            D.totalEntries)
    }

    // MARK: - Entry 1 — Phase J

    func testEntry1IsPhaseJ() {
        let e = D.entries[0]
        XCTAssertEqual(
            e.doctrineTypeName,
            "BASPhaseJKernelCacheCompletionDoctrine")
        XCTAssertEqual(e.entryKind, "phase-completion")
        XCTAssertEqual(e.chapterRangeStart, "chapter 六百六十四")
        XCTAssertEqual(e.chapterRangeEnd, "chapter 六百六十七")
        XCTAssertEqual(e.mNumberFirst, 2033)
        XCTAssertEqual(e.mNumberLast, 2048)
        XCTAssertEqual(e.chaptersInRange, 4)
        XCTAssertEqual(e.commitsInRange, 16)
        XCTAssertEqual(e.scoreDelta, 6)
        XCTAssertEqual(e.directiveImpact, ["原生利用神经引擎"])
    }

    // MARK: - Entry 2 — Phase K

    func testEntry2IsPhaseK() {
        let e = D.entries[1]
        XCTAssertEqual(
            e.doctrineTypeName,
            "BASPhaseKRuntimeModeToggleCompletionDoctrine")
        XCTAssertEqual(e.entryKind, "phase-completion")
        XCTAssertEqual(e.chapterRangeStart, "chapter 六百六十八")
        XCTAssertEqual(e.chapterRangeEnd, "chapter 六百七十一")
        XCTAssertEqual(e.mNumberFirst, 2049)
        XCTAssertEqual(e.mNumberLast, 2064)
        XCTAssertEqual(e.chaptersInRange, 4)
        XCTAssertEqual(e.commitsInRange, 16)
        XCTAssertEqual(e.scoreDelta, 3)
        XCTAssertEqual(
            e.directiveImpact,
            ["低熵复杂系统", "最激进"])
    }

    // MARK: - Entry 3 — Phase L

    func testEntry3IsPhaseL() {
        let e = D.entries[2]
        XCTAssertEqual(
            e.doctrineTypeName,
            "BASPhaseLCumulativeCompletionDoctrine")
        XCTAssertEqual(e.entryKind, "phase-completion")
        XCTAssertEqual(e.chapterRangeStart, "chapter 六百七十二")
        XCTAssertEqual(e.chapterRangeEnd, "chapter 六百七十五")
        XCTAssertEqual(e.mNumberFirst, 2065)
        XCTAssertEqual(e.mNumberLast, 2080)
        XCTAssertEqual(e.chaptersInRange, 4)
        XCTAssertEqual(e.commitsInRange, 16)
        XCTAssertEqual(e.scoreDelta, 8)
        XCTAssertEqual(
            e.directiveImpact,
            ["最激进", "最创新"])
    }

    // MARK: - Entry 4 — THE FLIP

    func testEntry4IsDefaultFlip() {
        let e = D.entries[3]
        XCTAssertEqual(
            e.doctrineTypeName,
            "BASPhaseLDefaultFlipCompletionDoctrine")
        XCTAssertEqual(e.entryKind, "default-flip-milestone")
        XCTAssertEqual(e.chapterRangeStart, "chapter 六百七十四")
        XCTAssertEqual(e.chapterRangeEnd, "chapter 六百七十四")
        XCTAssertEqual(e.mNumberFirst, 2074)
        XCTAssertEqual(e.mNumberLast, 2074)
        XCTAssertEqual(e.chaptersInRange, 1)
        XCTAssertEqual(e.commitsInRange, 1)
        XCTAssertEqual(e.scoreDelta, 0)
        XCTAssertEqual(
            e.directiveImpact,
            ["最激进", "最创新"])
    }

    // MARK: - Aggregates

    func testTotalChaptersAcrossPhaseEntriesIsTwelve() {
        XCTAssertEqual(D.totalChaptersAcrossPhaseEntries, 12)
    }

    func testTotalCommitsAcrossPhaseEntriesIsFortyEight() {
        XCTAssertEqual(D.totalCommitsAcrossPhaseEntries, 48)
    }

    func testAggregateScoreDeltaIsSeventeen() {
        // 6 + 3 + 8 + 0 = 17 (entry 4 = 0 to avoid double-
        // count since it's contained within Phase L)
        XCTAssertEqual(D.aggregateScoreDelta, 17)
    }

    func testRunFirstMNumberIs2033() {
        XCTAssertEqual(D.runFirstMNumber, 2033)
    }

    func testRunLastMNumberIs2080() {
        XCTAssertEqual(D.runLastMNumber, 2080)
    }

    func testRunChapterStart() {
        XCTAssertEqual(D.runChapterStart, "chapter 六百六十四")
    }

    func testRunChapterEnd() {
        XCTAssertEqual(D.runChapterEnd, "chapter 六百七十五")
    }

    func testTotalChaptersClaimedIsTwelve() {
        XCTAssertEqual(D.totalChaptersClaimed, 12)
    }

    func testTotalCommitsClaimedIsFortyEight() {
        XCTAssertEqual(D.totalCommitsClaimed, 48)
    }

    // MARK: - Score progression

    func testAggregateScoreBeforeIs45() {
        XCTAssertEqual(D.aggregateScoreBefore, 45)
    }

    func testAggregateScoreAfterIs58() {
        XCTAssertEqual(D.aggregateScoreAfter, 58)
    }

    func testAggregateScoreDeltaClaimedIsThirteen() {
        XCTAssertEqual(D.aggregateScoreDeltaClaimed, 13)
    }

    func testAggregateScoreArithmeticConsistent() {
        XCTAssertEqual(
            D.aggregateScoreAfter - D.aggregateScoreBefore,
            D.aggregateScoreDeltaClaimed)
    }

    // MARK: - Typed surfaces growth

    func testTypedSurfacesAddedAcrossPhasesIsThirteen() {
        XCTAssertEqual(
            D.typedSurfacesAddedAcrossPhases, 13)
    }

    // MARK: - Achievement flags

    func testByteEqualityPreservedThroughout() {
        XCTAssertTrue(D.byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverage() {
        XCTAssertTrue(D.allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChange() {
        XCTAssertTrue(D.allEntriesRealSubstrateChange)
    }

    func testAllEntriesUsedFourKnifeCadence() {
        XCTAssertTrue(D.allEntriesUsedFourKnifeCadence)
    }

    func testRunIsContiguous() {
        XCTAssertTrue(D.runIsContiguous)
    }

    // MARK: - DISTINCTIVE FEATURES of hexa #9

    func testIsPhaseCatalogNotGapFillCatalog() {
        XCTAssertTrue(D.isPhaseCatalogNotGapFillCatalog)
    }

    func testIsFourEntryNotSixEntry() {
        XCTAssertTrue(D.isFourEntryNotSixEntry)
    }

    func testIsAntiDriftCheckpointHexa() {
        XCTAssertTrue(D.isAntiDriftCheckpointHexa)
    }

    func testDocumentsDefaultBehaviorFlip() {
        XCTAssertTrue(D.documentsDefaultBehaviorFlip)
    }

    func testIsWithinWildRollingMeerkatPlan() {
        XCTAssertTrue(D.isWithinWildRollingMeerkatPlan)
    }

    func testIsScoreDeltaHeadlineHexa() {
        XCTAssertTrue(D.isScoreDeltaHeadlineHexa)
    }

    // MARK: - Plan progress

    func testPlanTotalChaptersIs46() {
        XCTAssertEqual(D.planTotalChapters, 46)
    }

    func testPlanTotalCommitsIs184() {
        XCTAssertEqual(D.planTotalCommits, 184)
    }

    func testPlanChaptersCompleteIsTwelve() {
        XCTAssertEqual(D.planChaptersComplete, 12)
    }

    func testPlanCommitsCompleteIsFortyEight() {
        XCTAssertEqual(D.planCommitsComplete, 48)
    }

    func testPlanPercentCompleteIsApproximatelyTwentySixPercent() {
        // 12 / 46 = 0.26086...
        XCTAssertEqual(
            D.planPercentComplete, 26.086956521739, accuracy: 0.001)
    }

    // MARK: - Cross-doctrine refs

    func testPhaseJCompletionRef() {
        XCTAssertEqual(
            D.phaseJCompletionRef,
            "BASPhaseJKernelCacheCompletionDoctrine")
    }

    func testPhaseKCompletionRef() {
        XCTAssertEqual(
            D.phaseKCompletionRef,
            "BASPhaseKRuntimeModeToggleCompletionDoctrine")
    }

    func testPhaseLCompletionRef() {
        XCTAssertEqual(
            D.phaseLCompletionRef,
            "BASPhaseLCumulativeCompletionDoctrine")
    }

    func testPhaseLFlipCompletionRef() {
        XCTAssertEqual(
            D.phaseLFlipCompletionRef,
            "BASPhaseLDefaultFlipCompletionDoctrine")
    }

    // MARK: - Catalog lineage

    func testCatalogLineageHasTenEntries() {
        // 10 entries:1 post-octa + 9 hexa catalogs
        XCTAssertEqual(D.catalogLineageLength, 10)
    }

    func testCatalogLineageEndsAtThisHexa() {
        XCTAssertTrue(
            D.catalogLineage.last?
                .contains("M2081 hexa #9") ?? false)
    }

    func testCatalogLineageStartsAtPostOcta() {
        XCTAssertEqual(
            D.catalogLineage.first,
            "M1805 post-octa")
    }

    // MARK: - Milestone markers

    func testIsBeyondM1700NarrativeArc() {
        XCTAssertTrue(D.isBeyondM1700NarrativeArc)
    }

    func testIsPastM2000Milestone() {
        XCTAssertTrue(D.isPastM2000Milestone)
    }

    func testIsPastM2080Milestone() {
        XCTAssertTrue(D.isPastM2080Milestone)
    }

    func testIsPastSixHundredFiftyConsecutiveByteEqual() {
        XCTAssertTrue(
            D.isPastSixHundredFiftyConsecutiveByteEqual)
    }

    // MARK: - Next phase pointers

    func testNextPhaseIsM() {
        XCTAssertEqual(D.nextPhase, "Phase M")
    }

    func testNextPhaseChapter() {
        XCTAssertEqual(
            D.nextPhaseChapter, "chapter 六百七十七")
    }

    func testNextPhaseMNumberStart() {
        XCTAssertEqual(D.nextPhaseMNumberStart, 2085)
    }

    // MARK: - Codable round-trip

    func testEntriesAreCodable() throws {
        let encoded = try JSONEncoder().encode(D.entries)
        let decoded = try JSONDecoder().decode(
            [D.EntryRecord].self, from: encoded)
        XCTAssertEqual(decoded, D.entries)
    }

    // MARK: - Determinism

    func testEntriesAreDeterministic() {
        XCTAssertEqual(D.entries, D.entries)
    }
}
