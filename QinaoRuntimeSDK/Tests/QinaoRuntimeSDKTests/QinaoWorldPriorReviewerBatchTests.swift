import XCTest
@testable import QinaoWorldPrior

/// 六十一.1 — reviewer batch contract tests.
///
/// Doctrine pinned:
/// - Only `.peerReview` sessions enter batch (others filter out)
/// - Markdown rendering deterministic + contains review checklist
/// - Decision round-trip: approve → `.domainApproved`,
///   reject → `.rejected`
/// - Unmatched decisions report typed-diagnostic
/// - Counts (approved / rejected) accurate
final class QinaoWorldPriorReviewerBatchTests:
    XCTestCase
{

    private func goodInput(
        templateID: String = "tmpl-test-x"
    ) -> BASWorldPriorTemplateAcceptance.Input {
        BASWorldPriorTemplateAcceptance.Input(
            templateID: templateID,
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1, 1],
            description:
                "Reviewer batch test description ≥ 30 chars.")
    }

    private func sessionAtPeerReview(
        templateID: String = "tmpl-test-x"
    ) throws -> BASWorldPriorTemplateAuthoringSession {
        var s = BASWorldPriorTemplateAuthoringSession(
            templateID: templateID)
        s = try XCTUnwrap(s.applying(.hostAccept))
        s = try XCTUnwrap(s.applying(.submitForPeerReview))
        return s
    }

    private func envelope(
        templateID: String = "tmpl-test-x"
    ) -> BASWorldPriorTemplateEnvelope {
        BASWorldPriorTemplateEnvelope(
            input: goodInput(templateID: templateID),
            provenance: .hostReviewed)
    }

    // MARK: - Item construction

    func test_itemFromSessionAndEnvelope() throws {
        let session = try sessionAtPeerReview()
        let item = BASWorldPriorReviewerBatchItem(
            from: session,
            envelope: envelope())
        XCTAssertEqual(item.templateID, "tmpl-test-x")
        XCTAssertTrue(
            item.description.contains("≥ 30 chars"))
        XCTAssertEqual(
            item.perturbKindsCovered,
            ["dropPrecondition"])
        XCTAssertEqual(
            item.branchEvidenceRungs, [2, 1, 1])
    }

    // MARK: - Batch filtering: only .peerReview enters

    func test_batchFiltersToPeerReviewOnly() throws {
        let draft = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-d-1")
        let peer = try sessionAtPeerReview(
            templateID: "tmpl-p-1")
        let host = try XCTUnwrap(
            draft.applying(.hostAccept))
        // host.currentStage == .hostReviewed (not peer)

        let batch = BASWorldPriorReviewerBatch.makeBatch(
            batchID: "b1",
            from: [
                (draft, envelope(templateID: "tmpl-d-1")),
                (peer, envelope(templateID: "tmpl-p-1")),
                (host, envelope(templateID: "tmpl-d-1")),
            ])
        XCTAssertEqual(batch.items.count, 1)
        XCTAssertEqual(
            batch.items.first?.templateID, "tmpl-p-1")
    }

    func test_emptyBatch() {
        let batch = BASWorldPriorReviewerBatch.makeBatch(
            batchID: "empty", from: [])
        XCTAssertEqual(batch.items.count, 0)
    }

    // MARK: - Markdown rendering

    func test_markdownContainsBatchHeader() throws {
        let session = try sessionAtPeerReview()
        let batch = BASWorldPriorReviewerBatch.makeBatch(
            batchID: "b-2026-05-01",
            from: [(session, envelope())])
        let md = BASWorldPriorReviewerBatchFormatter
            .renderMarkdown(batch)
        XCTAssertTrue(
            md.contains(
                "# Reviewer batch: b-2026-05-01"))
        XCTAssertTrue(
            md.contains("Items: **1**"))
    }

    func test_markdownContainsItemFields() throws {
        let session = try sessionAtPeerReview()
        let batch = BASWorldPriorReviewerBatch.makeBatch(
            batchID: "b1",
            from: [(session, envelope())])
        let md = BASWorldPriorReviewerBatchFormatter
            .renderMarkdown(batch)
        XCTAssertTrue(md.contains("`tmpl-test-x`"))
        XCTAssertTrue(
            md.contains("dropPrecondition"))
        XCTAssertTrue(
            md.contains("2, 1, 1"))
    }

    func test_markdownContainsChecklist() throws {
        let session = try sessionAtPeerReview()
        let batch = BASWorldPriorReviewerBatch.makeBatch(
            batchID: "b1",
            from: [(session, envelope())])
        let md = BASWorldPriorReviewerBatchFormatter
            .renderMarkdown(batch)
        XCTAssertTrue(md.contains("Review checklist"))
        XCTAssertTrue(
            md.contains("templateID follows"))
        XCTAssertTrue(
            md.contains("DECISION:"))
        XCTAssertTrue(
            md.contains("Justification"))
    }

    func test_markdownDeterministicForSameBatch() throws {
        let session = try sessionAtPeerReview()
        let batch = BASWorldPriorReviewerBatch.makeBatch(
            batchID: "b1",
            from: [(session, envelope())])
        let m1 = BASWorldPriorReviewerBatchFormatter
            .renderMarkdown(batch)
        let m2 = BASWorldPriorReviewerBatchFormatter
            .renderMarkdown(batch)
        XCTAssertEqual(m1, m2)
    }

    // MARK: - Applier: approve → .domainApproved

    func test_applyApproveAdvancesToDomainApproved()
        throws
    {
        let session = try sessionAtPeerReview(
            templateID: "tmpl-app-1")
        let decisions = [
            BASWorldPriorReviewerDecisionRecord(
                templateID: "tmpl-app-1",
                decision: .approve)
        ]
        let result =
            BASWorldPriorReviewerBatchApplier.apply(
                decisions: decisions,
                to: [session])
        XCTAssertEqual(result.updatedSessions.count, 1)
        XCTAssertEqual(
            result.updatedSessions.first?.currentStage,
            .domainApproved)
        XCTAssertEqual(result.approvedCount, 1)
        XCTAssertEqual(result.rejectedCount, 0)
        XCTAssertEqual(
            result.unmatchedTemplateIDs, [])
    }

    // MARK: - Applier: reject → .rejected

    func test_applyRejectAdvancesToRejected() throws {
        let session = try sessionAtPeerReview(
            templateID: "tmpl-rej-1")
        let decisions = [
            BASWorldPriorReviewerDecisionRecord(
                templateID: "tmpl-rej-1",
                decision: .reject(
                    reason:
                        "perturbKinds incomplete"))
        ]
        let result =
            BASWorldPriorReviewerBatchApplier.apply(
                decisions: decisions,
                to: [session])
        XCTAssertEqual(
            result.updatedSessions.first?.currentStage,
            .rejected)
        XCTAssertEqual(result.approvedCount, 0)
        XCTAssertEqual(result.rejectedCount, 1)
    }

    // MARK: - Applier: mixed batch

    func test_applyMixedDecisions() throws {
        let approveSession = try sessionAtPeerReview(
            templateID: "tmpl-mix-app")
        let rejectSession = try sessionAtPeerReview(
            templateID: "tmpl-mix-rej")
        let decisions = [
            BASWorldPriorReviewerDecisionRecord(
                templateID: "tmpl-mix-app",
                decision: .approve),
            BASWorldPriorReviewerDecisionRecord(
                templateID: "tmpl-mix-rej",
                decision: .reject(
                    reason: "wrong domain")),
        ]
        let result =
            BASWorldPriorReviewerBatchApplier.apply(
                decisions: decisions,
                to: [approveSession, rejectSession])
        XCTAssertEqual(result.approvedCount, 1)
        XCTAssertEqual(result.rejectedCount, 1)
        XCTAssertEqual(result.updatedSessions.count, 2)
        let stages = result.updatedSessions.map(
            \.currentStage)
        XCTAssertTrue(
            stages.contains(.domainApproved))
        XCTAssertTrue(stages.contains(.rejected))
    }

    // MARK: - Applier: unmatched (decision without session)

    func test_applyUnmatchedTemplateIDRecorded() {
        let decisions = [
            BASWorldPriorReviewerDecisionRecord(
                templateID: "tmpl-ghost-1",
                decision: .approve)
        ]
        let result =
            BASWorldPriorReviewerBatchApplier.apply(
                decisions: decisions, to: [])
        XCTAssertEqual(
            result.unmatchedTemplateIDs, ["tmpl-ghost-1"])
        XCTAssertEqual(result.updatedSessions.count, 0)
    }

    // MARK: - Applier: wrong stage rejected

    func test_applyWrongStageRecordedAsUnmatched() throws {
        let draft = BASWorldPriorTemplateAuthoringSession(
            templateID: "tmpl-wrongstage-1")
        let decisions = [
            BASWorldPriorReviewerDecisionRecord(
                templateID: "tmpl-wrongstage-1",
                decision: .approve)
        ]
        let result =
            BASWorldPriorReviewerBatchApplier.apply(
                decisions: decisions, to: [draft])
        XCTAssertEqual(
            result.unmatchedTemplateIDs,
            ["tmpl-wrongstage-1"])
        XCTAssertEqual(result.updatedSessions.count, 0)
    }

    // MARK: - Codable round-trip

    func test_batchCodableRoundTrip() throws {
        let item = BASWorldPriorReviewerBatchItem(
            templateID: "tmpl-cod-1",
            description:
                "Codable round-trip description body.",
            perturbKindsCovered: ["dropPrecondition"],
            branchEvidenceRungs: [2, 1])
        let batch = BASWorldPriorReviewerBatch(
            batchID: "b-codable",
            items: [item])
        let data = try JSONEncoder().encode(batch)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorReviewerBatch.self, from: data)
        XCTAssertEqual(decoded, batch)
    }

    func test_decisionCodableRoundTrip() throws {
        let cases: [BASWorldPriorReviewerDecision] = [
            .approve,
            .reject(reason: "test reason"),
        ]
        for d in cases {
            let data = try JSONEncoder().encode(d)
            let decoded = try JSONDecoder().decode(
                BASWorldPriorReviewerDecision.self,
                from: data)
            XCTAssertEqual(decoded, d)
        }
    }

    // MARK: - Full round-trip integration

    func test_fullRoundtripBatchToDecisionsToApply() throws {
        let s1 = try sessionAtPeerReview(
            templateID: "tmpl-rt-1")
        let s2 = try sessionAtPeerReview(
            templateID: "tmpl-rt-2")
        let batch = BASWorldPriorReviewerBatch.makeBatch(
            batchID: "b-rt",
            from: [
                (s1, envelope(templateID: "tmpl-rt-1")),
                (s2, envelope(templateID: "tmpl-rt-2")),
            ])
        XCTAssertEqual(batch.items.count, 2)

        // Simulate expert decisions.
        let decisions = batch.items.map {
            BASWorldPriorReviewerDecisionRecord(
                templateID: $0.templateID,
                decision: .approve)
        }

        let result =
            BASWorldPriorReviewerBatchApplier.apply(
                decisions: decisions, to: [s1, s2])
        XCTAssertEqual(result.approvedCount, 2)
        XCTAssertEqual(result.updatedSessions.count, 2)
        for session in result.updatedSessions {
            XCTAssertEqual(
                session.currentStage, .domainApproved)
        }
    }
}
