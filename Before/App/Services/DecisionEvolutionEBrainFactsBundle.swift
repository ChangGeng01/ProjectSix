import Foundation

struct DecisionEvolutionEBrainFactsBundle: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let summaryLine: String
    let runtimeSummaryLine: String
    let brainSummaryLine: String
    let budgetLine: String?
    let taskLine: String?
    let auditLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?
}

extension DeveloperDecisionReplayEBrainSummary {
    func factsBundle(modeTitle: String? = nil) -> DecisionEvolutionEBrainFactsBundle {
        let replaySummary = replayRecoverySummary
        let runtimeSummaryLine = [
            sourceDescriptor.kind == .checkpointRecovery ? "Recovered from checkpoint" : "Live runtime",
            modeTitle,
            "permit \(permitMode)",
            "risk \(riskLevel)",
            "fold \(thoughtFoldChecksum)"
        ]
            .compactMap { $0 }
            .joined(separator: " • ")
        let brainSummaryLine = [
            sourceDescriptor.title,
            "session \(sessionID)",
            "host gate \(hostGatePercent)%",
            "\(updateTicketSummaries.count) tickets"
        ].joined(separator: " • ")

        return DecisionEvolutionEBrainFactsBundle(
            sourceDescriptor: sourceDescriptor,
            summaryLine: replaySummary.headlineLine,
            runtimeSummaryLine: runtimeSummaryLine,
            brainSummaryLine: brainSummaryLine,
            budgetLine: replaySummary.budgetLine,
            taskLine: replaySummary.taskLine,
            auditLine: replaySummary.auditLine,
            activeKillSwitchesLine: replaySummary.activeKillSwitchesLine,
            killSwitchesLine: replaySummary.killSwitchesLine
        )
    }
}
