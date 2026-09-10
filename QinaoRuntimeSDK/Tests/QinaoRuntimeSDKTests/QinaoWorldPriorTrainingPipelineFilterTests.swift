import XCTest
@testable import QinaoWorldPrior

/// M295.2 — training-pipeline filter contract tests.
///
/// Doctrine A pinned: 宿主私有经验 NEVER 直接进 L2 权重. Filter
/// implementation:
/// - illustrative envelope → privateProvenance rejection
/// - hostReviewed envelope → privateProvenance rejection
/// - domainExpertReviewed + acceptable input → nil (pass)
/// - axiomatic + acceptable input → nil (pass)
/// - any provenance + unacceptable input → unacceptableInput
/// - rejection takes priority: provenance check first
final class QinaoWorldPriorTrainingPipelineFilterTests:
    XCTestCase
{

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

    // MARK: - Threshold doctrine

    func test_trainingProvenanceFloorIsDomainExpertReviewed() {
        XCTAssertEqual(
            BASWorldPriorTrainingPipelineFilter
                .trainingProvenanceFloor,
            .domainExpertReviewed)
    }

    // MARK: - Below-threshold rejections

    func test_illustrativeRejectedAsPrivateProvenance() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .illustrative)
        let reason = BASWorldPriorTrainingPipelineFilter
            .rejectionReason(for: envelope)
        XCTAssertEqual(
            reason, .privateProvenance(.illustrative))
    }

    func test_hostReviewedRejectedAsPrivateProvenance() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .hostReviewed)
        let reason = BASWorldPriorTrainingPipelineFilter
            .rejectionReason(for: envelope)
        XCTAssertEqual(
            reason, .privateProvenance(.hostReviewed))
    }

    // MARK: - At-or-above threshold passes (with acceptable input)

    func test_domainExpertReviewedWithAcceptableInputPasses() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .domainExpertReviewed)
        XCTAssertNil(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: envelope))
        XCTAssertTrue(
            BASWorldPriorTrainingPipelineFilter
                .isPermittedForTraining(envelope))
    }

    func test_axiomaticWithAcceptableInputPasses() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: goodInput(),
            provenance: .axiomatic)
        XCTAssertNil(
            BASWorldPriorTrainingPipelineFilter
                .rejectionReason(for: envelope))
    }

    // MARK: - Unacceptable input rejected even at threshold

    func test_domainExpertReviewedWithBadInputRejected() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: badInput(),
            provenance: .domainExpertReviewed)
        let reason = BASWorldPriorTrainingPipelineFilter
            .rejectionReason(for: envelope)
        // Reason should be unacceptableInput, not provenance.
        switch reason {
        case .unacceptableInput(let issues):
            XCTAssertFalse(issues.isEmpty)
        default:
            XCTFail(
                "expected unacceptableInput rejection, got \(String(describing: reason))")
        }
    }

    func test_axiomaticWithBadInputRejected() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: badInput(),
            provenance: .axiomatic)
        let reason = BASWorldPriorTrainingPipelineFilter
            .rejectionReason(for: envelope)
        switch reason {
        case .unacceptableInput:
            break // OK
        default:
            XCTFail(
                "expected unacceptableInput rejection, got \(String(describing: reason))")
        }
    }

    // MARK: - Provenance check takes priority

    func test_lowProvenanceLowQualityCheckedAsProvenanceFirst() {
        let envelope = BASWorldPriorTemplateEnvelope(
            input: badInput(),
            provenance: .illustrative)
        let reason = BASWorldPriorTrainingPipelineFilter
            .rejectionReason(for: envelope)
        // Doctrine: provenance is checked first; bad-input
        // signal is suppressed by the provenance failure.
        XCTAssertEqual(
            reason, .privateProvenance(.illustrative))
    }

    // MARK: - Batch filter

    func test_acceptedForTraining_filtersBatch() {
        let envs = [
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .illustrative),
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .hostReviewed),
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .domainExpertReviewed),
            BASWorldPriorTemplateEnvelope(
                input: goodInput(),
                provenance: .axiomatic),
            BASWorldPriorTemplateEnvelope(
                input: badInput(),
                provenance: .axiomatic),
        ]
        let kept = BASWorldPriorTrainingPipelineFilter
            .acceptedForTraining(envs)
        // 2 pass: domainExpertReviewed + axiomatic (with good
        // input). illustrative / hostReviewed rejected on
        // provenance; axiomatic + bad input rejected on input.
        XCTAssertEqual(kept.count, 2)
    }

    // MARK: - All starter examples blocked from training

    func test_allIllustrativeStartersBlockedFromTraining() {
        let envs = BASWorldPriorTemplateEnvelope
            .allIllustrativeStarters
        let kept = BASWorldPriorTrainingPipelineFilter
            .acceptedForTraining(envs)
        // Doctrine A: illustrative starters are typed-shape
        // demos, MUST NOT enter L2 training.
        XCTAssertEqual(kept, [])
    }

    // MARK: - Codable round-trip on Rejection

    func test_rejectionCodableRoundTrip() throws {
        let cases: [
            BASWorldPriorTrainingPipelineFilter.Rejection
        ] = [
            .privateProvenance(.illustrative),
            .privateProvenance(.hostReviewed),
            .unacceptableInput([
                .templateIDMissingPrefix,
                .descriptionEmpty,
            ]),
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(
                BASWorldPriorTrainingPipelineFilter
                    .Rejection.self,
                from: data)
            XCTAssertEqual(decoded, original)
        }
    }
}
