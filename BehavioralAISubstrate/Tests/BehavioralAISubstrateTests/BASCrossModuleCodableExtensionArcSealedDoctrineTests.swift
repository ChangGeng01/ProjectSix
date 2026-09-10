// MARK: - BASCrossModuleCodableExtensionArcSealedDoctrineTests
// chapter 五百六十九 / M1654 — anti-drift PROOF tests
//                          for the M1653 arc-seal
//                          milestone
//
// ## Coverage matrix (20 tests)
//
//   - Pin invariants (chapterTag,milestoneMNumber,
//     arcFirstChapter,arcLastChapter,arcChapterCount
//     = 3,arcFirstMNumber,arcLastMNumber,arcMNumberSpan
//     = 12,4 boolean flag pins)
//   - List + count invariants (13 total,3 chapter
//     contributions,3 extension doctrines,13 type
//     list,2 modules)
//   - Sum cross-checks (sumOfChapterContributions ==
//     totalTypesExtended; sumOfModuleCounts ==
//     totalTypesExtended;listSizeMatchesTotalCount)
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:single source-of-truth pins
//   - chapter 三百九二:doctrine commemorates 13 more
//     types entering replay-determinism surface
//   - ADR-016 advances M1653 → M1654

import XCTest
@testable import BASRuntimeCore

final class BASCrossModuleCodableExtensionArcSealedDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter569() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .chapterTag,
            "chapter 五百六十九")
    }

    func testMilestoneMNumberIs1653() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .milestoneMNumber,
            1653)
    }

    // MARK: - Arc range

    func testArcFirstChapterIs566() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcFirstChapter,
            "chapter 五百六十六")
    }

    func testArcLastChapterIs568() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcLastChapter,
            "chapter 五百六十八")
    }

    func testArcChapterCountIsThree() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcChapterCount,
            3)
    }

    func testArcFirstMNumberIs1641() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcFirstMNumber,
            1641)
    }

    func testArcLastMNumberIs1652() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcLastMNumber,
            1652)
    }

    func testArcMNumberSpanIsTwelve() {
        // 1652 - 1641 + 1 = 12
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcMNumberSpan,
            12)
    }

    // MARK: - Cross-module coverage

    func testTotalTypesExtendedIsThirteen() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended,
            13)
    }

    func testModuleBreakdownHasTwoEntries() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .moduleBreakdown.count,
            2)
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .modulesCovered,
            2)
    }

    func testSumOfModuleCountsMatchesTotal() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .sumOfModuleCounts,
            13)
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .sumOfModuleCounts,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }

    func testPerChapterContributionsHasThreeEntries() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .perChapterContributions.count,
            3)
    }

    func testSumOfChapterContributionsMatchesTotal() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .sumOfChapterContributions,
            13)
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .sumOfChapterContributions,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }

    func testPerChapterContributionsExactValues() {
        let entries = BASCrossModuleCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(entries[0].chapterTag,
                       "chapter 五百六十六")
        XCTAssertEqual(entries[0].mNumber, 1641)
        XCTAssertEqual(entries[0].typesAdded, 5)
        XCTAssertEqual(entries[1].typesAdded, 5)
        XCTAssertEqual(entries[2].typesAdded, 3)
    }

    // MARK: - Cross-doctrine refs

    func testPerChapterExtensionDoctrineRefsHasThreeEntries()
    {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .perChapterExtensionDoctrineRefs.count,
            3)
    }

    func testParallelArcRefIsAggregatorArc() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .parallelArcRef,
            "BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine")
    }

    // MARK: - Type list

    func testAllTypesGainedCodableHasThirteenEntries() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .allTypesGainedCodable.count,
            13)
    }

    func testListSizeMatchesTotalCountFlagSet() {
        XCTAssertTrue(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .listSizeMatchesTotalCount)
    }

    // MARK: - Achievement flags

    func testNowLedgerSerializableFlagSet() {
        XCTAssertTrue(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .nowLedgerSerializable)
    }

    func testRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .realSubstrateChange)
    }

    func testOutsideAuditProjectionFamilyFlagSet() {
        XCTAssertTrue(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .outsideAuditProjectionFamily)
    }
}
