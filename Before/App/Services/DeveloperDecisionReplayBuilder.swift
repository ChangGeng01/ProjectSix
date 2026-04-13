import Foundation
import BASHostKit

enum DeveloperDecisionReplayRecord: Identifiable {
    case quick(CheckEvent)
    case balance(BalanceDecisionRecord)
    case mirror(MirrorDecisionRecord)
    case checkpoint(DecisionEvolutionLineageSnapshot)

    var id: String {
        switch self {
        case .quick(let event):
            "quick-\(event.id.uuidString)"
        case .balance(let record):
            "balance-\(record.id.uuidString)"
        case .mirror(let record):
            "mirror-\(record.id.uuidString)"
        case .checkpoint(let lineage):
            "checkpoint-\(lineage.checkpointID)"
        }
    }

    var mode: DecisionMode {
        switch self {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case .checkpoint(let lineage):
            lineage.mode
        }
    }

    var timestamp: Date {
        switch self {
        case .quick(let event):
            event.createdAt
        case .balance(let record):
            record.updatedAt
        case .mirror(let record):
            record.updatedAt
        case .checkpoint(let lineage):
            lineage.eBrain.recordedAt
        }
    }

    var entrySource: EntrySource {
        switch self {
        case .quick(let event):
            event.entrySource
        case .balance(let record):
            record.entrySource
        case .mirror(let record):
            record.entrySource
        case .checkpoint:
            .app
        }
    }

    var title: String {
        switch self {
        case .quick(let event):
            event.currentPerspective
        case .balance(let record):
            record.prompt
        case .mirror(let record):
            record.prompt
        case .checkpoint(let lineage):
            "Recovered \(lineage.mode.shortTitle) lineage"
        }
    }

    var subtitle: String {
        switch self {
        case .quick(let event):
            event.afterPerspective
        case .balance(let record):
            record.focusSummary
        case .mirror(let record):
            record.coreTension
        case .checkpoint(let lineage):
            "Recovered from persisted checkpoint • \(lineage.eBrain.taskType.replacingOccurrences(of: "_", with: " "))"
        }
    }

    var statusTitle: String {
        switch self {
        case .quick(let event):
            event.verdict.title
        case .balance(let record):
            record.focusTitle
        case .mirror(let record):
            record.nextActionTitle
        case .checkpoint(let lineage):
            readableApprovalStateTitle(lineage.approvalState)
        }
    }

    var summaryLine: String {
        switch self {
        case .quick(let event):
            return "\(event.scenario.title) • \(event.finalAction.title(using: BeforePolicy.QuickCheck.defaultBufferDuration))"
        case .balance(let record):
            return record.nextAction
        case .mirror(let record):
            return record.nextAction
        case .checkpoint(let lineage):
            if let firstDiff = lineage.diffSummary.first, !firstDiff.isEmpty {
                return firstDiff
            }
            if let firstTicket = lineage.eBrain.updateTicketSummaries.first, !firstTicket.isEmpty {
                return firstTicket
            }
            return "Recovered \(lineage.eBrain.riskLevel) risk lineage via \(lineage.eBrain.permitMode)."
        }
    }
}

private func readableApprovalStateTitle(
    _ approvalState: BASEvolutionApprovalState
) -> String {
    switch approvalState {
    case .automatic:
        return "Automatic"
    case .reviewSuggested:
        return "Review Suggested"
    }
}

struct DeveloperDecisionReplayEntry: Identifiable {
    let record: DeveloperDecisionReplayRecord
    let trace: DeveloperDecisionReplayTraceSummary?
    let eBrain: DeveloperDecisionReplayEBrainSummary?

    var id: String { record.id }
    var mode: DecisionMode { record.mode }
    var timestamp: Date { record.timestamp }
    var entrySource: EntrySource { record.entrySource }
    var title: String { record.title }
    var subtitle: String { record.subtitle }
    var statusTitle: String { record.statusTitle }
    var summaryLine: String { record.summaryLine }
}

struct DeveloperDecisionReplayTraceSummary: Equatable, Sendable {
    let createdAt: Date
    let kind: DecisionIntelligenceTraceKind
    let preferredProvider: DecisionModelProviderKind
    let activeProvider: DecisionModelProviderKind?
    let attemptedProviders: [DecisionModelProviderKind]
    let allowFallbacks: Bool
    let usedFallback: Bool
    let prompt: String
    let outputPreview: String
    let detail: String

