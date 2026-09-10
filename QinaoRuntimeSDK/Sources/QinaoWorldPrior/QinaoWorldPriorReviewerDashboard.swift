import Foundation

// 六十一.2 — typed reviewer dashboard for Path B progress.
//
// ## Why this exists
//
// 五十三 ship 了 `BASWorldPriorAuthoringProgressReport` (per-
// session typed view) + `BASWorldPriorAuthoringBatchReport`
// (multi-session counts). 六十一 Path B 真审稿场景需要更
// 集中的 dashboard view：
//
// - per-domain breakdown（5 域 × 各 ~10 条），不只总计
// - 瓶颈识别：哪个 stage 最多 sessions 卡住
// - markdown rendering 给 host operator 直接发周报
//
// `BASWorldPriorReviewerDashboard` 在 batch report 之上加这
// 三件，重用既有 typed primitives，pure derived view。
//
// ## Doctrine
//
// - **Pure read-only view.** No mutation; sessions are source
//   of truth.
// - **Domain identification by templateID prefix.** Convention
//   `tmpl-<domain>-<name>` lets us partition without extra
//   metadata.
// - **Stable markdown.** Rendering uses sortedKeys-equivalent
//   ordering; same input → same output byte-for-byte.

public struct BASWorldPriorReviewerDashboardPerDomain:
    Sendable, Equatable, Hashable, Codable
{
    public let domain: String
    public let totalCount: Int
    public let stageCounts: [
        BASWorldPriorTemplateAuthoringStage: Int
    ]
    public let productionReadyCount: Int

    public init(
        domain: String,
        totalCount: Int,
        stageCounts: [
            BASWorldPriorTemplateAuthoringStage: Int
        ],
        productionReadyCount: Int
    ) {
        self.domain = domain
        self.totalCount = totalCount
        self.stageCounts = stageCounts
        self.productionReadyCount = productionReadyCount
    }

    public var productionReadyFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(productionReadyCount)
            / Double(totalCount)
    }
}

public struct BASWorldPriorReviewerDashboardSummary:
    Sendable, Equatable, Hashable, Codable
{
    public let totalSessions: Int
    public let stageCounts: [
        BASWorldPriorTemplateAuthoringStage: Int
    ]
    public let productionReadyCount: Int
    public let bottleneckStage:
        BASWorldPriorTemplateAuthoringStage?

    public init(
        totalSessions: Int,
        stageCounts: [
            BASWorldPriorTemplateAuthoringStage: Int
        ],
        productionReadyCount: Int,
        bottleneckStage:
            BASWorldPriorTemplateAuthoringStage?
    ) {
        self.totalSessions = totalSessions
        self.stageCounts = stageCounts
        self.productionReadyCount = productionReadyCount
        self.bottleneckStage = bottleneckStage
    }

    public var productionReadyFraction: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(productionReadyCount)
            / Double(totalSessions)
    }
}

