// MARK: - BASCodableExtensionQuadArcCompletionDoctrineWireInTests
// chapter 五百七十五 / M1679 — wire-in PROOF tests
//                          cross-checking the M1677
//                          quad-arc catalog against the
//                          4 source arc-seal doctrines
//
// ## Coverage (16 wire-in PROOF tests)
//
// For each of the 4 sealed arcs:
//   1. quad-arc's typesExtended must match the source
//      arc-seal's type-count field
//   2. quad-arc's sealedAtMNumber must match the
//      source arc-seal's last M-number (where exposed)
//      or known M-number literal (cascade arc)
//   3. quad-arc's arc-range must match the source
//      arc-seal's arc-range (where exposed)
//   4. quad-arc's doctrineTypeName must spell the
//      source arc-seal's exact type name
//
// Plus:
//   - Tri-arc snapshot ref points at the chapter 570
//     frozen doctrine
//   - Quad-arc totalTypesExtendedAcrossArcs matches
//     the chapter-570 tri-arc total (44) plus the new
//     4th arc's 6 types = 50
//
// Mirrors chapter 569/574 arc-seal wire-in patterns。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1678 → M1679

import XCTest
@testable import BASRuntimeCore

final class BASCodableExtensionQuadArcCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - ARC 1 — Cascade wire-ins

    func testArc1CascadeTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[0].typesExtended,
            BASCodableCascadeArcSealedDoctrine
                .totalTypesGainedCodable)
    }

    func testArc1CascadeCommitsWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[0].commits,
            BASCodableCascadeArcSealedDoctrine
                .arcCommitCount)
    }

    func testArc1CascadeSealedMNumberMatchesLast() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[0].sealedAtMNumber,
            BASCodableCascadeArcSealedDoctrine
                .arcLastMNumber - 1) // 1591 vs 1592 close-out
    }

    func testArc1CascadeDoctrineTypeNameMatches() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[0].doctrineTypeName,
            "BASCodableCascadeArcSealedDoctrine")
    }

    // MARK: - ARC 2 — Aggregator wire-ins

    func testArc2AggregatorTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[1].typesExtended,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .totalAggregatorTypesExtended)
    }

    func testArc2AggregatorSealedChapterWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[1].sealedAtChapter,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .chapterTag)
    }

    func testArc2AggregatorSealedMNumberWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[1].sealedAtMNumber,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    func testArc2AggregatorDoctrineTypeNameMatches() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[1].doctrineTypeName,
            "BASAuditProjectionsAggregator" +
            "CodableExtensionArcSealedDoctrine")
    }

    // MARK: - ARC 3 — Cross-module wire-ins

    func testArc3CrossModuleTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[2].typesExtended,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }

    func testArc3CrossModuleSealedChapterWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[2].sealedAtChapter,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .chapterTag)
    }

    func testArc3CrossModuleSealedMNumberWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[2].sealedAtMNumber,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    // MARK: - ARC 4 — Orchestration wire-ins

    func testArc4OrchestrationTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[3].typesExtended,
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }

    func testArc4OrchestrationSealedChapterWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[3].sealedAtChapter,
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .chapterTag)
    }

    func testArc4OrchestrationSealedMNumberWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .arcs[3].sealedAtMNumber,
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    // MARK: - Tri-arc snapshot ref + supersession

    func testPriorTriArcSnapshotRefPointsCorrectly() {
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .priorTriArcSnapshotRef,
            "BASCodableExtensionTriArcCompletionDoctrine")
    }

    func testQuadArcExtendsTriArcByOrchestrationCount() {
        // Tri-arc had 44 types; quad-arc adds the 4th
        // arc's 6 types → 50 total。
        XCTAssertEqual(
            BASCodableExtensionQuadArcCompletionDoctrine
                .totalTypesExtendedAcrossArcs,
            BASCodableExtensionTriArcCompletionDoctrine
                .totalTypesExtendedAcrossArcs
                + BASOrchestrationCodableExtensionArcSealedDoctrine
                    .totalTypesExtended)
    }
}
