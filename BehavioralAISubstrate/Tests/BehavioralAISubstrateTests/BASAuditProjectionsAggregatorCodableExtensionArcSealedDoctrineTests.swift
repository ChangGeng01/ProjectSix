// MARK: - BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrineTests
// chapter 五百六十四 / M1634 — anti-drift PROOF tests
//                          for the M1633 arc-seal
//                          doctrine
//
// ## Coverage matrix (18 tests)
//
//   - Pin invariants (chapterTag,milestoneMNumber,
//     arcFirstChapter,arcLastChapter,arcChapterCount
//     = 3,arcFirstMNumber,arcLastMNumber,arcMNumberSpan
//     = 12,3 boolean / string flag pins)
//   - List + count invariants (15 total types,3-chapter
//     contributions list,3 extension doctrine refs,15
//     type list)
//   - Sum + size cross-checks (sumOfChapterContributions
//     == totalAggregatorTypesExtended;
//     listSizeMatchesTotalCount = true)
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:single source-of-truth pins
//   - chapter 三百九二:this doctrine commemorates 15
//     types entering the replay-determinism surface
//   - ADR-016 advances M1633 → M1634

import XCTest
@testable import BASRuntimeCore

final class BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter564() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .chapterTag,
            "chapter 五百六十四")
    }

    func testMilestoneMNumberIs1633() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .milestoneMNumber,
            1633)
    }

    // MARK: - Arc range

    func testArcFirstChapterIs561() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcFirstChapter,
            "chapter 五百六十一")
    }

    func testArcLastChapterIs563() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcLastChapter,
            "chapter 五百六十三")
    }

    func testArcChapterCountIsThree() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcChapterCount,
            3)
    }

    func testArcFirstMNumberIs1621() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcFirstMNumber,
            1621)
    }

    func testArcLastMNumberIs1632() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcLastMNumber,
            1632)
    }

    func testArcMNumberSpanIsTwelve() {
        // 1632 - 1621 + 1 = 12
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcMNumberSpan,
            12)
    }

    // MARK: - Aggregator coverage

    func testTotalAggregatorTypesExtendedIsFifteen() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .totalAggregatorTypesExtended,
            15)
    }

    func testPerChapterContributionsHasThreeEntries() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .perChapterContributions.count,
            3)
    }

    func testSumOfChapterContributionsMatchesTotal() {
        // 3 + 5 + 7 = 15
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .sumOfChapterContributions,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .totalAggregatorTypesExtended)
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .sumOfChapterContributions,
            15)
    }

    func testPerChapterContributionsExactValues() {
        let entries = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(entries[0].chapterTag,
                       "chapter 五百六十一")
        XCTAssertEqual(entries[0].mNumber, 1621)
        XCTAssertEqual(entries[0].typesAdded, 3)
        XCTAssertEqual(entries[1].chapterTag,
                       "chapter 五百六十二")
        XCTAssertEqual(entries[1].mNumber, 1625)
        XCTAssertEqual(entries[1].typesAdded, 5)
        XCTAssertEqual(entries[2].chapterTag,
                       "chapter 五百六十三")
        XCTAssertEqual(entries[2].mNumber, 1629)
        XCTAssertEqual(entries[2].typesAdded, 7)
    }

    // MARK: - Cross-doctrine refs

    func testPerChapterExtensionDoctrineRefsHasThreeEntries()
    {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .perChapterExtensionDoctrineRefs.count,
            3)
    }

    func testParallelArcRefMatchesCascadeArc() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .parallelArcRef,
            "BASCodableCascadeArcSealedDoctrine")
    }

    // MARK: - Type list

    func testAllTypesGainedCodableHasFifteenEntries() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .allTypesGainedCodable.count,
            15)
    }

    func testListSizeMatchesTotalCountFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .listSizeMatchesTotalCount)
    }

    // MARK: - Achievement flags

    func testNowLedgerSerializableFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .nowLedgerSerializable)
    }

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .realSubstrateChange)
    }

    func testArcCompleteFlagSet() {
        XCTAssertTrue(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcComplete)
    }
}
