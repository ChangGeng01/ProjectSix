import XCTest
@testable import QinaoWorldPrior

/// 五十八.3 — production curriculum scaffold tests.
///
/// Doctrine pinned:
/// - `.empty` is the default (no production content yet)
/// - Registering an entry requires production-grade
///   (provenance ≥ `.domainExpertReviewed` + valid attestation)
/// - Sub-grade entries return nil from `registering(_:)`
/// - Walkthrough produces session at `.domainApproved` with
///   correct lineage
/// - Production envelopes pass training filter (Doctrine A
///   inverse: post-expert-review CAN flow into training)
final class QinaoWorldPriorProductionCurriculumTests:
    XCTestCase
{

    private func goodInput(
        templateID: String = "tmpl-test-prod"
    ) -> BASWorldPriorTemplateAcceptance.Input {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: templateID,
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Production candidate with adequate description.")
    }

    /// All templateIDs in this suite must follow
    /// `tmpl-<domain>-<name>` (M295.0 validator pattern).

    // MARK: - Empty default

    func test_emptyByDefault() {
        let curriculum =
            BASWorldPriorProductionCurriculum.empty
        XCTAssertEqual(curriculum.entries.count, 0)
        XCTAssertEqual(
            curriculum.productionEnvelopes.count, 0)
        XCTAssertEqual(curriculum.provenanceCounts, [:])
    }

    // MARK: - Walkthrough

    func test_walkToDomainApprovedYieldsCorrectStage()
        throws
    {
        let session = try XCTUnwrap(
            BASWorldPriorProductionCurriculumWalkthrough
                .walkToDomainApproved(
                    templateID: "tmpl-walk-domain"))
        XCTAssertEqual(
            session.currentStage, .domainApproved)
        XCTAssertEqual(
            session.attainedProvenance,
            .domainExpertReviewed)
        XCTAssertEqual(session.history.count, 3)
        XCTAssertEqual(
            session.history.map(\.action), [
                .hostAccept,
                .submitForPeerReview,
                .approveDomain,
            ])
        XCTAssertEqual(
            session.templateID, "tmpl-walk-domain")
    }

    // MARK: - Registering production-grade entry

    func test_registerProductionGradeEntry() throws {
        let session = try XCTUnwrap(
            BASWorldPriorProductionCurriculumWalkthrough
                .walkToDomainApproved(
                    templateID: "tmpl-test-prod"))
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        let entry =
            BASWorldPriorProductionCurriculumEntry(
                envelope: envelope,
                authoringSession: session)
        XCTAssertTrue(entry.isProductionGrade)

        let curriculum =
            BASWorldPriorProductionCurriculum.empty
        let updated = try XCTUnwrap(
            curriculum.registering(entry))
        XCTAssertEqual(updated.entries.count, 1)
        XCTAssertNotNil(
            updated.entry(for: "tmpl-test-prod"))
    }

    // MARK: - Sub-grade entries rejected

    func test_illustrativeEntryRefusedAtRegister() throws {
        let session =
            BASWorldPriorTemplateAuthoringSession(
                templateID: "tmpl-illu-refused-x")
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(
                templateID: "tmpl-illu-refused-x"),
            provenance: .illustrative)
        let entry =
            BASWorldPriorProductionCurriculumEntry(
                envelope: envelope,
                authoringSession: session)
        XCTAssertFalse(entry.isProductionGrade)

        let curriculum =
            BASWorldPriorProductionCurriculum.empty
        XCTAssertNil(curriculum.registering(entry))
    }

    func test_envelopeProvenanceExceedsSessionRefused()
        throws
    {
        // Envelope claims .axiomatic but session is only at
        // .draft. Attestation gate rejects → registering nil.
        let session =
            BASWorldPriorTemplateAuthoringSession(
                templateID: "tmpl-bad-attest")
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(
                templateID: "tmpl-bad-attest"),
            provenance: .axiomatic)
        let entry =
            BASWorldPriorProductionCurriculumEntry(
                envelope: envelope,
                authoringSession: session)
        XCTAssertFalse(entry.isProductionGrade)
        let curriculum =
            BASWorldPriorProductionCurriculum.empty
        XCTAssertNil(curriculum.registering(entry))
    }

    // MARK: - Production envelopes flow into training

    func test_productionEnvelopesPassTrainingFilter()
        throws
    {
        let session = try XCTUnwrap(
            BASWorldPriorProductionCurriculumWalkthrough
                .walkToDomainApproved(
                    templateID: "tmpl-train-base"))
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "tmpl-train-base"),
            provenance: .domainExpertReviewed)
        let entry =
            BASWorldPriorProductionCurriculumEntry(
                envelope: envelope,
                authoringSession: session)
        let curriculum = try XCTUnwrap(
            BASWorldPriorProductionCurriculum.empty
                .registering(entry))

        // Production envelopes pass the training filter —
        // that's the **whole point** of upgrading them.
        let exported =
            BASWorldPriorTrainingPipelineFilter
                .acceptedForTraining(
                    curriculum.productionEnvelopes)
        XCTAssertEqual(exported.count, 1)
    }

    // MARK: - Provenance counts

    func test_provenanceCountsGroupedCorrectly() throws {
        let session = try XCTUnwrap(
            BASWorldPriorProductionCurriculumWalkthrough
                .walkToDomainApproved(
                    templateID: "tmpl-count-test"))
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "tmpl-count-test"),
            provenance: .domainExpertReviewed)
        let entry =
            BASWorldPriorProductionCurriculumEntry(
                envelope: envelope,
                authoringSession: session)
        let curriculum = try XCTUnwrap(
            BASWorldPriorProductionCurriculum.empty
                .registering(entry))
        XCTAssertEqual(
            curriculum.provenanceCounts[
                .domainExpertReviewed], 1)
    }

    // MARK: - Codable round-trip

    func test_curriculumCodableRoundTrip() throws {
        let session = try XCTUnwrap(
            BASWorldPriorProductionCurriculumWalkthrough
                .walkToDomainApproved(
                    templateID: "tmpl-codable-roundtrip"))
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "tmpl-codable-roundtrip"),
            provenance: .domainExpertReviewed)
        let entry =
            BASWorldPriorProductionCurriculumEntry(
                envelope: envelope,
                authoringSession: session)
        let curriculum = try XCTUnwrap(
            BASWorldPriorProductionCurriculum.empty
                .registering(entry))

        let data = try JSONEncoder().encode(curriculum)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorProductionCurriculum.self,
            from: data)
        XCTAssertEqual(decoded, curriculum)
    }
}