    init(trace: DecisionIntelligenceTrace) {
        self.createdAt = trace.createdAt
        self.kind = trace.kind
        self.preferredProvider = trace.preferredProvider
        self.activeProvider = trace.activeProvider
        self.attemptedProviders = trace.attemptedProviders
        self.allowFallbacks = trace.allowFallbacks
        self.usedFallback = trace.usedFallback
        self.prompt = trace.prompt
        self.outputPreview = trace.outputPreview
        self.detail = trace.detail
    }
}

enum DeveloperDecisionReplayEBrainSource: String, Equatable, Sendable {
    case liveRuntime = "live_runtime"
    case persistedCheckpoint = "persisted_checkpoint"

    var title: String {
        switch self {
        case .liveRuntime:
            "Live runtime"
        case .persistedCheckpoint:
            "Checkpoint recovery"
        }
    }
}

struct DeveloperDecisionReplayEBrainSummary: Equatable, Sendable {
    let source: DeveloperDecisionReplayEBrainSource
    let recordedAt: Date
    let sessionID: String
    let taskType: String
    let riskLevel: String
    let permitMode: String
    let hostGatePercent: Int
    let thoughtFoldChecksum: String
    let updateTicketSummaries: [String]
    let guardrailFindings: [String]
    let killSwitches: [String]

    init(turn: BASEBrainTurnResult) {
        self.source = .liveRuntime
        self.recordedAt = turn.runtimeTrace.recordedAt
        self.sessionID = turn.runtimeTrace.sessionID
        self.taskType = turn.contextFrame.taskType.rawValue
        self.riskLevel = turn.riskCard.riskLevel.rawValue
        self.permitMode = turn.actionPermit.mode.rawValue
        self.hostGatePercent = Int((turn.hostGateValue * 100).rounded())
        self.thoughtFoldChecksum = String(turn.thoughtFold.checksum.prefix(12))
        self.updateTicketSummaries = turn.updateTickets.map(\.summary)
        self.guardrailFindings = turn.runtimeTrace.guardrailFindings.map(\.summary)
        self.killSwitches = turn.runtimeTrace.recommendedKillSwitches.map(\.rawValue)
    }

    init(lineageSummary: BASEvolutionLineageSummary) {
        self.source = .persistedCheckpoint
        self.recordedAt = lineageSummary.recordedAt
        self.sessionID = lineageSummary.sessionID
        self.taskType = lineageSummary.taskType
        self.riskLevel = lineageSummary.riskLevel
        self.permitMode = lineageSummary.permitMode
        self.hostGatePercent = lineageSummary.hostGatePercent
        self.thoughtFoldChecksum = lineageSummary.thoughtFoldChecksum
        self.updateTicketSummaries = lineageSummary.updateTicketSummaries
        self.guardrailFindings = lineageSummary.guardrailFindings
        self.killSwitches = lineageSummary.recommendedKillSwitches
    }
}

private extension BASEBrainTurnResult {
    var replayMode: DecisionMode? {
        if let workflow = hostContext.workRoutines.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            if let match = DecisionMode.allCases.first(where: {
                workflow.contains($0.rawValue) || workflow.contains($0.shortTitle.lowercased())
            }) {
                return match
            }
        }

        if let sessionMode = runtimeTrace.sessionID
            .split(separator: "|")
            .first?
            .split(separator: ".")
            .last
            .map(String.init),
           let match = DecisionMode(rawValue: sessionMode) {
            return match
        }

        return nil
    }
}

