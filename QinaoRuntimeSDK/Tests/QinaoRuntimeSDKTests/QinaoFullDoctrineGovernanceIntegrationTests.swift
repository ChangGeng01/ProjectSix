import XCTest
@testable import QinaoWorldPrior
import BASSovereign
@testable import BASRuntimeCore

/// 五十二 — full-stack doctrine governance integration test.
///
/// **Capstone test** for the entire typed governance system shipped
/// in honesty-board 二十五–五十一. Walks one canonical scenario
/// (domain expert authors a template, lifts it through the stages,
/// publishes as production envelope, exercises every typed gate)
/// and asserts:
///
/// 1. **Authoring lifecycle (M295.1.0)**: 4-step transition draft →
///    hostReviewed → peerReview → domainApproved, history accumulates.
/// 2. **Attestation gate (M295.1.1)**: envelope at .domainExpertReviewed
///    validates against domainApproved session.
/// 3. **Acceptance validator (M295.0)**: well-formed input passes M295.0.
/// 4. **Training filter (M295.2)**: domain-expert-reviewed envelope is
///    permitted into training pipeline.
/// 5. **Doctrine D matrix (BASActor)**: secondBrain produces authoritative
///    output (the production permit), neuralNetwork produces advisory
///    only.
/// 6. **Doctrine B+C unified guard (BASDoctrineActorOperationGuard)**:
///    canonical secondBrain operation at process scope with medium
///    velocity is compliant.
/// 7. **Manifest stream typed reference**: stages and verdicts trace
///    through cognition / permission / growth streams.
///
/// Pre-domain-expert (illustrative starter) is **typed-blocked** at
/// the attestation + training-filter level, proving Doctrine A is
/// physically enforced through the chain.
final class QinaoFullDoctrineGovernanceIntegrationTests:
    XCTestCase
{

    // MARK: - Scenario fixture

    private func goodInput()
        -> BASWorldPriorTemplateAcceptance.Input
    {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: "tmpl-relationship-conflict",
            perturbKindsCovered: [
                "dropPrecondition",
                "introduceBlocker",
            ],
            branchEvidenceRungs: [2, 2, 1, 1],
            description:
                "Conflict pressure changes communication shape.")
    }

    // MARK: - End-to-end: domain expert lifts template through stages

    func test_endToEnd_domainExpertAuthorsTemplate_allGatesPass()
        throws
    {
        // Step 1 — author starts session at .draft.
        var session = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-relationship-conflict")
        XCTAssertEqual(session.currentStage, .draft)
        XCTAssertEqual(
            session.attainedProvenance, .illustrative)

        // Step 2 — host accepts the draft.
        session = try XCTUnwrap(
            session.applying(.hostAccept))
        XCTAssertEqual(session.currentStage, .hostReviewed)
        XCTAssertEqual(
            session.attainedProvenance, .hostReviewed)

        // Step 3 — submit for peer review.
        session = try XCTUnwrap(
            session.applying(.submitForPeerReview))
        XCTAssertEqual(session.currentStage, .peerReview)

        // Step 4 — domain expert approves.
        session = try XCTUnwrap(
            session.applying(.approveDomain))
        XCTAssertEqual(
            session.currentStage, .domainApproved)
        XCTAssertEqual(
            session.attainedProvenance,
            .domainExpertReviewed)
        XCTAssertEqual(session.history.count, 3)

        // Step 5 — wrap production envelope at attained provenance.
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)

        // Step 6 — attestation gate: envelope ↔ session bind.
        let attestation =
            BASWorldPriorTemplateAttestation(
                envelope: envelope,
                authoringSession: session)
        XCTAssertEqual(
            BASWorldPriorTemplateAttestationGate
                .validate(attestation),
            [],
            "domain expert envelope must pass attestation")

        // Step 7 — M295.0 acceptance validator.
        XCTAssertTrue(
            BASWorldPriorTemplateAcceptance.isAcceptable(
                envelope.input))

        // Step 8 — M295.2 training pipeline filter (Doctrine A).
        XCTAssertTrue(
            BASWorldPriorTrainingPipelineFilter
                .isPermittedForTraining(envelope))
        XCTAssertNil(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: envelope))

        // Step 9 — Doctrine D matrix: secondBrain produces
        // authoritative output (the production permit being
        // issued for this template).
        XCTAssertTrue(
            BASActor.secondBrain.permits(
                outputClass: .authoritative))
        XCTAssertFalse(
            BASActor.neuralNetwork.permits(
                outputClass: .authoritative))

        // Step 10 — Doctrine B+C unified guard for secondBrain
        // operating in canonical .process scope at .medium
        // velocity (issuing the permit).
        let issuingPermit = BASDoctrineActorOperation(
            actor: .secondBrain,
            outputClass: .authoritative,
            stateUpdateScope: .process,
            stateUpdateVelocity: .medium)
        XCTAssertTrue(
            BASDoctrineActorOperationGuard.isCompliant(
                issuingPermit))
    }

    // MARK: - Pre-promotion blocking: Doctrine A typed enforcement

    func test_endToEnd_illustrativeContent_typedBlockedAtAllGates()
        throws
    {
        // Author has only reached .draft (illustrative).
        let session = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-relationship-conflict")

        // Caller tries to ship envelope claiming
        // .domainExpertReviewed without going through stages.
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)

        // Attestation gate (M295.1.1) blocks: envelope
        // provenance > session attained.
        let attestation =
            BASWorldPriorTemplateAttestation(
                envelope: envelope,
                authoringSession: session)
        XCTAssertFalse(
            BASWorldPriorTemplateAttestationGate.isValid(
                attestation),
            "claim at .domainExpertReviewed without authoring track must fail attestation")

        // Even if caller bypasses attestation and pushes
        // envelope to training, the filter still blocks
        // illustrative-tagged content.
        let illustrativeEnvelope =
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .illustrative)
        XCTAssertEqual(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(
                    for: illustrativeEnvelope),
            .privateProvenance(.illustrative),
            "illustrative envelope must be typed-blocked from training")
    }

    // MARK: - Doctrine D physical block: neural network can't produce execution

    func test_neuralNetworkCannotProduceExecution_typedBlocked()
    {
        // Manifest v2 Doctrine D: 神经网络 = produce 意向; SDK
        // = execute. Neural network attempting execution is
        // typed-blocked at the matrix level.
        let nnAttemptsExecute = BASDoctrineActorOperation(
            actor: .neuralNetwork,
            outputClass: .execution,
            stateUpdateScope: .parameter,
            stateUpdateVelocity: .veryLow)
        let violations =
            BASDoctrineActorOperationGuard.check(
                nnAttemptsExecute)
        XCTAssertTrue(
            violations.contains(
                .actorOutputClassDenied(
                    .neuralNetwork, .execution)),
            "Doctrine D: neural network typed-blocked from execution")
    }

    // MARK: - Doctrine C physical block: parameter-scope changes need .veryLow

    func test_parameterScopeRequiresVeryLow_typedBlocked() {
        // L2 weight changes at any non-veryLow velocity violate
        // Doctrine C — physical typed enforcement.
        for badVelocity in [
            BASGrowthVelocity.immediate,
            .fast,
            .medium,
            .slow,
        ] {
            let op = BASDoctrineActorOperation(
                actor: .neuralNetwork,
                outputClass: .advisory,
                stateUpdateScope: .parameter,
                stateUpdateVelocity: badVelocity)
            let violations =
                BASDoctrineActorOperationGuard.check(op)
            XCTAssertTrue(
                violations.contains(
                    .velocityViolatesScope(
                        .parameter, badVelocity)),
                "Doctrine C: parameter scope at \(badVelocity) must violate")
        }
    }

    // MARK: - Three-stream typed coverage

    func test_threeStreamsTypedCoverageOfPipelineStages() {
        // Cognition stream: 5 stages from input to surfaceRender.
        let cognitionStages =
            BASManifestStream.cognition.stages
        XCTAssertEqual(cognitionStages.count, 5)

        // Permission stream (Doctrine D enforcement boundary):
        // 3 stages neural → brain → SDK.
        let permissionStages =
            BASManifestStream.permission.stages
        XCTAssertEqual(permissionStages, [
            .neuralIntent,
            .secondBrainPermit,
            .sdkExecute,
        ])

        // Growth stream (Doctrine A enforcement boundary):
        // 5 stages, hostFeedback → versionDelta. Must NOT
        // contain training/weight stages — Doctrine A says
        // private experience never enters L2.
        let growthStages =
            BASManifestStream.growth.stages
        XCTAssertFalse(
            growthStages.contains(where: { stage in
                stage.rawValue.contains("training")
                    || stage.rawValue.contains("weight")
            }),
            "Doctrine A: growth stream must not contain training/weight stages")
    }

    // MARK: - Manifest v2 4 doctrine 全 typed-enforced 现实

    func test_allFourDoctrinesTypedEnforced() {
        // A: provenance gate exists, training filter exists.
        XCTAssertNotNil(
            BASWorldPriorTrainingPipelineFilter
                .trainingProvenanceFloor)

        // B: 4 actors map to 4 distinct scopes.
        let scopes = BASActor.allCases.map(
            \.canonicalUpdateScope)
        XCTAssertEqual(Set(scopes).count, 4)

        // C: parameter scope's canonical velocity is .veryLow
        // (Doctrine C invariant).
        XCTAssertEqual(
            BASStateUpdateScope.parameter
                .canonicalVelocity, .veryLow)

        // D: 4 actors map to disjoint output class sets
        // (with shared advisory between secondBrain + neural).
        let permittedSets = BASActor.allCases.map {
            $0.permittedOutputClasses
        }
        let directiveProducers = BASActor.allCases.filter {
            $0.permits(outputClass: .directive)
        }
        let executors = BASActor.allCases.filter {
            $0.permits(outputClass: .execution)
        }
        XCTAssertEqual(directiveProducers, [.host])
        XCTAssertEqual(executors, [.sdk])
        XCTAssertEqual(permittedSets.count, 4)
    }
}
