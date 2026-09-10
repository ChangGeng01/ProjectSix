import XCTest
@testable import QinaoWorldPrior

/// 五十一 — attestation gate contract tests.
///
/// Doctrine pinned:
/// - envelope.provenance == session.attained → valid
/// - envelope.provenance < session.attained → valid (deliberate
///   downgrade allowed)
/// - envelope.provenance > session.attained → typed issue
/// - templateID mismatch → typed issue
/// - Multiple issues accumulate
final class QinaoWorldPriorTemplateAttestationTests:
    XCTestCase
{

    private func goodInput(
        templateID: String = "tmpl-x-y"
    ) -> BASWorldPriorTemplateAcceptance.Input {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: templateID,
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description: "Drinking water hydrates body.")
    }

    private func session(
        templateID: String = "tmpl-x-y",
        atStage stage:
            BASWorldPriorTemplateAuthoringStage = .draft
    ) -> BASWorldPriorTemplateAuthoringSession {
        BASWorldPriorTemplateAuthoringSession(
            templateID: templateID,
            currentStage: stage,
            history: [])
    }

    // MARK: - Provenance binding (invariant 1)

    func test_provenanceMatchesAttainment_valid() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        let attestation = BASWorldPriorTemplateAttestation(
            envelope: envelope,
            authoringSession: session(
                atStage: .domainApproved))
        XCTAssertEqual(
            BASWorldPriorTemplateAttestationGate.validate(
                attestation), [])
        XCTAssertTrue(
            BASWorldPriorTemplateAttestationGate.isValid(
                attestation))
    }

    func test_provenanceBelowAttainment_validDeliberateDowngrade()
    {
        // Session is axiomatized but envelope tagged
        // illustrative — caller deliberately downgrades.
        // Doctrine: downgrade allowed.
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .illustrative)
        let attestation = BASWorldPriorTemplateAttestation(
            envelope: envelope,
            authoringSession: session(
                atStage: .axiomatized))
        XCTAssertTrue(
            BASWorldPriorTemplateAttestationGate.isValid(
                attestation))
    }

    func test_provenanceAboveAttainment_typedIssue() {
        // Attack: caller claims envelope is .axiomatic but
        // session never advanced past .draft. Typed-blocked.
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .axiomatic)
        let attestation = BASWorldPriorTemplateAttestation(
            envelope: envelope,
            authoringSession: session(atStage: .draft))
        let issues =
            BASWorldPriorTemplateAttestationGate.validate(
                attestation)
        XCTAssertTrue(
            issues.contains(
                .envelopeProvenanceExceedsSession(
                    claimed: .axiomatic,
                    attained: .illustrative)))
    }

    func test_envelopeDomainExpertButSessionInPeerReview_typedIssue()
    {
        // peerReview attains .hostReviewed; envelope claiming
        // .domainExpertReviewed exceeds.
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        let attestation = BASWorldPriorTemplateAttestation(
            envelope: envelope,
            authoringSession: session(
                atStage: .peerReview))
        let issues =
            BASWorldPriorTemplateAttestationGate.validate(
                attestation)
        XCTAssertTrue(
            issues.contains(
                .envelopeProvenanceExceedsSession(
                    claimed: .domainExpertReviewed,
                    attained: .hostReviewed)))
    }

    // MARK: - Template ID binding (invariant 2)

    func test_templateIDMismatch_typedIssue() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "tmpl-x-y"),
            provenance: .hostReviewed)
        let attestation = BASWorldPriorTemplateAttestation(
            envelope: envelope,
            authoringSession: session(
                templateID: "tmpl-other-z",
                atStage: .hostReviewed))
        let issues =
            BASWorldPriorTemplateAttestationGate.validate(
                attestation)
        XCTAssertTrue(
            issues.contains(
                .templateIDMismatch(
                    envelopeID: "tmpl-x-y",
                    sessionID: "tmpl-other-z")))
    }

    // MARK: - Multiple issues accumulate

    func test_bothIssuesAccumulate() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: "envelope-id"),
            provenance: .axiomatic)
        let attestation = BASWorldPriorTemplateAttestation(
            envelope: envelope,
            authoringSession: session(
                templateID: "session-id",
                atStage: .draft))
        let issues =
            BASWorldPriorTemplateAttestationGate.validate(
                attestation)
        XCTAssertEqual(issues.count, 2)
    }

    // MARK: - Full authoring lifecycle integration

    func test_authoringLifecycleEndToEnd_validAttestation()
        throws
    {
        // Domain expert lifecycle: draft → hostAccept →
        // submitForPeerReview → approveDomain → axiomatize.
        // At each stage, envelope tagged at the matching
        // provenance must validate.
        var s = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-x-y")
        s = try XCTUnwrap(s.applying(.hostAccept))
        // Now session is .hostReviewed. Envelope tagged
        // .hostReviewed must validate.
        let env1 = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .hostReviewed)
        XCTAssertTrue(
            BASWorldPriorTemplateAttestationGate.isValid(
                BASWorldPriorTemplateAttestation(
                    envelope: env1, authoringSession: s)))

        s = try XCTUnwrap(s.applying(.submitForPeerReview))
        s = try XCTUnwrap(s.applying(.approveDomain))
        // Now session is .domainApproved. Envelope tagged
        // .domainExpertReviewed must validate.
        let env2 = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        XCTAssertTrue(
            BASWorldPriorTemplateAttestationGate.isValid(
                BASWorldPriorTemplateAttestation(
                    envelope: env2, authoringSession: s)))

        s = try XCTUnwrap(s.applying(.axiomatize))
        // Now session is .axiomatized.
        let env3 = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .axiomatic)
        XCTAssertTrue(
            BASWorldPriorTemplateAttestationGate.isValid(
                BASWorldPriorTemplateAttestation(
                    envelope: env3, authoringSession: s)))
    }

    // MARK: - Codable round-trip

    func test_attestationCodableRoundTrip() throws {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .hostReviewed)
        let original = BASWorldPriorTemplateAttestation(
            envelope: envelope,
            authoringSession: session(
                atStage: .hostReviewed))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorTemplateAttestation.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_issueCodableRoundTrip() throws {
        let cases: [
            BASWorldPriorTemplateAttestationIssue
        ] = [
            .envelopeProvenanceExceedsSession(
                claimed: .axiomatic,
                attained: .illustrative),
            .templateIDMismatch(
                envelopeID: "a",
                sessionID: "b"),
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(
                BASWorldPriorTemplateAttestationIssue.self,
                from: data)
            XCTAssertEqual(decoded, original)
        }
    }
}
