import XCTest
@testable import QinaoWorldPrior

/// 五十三 — authoring progress report tests.
///
/// Doctrine pinned:
/// - Report derives correctly from session state
/// - isProductionReady ↔ attainedProvenance ≥ .domainExpertReviewed
/// - isTerminal ↔ currentStage.isTerminal
/// - stagesVisited preserves causal order, dedup
/// - Batch report aggregates correctly
/// - Codable round-trip
final class QinaoWorldPriorAuthoringProgressReportTests:
    XCTestCase
{

    private func session(
        templateID: String = "tmpl-x-y",
        atStage stage:
            BASWorldPriorTemplateAuthoringStage
    ) throws -> BASWorldPriorTemplateAuthoringSession {
        // Build a session that has actually walked stages, so
        // history is realistic.
        var s = BASWorldPriorTemplateAuthoringSession(
            templateID: templateID)
        switch stage {
        case .draft:
            return s
        case .hostReviewed:
            s = try XCTUnwrap(s.applying(.hostAccept))
            return s
        case .peerReview:
            s = try XCTUnwrap(s.applying(.hostAccept))
            s = try XCTUnwrap(
                s.applying(.submitForPeerReview))
            return s
        case .domainApproved:
            s = try XCTUnwrap(s.applying(.hostAccept))
            s = try XCTUnwrap(
                s.applying(.submitForPeerReview))
            s = try XCTUnwrap(s.applying(.approveDomain))
            return s
        case .axiomatized:
            s = try XCTUnwrap(s.applying(.hostAccept))
            s = try XCTUnwrap(
                s.applying(.submitForPeerReview))
            s = try XCTUnwrap(s.applying(.approveDomain))
            s = try XCTUnwrap(s.applying(.axiomatize))
            return s
        case .rejected:
            s = try XCTUnwrap(s.applying(.hostAccept))
            s = try XCTUnwrap(s.applying(.reject))
            return s
        case .withdrawn:
            s = try XCTUnwrap(s.applying(.withdraw))
            return s
        }
    }

    // MARK: - Per-session report

    func test_reportFromDraft() throws {
        let s = try session(atStage: .draft)
        let report =
            BASWorldPriorAuthoringProgressReport(from: s)
        XCTAssertEqual(report.templateID, "tmpl-x-y")
        XCTAssertEqual(report.currentStage, .draft)
        XCTAssertEqual(
            report.attainedProvenance, .illustrative)
        XCTAssertFalse(report.isProductionReady)
        XCTAssertFalse(report.isTerminal)
        XCTAssertEqual(report.transitionCount, 0)
        XCTAssertEqual(report.stagesVisited, [.draft])
        XCTAssertEqual(report.actionsApplied, [])
    }

    func test_reportFromHostReviewed() throws {
        let s = try session(atStage: .hostReviewed)
        let r =
            BASWorldPriorAuthoringProgressReport(from: s)
        XCTAssertEqual(r.attainedProvenance, .hostReviewed)
        XCTAssertFalse(r.isProductionReady)
        XCTAssertEqual(r.transitionCount, 1)
        XCTAssertEqual(
            r.stagesVisited, [.draft, .hostReviewed])
        XCTAssertEqual(r.actionsApplied, [.hostAccept])
    }

    func test_reportFromDomainApproved_productionReady()
        throws
    {
        let s = try session(atStage: .domainApproved)
        let r =
            BASWorldPriorAuthoringProgressReport(from: s)
        XCTAssertEqual(
            r.attainedProvenance, .domainExpertReviewed)
        XCTAssertTrue(r.isProductionReady)
        XCTAssertFalse(r.isTerminal)
        XCTAssertEqual(r.transitionCount, 3)
        XCTAssertEqual(
            r.stagesVisited,
            [
                .draft,
                .hostReviewed,
                .peerReview,
                .domainApproved,
            ])
    }

    func test_reportFromAxiomatized_terminalAndReady()
        throws
    {
        let s = try session(atStage: .axiomatized)
        let r =
            BASWorldPriorAuthoringProgressReport(from: s)
        XCTAssertEqual(
            r.attainedProvenance, .axiomatic)
        XCTAssertTrue(r.isProductionReady)
        XCTAssertTrue(r.isTerminal)
        XCTAssertEqual(r.transitionCount, 4)
    }

    func test_reportFromRejected_terminalNotReady() throws {
        let s = try session(atStage: .rejected)
        let r =
            BASWorldPriorAuthoringProgressReport(from: s)
        XCTAssertEqual(
            r.attainedProvenance, .illustrative)
        XCTAssertFalse(r.isProductionReady)
        XCTAssertTrue(r.isTerminal)
    }

    func test_reportCodableRoundTrip() throws {
        let s = try session(atStage: .domainApproved)
        let original =
            BASWorldPriorAuthoringProgressReport(from: s)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorAuthoringProgressReport.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Batch report

    func test_batchEmptyReturnsZeroes() {
        let report = BASWorldPriorAuthoringBatchReport(
            from: [])
        XCTAssertEqual(report.totalSessions, 0)
        XCTAssertEqual(report.productionReadyCount, 0)
        XCTAssertEqual(report.terminalCount, 0)
        XCTAssertEqual(
            report.productionReadyFraction, 0)
        XCTAssertEqual(report.stageCounts, [:])
    }

    func test_batchAggregatesCorrectly() throws {
        let sessions = [
            try session(atStage: .draft),
            try session(atStage: .hostReviewed),
            try session(atStage: .domainApproved),
            try session(atStage: .axiomatized),
            try session(atStage: .rejected),
        ]
        let report = BASWorldPriorAuthoringBatchReport(
            from: sessions)
        XCTAssertEqual(report.totalSessions, 5)
        // domainApproved + axiomatized are production ready.
        XCTAssertEqual(report.productionReadyCount, 2)
        // axiomatized + rejected are terminal.
        XCTAssertEqual(report.terminalCount, 2)
        XCTAssertEqual(
            report.productionReadyFraction,
            0.4, accuracy: 1e-9)
        XCTAssertEqual(report.stageCounts[.draft], 1)
        XCTAssertEqual(
            report.stageCounts[.hostReviewed], 1)
        XCTAssertEqual(
            report.stageCounts[.domainApproved], 1)
        XCTAssertEqual(
            report.stageCounts[.axiomatized], 1)
        XCTAssertEqual(
            report.stageCounts[.rejected], 1)
    }

    func test_batchProductionReadyFractionAllReady()
        throws
    {
        let sessions = [
            try session(atStage: .domainApproved),
            try session(atStage: .axiomatized),
        ]
        let report = BASWorldPriorAuthoringBatchReport(
            from: sessions)
        XCTAssertEqual(
            report.productionReadyFraction, 1.0,
            accuracy: 1e-9)
    }

    func test_batchCodableRoundTrip() throws {
        let sessions = [
            try session(atStage: .draft),
            try session(atStage: .domainApproved),
        ]
        let original =
            BASWorldPriorAuthoringBatchReport(
                from: sessions)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorAuthoringBatchReport.self,
            from: data)
        XCTAssertEqual(decoded, original)
    }
}
