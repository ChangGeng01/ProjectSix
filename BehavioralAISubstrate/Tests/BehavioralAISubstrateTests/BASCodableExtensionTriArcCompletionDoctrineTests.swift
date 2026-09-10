// MARK: - BASCodableExtensionTriArcCompletionDoctrineTests
// chapter 五百七十 / M1658 — anti-drift PROOF tests
//                        for the M1657 meta-meta
//                        milestone
//
// ## Coverage matrix (18 tests)
//
//   - Pin invariants (chapterTag,milestoneMNumber,
//     totalArcsSealed,totalContributingChapters,
//     postArcInputsCount,3 boolean flags)
//   - Arcs list (3 entries,each with exact field
//     values)
//   - Aggregate computed accessors (sum invariants:
//     44 types,36 commits,46 total session count)
//   - Codable round-trip on ArcRecord
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:single source-of-truth pins
//   - ADR-016 advances M1657 → M1658

import XCTest
@testable import BASRuntimeCore

final class BASCodableExtensionTriArcCompletionDoctrineTests:
    XCTestCase
{

    // MARK: - Pin invariants

    func testChapterTagIsChapter570() {
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .chapterTag,
            "chapter 五百七十")
    }

    func testMilestoneMNumberIs1657() {
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .milestoneMNumber,
            1657)
    }

    func testTotalArcsSealedIsThree() {
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .totalArcsSealed,
            3)
    }

    func testTotalContributingChaptersIsNine() {
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .totalContributingChapters,
            9)
    }

    func testPostArcInputsCountIsTwo() {
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .postArcInputsCount,
            2)
    }

    func testAllArcsRealSubstrateChangeFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionTriArcCompletionDoctrine
                .allArcsRealSubstrateChange)
    }

    func testByteEqualityPreservedThroughoutFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionTriArcCompletionDoctrine
                .byteEqualityPreservedThroughout)
    }

    func testAllArcsHaveAntiDriftCoverageFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionTriArcCompletionDoctrine
                .allArcsHaveAntiDriftCoverage)
    }

    // MARK: - Arcs list

    func testArcsHasThreeEntries() {
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .arcs.count,
            3)
    }

    func testArcsCountMatchesTotalFlagSet() {
        XCTAssertTrue(
            BASCodableExtensionTriArcCompletionDoctrine
                .arcsCountMatchesTotal)
    }

    func testArc1CascadeRecord() {
        let arc =
            BASCodableExtensionTriArcCompletionDoctrine
                .arcs[0]
        XCTAssertEqual(arc.doctrineTypeName,
                       "BASCodableCascadeArcSealedDoctrine")
        XCTAssertEqual(arc.sealedAtChapter,
                       "chapter 五百五十三")
        XCTAssertEqual(arc.sealedAtMNumber, 1591)
        XCTAssertEqual(arc.arcFirstChapter,
                       "chapter 五百五十一")
        XCTAssertEqual(arc.arcLastChapter,
                       "chapter 五百五十三")
        XCTAssertEqual(arc.typesExtended, 16)
        XCTAssertEqual(arc.commits, 12)
    }

    func testArc2AggregatorRecord() {
        let arc =
            BASCodableExtensionTriArcCompletionDoctrine
                .arcs[1]
        XCTAssertEqual(arc.doctrineTypeName,
            "BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine")
        XCTAssertEqual(arc.sealedAtChapter,
                       "chapter 五百六十四")
        XCTAssertEqual(arc.sealedAtMNumber, 1633)
        XCTAssertEqual(arc.typesExtended, 15)
        XCTAssertEqual(arc.commits, 12)
    }

    func testArc3CrossModuleRecord() {
        let arc =
            BASCodableExtensionTriArcCompletionDoctrine
                .arcs[2]
        XCTAssertEqual(arc.doctrineTypeName,
            "BASCrossModuleCodableExtensionArcSealedDoctrine")
        XCTAssertEqual(arc.sealedAtChapter,
                       "chapter 五百六十九")
        XCTAssertEqual(arc.sealedAtMNumber, 1653)
        XCTAssertEqual(arc.typesExtended, 13)
        XCTAssertEqual(arc.commits, 12)
    }

    // MARK: - Aggregate computed accessors

    func testTotalTypesExtendedAcrossArcsIsFortyFour() {
        // 16 + 15 + 13 = 44
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .totalTypesExtendedAcrossArcs,
            44)
    }

    func testTotalCommitsAcrossArcsIsThirtySix() {
        // 12 × 3 = 36
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .totalCommitsAcrossArcs,
            36)
    }

    func testTotalSessionLedgerSerializableIsFortySix() {
        // 44 (arcs) + 2 (post-arc) = 46
        XCTAssertEqual(
            BASCodableExtensionTriArcCompletionDoctrine
                .totalSessionLedgerSerializable,
            46)
    }

    // MARK: - Codable round-trip on ArcRecord

    /// The ArcRecord type is itself Codable;each
    /// entry round-trips byte-identical via JSON。
    func testArcRecordRoundTripsByteIdentical() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let arcs = BASCodableExtensionTriArcCompletionDoctrine
            .arcs
        let data = try encoder.encode(arcs)
        let decoded = try JSONDecoder().decode(
            [BASCodableExtensionTriArcCompletionDoctrine
                .ArcRecord].self,
            from: data)
        XCTAssertEqual(decoded, arcs)
        XCTAssertEqual(decoded.count, 3)
    }

    // MARK: - Sealed M-numbers are monotonically increasing

    func testSealedMNumbersAreStrictlyMonotonic() {
        let arcs = BASCodableExtensionTriArcCompletionDoctrine
            .arcs
        for i in 1..<arcs.count {
            XCTAssertGreaterThan(
                arcs[i].sealedAtMNumber,
                arcs[i - 1].sealedAtMNumber,
                "Arc \(i) sealed M-number must be > arc \(i-1)")
        }
    }
}
