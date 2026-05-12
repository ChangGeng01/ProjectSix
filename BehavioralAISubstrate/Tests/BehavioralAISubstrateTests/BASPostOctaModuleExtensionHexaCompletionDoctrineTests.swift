// MARK: - BASPostOctaModuleExtensionHexaCompletionDoctrineTests
// chapter 六百七 / M1806 — anti-drift PROOF tests for
//                          the M1805 post-octa hexa
//                          completion milestone
//
// ## Coverage (30 anti-drift PROOF tests)
//
// Identity + entry counts (incl。 2 kind-bucket
// counts) + 6 per-entry identity pins + aggregate
// accessors + 5 achievement flags + 2 prior-snapshot
// refs + EntryRecord Codable round-trip。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1805 → M1806

import XCTest
@testable import BASRuntimeCore

final class BASPostOctaModuleExtensionHexaCompletionDoctrineTests:
    XCTestCase
{
    // MARK: - Identity pins

    func testChapterTag() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .chapterTag,
            "chapter 六百七")
    }

    func testMilestoneMNumber() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .milestoneMNumber,
            1805)
    }

    // MARK: - Entry count pins

    func testTotalEntries() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .totalEntries,
            6)
    }

    func testEntriesListSizeMatchesTotal() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries.count,
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .totalEntries)
    }

    func testEntriesCountMatchesTotalFlag() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entriesCountMatchesTotal)
    }

    func testFirstEverEntryCount() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .firstEverEntryCount,
            3)
    }

    func testFormalEntryEntryCount() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .formalEntryEntryCount,
            3)
    }

    func testKindBucketsSumMatchesTotalFlag() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .kindBucketsSumMatchesTotal)
    }

    // MARK: - Per-entry identity pins

    func testEntry1IsBASOrgan() {
        let e =
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[0]
        XCTAssertEqual(e.module, "BASOrgan")
        XCTAssertEqual(e.mNumberFirst, 1769)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.moduleCountAfter, 7)
        XCTAssertEqual(e.kind, "first-ever")
    }

    func testEntry2IsBASMLXAdapter() {
        let e =
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[1]
        XCTAssertEqual(e.module, "BASMLXAdapter")
        XCTAssertEqual(e.mNumberFirst, 1773)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.moduleCountAfter, 8)
        XCTAssertEqual(e.kind, "first-ever")
    }

    func testEntry3IsBASChatCompletionsAdapter() {
        let e =
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[2]
        XCTAssertEqual(
            e.module,
            "BASChatCompletionsAdapter")
        XCTAssertEqual(e.mNumberFirst, 1789)
        XCTAssertEqual(e.typesExtended, 1)
        XCTAssertEqual(e.moduleCountAfter, 9)
        XCTAssertEqual(e.kind, "first-ever")
    }

    func testEntry4IsBASAppleAdapters() {
        let e =
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[3]
        XCTAssertEqual(e.module, "BASAppleAdapters")
        XCTAssertEqual(e.mNumberFirst, 1793)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.moduleCountAfter, 10)
        XCTAssertEqual(e.kind, "formal-entry")
    }

    func testEntry5IsBASMetalSubstrate() {
        let e =
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[4]
        XCTAssertEqual(e.module, "BASMetalSubstrate")
        XCTAssertEqual(e.mNumberFirst, 1797)
        XCTAssertEqual(e.typesExtended, 2)
        XCTAssertEqual(e.moduleCountAfter, 11)
        XCTAssertEqual(e.kind, "formal-entry")
    }

    func testEntry6IsBASSovereign() {
        let e =
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[5]
        XCTAssertEqual(e.module, "BASSovereign")
        XCTAssertEqual(e.mNumberFirst, 1801)
        XCTAssertEqual(e.typesExtended, 4)
        XCTAssertEqual(e.moduleCountAfter, 12)
        XCTAssertEqual(e.kind, "formal-entry")
    }

    // MARK: - Aggregate accessor pins

    func testTotalTypesExtendedAcrossEntriesIs13() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .totalTypesExtendedAcrossEntries,
            13)
    }

    func testTotalCommitsAcrossEntriesIs24() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .totalCommitsAcrossEntries,
            24)
    }

    func testModuleCountAtOctaCloseIs6() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .moduleCountAtOctaClose,
            6)
    }

    func testModuleCountAfterAllEntriesIs12() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .moduleCountAfterAllEntries,
            12)
    }

    func testDistinctModulesTouchedIs6() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .distinctModulesTouched,
            6)
    }

    // MARK: - Achievement flag pins

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllEntriesHaveFullCoverageFlagSet() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .allEntriesHaveFullCoverage)
    }

    func testAllEntriesRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .allEntriesRealSubstrateChange)
    }

    func testIncludesM1800RoundMilestoneFlagSet() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .includesM1800RoundMilestone)
    }

    func testIncludesFirstPastM1800FlagSet() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .includesFirstPastM1800)
    }

    func testIsPastM1800MilestoneFlagSet() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .isPastM1800Milestone)
    }

    func testIsBeyondM1700NarrativeArcFlagSet() {
        XCTAssertTrue(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .isBeyondM1700NarrativeArc)
    }

    // MARK: - Reference pins

    func testPriorOctaMilestoneRefPointsCorrectly() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .priorOctaMilestoneRef,
            "BASCodableExtensionOctaMilestoneCompletionDoctrine")
    }

    func testOriginalFreshModulePrecedentRefPointsCorrectly() {
        XCTAssertEqual(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .originalFreshModulePrecedentRef,
            "BASObservabilityFirstEverCodableExtensionDoctrine")
    }

    // MARK: - EntryRecord Codable round-trip

    func testEntryRecordIsCodable() throws {
        let entry =
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .entries[5]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            BASPostOctaModuleExtensionHexaCompletionDoctrine
                .EntryRecord.self,
            from: data)
        XCTAssertEqual(decoded, entry)
    }
}
