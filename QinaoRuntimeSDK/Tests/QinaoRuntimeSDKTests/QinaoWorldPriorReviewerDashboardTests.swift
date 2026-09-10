import XCTest
@testable import QinaoWorldPrior

/// 六十一.2 — reviewer dashboard contract tests.
///
/// Doctrine pinned:
/// - Empty input → empty dashboard
/// - Counts grouped correctly per stage
/// - Per-domain partition by `tmpl-<domain>-<name>`
/// - Bottleneck identification picks non-terminal stage with
///   highest count
/// - Production-ready count requires `.attainedProvenance >=
///   .domainExpertReviewed`
/// - Markdown rendering deterministic + non-empty
/// - 5 domains × 10 templates = 50 entries display test
final class QinaoWorldPriorReviewerDashboardTests:
    XCTestCase
{

    private func session(
        templateID: String,
        atStage stage:
            BASWorldPriorTemplateAuthoringStage = .draft
    ) -> BASWorldPriorTemplateAuthoringSession {
        BASWorldPriorTemplateAuthoringSession(
            templateID: templateID,
            currentStage: stage,
            history: [])
    }

    // MARK: - Empty

    func test_emptyDashboard() {
        let dashboard = BASWorldPriorReviewerDashboard(
            from: [])
        XCTAssertEqual(
            dashboard.summary.totalSessions, 0)
        XCTAssertEqual(
            dashboard.summary.productionReadyCount, 0)
        XCTAssertNil(
            dashboard.summary.bottleneckStage)
        XCTAssertEqual(
            dashboard.summary.productionReadyFraction,
            0,
            accuracy: 1e-9)
        XCTAssertEqual(dashboard.perDomain.count, 0)
    }

    // MARK: - Stage counts

    func test_stageCountsAggregatedCorrectly() {
        let sessions = [
            session(
                templateID: "tmpl-a-1",
                atStage: .draft),
            session(
                templateID: "tmpl-a-2",
                atStage: .hostReviewed),
            session(
                templateID: "tmpl-a-3",
                atStage: .peerReview),
            session(
                templateID: "tmpl-a-4",
                atStage: .peerReview),
            session(
                templateID: "tmpl-a-5",
                atStage: .domainApproved),
        ]
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        XCTAssertEqual(
            dashboard.summary.totalSessions, 5)
        XCTAssertEqual(
            dashboard.summary.stageCounts[.draft], 1)
        XCTAssertEqual(
            dashboard.summary.stageCounts[
                .hostReviewed], 1)
        XCTAssertEqual(
            dashboard.summary.stageCounts[
                .peerReview], 2)
        XCTAssertEqual(
            dashboard.summary.stageCounts[
                .domainApproved], 1)
    }

    // MARK: - Production-ready count

    func test_productionReadyCountFromDomainApproved() {
        let sessions = [
            session(
                templateID: "tmpl-a-1",
                atStage: .domainApproved),
            session(
                templateID: "tmpl-a-2",
                atStage: .domainApproved),
            session(
                templateID: "tmpl-a-3",
                atStage: .axiomatized),
            session(
                templateID: "tmpl-a-4",
                atStage: .draft),
        ]
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        XCTAssertEqual(
            dashboard.summary.productionReadyCount, 3)
        XCTAssertEqual(
            dashboard.summary.productionReadyFraction,
            0.75,
            accuracy: 1e-9)
    }

    // MARK: - Bottleneck

    func test_bottleneckIdentifiesPeerReviewWhenStuck() {
        let sessions = [
            session(
                templateID: "tmpl-a-1",
                atStage: .peerReview),
            session(
                templateID: "tmpl-a-2",
                atStage: .peerReview),
            session(
                templateID: "tmpl-a-3",
                atStage: .peerReview),
            session(
                templateID: "tmpl-a-4",
                atStage: .hostReviewed),
            session(
                templateID: "tmpl-a-5",
                atStage: .domainApproved),
        ]
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        XCTAssertEqual(
            dashboard.summary.bottleneckStage,
            .peerReview)
    }

    func test_bottleneckIsNilForAllTerminal() {
        let sessions = [
            session(
                templateID: "tmpl-a-1",
                atStage: .axiomatized),
            session(
                templateID: "tmpl-a-2",
                atStage: .rejected),
            session(
                templateID: "tmpl-a-3",
                atStage: .withdrawn),
        ]
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        XCTAssertNil(
            dashboard.summary.bottleneckStage,
            "all-terminal must report no bottleneck")
    }

    // MARK: - Per-domain partition

    func test_perDomainPartitionByTemplateIDPrefix() {
        let sessions = [
            session(templateID: "tmpl-relationship-1"),
            session(templateID: "tmpl-relationship-2"),
            session(templateID: "tmpl-decision-1"),
            session(templateID: "tmpl-time-1"),
            session(templateID: "tmpl-time-2"),
            session(templateID: "tmpl-time-3"),
        ]
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        XCTAssertEqual(dashboard.perDomain.count, 3)
        let byDomain = Dictionary(
            uniqueKeysWithValues:
                dashboard.perDomain.map {
                    ($0.domain, $0)
                })
        XCTAssertEqual(
            byDomain["relationship"]?.totalCount, 2)
        XCTAssertEqual(
            byDomain["decision"]?.totalCount, 1)
        XCTAssertEqual(
            byDomain["time"]?.totalCount, 3)
    }

    func test_domainExtractionFromTemplateID() {
        XCTAssertEqual(
            BASWorldPriorReviewerDashboard.domain(
                from: "tmpl-relationship-conflict"),
            "relationship")
        XCTAssertEqual(
            BASWorldPriorReviewerDashboard.domain(
                from: "tmpl-decision-defaults-bias"),
            "decision")
        XCTAssertEqual(
            BASWorldPriorReviewerDashboard.domain(
                from: "tmpl-x"),
            "unknown",
            "single-segment after tmpl- is malformed")
        XCTAssertEqual(
            BASWorldPriorReviewerDashboard.domain(
                from: "garbage"),
            "unknown")
    }

    // MARK: - Per-domain production-ready fraction

    func test_perDomainProductionReadyFraction() throws {
        let sessions = [
            session(
                templateID: "tmpl-a-1",
                atStage: .domainApproved),
            session(
                templateID: "tmpl-a-2",
                atStage: .draft),
            session(
                templateID: "tmpl-b-1",
                atStage: .axiomatized),
            session(
                templateID: "tmpl-b-2",
                atStage: .domainApproved),
            session(
                templateID: "tmpl-b-3",
                atStage: .domainApproved),
        ]
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        let byDomain = Dictionary(
            uniqueKeysWithValues:
                dashboard.perDomain.map {
                    ($0.domain, $0)
                })
        XCTAssertEqual(
            byDomain["a"]?.productionReadyCount, 1)
        let aFraction = try XCTUnwrap(
            byDomain["a"]?.productionReadyFraction)
        XCTAssertEqual(aFraction, 0.5, accuracy: 1e-9)
        XCTAssertEqual(
            byDomain["b"]?.productionReadyCount, 3)
        let bFraction = try XCTUnwrap(
            byDomain["b"]?.productionReadyFraction)
        XCTAssertEqual(bFraction, 1.0, accuracy: 1e-9)
    }

    // MARK: - 5 domains × 10 templates = 50 entries

    func test_fiveDomainsTenTemplatesEach() {
        var sessions: [
            BASWorldPriorTemplateAuthoringSession
        ] = []
        let domains = [
            "relationship",
            "decision",
            "time",
            "boundary",
            "analogy",
        ]
        for domain in domains {
            for i in 1...10 {
                sessions.append(
                    session(
                        templateID:
                            "tmpl-\(domain)-\(i)"))
            }
        }
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        XCTAssertEqual(
            dashboard.summary.totalSessions, 50)
        XCTAssertEqual(dashboard.perDomain.count, 5)
        for entry in dashboard.perDomain {
            XCTAssertEqual(entry.totalCount, 10)
        }
    }

    // MARK: - Markdown rendering

    func test_markdownContainsHeader() {
        let dashboard = BASWorldPriorReviewerDashboard(
            from: [
                session(templateID: "tmpl-a-1")
            ])
        let md =
            BASWorldPriorReviewerDashboardFormatter
                .renderMarkdown(dashboard)
        XCTAssertTrue(
            md.contains("# Path B Progress Dashboard"))
        XCTAssertTrue(md.contains("## Summary"))
    }

    func test_markdownContainsPercentages() {
        let sessions = [
            session(
                templateID: "tmpl-a-1",
                atStage: .domainApproved),
            session(
                templateID: "tmpl-a-2",
                atStage: .draft),
        ]
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        let md =
            BASWorldPriorReviewerDashboardFormatter
                .renderMarkdown(dashboard)
        XCTAssertTrue(
            md.contains("50%"),
            "production-ready 50% must render in markdown")
    }

    func test_markdownDeterministicForSameInput() {
        let sessions = [
            session(
                templateID: "tmpl-a-1",
                atStage: .peerReview),
            session(
                templateID: "tmpl-b-1",
                atStage: .domainApproved),
        ]
        let dashboard = BASWorldPriorReviewerDashboard(
            from: sessions)
        let m1 =
            BASWorldPriorReviewerDashboardFormatter
                .renderMarkdown(dashboard)
        let m2 =
            BASWorldPriorReviewerDashboardFormatter
                .renderMarkdown(dashboard)
        XCTAssertEqual(m1, m2)
    }

    // MARK: - Codable round-trip

    func test_dashboardCodableRoundTrip() throws {
        let dashboard = BASWorldPriorReviewerDashboard(
            from: [
                session(templateID: "tmpl-a-1"),
                session(templateID: "tmpl-b-1"),
            ])
        let data = try JSONEncoder().encode(dashboard)
        let decoded = try JSONDecoder().decode(
            BASWorldPriorReviewerDashboard.self,
            from: data)
        XCTAssertEqual(decoded, dashboard)
    }
}
