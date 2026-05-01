import XCTest
@testable import BASOrgan

/// M343 — pin the trained-weight provenance envelope + filter.
///
/// This is the **typed pin** leg of the v5 doctrine triple for
/// the `Adapter-trained L2` candidate parked in
/// `QINAO_MANIFESTO_V5_DOCTRINE` appendix.
///
/// What this file pins:
///
///   1. Tier ladder is exactly 4 cases, ordered illustrative <
///      aiAdvisory < peerReviewed < domainExpertReviewed.
///   2. Production floor is `.domainExpertReviewed` —
///      `.illustrative` / `.aiAdvisory` / `.peerReviewed` are
///      rejected by the production gate.
///   3. `.domainExpertReviewed` requires both attestation
///      signature reference AND issued-at timestamp; missing
///      either is rejected with `.missingAttestationForProductionTier`.
///   4. Non-production tier carrying an attestation reference
///      surfaces as `.nonProductionTierCarriesAttestation`
///      (forged-uplift detection).
///   5. Hash field length is exactly 64 hex chars.
///   6. `acceptedForProduction(_:)` preserves input order.
///   7. Codable round-trip stable.
final class M343OrganTrainedWeightProvenanceTests: XCTestCase {

    // MARK: - Fixture helpers

    private let validHash =
        "9e15d296c25c5b28da42eb5d5ca7d89bf768f407a49cbad21ed0b735eec114f5"

    private func envelope(
        tier: BASOrganTrainedWeightProvenance.Tier,
        attestationRef: String? = nil,
        attestationIssuedAt: Date? = nil
    ) -> BASOrganTrainedWeightProvenance {
        BASOrganTrainedWeightProvenance(
            adapterID: "adapter.test.v1",
            baseModelID: "apple.foundation-models.v1",
            tier: tier,
            trainingCurriculumRef:
                "audit.curriculum.test.v1",
            trainingCorpusHashHex: validHash,
            trainedWeightsHashHex: validHash,
            expertAttestationSignatureRef: attestationRef,
            attestationIssuedAt: attestationIssuedAt)
    }

    // MARK: - Tier ladder

    func testTierLadderHasFourCases() {
        XCTAssertEqual(
            BASOrganTrainedWeightProvenance.Tier.allCases.count, 4)
    }

    func testTierComparable() {
        let tiers = BASOrganTrainedWeightProvenance.Tier
            .allCases.sorted()
        XCTAssertEqual(
            tiers,
            [.illustrative,
             .aiAdvisory,
             .peerReviewed,
             .domainExpertReviewed])
    }

    func testProductionFloorIsDomainExpertReviewed() {
        XCTAssertEqual(
            BASOrganTrainedWeightFilter.productionTierFloor,
            .domainExpertReviewed)
    }

    // MARK: - Production gate

    func testIllustrativeTierIsRejected() {
        let env = envelope(tier: .illustrative)
        let reason = BASOrganTrainedWeightFilter
            .rejectionReason(for: env)
        XCTAssertEqual(
            reason, .belowProductionTier(.illustrative))
        XCTAssertFalse(
            BASOrganTrainedWeightFilter
                .isPermittedForProduction(env))
    }

    func testAiAdvisoryTierIsRejected() {
        let env = envelope(tier: .aiAdvisory)
        XCTAssertEqual(
            BASOrganTrainedWeightFilter
                .rejectionReason(for: env),
            .belowProductionTier(.aiAdvisory))
    }

    func testPeerReviewedTierIsRejected() {
        let env = envelope(tier: .peerReviewed)
        XCTAssertEqual(
            BASOrganTrainedWeightFilter
                .rejectionReason(for: env),
            .belowProductionTier(.peerReviewed))
    }

