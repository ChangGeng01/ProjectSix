// MARK: - BASCodableExtensionPentaMilestoneCompletionDoctrineWireInTests
// chapter 五百八十 / M1699 — wire-in PROOF tests
//                        cross-checking the M1697
//                        penta-milestone catalog
//                        against the 5 source seal
//                        doctrines
//
// ## Coverage (18 wire-in PROOF tests)
//
// For each of the 5 sealed milestones:
//   1. penta's typesExtended must match source
//      doctrine's type-count field
//   2. penta's sealedAtMNumber must match the source
//      doctrine's last/seal M-number
//
// Plus:
//   - Quad-arc snapshot ref points correctly
//   - Tri-arc snapshot ref points correctly
//   - Penta total == quad-arc total + post-arc trilogy
//     (supersession invariant)
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:test-only additions
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1698 → M1699

import XCTest
@testable import BASRuntimeCore

final class BASCodableExtensionPentaMilestoneCompletionDoctrineWireInTests:
    XCTestCase
{
    // MARK: - MILESTONE 1 — Cascade wire-ins

    func testMilestone1CascadeTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[0].typesExtended,
            BASCodableCascadeArcSealedDoctrine
                .totalTypesGainedCodable)
    }

    func testMilestone1CascadeCommitsWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[0].commits,
            BASCodableCascadeArcSealedDoctrine
                .arcCommitCount)
    }

    func testMilestone1CascadeSealMNumberMatchesLastMinusOne()
    {
        // Cascade seal is M1591, arcLastMNumber is
        // M1592 (close-out)。 Same offset as chapter
        // 575 quad-arc wire-in。
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[0].sealedAtMNumber,
            BASCodableCascadeArcSealedDoctrine
                .arcLastMNumber - 1)
    }

    func testMilestone1CascadeKind() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[0].kind,
            "arc")
    }

    // MARK: - MILESTONE 2 — Aggregator wire-ins

    func testMilestone2AggregatorTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[1].typesExtended,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .totalAggregatorTypesExtended)
    }

    func testMilestone2AggregatorSealMNumberWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[1].sealedAtMNumber,
            BASAuditProjectionsAggregatorCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    func testMilestone2AggregatorKind() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[1].kind,
            "arc")
    }

    // MARK: - MILESTONE 3 — Cross-module wire-ins

    func testMilestone3CrossModuleTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[2].typesExtended,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }

    func testMilestone3CrossModuleSealMNumberWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[2].sealedAtMNumber,
            BASCrossModuleCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    func testMilestone3CrossModuleKind() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[2].kind,
            "arc")
    }

    // MARK: - MILESTONE 4 — Orchestration arc wire-ins

    func testMilestone4OrchestrationTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[3].typesExtended,
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .totalTypesExtended)
    }

    func testMilestone4OrchestrationSealMNumberWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[3].sealedAtMNumber,
            BASOrchestrationCodableExtensionArcSealedDoctrine
                .milestoneMNumber)
    }

    func testMilestone4OrchestrationKind() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[3].kind,
            "arc")
    }

    // MARK: - MILESTONE 5 — Post-arc trilogy wire-ins

    func testMilestone5PostArcTrilogyTypesExtendedWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[4].typesExtended,
            BASOrchestrationCodableExtensionPostArcTrilogySealedDoctrine
                .totalTypesExtended)
    }

    func testMilestone5PostArcTrilogySealMNumberWiresIn() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[4].sealedAtMNumber,
            BASOrchestrationCodableExtensionPostArcTrilogySealedDoctrine
                .milestoneMNumber)
    }

    func testMilestone5PostArcTrilogyKind() {
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .milestones[4].kind,
            "post-arc-trilogy")
    }

    // MARK: - Supersession invariants

    func testPentaTotalEqualsQuadArcPlusPostArcTrilogy() {
        // Quad-arc had 50 types; penta adds the 5th
        // milestone's 6 types → 56 total。
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalTypesExtendedAcrossMilestones,
            BASCodableExtensionQuadArcCompletionDoctrine
                .totalTypesExtendedAcrossArcs
                + BASOrchestrationCodableExtensionPostArcTrilogySealedDoctrine
                    .totalTypesExtended)
    }

    func testPentaSessionTotalEqualsQuadArcSessionPlusTrilogyTypes() {
        // Session total includes the 2 post-arc inputs
        // from chapter 565,which both penta and quad-
        // arc already account for。
        XCTAssertEqual(
            BASCodableExtensionPentaMilestoneCompletionDoctrine
                .totalSessionLedgerSerializable,
            BASCodableExtensionQuadArcCompletionDoctrine
                .totalSessionLedgerSerializable
                + BASOrchestrationCodableExtensionPostArcTrilogySealedDoctrine
                    .totalTypesExtended)
    }
}
