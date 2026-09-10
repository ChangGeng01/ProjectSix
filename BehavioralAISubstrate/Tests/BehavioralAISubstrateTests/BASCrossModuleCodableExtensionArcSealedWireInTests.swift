// MARK: - BASCrossModuleCodableExtensionArcSealedWireInTests
// chapter 五百六十九 / M1655 — wire-in PROOF tests for
//                          the M1653 arc-seal
//                          milestone
//
// ## What these wire-in tests prove
//
// 12 wire-in tests cross-check the M1653 arc-seal
// against the 3 actual extension doctrines + parallel
// chapter 564 aggregator-arc:
//
//   - perChapterExtensionDoctrineRefs match actual
//     type names (3 doctrines)
//   - perChapterContributions M-numbers match the
//     extensionMNumber on each catalogued extension
//     doctrine
//   - perChapterContributions typesAdded counts match
//     the totalTypesExtended on each extension
//     doctrine
//   - parallelArcRef matches actual aggregator arc
//     doctrine name
//   - arc M-number range agrees with extension
//     M-numbers
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:wire-in PROOF
//   - ADR-016 advances M1654 → M1655

import XCTest
@testable import BASRuntimeCore

final class BASCrossModuleCodableExtensionArcSealedWireInTests:
    XCTestCase
{

    // MARK: - Type-name agreement

    /// All 3 extension doctrine refs match actual
    /// type names。
    func testPerChapterExtensionDoctrineRefsMatchActualNames()
    {
        let actualNames = [
            String(describing:
                BASCrossModuleCodableExtensionDoctrine
                    .self),
            String(describing:
                BASMemoryCodableExtensionDoctrine.self),
            String(describing:
                BASCrossModuleCodableExtensionThirdWaveDoctrine
                    .self)
        ]
        let refs = BASCrossModuleCodableExtensionArcSealedDoctrine
            .perChapterExtensionDoctrineRefs
        XCTAssertEqual(refs.count, actualNames.count)
        for name in actualNames {
            XCTAssertTrue(refs.contains(name),
                "Arc-seal refs must include \(name)")
        }
    }

    /// parallelArcRef matches actual aggregator-arc
    /// doctrine name (chapter 564)。
    func testParallelArcRefMatchesActualName() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .parallelArcRef,
            String(describing:
                BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                    .self))
    }

    // MARK: - M-number cross-checks

    func testChapter566MNumberMatchesExtensionDoctrine()
    {
        let entries = BASCrossModuleCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[0].mNumber,
            BASCrossModuleCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testChapter567MNumberMatchesExtensionDoctrine()
    {
        let entries = BASCrossModuleCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[1].mNumber,
            BASMemoryCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testChapter568MNumberMatchesExtensionDoctrine()
    {
        let entries = BASCrossModuleCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[2].mNumber,
            BASCrossModuleCodableExtensionThirdWaveDoctrine
                .extensionMNumber)
    }

    // MARK: - Types-added cross-checks

    func testChapter566TypesAddedMatchesExtensionDoctrine()
    {
        let entries = BASCrossModuleCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[0].typesAdded,
            BASCrossModuleCodableExtensionDoctrine
                .totalTypesExtended)
    }

    func testChapter567TypesAddedMatchesExtensionDoctrine()
    {
        let entries = BASCrossModuleCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[1].typesAdded,
            BASMemoryCodableExtensionDoctrine
                .totalTypesExtended)
    }

    func testChapter568TypesAddedMatchesExtensionDoctrine()
    {
        let entries = BASCrossModuleCodableExtensionArcSealedDoctrine
            .perChapterContributions
        XCTAssertEqual(
            entries[2].typesAdded,
            BASCrossModuleCodableExtensionThirdWaveDoctrine
                .totalTypesExtended)
    }

    // MARK: - Arc range agreement

    func testArcFirstMNumberMatchesChapter566Extension() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcFirstMNumber,
            BASCrossModuleCodableExtensionDoctrine
                .extensionMNumber)
    }

    func testArcLastMNumberPlusOneEqualsMilestoneMNumber()
    {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcLastMNumber + 1,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    func testAllExtensionMNumbersFallWithinArcRange() {
        let first = BASCrossModuleCodableExtensionArcSealedDoctrine
            .arcFirstMNumber
        let last = BASCrossModuleCodableExtensionArcSealedDoctrine
            .arcLastMNumber
        let extMNumbers = [
            BASCrossModuleCodableExtensionDoctrine
                .extensionMNumber,
            BASMemoryCodableExtensionDoctrine
                .extensionMNumber,
            BASCrossModuleCodableExtensionThirdWaveDoctrine
                .extensionMNumber
        ]
        for m in extMNumbers {
            XCTAssertGreaterThanOrEqual(m, first)
            XCTAssertLessThanOrEqual(m, last)
        }
    }

    // MARK: - Combined count cross-check

    /// totalTypesExtended (13) equals sum of
    /// totalTypesExtended across 3 extension doctrines。
    func testTotalEqualsSumOfExtensions() {
        let sum =
            BASCrossModuleCodableExtensionDoctrine
                .totalTypesExtended
            + BASMemoryCodableExtensionDoctrine
                .totalTypesExtended
            + BASCrossModuleCodableExtensionThirdWaveDoctrine
                .totalTypesExtended
        XCTAssertEqual(
            sum,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
        XCTAssertEqual(sum, 13)
    }

    /// combinedCrossModuleCount on the M1651 doctrine
    /// equals 13 — agrees with the arc-seal total。
    func testM1651CombinedCountAgreesWithArcTotal() {
        XCTAssertEqual(
            BASCrossModuleCodableExtensionThirdWaveDoctrine
                .combinedCrossModuleCount,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }
}