    func testDomainExpertReviewedWithFullAttestationPasses() {
        let env = envelope(
            tier: .domainExpertReviewed,
            attestationRef:
                "audit.attestation.therapy.expert.v1",
            attestationIssuedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        XCTAssertNil(
            BASOrganTrainedWeightFilter
                .rejectionReason(for: env))
        XCTAssertTrue(
            BASOrganTrainedWeightFilter
                .isPermittedForProduction(env))
    }

    func testDomainExpertReviewedWithoutAttestationRefIsRejected() {
        let env = envelope(
            tier: .domainExpertReviewed,
            attestationRef: nil,
            attestationIssuedAt: Date())
        XCTAssertEqual(
            BASOrganTrainedWeightFilter
                .rejectionReason(for: env),
            .missingAttestationForProductionTier)
    }

    func testDomainExpertReviewedWithoutIssuedAtIsRejected() {
        let env = envelope(
            tier: .domainExpertReviewed,
            attestationRef:
                "audit.attestation.test.v1",
            attestationIssuedAt: nil)
        XCTAssertEqual(
            BASOrganTrainedWeightFilter
                .rejectionReason(for: env),
            .missingAttestationForProductionTier)
    }

    func testNonProductionTierCarryingAttestationIsForgeryRejection() {
        let env = envelope(
            tier: .peerReviewed,
            attestationRef:
                "audit.attestation.suspicious.v1",
            attestationIssuedAt: Date())
        // Forged-uplift signal takes precedence over plain
        // tier rejection.
        XCTAssertEqual(
            BASOrganTrainedWeightFilter
                .rejectionReason(for: env),
            .nonProductionTierCarriesAttestation)
    }

    // MARK: - Hash length pin

    func testMalformedCorpusHashIsRejected() {
        let env = BASOrganTrainedWeightProvenance(
            adapterID: "adapter.test",
            baseModelID: "apple.foundation-models.v1",
            tier: .domainExpertReviewed,
            trainingCurriculumRef: "audit.curriculum.test",
            trainingCorpusHashHex: "deadbeef",  // wrong length
            trainedWeightsHashHex: validHash,
            expertAttestationSignatureRef:
                "audit.attestation.test",
            attestationIssuedAt: Date())
        XCTAssertEqual(
            BASOrganTrainedWeightFilter
                .rejectionReason(for: env),
            .malformedHash(
                field: "trainingCorpusHashHex",
                length: 8))
    }

    func testMalformedWeightsHashIsRejected() {
        let env = BASOrganTrainedWeightProvenance(
            adapterID: "adapter.test",
            baseModelID: "apple.foundation-models.v1",
            tier: .domainExpertReviewed,
            trainingCurriculumRef: "audit.curriculum.test",
            trainingCorpusHashHex: validHash,
            trainedWeightsHashHex: "abc",  // wrong length
            expertAttestationSignatureRef:
                "audit.attestation.test",
            attestationIssuedAt: Date())
        XCTAssertEqual(
            BASOrganTrainedWeightFilter
                .rejectionReason(for: env),
            .malformedHash(
                field: "trainedWeightsHashHex",
                length: 3))
    }

    // MARK: - Self-consistency

    func testStructurallyConsistentProductionTier() {
        let env = envelope(
            tier: .domainExpertReviewed,
            attestationRef: "audit.attestation.test",
            attestationIssuedAt: Date())
        XCTAssertTrue(env.isStructurallyConsistent)
    }

    func testStructurallyInconsistentNonProductionWithAttestation() {
        let env = envelope(
            tier: .illustrative,
            attestationRef: "audit.attestation.fake",
            attestationIssuedAt: Date())
        XCTAssertFalse(env.isStructurallyConsistent)
    }

    // MARK: - Batch filter

    func testAcceptedForProductionPreservesOrder() {
        let illust = envelope(tier: .illustrative)
        let peer = envelope(tier: .peerReviewed)
        let prod1 = envelope(
            tier: .domainExpertReviewed,
            attestationRef:
                "audit.attestation.prod.v1",
            attestationIssuedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let prod2 = envelope(
            tier: .domainExpertReviewed,
            attestationRef:
                "audit.attestation.prod.v2",
            attestationIssuedAt: Date(
                timeIntervalSince1970: 1_700_000_001))
        let advisory = envelope(tier: .aiAdvisory)

        let accepted = BASOrganTrainedWeightFilter
            .acceptedForProduction(
                [illust, prod1, peer, prod2, advisory])
        XCTAssertEqual(accepted, [prod1, prod2])
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original = envelope(
            tier: .domainExpertReviewed,
            attestationRef:
                "audit.attestation.therapy.expert.v1",
            attestationIssuedAt: Date(
                timeIntervalSince1970: 1_700_000_000))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASOrganTrainedWeightProvenance.self,
            from: data)
        XCTAssertEqual(original, decoded)
    }
}
