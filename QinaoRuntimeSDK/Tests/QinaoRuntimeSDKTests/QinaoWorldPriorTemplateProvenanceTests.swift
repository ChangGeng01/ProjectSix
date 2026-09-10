import XCTest
@testable import QinaoWorldPrior

/// M295.1 — provenance + envelope + gate contract tests.
///
/// Doctrine pinned:
/// - 4 provenance levels Comparable by rank
/// - Codable round-trip
/// - Gate requires both M295.0 acceptance AND minimum provenance
/// - Filter helper batches the predicate
/// - Starter envelopes default to `.illustrative`
final class QinaoWorldPriorTemplateProvenanceTests: XCTestCase {

    private func goodInput()
        -> BASWorldPriorTemplateAcceptance.Input
    {
        .exampleBodyHydration
    }

    private func badInput()
        -> BASWorldPriorTemplateAcceptance.Input
    {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: "no-prefix",
            perturbKindsCovered: [],
            branchEvidenceRungs: [],
            description: "")
    }

    // MARK: - Provenance ordering

    func test_provenanceComparable() {
        XCTAssertLessThan(
            BASWorldPriorTemplateProvenance.illustrative,
            BASWorldPriorTemplateProvenance.hostReviewed)
        XCTAssertLessThan(
            BASWorldPriorTemplateProvenance.hostReviewed,
            BASWorldPriorTemplateProvenance
                .domainExpertReviewed)
        XCTAssertLessThan(
            BASWorldPriorTemplateProvenance
                .domainExpertReviewed,
            BASWorldPriorTemplateProvenance.axiomatic)
    }

    func test_provenanceRanksPinned() {
        XCTAssertEqual(
            BASWorldPriorTemplateProvenance.illustrative
                .rank, 0)
        XCTAssertEqual(
            BASWorldPriorTemplateProvenance.hostReviewed
                .rank, 1)
        XCTAssertEqual(
            BASWorldPriorTemplateProvenance
                .domainExpertReviewed.rank, 2)
        XCTAssertEqual(
            BASWorldPriorTemplateProvenance.axiomatic
                .rank, 3)
    }

    func test_provenanceFourCases() {
        XCTAssertEqual(
            BASWorldPriorTemplateProvenance.allCases.count, 4)
    }

    func test_provenanceCodableRoundTrip() throws {
        for p in BASWorldPriorTemplateProvenance.allCases {
            let data = try JSONEncoder().encode(p)
            let decoded = try JSONDecoder().decode(
                BASWorldPriorTemplateProvenance.self,
                from: data)
            XCTAssertEqual(decoded, p)
        }
    }

    // MARK: - Envelope round-trip

    func test_envelopeCodableRoundTrip() throws {
        let original = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorTemplateEnvelope.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Gate semantics

    func test_gate_passesWhenBothChecksHold() {
        let env = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        XCTAssertTrue(
            BASWorldPriorTemplateProvenanceGate.acceptable(
                env, requiring: .hostReviewed))
    }

    func test_gate_failsWhenProvenanceBelowMinimum() {
        let env = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .illustrative)
        XCTAssertFalse(
            BASWorldPriorTemplateProvenanceGate.acceptable(
                env, requiring: .hostReviewed))
    }

    func test_gate_failsWhenInputUnacceptable() {
        let env = BASWorldPriorTemplateEnvelope(
            input: badInput(),
            provenance: .axiomatic)
        XCTAssertFalse(
            BASWorldPriorTemplateProvenanceGate.acceptable(
                env, requiring: .hostReviewed))
    }

    func test_gate_passesAtBoundary() {
        let env = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .hostReviewed)
        XCTAssertTrue(
            BASWorldPriorTemplateProvenanceGate.acceptable(
                env, requiring: .hostReviewed))
    }

    // MARK: - Filter helper

    func test_filterReturnsOnlyAcceptableAtMinimum() {
        let envs = [
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .illustrative),
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .hostReviewed),
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .axiomatic),
            BASWorldPriorTemplateEnvelope(
                input: badInput(),
                provenance: .axiomatic),
        ]
        let kept = BASWorldPriorTemplateProvenanceGate.filter(
            envs, requiring: .hostReviewed)
        XCTAssertEqual(kept.count, 2)
        // Both kept envelopes have provenance ≥ hostReviewed
        // AND acceptable input.
        for env in kept {
            XCTAssertGreaterThanOrEqual(
                env.provenance, .hostReviewed)
            XCTAssertTrue(
                BASWorldPriorTemplateAcceptance.isAcceptable(
                    env.input))
        }
    }

    // MARK: - Starter envelopes default to illustrative

    func test_allIllustrativeStartersAreIllustrative() {
        let envs = BASWorldPriorTemplateEnvelope
            .allIllustrativeStarters
        XCTAssertEqual(envs.count, 5)
        for env in envs {
            XCTAssertEqual(env.provenance, .illustrative)
        }
    }

    func test_illustrativeStartersFailHostReviewedGate() {
        let envs = BASWorldPriorTemplateEnvelope
            .allIllustrativeStarters
        let kept = BASWorldPriorTemplateProvenanceGate.filter(
            envs, requiring: .hostReviewed)
        // illustrative < hostReviewed, all filtered out.
        XCTAssertEqual(kept, [])
    }

    func test_illustrativeStartersPassIllustrativeGate() {
        let envs = BASWorldPriorTemplateEnvelope
            .allIllustrativeStarters
        let kept = BASWorldPriorTemplateProvenanceGate.filter(
            envs, requiring: .illustrative)
        XCTAssertEqual(kept.count, 5)
    }
}
