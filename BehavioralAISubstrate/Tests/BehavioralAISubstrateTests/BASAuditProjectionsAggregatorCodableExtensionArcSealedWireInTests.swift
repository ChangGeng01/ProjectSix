// MARK: - BASAuditProjectionsAggregatorCodableExtensionArcSealedWireInTests
// chapter 五百六十四 / M1635 — wire-in PROOF tests for
//                          the M1633 arc-seal
//                          doctrine
//
// ## What these wire-in tests prove
//
// 12 wire-in tests cross-check the M1633 arc-seal
// doctrine against the 3 actual extension doctrines
// + the parallel chapter 553 cascade-arc doctrine:
//
//   - perChapterExtensionDoctrineRefs match actual
//     type names (3 doctrines)
//   - perChapterContributions M-numbers match the
//     extensionMNumber on each catalogued extension
//     doctrine
//   - perChapterContributions typesAdded counts match
//     the totalTypesExtended fields on each extension
//     doctrine
//   - parallelArcRef matches actual chapter 553 arc-
//     seal doctrine name
//   - arc M-number range agrees with extension
//     doctrines' M-numbers
//   - arcLastMNumber + 1 == milestoneMNumber
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:wire-in PROOF
//   - ADR-016 advances M1634 → M1635

import XCTest
@testable import BASRuntimeCore

final class BASAuditProjectionsAggregatorCodableExtensionArcSealedWireInTests:
    XCTestCase
{

    // MARK: - Type-name agreement

    /// All 3 extension doctrine refs match actual
    /// String(describing: T.self)。
    func testPerChapterExtensionDoctrineRefsMatchActualNames()
    {
        let actualNames = [
            String(describing:
                BASTurnAuditProjectionsTrioCodableExtensionDoctrine
                    .self),
            String(describing:
                BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine
                    .self),
            String(describing:
                BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine
                    .self)
        ]
        let refs = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .perChapterExtensionDoctrineRefs
        XCTAssertEqual(refs.count, actualNames.count)
        for name in actualNames {
            XCTAssertTrue(refs.contains(name),
                "Arc-seal refs must include \(name)")
        }
    }

    func testParallelArcRefMatchesActualName() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .parallelArcRef,
            String(describing:
                BASCodableCascadeArcSealedDoctrine.self))
    }

    // MARK: - M-number cross-checks

    /// Chapter 561 contribution M-number = 1621 = M1621
    /// extension M-number on the chapter-561 extension
    /// doctrine。
    func testChapter561MNumberMatchesExtensionDoctrine()
    {
        let entries = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[0].mNumber,
            BASTurnAuditProjectionsTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testChapter562MNumberMatchesExtensionDoctrine()
    {
        let entries = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[1].mNumber,
            BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testChapter563MNumberMatchesExtensionDoctrine()
    {
        let entries = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[2].mNumber,
            BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine
                .extensionMNumber)
    }

    // MARK: - Types-added cross-checks

    func testChapter561TypesAddedMatchesExtensionDoctrine()
    {
        let entries = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[0].typesAdded,
            BASTurnAuditProjectionsTrioCodableExtensionDoctrine
                .totalTypesExtended)
    }

    func testChapter562TypesAddedMatchesExtensionDoctrine()
    {
        let entries = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[1].typesAdded,
            BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine
                .totalTypesExtended)
    }

    func testChapter563TypesAddedMatchesExtensionDoctrine()
    {
        let entries = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[2].typesAdded,
            BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine
                .totalTypesExtended)
    }

    // MARK: - Arc M-number range agreement

    func testArcFirstMNumberMatchesChapter561Extension() {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcFirstMNumber,
            BASTurnAuditProjectionsTrioCodableExtensionDoctrine
                .extensionMNumber)
    }

    /// arcLastMNumber (M1632) sits AT the close-out of
    /// chapter 563 (M1629-M1632)。 chapter-563
    /// extension shipped at M1629,close-out at M1632。
    /// The arc-seal milestone (this doctrine) ships
    /// at M1633 = arcLastMNumber + 1。
    func testArcLastMNumberPlusOneEqualsMilestoneMNumber()
    {
        XCTAssertEqual(
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcLastMNumber + 1,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    /// All 3 extension M-numbers fall within the arc
    /// range [arcFirstMNumber, arcLastMNumber]。
    func testAllExtensionMNumbersFallWithinArcRange() {
        let first = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .arcFirstMNumber
        let last = BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
            .arcLastMNumber
        let extMNumbers = [
            BASTurnAuditProjectionsTrioCodableExtensionDoctrine
                .extensionMNumber,
            BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine
                .extensionMNumber,
            BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine
                .extensionMNumber
        ]
        for m in extMNumbers {
            XCTAssertGreaterThanOrEqual(m, first)
            XCTAssertLessThanOrEqual(m, last)
        }
    }

    // MARK: - Combined aggregator count agreement

    /// totalAggregatorTypesExtended (15) must equal
    /// the sum of totalTypesExtended on the 3
    /// extension doctrines。
    func testTotalAggregatorTypesEqualsSumOfExtensions()
    {
        let sum =
            BASTurnAuditProjectionsTrioCodableExtensionDoctrine
                .totalTypesExtended
            + BASTurnAuditProjectionsFiveAggregatorCodableExtensionDoctrine
                .totalTypesExtended
            + BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine
                .totalTypesExtended
        XCTAssertEqual(
            sum,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .totalAggregatorTypesExtended)
        XCTAssertEqual(sum, 15)
    }

    /// The combinedAggregatorCount field on the M1631
    /// (chapter 563) extension doctrine equals 15 —
    /// agrees with the arc-seal total。
    func testM1631CombinedCountAgreesWithArcTotal() {
        XCTAssertEqual(
            BASTurnAuditProjectionsSevenAggregatorCodableExtensionDoctrine
                .combinedAggregatorCount,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .totalAggregatorTypesExtended)
    }
}
