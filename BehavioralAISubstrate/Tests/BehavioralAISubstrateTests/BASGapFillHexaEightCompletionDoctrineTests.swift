// MARK: - BASGapFillHexaEightCompletionDoctrineTests
// chapter 六百六十三 / M2030 — anti-drift PROOF tests for
//                              the M2029 hexa #8 catalog

import XCTest
@testable import BASRuntimeCore

final class BASGapFillHexaEightCompletionDoctrineTests: XCTestCase {
    typealias D = BASGapFillHexaEightCompletionDoctrine

    func testChapterTag() { XCTAssertEqual(D.chapterTag, "chapter 六百六十三") }
    func testMilestoneMNumber() { XCTAssertEqual(D.milestoneMNumber, 2029) }
    func testTotalEntries() { XCTAssertEqual(D.totalEntries, 6) }
    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(D.entries.count, D.totalEntries)
    }
    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(D.entriesCountMatchesTotal)
    }

    // 6 kind buckets
    func testRoadmapEvalMockTrioCountIsOne() {
        XCTAssertEqual(D.roadmapEvalMockTrioCount, 1)
    }
    func testBiomimeticObservationTrioCountIsOne() {
        XCTAssertEqual(D.biomimeticObservationTrioCount, 1)
    }
    func testKernelResultTrioCountIsOne() {
        XCTAssertEqual(D.kernelResultTrioCount, 1)
    }
    func testHostProjectionTrioCountIsOne() {
        XCTAssertEqual(D.hostProjectionTrioCount, 1)
    }
    func testConvenienceCadenceRecordTrioCountIsOne() {
        XCTAssertEqual(D.convenienceCadenceRecordTrioCount, 1)
    }
    func testBiomimeticSignalRecordTrioCountIsOne() {
        XCTAssertEqual(D.biomimeticSignalRecordTrioCount, 1)
    }
    func testEveryKindAppearsExactlyOnce() {
        XCTAssertTrue(D.everyKindAppearsExactlyOnce)
    }
    func testKindBucketsSumMatchesTotal() {
        XCTAssertTrue(D.kindBucketsSumMatchesTotal)
    }

    // Aggregates
    func testTotalTypesExtendedAcrossEntries() {
        XCTAssertEqual(D.totalTypesExtendedAcrossEntries, 18)
    }
    func testTotalCommitsAcrossEntries() {
        XCTAssertEqual(D.totalCommitsAcrossEntries, 24)
    }
    func testDistinctModulesTouchedIsFour() {
        XCTAssertEqual(D.distinctModulesTouched, 4)
    }
    func testIsEntirelySingleModuleHexaIsFalse() {
        XCTAssertFalse(D.isEntirelySingleModuleHexa)
    }
    func testAllStructEntryCountIsFive() {
        XCTAssertEqual(D.allStructEntryCount, 5)
    }
    func testAllEnumEntryCountIsOne() {
        XCTAssertEqual(D.allEnumEntryCount, 1)
    }
    func testRunFirstMNumber() { XCTAssertEqual(D.runFirstMNumber, 2005) }
    func testRunLastMNumber() { XCTAssertEqual(D.runLastMNumber, 2028) }

    // Achievement flags
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
    func testRunIsContiguous() { XCTAssertTrue(D.runIsContiguous) }

    // DISTINCTIVE FEATURES
    func testHasFiveConsecutiveAllStructTrios() {
        XCTAssertTrue(D.hasFiveConsecutiveAllStructTrios)
    }
    func testCrossesSixHundredCommitMilestone() {
        XCTAssertTrue(D.crossesSixHundredCommitMilestone)
    }

    // Substrate cumulative growth
    func testSubstrateCumulativeAtCycleStartIs197() {
        XCTAssertEqual(D.substrateCumulativeAtCycleStart, 197)
    }
    func testSubstrateCumulativeAtCycleEndIs203() {
        XCTAssertEqual(D.substrateCumulativeAtCycleEnd, 203)
    }
    func testSubstrateCumulativeDeltaIsSix() {
        XCTAssertEqual(D.substrateCumulativeDelta, 6)
    }

    // Cross-doctrine refs
    func testPriorGapFillHexaSevenRef() {
        XCTAssertEqual(D.priorGapFillHexaSevenRef,
                       "BASGapFillHexaSevenCompletionDoctrine")
    }

    // Milestone flags
    func testIsBeyondM1700NarrativeArc() {
        XCTAssertTrue(D.isBeyondM1700NarrativeArc)
    }
    func testIsPastM2000Milestone() { XCTAssertTrue(D.isPastM2000Milestone) }
    func testIsPastSixHundredConsecutiveByteEqual() {
        XCTAssertTrue(D.isPastSixHundredConsecutiveByteEqual)
    }

    // Per-entry chapter tag pins
    func testEntry1ChapterTag() {
        XCTAssertEqual(D.entries[0].chapterTag, "chapter 六百五十七")
    }
    func testEntry2ChapterTag() {
        XCTAssertEqual(D.entries[1].chapterTag, "chapter 六百五十八")
    }
    func testEntry3ChapterTag() {
        XCTAssertEqual(D.entries[2].chapterTag, "chapter 六百五十九")
    }
    func testEntry4ChapterTag() {
        XCTAssertEqual(D.entries[3].chapterTag, "chapter 六百六十")
    }
    func testEntry5ChapterTag() {
        XCTAssertEqual(D.entries[4].chapterTag, "chapter 六百六十一")
    }
    func testEntry6ChapterTag() {
        XCTAssertEqual(D.entries[5].chapterTag, "chapter 六百六十二")
    }

    // Per-entry mNumberFirst pins
    func testEntry1MNumberFirst() {
        XCTAssertEqual(D.entries[0].mNumberFirst, 2005)
    }
    func testEntry6MNumberFirst() {
        XCTAssertEqual(D.entries[5].mNumberFirst, 2025)
    }

    // Codable round-trip
    func testEntriesAreCodable() throws {
        let encoded = try JSONEncoder().encode(D.entries)
        let decoded = try JSONDecoder().decode(
            [D.EntryRecord].self, from: encoded)
        XCTAssertEqual(decoded, D.entries)
    }
}
