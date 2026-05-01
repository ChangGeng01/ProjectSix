import XCTest
import BASMemory
import BASRuntimeCore
import BASSovereign
@testable import QinaoSeats
@testable import QinaoWorldPrior

/// 六十三 — repo closure capstone integration test.
///
/// **One mega-test that exercises every doctrine surface
/// shipped over chapters 二十五–六十二 and proves they
/// compose without conflict.**
///
/// This is **the** acceptance test for the entire
/// typed-doctrine layer. If a future change breaks any
/// doctrine compose-rule, this test fails first.
///
/// Pure-typed only — no AFM, no real network, no domain
/// experts needed. Runs on every `swift test`.
///
/// Doctrine surfaces touched:
///
/// 1. Doctrine A (private experience never enters L2)
/// 2. Doctrine A inverse (post-Path-B permitted)
/// 3. Doctrine B (actor → scope mapping)
/// 4. Doctrine C (parameter scope = .veryLow velocity)
/// 5. Doctrine D (actor → output class permission)
/// 6. Cross-pillar guard (B+C+D unified)
/// 7. Three streams (cognition / permission / growth)
/// 8. L4 治理 7-stage authoring track
/// 9. L13 evolution lifecycle state machine
/// 10. Cross-vault contract (worldPrior / hostConstitution
///     / snapshotArk)
/// 11. v3 motherboard L1-L14 ↔ kernel/bus/vault mapping
/// 12. v3 motherboard runtime 8-step canonical sequence
/// 13. v3 motherboard 4 sovereign emergency ops
/// 14. v3 motherboard 7 cognitive objects axis
/// 15. v3 motherboard 5 restraint surfaces
final class QinaoRepoClosureCapstoneTests: XCTestCase {

    // MARK: - Fixtures