enum DeveloperDecisionReplayBuilder {
    static func build(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        traces: [DecisionIntelligenceTrace],
        eBrainTurns: [BASEBrainTurnResult] = [],
        persistedLineages: [DecisionEvolutionLineageSnapshot] = [],
        limit: Int = BeforePolicy.Settings.developerReplayLimit
    ) -> [DeveloperDecisionReplayEntry] {
        let records = (
            quick.map(DeveloperDecisionReplayRecord.quick)
            + balance.map(DeveloperDecisionReplayRecord.balance)
            + mirror.map(DeveloperDecisionReplayRecord.mirror)
        )
        .sorted { $0.timestamp > $1.timestamp }

        var unmatchedTraces = Dictionary(
            grouping: traces.sorted { $0.createdAt > $1.createdAt },
            by: \.kind
        )
        var unmatchedTurns = Dictionary(
            grouping: eBrainTurns.sorted { $0.runtimeTrace.recordedAt > $1.runtimeTrace.recordedAt },
            by: { $0.replayMode ?? .quick }
        )
        var unmatchedPersistedLineages = Dictionary(
            grouping: persistedLineages.sorted { lhs, rhs in
                if lhs.eBrain.recordedAt == rhs.eBrain.recordedAt {
                    return lhs.checkpointID > rhs.checkpointID
                }
                return lhs.eBrain.recordedAt > rhs.eBrain.recordedAt
            },
            by: \.mode
        )

        let replayEntries = records.map { record in
            let trace = matchingTrace(
                for: record,
                unmatchedTraces: &unmatchedTraces
            )
            let turn = matchingTurn(
                for: record,
                unmatchedTurns: &unmatchedTurns
            )
            let persistedLineage = turn == nil
                ? matchingPersistedLineage(
                    for: record,
                    unmatchedLineages: &unmatchedPersistedLineages
                )
                : nil
            return DeveloperDecisionReplayEntry(
                record: record,
                trace: trace.map(DeveloperDecisionReplayTraceSummary.init),
                eBrain: turn.map(DeveloperDecisionReplayEBrainSummary.init)
                    ?? persistedLineage.map(\.eBrain)
            )
        }

        let checkpointOnlyEntries = unmatchedPersistedLineages.values
            .flatMap { $0 }
            .map { lineage in
                DeveloperDecisionReplayEntry(
                    record: .checkpoint(lineage),
                    trace: nil,
                    eBrain: lineage.eBrain
                )
            }

        return (replayEntries + checkpointOnlyEntries)
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }

    private static func matchingTrace(
        for record: DeveloperDecisionReplayRecord,
        unmatchedTraces: inout [DecisionIntelligenceTraceKind: [DecisionIntelligenceTrace]]
    ) -> DecisionIntelligenceTrace? {
        let kind = traceKind(for: record.mode)
        guard var candidates = unmatchedTraces[kind] else { return nil }
        guard let matchIndex = candidates.firstIndex(where: { isReasonableMatch(trace: $0, for: record.timestamp) }) else {
            return nil
        }

        let match = candidates.remove(at: matchIndex)
        unmatchedTraces[kind] = candidates
        return match
    }

    private static func matchingTurn(
        for record: DeveloperDecisionReplayRecord,
        unmatchedTurns: inout [DecisionMode: [BASEBrainTurnResult]]
    ) -> BASEBrainTurnResult? {
        guard var candidates = unmatchedTurns[record.mode] else { return nil }
        guard let matchIndex = candidates.firstIndex(where: { isReasonableMatch(turn: $0, for: record.timestamp) }) else {
            return nil
        }

        let match = candidates.remove(at: matchIndex)
        unmatchedTurns[record.mode] = candidates
        return match
    }

    private static func matchingPersistedLineage(
        for record: DeveloperDecisionReplayRecord,
        unmatchedLineages: inout [DecisionMode: [DecisionEvolutionLineageSnapshot]]
    ) -> DecisionEvolutionLineageSnapshot? {
        guard var candidates = unmatchedLineages[record.mode] else { return nil }
        guard let matchIndex = candidates.firstIndex(where: { isReasonableMatch(lineage: $0, for: record.timestamp) }) else {
            return nil
        }

        let match = candidates.remove(at: matchIndex)
        unmatchedLineages[record.mode] = candidates
        return match
    }

    private static func isReasonableMatch(trace: DecisionIntelligenceTrace, for timestamp: Date) -> Bool {
        let delta = timestamp.timeIntervalSince(trace.createdAt)
        return delta >= -BeforePolicy.Settings.developerReplayFutureTraceGraceInterval
            && delta <= BeforePolicy.Settings.developerReplayTraceLookbackInterval
    }

    private static func isReasonableMatch(turn: BASEBrainTurnResult, for timestamp: Date) -> Bool {
        let delta = timestamp.timeIntervalSince(turn.runtimeTrace.recordedAt)
        return delta >= -BeforePolicy.Settings.developerReplayFutureTraceGraceInterval
            && delta <= BeforePolicy.Settings.developerReplayTraceLookbackInterval
    }

    private static func isReasonableMatch(lineage: DecisionEvolutionLineageSnapshot, for timestamp: Date) -> Bool {
        let delta = timestamp.timeIntervalSince(lineage.eBrain.recordedAt)
        return delta >= -BeforePolicy.Settings.developerReplayFutureTraceGraceInterval
            && delta <= BeforePolicy.Settings.developerReplayTraceLookbackInterval
    }

    private static func traceKind(for mode: DecisionMode) -> DecisionIntelligenceTraceKind {
        switch mode {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        }
    }
}
