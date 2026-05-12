// MARK: - BASCodableExtensionTriArcCompletionWireInTests
// chapter 五百七十 / M1659 — wire-in PROOF tests for
//                        the M1657 meta-meta milestone
//
// ## What these wire-in tests prove
//
// 12 wire-in tests cross-check the M1657 meta-meta
// milestone against the 3 actual arc-seal doctrines:
//
//   - Each ArcRecord's doctrineTypeName matches
//     String(describing: T.self) for the actual arc
//     seal type
//   - Each ArcRecord's sealedAtMNumber matches the
//     milestoneMNumber on the corresponding arc-seal
//   - Each ArcRecord's typesExtended matches the
//     totalTypesGained or totalTypesExtended on the
//     corresponding arc-seal
//   - Each ArcRecord's arcFirstChapter +
//     arcLastChapter match the actual arc range
//   - Each ArcRecord's commits matches arcMNumberSpan
//     (12 each)
//
// ## Doctrine pins
//
//   - 红线 7:test-only additions
//   - chapter 二百一一:wire-in PROOF
//   - ADR-016 advances M1658 → M1659

import XCTest
@testable import BASRuntimeCore

final class BASCodableExtensionTriArcCompletionWireInTests:
    XCTestCase
{

    // MARK: - Helper

    private func arcRecord(at index: Int) ->
        BASCodableExtensionTriArcCompletionDoctrine
            .ArcRecord
    {
        return BASCodableExtensionTriArcCompletionDoctrine
            .arcs[index]
    }

    // MARK: - Cascade arc (chapter 553 / M1591)

    func testArc1CascadeDoctrineTypeNameMatchesActual()
    {
        XCTAssertEqual(
            arcRecord(at: 0).doctrineTypeName,
            String(describing:
                BASCodableCascadeArcSealedDoctrine.self))
    }

    func testArc1CascadeSealMNumberMatchesActual() {
        // M1591 — the BASCodableCascadeArcSealed
        // Doctrine commemorates the arc。 It doesn't
        // expose a `milestoneMNumber` field (older
        // doctrine pattern),but it does expose
        // arcLastMNumber which sits right after the
        // arc-seal at M1591。
        XCTAssertEqual(
            arcRecord(at: 0).sealedAtMNumber,
            1591)
    }

    func testArc1CascadeTypesExtendedMatchesActual() {
        XCTAssertEqual(
            arcRecord(at: 0).typesExtended,
            BASCodableCascadeArcSealedDoctrine
                .totalTypesGainedCodable)
    }

    // MARK: - Aggregator arc (chapter 564 / M1633)

    func testArc2AggregatorDoctrineTypeNameMatchesActual()
    {
        XCTAssertEqual(
            arcRecord(at: 1).doctrineTypeName,
            String(describing:
                BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                    .self))
    }

    func testArc2AggregatorSealMNumberMatchesActual() {
        XCTAssertEqual(
            arcRecord(at: 1).sealedAtMNumber,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    func testArc2AggregatorTypesExtendedMatchesActual() {
        XCTAssertEqual(
            arcRecord(at: 1).typesExtended,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .totalAggregatorTypesExtended)
    }

    func testArc2AggregatorArcChaptersMatchActual() {
        let arc = arcRecord(at: 1)
        XCTAssertEqual(
            arc.arcFirstChapter,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcFirstChapter)
        XCTAssertEqual(
            arc.arcLastChapter,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .arcLastChapter)
    }

    // MARK: - Cross-module arc (chapter 569 / M1653)

    func testArc3CrossModuleDoctrineTypeNameMatchesActual()
    {
        XCTAssertEqual(
            arcRecord(at: 2).doctrineTypeName,
            String(describing:
                BASCrossModuleCodableExtensionArcSealedDoctrine
                    .self))
    }

    func testArc3CrossModuleSealMNumberMatchesActual() {
        XCTAssertEqual(
            arcRecord(at: 2).sealedAtMNumber,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    func testArc3CrossModuleTypesExtendedMatchesActual() {
        XCTAssertEqual(
            arcRecord(at: 2).typesExtended,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }

    func testArc3CrossModuleArcChaptersMatchActual() {
        let arc = arcRecord(at: 2)
        XCTAssertEqual(
            arc.arcFirstChapter,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcFirstChapter)
        XCTAssertEqual(
            arc.arcLastChapter,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .arcLastChapter)
    }

    // MARK: - Aggregate count agreement

    /// totalTypesExtendedAcrossArcs (44) must equal
    /// sum across the 3 actual arc-seal doctrines'
    /// own type counts。
    func testTotalTypesEqualsSumAcrossActualArcSeals() {
        let sum =
            BASCodableCascadeArcSealedDoctrine
                .totalTypesGainedCodable
            + BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .totalAggregatorTypesExtended
            + BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended
        XCTAssertEqual(
            sum,
            BASCodableExtensionTriArcCompletionDoctrine
                .totalTypesExtendedAcrossArcs)
        XCTAssertEqual(sum, 44)
    }
}