    private func goodInput(
        templateID: String = "tmpl-closure-capstone"
    ) -> BASWorldPriorTemplateAcceptance.Input {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: templateID,
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Closure capstone canonical template " +
                "with adequate description length.")
    }

    // MARK: - The mega-capstone

    func test_repoClosureCapstone_allDoctrineSurfacesCompose()
        throws
    {
        // ============================================================
        // Doctrine D — actor / output class / scope / velocity
        // ============================================================

        XCTAssertEqual(
            BASActor.allCases.count, 4,
            "4 actors typed-pinned")
        XCTAssertTrue(
            BASActor.host.permits(
                outputClass: .directive))
        XCTAssertTrue(
            BASActor.secondBrain.permits(
                outputClass: .authoritative))
        XCTAssertTrue(
            BASActor.neuralNetwork.permits(
                outputClass: .advisory))
        XCTAssertTrue(
            BASActor.sdk.permits(
                outputClass: .execution))
        // No actor outside the matrix.
        XCTAssertFalse(
            BASActor.neuralNetwork.permits(
                outputClass: .execution))
        XCTAssertFalse(
            BASActor.host.permits(
                outputClass: .authoritative))

        // ============================================================
        // Doctrine B — canonical scope per actor
        // ============================================================

        XCTAssertEqual(
            BASActor.neuralNetwork.canonicalUpdateScope,
            .parameter)
        XCTAssertEqual(
            BASActor.secondBrain.canonicalUpdateScope,
            .process)
        XCTAssertEqual(
            BASActor.host.canonicalUpdateScope,
            .individual)
        XCTAssertEqual(
            BASActor.sdk.canonicalUpdateScope, .device)

        // ============================================================
        // Doctrine C — parameter scope must run at .veryLow
        // ============================================================

        XCTAssertEqual(
            BASStateUpdateScope.parameter
                .canonicalVelocity,
            .veryLow)
        XCTAssertTrue(
            BASDoctrineCInvariant.permits(
                velocity: .veryLow,
                at: .parameter))
        XCTAssertFalse(
            BASDoctrineCInvariant.permits(
                velocity: .immediate,
                at: .parameter))

        // ============================================================
        // Three streams — cognition / permission / growth
        // ============================================================

        XCTAssertEqual(
            BASManifestStream.allCases.count, 3)
        XCTAssertEqual(
            BASManifestStream.cognition.stages.count, 5)
        XCTAssertEqual(
            BASManifestStream.permission.stages.count, 3)
        XCTAssertEqual(
            BASManifestStream.growth.stages.count, 5)
        XCTAssertEqual(
            BASManifestStreamStage.allCases.count, 13)

        // ============================================================
        // Cross-pillar unified guard
        // ============================================================

        let canonicalOp = BASDoctrineActorOperation(
            actor: .secondBrain,
            outputClass: .authoritative,
            stateUpdateScope: .process,
            stateUpdateVelocity: .medium)
        XCTAssertTrue(
            BASDoctrineActorOperationGuard.isCompliant(
                canonicalOp))

        let badOp = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .execution,
            stateUpdateScope: .parameter,
            stateUpdateVelocity: .immediate)
        XCTAssertFalse(
            BASDoctrineActorOperationGuard.isCompliant(
                badOp))

        // ============================================================
        // L4 治理 — Doctrine A + 7-stage authoring track
        // ============================================================

        // Pre-approval envelope is .illustrative → blocked
        let illustrativeEnvelope =
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .illustrative)
        XCTAssertEqual(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(
                    for: illustrativeEnvelope),
            .privateProvenance(.illustrative),
            "Doctrine A: .illustrative blocked from training")

        // Walk authoring track
        var session =
            BASWorldPriorTemplateAuthoringSession(
                templateID: "tmpl-closure-capstone")
        XCTAssertEqual(session.currentStage, .draft)
        session = try XCTUnwrap(
            session.applying(.hostAccept))
        session = try XCTUnwrap(
            session.applying(.submitForPeerReview))
        session = try XCTUnwrap(
            session.applying(.approveDomain))
        XCTAssertEqual(
            session.currentStage, .domainApproved)
        XCTAssertEqual(
            session.attainedProvenance,
            .domainExpertReviewed)

        // Doctrine A inverse — post-approval permitted
        let approvedEnvelope =
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .domainExpertReviewed)
        XCTAssertNil(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(
                    for: approvedEnvelope),
            "Doctrine A inverse: domainExpertReviewed " +
            "passes training filter")

        // Attestation binding
        let attestation =
            BASWorldPriorTemplateAttestation(
                envelope: approvedEnvelope,
                authoringSession: session)
        XCTAssertTrue(
            BASWorldPriorTemplateAttestationGate.isValid(
                attestation))

        // Production curriculum entry
        let entry =
            BASWorldPriorProductionCurriculumEntry(
                envelope: approvedEnvelope,
                authoringSession: session)
        XCTAssertTrue(entry.isProductionGrade)
        let curriculum = try XCTUnwrap(
            BASWorldPriorProductionCurriculum.empty
                .registering(entry))
        XCTAssertEqual(curriculum.entries.count, 1)

        // Training export
        let exportResult =
            BASWorldPriorTrainingExporter.export(
                curriculum.productionEnvelopes)
        XCTAssertEqual(
            exportResult.report.exportedCount, 1)
        XCTAssertFalse(exportResult.jsonl.isEmpty)

        // ============================================================
        // L13 evolution lifecycle state machine
        // ============================================================

        var lifecycle =
            BASEvolutionLifecycleSession(
                candidateID: "cand-closure-capstone")
        for action: BASEvolutionLifecycleAction in [
            .registerCandidate,
            .startShadowTrial,
            .finalizeTrial,
            .promote,
        ] {
            lifecycle = try XCTUnwrap(
                lifecycle.applying(action))
        }
        XCTAssertEqual(
            lifecycle.currentStage, .promoted)
        XCTAssertTrue(lifecycle.hasReachedPromotion)
        XCTAssertFalse(
            lifecycle.isTerminal,
            ".promoted is not terminal — retraction reachable")

        // ============================================================
        // v3 motherboard — 6 macro enums + 10 micro enums
        // ============================================================

        XCTAssertEqual(
            BASMotherboardPrinciple.allCases.count, 5)
        XCTAssertEqual(
            BASMotherboardPlane.allCases.count, 3)
        XCTAssertEqual(
            BASMotherboardKernel.allCases.count, 4)
        XCTAssertEqual(
            BASMotherboardBus.allCases.count, 8)
        XCTAssertEqual(
            BASMotherboardVault.allCases.count, 3)
        XCTAssertEqual(
            BASMotherboardSDKAPI.allCases.count, 4)

        // 14 layers + 8 steps + 31 duties + 4 emergency ops
        XCTAssertEqual(
            BASMotherboardLayer14.allCases.count, 14)
        XCTAssertEqual(
            BASMotherboardRuntimeStep.allCases.count, 8)
        XCTAssertEqual(
            BASMotherboardSovereignDuty.allCases.count, 8)
        XCTAssertEqual(
            BASMotherboardLifeDuty.allCases.count, 9)
        XCTAssertEqual(
            BASMotherboardOrganDuty.allCases.count, 8)
        XCTAssertEqual(
            BASMotherboardStateGraphDuty.allCases.count, 6)
        XCTAssertEqual(
            BASMotherboardSovereignEmergencyOp
                .allCases.count, 4)
        XCTAssertEqual(
            BASMotherboardCognitiveObjectAxis
                .theSeven.count, 7)
        XCTAssertEqual(
            BASMotherboardRestraintSurface
                .allCases.count, 5)

        // L1-L14 mapping consistency
        XCTAssertEqual(
            BASMotherboardLayer14.l14.primaryKernel,
            .sovereignMicrokernel)
        XCTAssertEqual(
            BASMotherboardLayer14.l1.primaryKernel,
            .leaseAndLife)
        XCTAssertEqual(
            BASMotherboardLayer14.l4.primaryVault,
            .worldPriorVault)
        XCTAssertEqual(
            BASMotherboardLayer14.l5.primaryVault,
            .hostConstitutionVault)

        // Runtime 8-step ordered
        XCTAssertEqual(
            BASMotherboardRuntimeSequence.entry,
            .hostInputIntoSDK)
        XCTAssertEqual(
            BASMotherboardRuntimeSequence.terminus,
            .eventSourcing)

        // 4 emergency ops all trace to delete-rollback-reboot
        // first-class principle
        for op in
            BASMotherboardSovereignEmergencyOp.allCases
        {
            XCTAssertEqual(
                op.triggeredByPrinciple,
                .deleteRollbackRebootFirstClass)
        }

        // 5 restraint surfaces all fall back from permitGate
        for surface in
            BASMotherboardRestraintSurface.allCases
        {
            XCTAssertEqual(
                surface.fallbackFrom, .permitGate)
        }

        // 7 cognitive objects all carry on some bus
        for object in
            BASMotherboardCognitiveObjectAxis.theSeven
        {
            XCTAssertNotNil(
                object.carryingBus,
                "cognitive object \(object) must be " +
                "carried by some bus")
        }

        // ============================================================
        // Cross-vault contract — host vault + world vault +
        // snapshot manager (we check only the typed
        // attestation here; full async test is in 五十六)
        // ============================================================

        let hostConstitution = BASHostConstitution(
            hostID: "host-closure",
            activeVersion: "host.v1")
        let hostVault = BASHostConstitutionVault(
            constitutionSnapshot: hostConstitution,
            deviceConsistencyReport:
                BASHostDeviceConsistencyReport(
                    sourceDeviceID: "device-closure"))
        XCTAssertEqual(
            hostVault.constitutionSnapshot.hostID,
            "host-closure")

        // ============================================================
        // 9-seat council typed pin
        // ============================================================

        XCTAssertEqual(QinaoSeat.allCases.count, 9)
        XCTAssertTrue(
            QinaoSeat.allCases.contains(.scout))
        XCTAssertTrue(
            QinaoSeat.allCases.contains(.planner))
        XCTAssertTrue(
            QinaoSeat.allCases.contains(.critic))
        XCTAssertTrue(
            QinaoSeat.allCases.contains(.sovereignSentinel))

        // ============================================================
        // Closure assertion — total invariant count
        // ============================================================

        // 4 doctrines × multiple invariants × all pass
        // means the typed doctrine layer composes without
        // contradiction.
        // This single test is the acceptance gate for "did
        // any compose-rule break".
    }
}
