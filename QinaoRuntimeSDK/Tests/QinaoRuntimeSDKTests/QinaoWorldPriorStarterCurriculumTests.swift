import XCTest
@testable import QinaoWorldPrior

/// 五十四 — Path A starter curriculum contract tests.
///
/// Doctrine pinned:
/// - All 50 templates pass M295.0 acceptance (typed shape valid)
/// - All 50 template IDs distinct
/// - Each domain (5) has 10 templates
/// - Domain prefix matches template ID convention
/// - All 50 illustrative envelopes typed-blocked from training
///   pipeline (Doctrine A enforcement)
/// - All 50 draft sessions start at .draft / .illustrative
/// - Every template's perturbKindsCovered ⊆ valid PerturbKind
///   raw values
/// - Every template's branchEvidenceRungs ⊆ 0...4
final class QinaoWorldPriorStarterCurriculumTests:
    XCTestCase
{

    // MARK: - Cardinality

    func test_fiftyTotalTemplates() {
        XCTAssertEqual(
            BASWorldPriorStarterCurriculum.allTemplates
                .count,
            50)
    }

    func test_fiftyIllustrativeEnvelopes() {
        XCTAssertEqual(
            BASWorldPriorStarterCurriculum
                .allIllustrativeEnvelopes.count,
            50)
    }

    func test_fiftyDraftSessions() {
        XCTAssertEqual(
            BASWorldPriorStarterCurriculum
                .allDraftSessions.count,
            50)
    }

    // MARK: - All pass M295.0 acceptance validator

    func test_allTemplatesPassAcceptance() {
        for template in BASWorldPriorStarterCurriculum
            .allTemplates
        {
            let issues = BASWorldPriorTemplateAcceptance
                .validate(template)
            XCTAssertEqual(
                issues, [],
                "template \(template.templateID) has issues: \(issues)")
        }
    }

    func test_batchAcceptanceAllAcceptable() {
        let report = BASWorldPriorTemplateAcceptance
            .batchValidate(
                BASWorldPriorStarterCurriculum
                    .allTemplates)
        XCTAssertEqual(report.totalCount, 50)
        XCTAssertEqual(report.acceptableCount, 50)
        XCTAssertEqual(
            report.acceptableFraction, 1.0,
            accuracy: 1e-9)
        XCTAssertNil(report.mostCommonIssue)
    }

    // MARK: - Distinct template IDs

    func test_allTemplateIDsDistinct() {
        let ids = BASWorldPriorStarterCurriculum
            .allTemplates.map(\.templateID)
        XCTAssertEqual(
            Set(ids).count, ids.count,
            "duplicate template IDs found")
    }

    // MARK: - 5 domains × 10 templates each

    func test_relationshipDomainHasTenTemplates() {
        let count = BASWorldPriorStarterCurriculum
            .allTemplates.filter {
                $0.templateID.hasPrefix(
                    "tmpl-relationship-")
            }.count
        XCTAssertEqual(count, 10)
    }

    func test_decisionDomainHasTenTemplates() {
        let count = BASWorldPriorStarterCurriculum
            .allTemplates.filter {
                $0.templateID.hasPrefix("tmpl-decision-")
            }.count
        XCTAssertEqual(count, 10)
    }

    func test_timeDomainHasTenTemplates() {
        let count = BASWorldPriorStarterCurriculum
            .allTemplates.filter {
                $0.templateID.hasPrefix("tmpl-time-")
            }.count
        XCTAssertEqual(count, 10)
    }

    func test_boundaryDomainHasTenTemplates() {
        let count = BASWorldPriorStarterCurriculum
            .allTemplates.filter {
                $0.templateID.hasPrefix("tmpl-boundary-")
            }.count
        XCTAssertEqual(count, 10)
    }

    func test_analogyDomainHasTenTemplates() {
        let count = BASWorldPriorStarterCurriculum
            .allTemplates.filter {
                $0.templateID.hasPrefix("tmpl-analogy-")
            }.count
        XCTAssertEqual(count, 10)
    }

    // MARK: - Perturb kind validity

    func test_allPerturbKindsAreValid() {
        let validKinds: Set<String> = Set(
            QinaoWorldPriorPerturbKind.allCases.map(
                \.rawValue))
        for template in BASWorldPriorStarterCurriculum
            .allTemplates
        {
            for kind in template.perturbKindsCovered {
                XCTAssertTrue(
                    validKinds.contains(kind),
                    "template \(template.templateID) uses invalid perturb kind: \(kind)")
            }
        }
    }

    // MARK: - Evidence rung validity

    func test_allEvidenceRungsInRange() {
        for template in BASWorldPriorStarterCurriculum
            .allTemplates
        {
            for rung in template.branchEvidenceRungs {
                XCTAssertTrue(
                    rung >= 0 && rung <= 4,
                    "template \(template.templateID) has out-of-range rung: \(rung)")
            }
        }
    }

    // MARK: - Doctrine A enforcement: all illustrative
    // envelopes blocked from training

    func test_allIllustrativeEnvelopesBlockedFromTraining() {
        for envelope in BASWorldPriorStarterCurriculum
            .allIllustrativeEnvelopes
        {
            let reason =
                BASWorldPriorTrainingPipelineFilter
                    .rejectionReason(for: envelope)
            XCTAssertEqual(
                reason,
                .privateProvenance(.illustrative),
                "Doctrine A: illustrative envelope \(envelope.input.templateID) must be typed-blocked from training")
        }
    }

    func test_batchTrainingFilterRejectsAll() {
        let envelopes = BASWorldPriorStarterCurriculum
            .allIllustrativeEnvelopes
        let accepted =
            BASWorldPriorTrainingPipelineFilter
                .acceptedForTraining(envelopes)
        XCTAssertEqual(
            accepted, [],
            "all illustrative envelopes must be filtered out")
    }

    // MARK: - All draft sessions start at .draft / illustrative

    func test_allDraftSessionsStartAtDraft() {
        for session in BASWorldPriorStarterCurriculum
            .allDraftSessions
        {
            XCTAssertEqual(
                session.currentStage, .draft)
            XCTAssertEqual(
                session.attainedProvenance,
                .illustrative)
            XCTAssertEqual(session.history.count, 0)
        }
    }

    func test_allDraftSessionTemplateIDsMatchTemplates() {
        let sessionIDs = Set(
            BASWorldPriorStarterCurriculum
                .allDraftSessions.map(\.templateID))
        let templateIDs = Set(
            BASWorldPriorStarterCurriculum.allTemplates
                .map(\.templateID))
        XCTAssertEqual(sessionIDs, templateIDs)
    }

    // MARK: - Host promotion path: drafts can advance to .hostReviewed

    func test_anyDraftCanAdvanceToHostReviewed() throws {
        // Smoke test: pick first draft, advance through
        // .applying(.hostAccept), confirm session attains
        // .hostReviewed.
        let draft = try XCTUnwrap(
            BASWorldPriorStarterCurriculum
                .allDraftSessions.first)
        let advanced = try XCTUnwrap(
            draft.applying(.hostAccept))
        XCTAssertEqual(
            advanced.currentStage, .hostReviewed)
        XCTAssertEqual(
            advanced.attainedProvenance, .hostReviewed)
    }

    // MARK: - Description quality minimum

    func test_allDescriptionsMeetMinimumLength() {
        for template in BASWorldPriorStarterCurriculum
            .allTemplates
        {
            XCTAssertGreaterThanOrEqual(
                template.description.count, 30,
                "template \(template.templateID) description too short for usefulness")
        }
    }

    // MARK: - Capstone integration: full Path A flow for one template

    func test_pathAFlowForOneTemplate_endToEnd() throws {
        // Pick first template; demonstrate Path A flow:
        // 1. Get the input
        // 2. Wrap as illustrative envelope
        // 3. Confirm typed-blocked from training
        // 4. Get a fresh draft session
        // 5. Advance through .hostAccept → .hostReviewed
        // 6. Wrap a NEW envelope at .hostReviewed
        // 7. Confirm attestation passes against the advanced session
        // 8. Confirm STILL typed-blocked from training (Doctrine A:
        //    .hostReviewed is below trainingProvenanceFloor)
        let input = BASWorldPriorStarterCurriculum
            .relationshipDirectConfrontation
        let illustrative =
            BASWorldPriorTemplateEnvelope(
                input: input,
                provenance: .illustrative)
        XCTAssertNotNil(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: illustrative))
        var session =
            BASWorldPriorTemplateAuthoringSession(
                templateID: input.templateID)
        session = try XCTUnwrap(
            session.applying(.hostAccept))
        let hostReviewed =
            BASWorldPriorTemplateEnvelope(
                input: input,
                provenance: .hostReviewed)
        let attestation =
            BASWorldPriorTemplateAttestation(
                envelope: hostReviewed,
                authoringSession: session)
        XCTAssertTrue(
            BASWorldPriorTemplateAttestationGate.isValid(
                attestation),
            "envelope at .hostReviewed must validate against hostReviewed session")
        XCTAssertNotNil(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: hostReviewed),
            "Doctrine A: .hostReviewed still blocked from training (floor is .domainExpertReviewed)")
    }
}