public struct BASWorldPriorReviewerDashboard:
    Sendable, Equatable, Hashable, Codable
{
    public let summary:
        BASWorldPriorReviewerDashboardSummary
    public let perDomain: [
        BASWorldPriorReviewerDashboardPerDomain
    ]

    public init(
        summary:
            BASWorldPriorReviewerDashboardSummary,
        perDomain: [
            BASWorldPriorReviewerDashboardPerDomain
        ]
    ) {
        self.summary = summary
        self.perDomain = perDomain
    }

    /// Build a dashboard from a flat session list.
    public init(
        from sessions: [
            BASWorldPriorTemplateAuthoringSession
        ]
    ) {
        // Aggregate counts.
        var stageCounts: [
            BASWorldPriorTemplateAuthoringStage: Int
        ] = [:]
        var ready = 0
        for session in sessions {
            stageCounts[
                session.currentStage, default: 0] += 1
            if session.currentStage.attainedProvenance
                >= .domainExpertReviewed
            {
                ready += 1
            }
        }
        // Bottleneck: non-terminal stage with the highest
        // count (excluding `.draft`, which is not a wait).
        let nonTerminalActive: [
            BASWorldPriorTemplateAuthoringStage
        ] = [
            .hostReviewed,
            .peerReview,
            .domainApproved,
        ]
        let bottleneck = nonTerminalActive
            .max { (a, b) in
                stageCounts[a, default: 0]
                    < stageCounts[b, default: 0]
            }
            .flatMap { stage -> BASWorldPriorTemplateAuthoringStage? in
                stageCounts[stage, default: 0] > 0
                    ? stage : nil
            }

        let summary =
            BASWorldPriorReviewerDashboardSummary(
                totalSessions: sessions.count,
                stageCounts: stageCounts,
                productionReadyCount: ready,
                bottleneckStage: bottleneck)

        // Partition by domain prefix.
        var grouped: [
            String:
                [BASWorldPriorTemplateAuthoringSession]
        ] = [:]
        for session in sessions {
            let domain = Self.domain(
                from: session.templateID)
            grouped[domain, default: []].append(session)
        }

        var perDomain: [
            BASWorldPriorReviewerDashboardPerDomain
        ] = []
        for domain in grouped.keys.sorted() {
            let domainSessions = grouped[domain] ?? []
            var counts: [
                BASWorldPriorTemplateAuthoringStage: Int
            ] = [:]
            var domainReady = 0
            for session in domainSessions {
                counts[
                    session.currentStage, default: 0
                ] += 1
                if session.currentStage
                    .attainedProvenance
                    >= .domainExpertReviewed
                {
                    domainReady += 1
                }
            }
            perDomain.append(
                BASWorldPriorReviewerDashboardPerDomain(
                    domain: domain,
                    totalCount: domainSessions.count,
                    stageCounts: counts,
                    productionReadyCount: domainReady))
        }

        self.summary = summary
        self.perDomain = perDomain
    }

    /// Extract domain from templateID. Convention:
    /// `tmpl-<domain>-<name>`. If the ID doesn't have at
    /// least 2 segments after `tmpl-`, returns `"unknown"`.
    public static func domain(
        from templateID: String
    ) -> String {
        let parts = templateID.split(separator: "-")
        // parts[0] == "tmpl", parts[1] == domain.
        guard parts.count >= 3, parts[0] == "tmpl"
        else { return "unknown" }
        return String(parts[1])
    }
}

// MARK: - Markdown formatter

public enum BASWorldPriorReviewerDashboardFormatter {
    /// Render a dashboard to markdown text. Output is byte-
    /// stable for the same input (sorted keys, sorted domain
    /// list).
    public static func renderMarkdown(
        _ dashboard: BASWorldPriorReviewerDashboard
    ) -> String {
        var lines: [String] = []
        let summary = dashboard.summary

        lines.append("# Path B Progress Dashboard")
        lines.append("")
        lines.append("## Summary")
        lines.append("")
        lines.append(
            "- Total sessions: **\(summary.totalSessions)**")
        lines.append(
            "- Production-ready: **\(summary.productionReadyCount)** (\(percent(summary.productionReadyFraction)))")
        if let bottleneck = summary.bottleneckStage {
            lines.append(
                "- Bottleneck stage: **\(bottleneck.rawValue)** (\(summary.stageCounts[bottleneck, default: 0]) sessions)")
        } else {
            lines.append(
                "- Bottleneck stage: _(none — no active sessions)_")
        }
        lines.append("")

        lines.append("## Stage breakdown (overall)")
        lines.append("")
        for stage in BASWorldPriorTemplateAuthoringStage
            .allCases
        {
            let count = summary.stageCounts[
                stage, default: 0]
            if count > 0 {
                lines.append(
                    "- `\(stage.rawValue)`: **\(count)**")
            }
        }
        lines.append("")

        lines.append("## Per-domain breakdown")
        lines.append("")
        for domain in dashboard.perDomain {
            lines.append("### \(domain.domain)")
            lines.append("")
            lines.append(
                "- Total: **\(domain.totalCount)**")
            lines.append(
                "- Production-ready: **\(domain.productionReadyCount)** (\(percent(domain.productionReadyFraction)))")
            for stage in
                BASWorldPriorTemplateAuthoringStage
                .allCases
            {
                let count = domain.stageCounts[
                    stage, default: 0]
                if count > 0 {
                    lines.append(
                        "  - `\(stage.rawValue)`: \(count)")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func percent(
        _ fraction: Double
    ) -> String {
        let rounded = Int(
            (fraction * 100).rounded())
        return "\(rounded)%"
    }
}
