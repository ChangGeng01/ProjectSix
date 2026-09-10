import XCTest
@testable import QinaoWorldPrior

/// 五十 — typed authoring governance track tests.
///
/// Doctrine pinned:
/// - 7 stages, 6 actions
/// - Stage → provenance mapping pinned
/// - Terminal states (axiomatized / rejected / withdrawn)
///   permit no further transitions
/// - Valid transitions per stage pinned
/// - Invalid transitions return nil
/// - Session apply chains stages with history
/// - Codable round-trip
final class QinaoWorldPriorTemplateAuthoringTests: XCTestCase {

    // MARK: - Cardinality

    func test_sevenStages() {
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringStage.allCases
                .count, 7)
    }

    func test_sixActions() {
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringAction.allCases
                .count, 6)
    }

    // MARK: - Stage → provenance mapping

    func test_draftMapsToIllustrative() {
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringStage.draft
                .attainedProvenance,
            .illustrative)
    }

    func test_hostReviewedMapsToHostReviewed() {
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringStage.hostReviewed
                .attainedProvenance,
            .hostReviewed)
    }

    func test_peerReviewStillHostReviewed() {
        // peerReview is "in flight" — provenance hasn't been
        // upgraded by domain expert yet, so it's still
        // hostReviewed.
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringStage.peerReview
                .attainedProvenance,
            .hostReviewed)
    }

    func test_domainApprovedMapsToDomainExpertReviewed() {
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringStage
                .domainApproved.attainedProvenance,
            .domainExpertReviewed)
    }

    func test_axiomatizedMapsToAxiomatic() {
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringStage.axiomatized
                .attainedProvenance,
            .axiomatic)
    }

    func test_rejectedAndWithdrawnMapToIllustrative() {
        // Rejected/withdrawn templates cannot claim authority.
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringStage.rejected
                .attainedProvenance,
            .illustrative)
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringStage.withdrawn
                .attainedProvenance,
            .illustrative)
    }

    // MARK: - Terminal states

    func test_axiomatizedIsTerminal() {
        XCTAssertTrue(
            BASWorldPriorTemplateAuthoringStage.axiomatized
                .isTerminal)
    }

    func test_rejectedIsTerminal() {
        XCTAssertTrue(
            BASWorldPriorTemplateAuthoringStage.rejected
                .isTerminal)
    }

    func test_withdrawnIsTerminal() {
        XCTAssertTrue(
            BASWorldPriorTemplateAuthoringStage.withdrawn
                .isTerminal)
    }

    func test_activeStagesNotTerminal() {
        XCTAssertFalse(
            BASWorldPriorTemplateAuthoringStage.draft
                .isTerminal)
        XCTAssertFalse(
            BASWorldPriorTemplateAuthoringStage.hostReviewed
                .isTerminal)
        XCTAssertFalse(
            BASWorldPriorTemplateAuthoringStage.peerReview
                .isTerminal)
        XCTAssertFalse(
            BASWorldPriorTemplateAuthoringStage
                .domainApproved.isTerminal)
    }

    // MARK: - Valid transitions per stage

    func test_draftValidTransitions() {
        let t = BASWorldPriorTemplateAuthoringPolicy
            .validTransitions(from: .draft)
        XCTAssertEqual(t[.hostAccept], .hostReviewed)
        XCTAssertEqual(t[.reject], .rejected)
        XCTAssertEqual(t[.withdraw], .withdrawn)
        XCTAssertNil(t[.submitForPeerReview])
    }

    func test_hostReviewedValidTransitions() {
        let t = BASWorldPriorTemplateAuthoringPolicy
            .validTransitions(from: .hostReviewed)
        XCTAssertEqual(
            t[.submitForPeerReview], .peerReview)
        XCTAssertEqual(t[.reject], .rejected)
        XCTAssertEqual(t[.withdraw], .withdrawn)
        XCTAssertNil(t[.hostAccept])
    }

    func test_peerReviewValidTransitions() {
        let t = BASWorldPriorTemplateAuthoringPolicy
            .validTransitions(from: .peerReview)
        XCTAssertEqual(
            t[.approveDomain], .domainApproved)
        XCTAssertEqual(t[.reject], .rejected)
        XCTAssertEqual(t[.withdraw], .withdrawn)
    }

    func test_domainApprovedValidTransitions() {
        let t = BASWorldPriorTemplateAuthoringPolicy
            .validTransitions(from: .domainApproved)
        XCTAssertEqual(t[.axiomatize], .axiomatized)
        XCTAssertEqual(t[.reject], .rejected)
        XCTAssertEqual(t[.withdraw], .withdrawn)
    }

    func test_terminalStagesHaveNoValidTransitions() {
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringPolicy
                .validTransitions(from: .axiomatized), [:])
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringPolicy
                .validTransitions(from: .rejected), [:])
        XCTAssertEqual(
            BASWorldPriorTemplateAuthoringPolicy
                .validTransitions(from: .withdrawn), [:])
    }

    // MARK: - apply(_:from:)

    func test_applyValidActionReturnsTransition() {
        let t = BASWorldPriorTemplateAuthoringPolicy
            .apply(.hostAccept, from: .draft)
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.from, .draft)
        XCTAssertEqual(t?.to, .hostReviewed)
        XCTAssertEqual(t?.action, .hostAccept)
    }

    func test_applyInvalidActionReturnsNil() {
        // submitForPeerReview is not valid from .draft.
        XCTAssertNil(
            BASWorldPriorTemplateAuthoringPolicy.apply(
                .submitForPeerReview, from: .draft))
    }

    func test_applyFromTerminalReturnsNil() {
        XCTAssertNil(
            BASWorldPriorTemplateAuthoringPolicy.apply(
                .hostAccept, from: .axiomatized))
        XCTAssertNil(
            BASWorldPriorTemplateAuthoringPolicy.apply(
                .axiomatize, from: .rejected))
    }

    // MARK: - Session lifecycle

    func test_sessionStartsAtDraft() {
        let s = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-x-y")
        XCTAssertEqual(s.currentStage, .draft)
        XCTAssertEqual(s.attainedProvenance, .illustrative)
        XCTAssertEqual(s.history, [])
    }

    func test_sessionApplyValidActionAdvances() {
        let s = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-x-y")
        let s2 = s.applying(.hostAccept)
        XCTAssertNotNil(s2)
        XCTAssertEqual(s2?.currentStage, .hostReviewed)
        XCTAssertEqual(
            s2?.attainedProvenance, .hostReviewed)
        XCTAssertEqual(s2?.history.count, 1)
        XCTAssertEqual(
            s2?.history.first?.action, .hostAccept)
    }

    func test_sessionApplyInvalidActionReturnsNil() {
        let s = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-x-y")
        XCTAssertNil(s.applying(.axiomatize))
    }

    func test_sessionFullLifecycleToAxiomatized() {
        var s = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-x-y")
        // draft → hostReviewed → peerReview → domainApproved
        // → axiomatized
        s = try! XCTUnwrap(s.applying(.hostAccept))
        s = try! XCTUnwrap(
            s.applying(.submitForPeerReview))
        s = try! XCTUnwrap(s.applying(.approveDomain))
        s = try! XCTUnwrap(s.applying(.axiomatize))
        XCTAssertEqual(s.currentStage, .axiomatized)
        XCTAssertEqual(s.attainedProvenance, .axiomatic)
        XCTAssertEqual(s.history.count, 4)
    }

    func test_sessionRejectionPathReturnsToIllustrative()
        throws
    {
        var s = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-x-y")
        s = try XCTUnwrap(s.applying(.hostAccept))
        s = try XCTUnwrap(
            s.applying(.submitForPeerReview))
        s = try XCTUnwrap(s.applying(.reject))
        XCTAssertEqual(s.currentStage, .rejected)
        XCTAssertEqual(s.attainedProvenance, .illustrative)
        // Cannot continue from rejected.
        XCTAssertNil(s.applying(.approveDomain))
    }

    // MARK: - Codable round-trip

    func test_sessionCodableRoundTrip() throws {
        var original = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-x-y")
        original = try XCTUnwrap(
            original.applying(.hostAccept))
        original = try XCTUnwrap(
            original.applying(.submitForPeerReview))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorTemplateAuthoringSession.self,
            from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.history.count, 2)
    }

    func test_stageCodableRoundTrip() throws {
        for stage in BASWorldPriorTemplateAuthoringStage
            .allCases
        {
            let data = try JSONEncoder().encode(stage)
            let decoded = try JSONDecoder().decode(
                BASWorldPriorTemplateAuthoringStage.self,
                from: data)
            XCTAssertEqual(decoded, stage)
        }
    }

    func test_actionCodableRoundTrip() throws {
        for action in BASWorldPriorTemplateAuthoringAction
            .allCases
        {
            let data = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(
                BASWorldPriorTemplateAuthoringAction.self,
                from: data)
            XCTAssertEqual(decoded, action)
        }
    }
}
