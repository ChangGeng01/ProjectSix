import Foundation

// 五十三 — typed progress report for authoring sessions.
//
// ## Why this exists
//
// `BASWorldPriorTemplateAuthoringSession` (M295.1.0) ship 了
// 7-stage state machine + immutable history. UI / audit / CLI
// tools 想要 dashboard view 时还得自己解析 session.history /
// session.currentStage / session.attainedProvenance 三件。
// `BASWorldPriorAuthoringProgressReport` ship typed dashboard
// view: session → 一个 Codable struct，包含 dashboards 关心的
// 全部 derived 字段。
//
// `BASWorldPriorAuthoringBatchReport` 进一步把多 session 聚合成
// 一份 batch dashboard（counts by stage + production-ready
// fraction）。
//
// ## Doctrine
//
// - **Pure derived values**——session 是 source of truth;
//   reports 是 view。
// - **Codable + Hashable**——dashboards / audit ledgers 任意
//   存储 / 序列化。
// - **No mutation of session**——pure read-only convenience.

public struct BASWorldPriorAuthoringProgressReport:
    Sendable, Equatable, Hashable, Codable
{
    public let templateID: String
    public let currentStage:
        BASWorldPriorTemplateAuthoringStage
    public let attainedProvenance:
        BASWorldPriorTemplateProvenance

    /// True iff `attainedProvenance >= .domainExpertReviewed`
    /// — envelope wrapped at this provenance can pass training
    /// filter (M295.2). Used by dashboards to highlight ready
    /// templates.
    public let isProductionReady: Bool

    /// True iff `currentStage.isTerminal` — no further
    /// transitions possible.
    public let isTerminal: Bool

    /// Total number of transitions in session history.
    public let transitionCount: Int

    /// Distinct stages visited, in causal order. Useful for
    /// audit (proves stages were not skipped — the authoring
    /// policy enforces this anyway, but a reported derived
    /// trail is grep-friendly).
    public let stagesVisited: [
        BASWorldPriorTemplateAuthoringStage
    ]

    /// Actions applied in causal order.
    public let actionsApplied: [
        BASWorldPriorTemplateAuthoringAction
    ]

    public init(
        from session: BASWorldPriorTemplateAuthoringSession
    ) {
        self.templateID = session.templateID
        self.currentStage = session.currentStage
        let attained = session.currentStage
            .attainedProvenance
        self.attainedProvenance = attained
        self.isProductionReady =
            attained >= .domainExpertReviewed
        self.isTerminal = session.currentStage.isTerminal
        self.transitionCount = session.history.count

        // Compute stagesVisited preserving causal order; first
        // appearance kept.
        var seen = Set<
            BASWorldPriorTemplateAuthoringStage
        >()
        var ordered: [
            BASWorldPriorTemplateAuthoringStage
        ] = []
        // Start always at .draft (session begins here).
        if !seen.contains(.draft) {
            seen.insert(.draft)
            ordered.append(.draft)
        }
        for transition in session.history {
            if !seen.contains(transition.to) {
                seen.insert(transition.to)
                ordered.append(transition.to)
            }
        }
        self.stagesVisited = ordered

        self.actionsApplied = session.history.map(\.action)
    }
}

public struct BASWorldPriorAuthoringBatchReport:
    Sendable, Equatable, Hashable, Codable
{
    /// Total number of sessions in the batch.
    public let totalSessions: Int

    /// Counts of sessions at each stage. Stages with zero
    /// count are omitted from the dictionary.
    public let stageCounts: [
        BASWorldPriorTemplateAuthoringStage: Int
    ]

    /// Number of sessions production-ready
    /// (`attainedProvenance >= .domainExpertReviewed`).
    public let productionReadyCount: Int

    /// Number of sessions in terminal states
    /// (axiomatized / rejected / withdrawn).
    public let terminalCount: Int

    public init(
        from sessions:
            [BASWorldPriorTemplateAuthoringSession]
    ) {
        self.totalSessions = sessions.count
        var counts: [
            BASWorldPriorTemplateAuthoringStage: Int
        ] = [:]
        var ready = 0
        var terminal = 0
        for session in sessions {
            counts[session.currentStage, default: 0] += 1
            if session.currentStage.attainedProvenance
                >= .domainExpertReviewed
            {
                ready += 1
            }
            if session.currentStage.isTerminal {
                terminal += 1
            }
        }
        self.stageCounts = counts
        self.productionReadyCount = ready
        self.terminalCount = terminal
    }

    /// Fraction in [0, 1]; 0 when batch empty.
    public var productionReadyFraction: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(productionReadyCount)
            / Double(totalSessions)
    }
}
