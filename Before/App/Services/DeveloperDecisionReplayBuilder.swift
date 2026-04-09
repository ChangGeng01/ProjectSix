import Foundation

enum DeveloperDecisionReplayRecord: Identifiable {
    case quick(CheckEvent)
    case balance(BalanceDecisionRecord)
    case mirror(MirrorDecisionRecord)

    var id: String {
        switch self {
        case .quick(let event):
            "quick-\(event.id.uuidString)"
        case .balance(let record):
            "balance-\(record.id.uuidString)"
        case .mirror(let record):
            "mirror-\(record.id.uuidString)"
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
        }
    }

    var summaryLine: String {
        switch self {
        case .quick(let event):
            "\(event.scenario.title) • \(event.finalAction.title(using: BeforePolicy.QuickCheck.defaultBufferDuration))"
        case .balance(let record):
            record.nextAction
        case .mirror(let record):
            record.nextAction
        }
    }
}

struct DeveloperDecisionReplayEntry: Identifiable {
    let record: DeveloperDecisionReplayRecord
    let trace: DeveloperDecisionReplayTraceSummary?

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

enum DeveloperDecisionReplayBuilder {
    static func build(
        quick: [CheckEvent],
        balance: [BalanceDecisionRecord],
        mirror: [MirrorDecisionRecord],
        traces: [DecisionIntelligenceTrace],
        limit: Int = BeforePolicy.Settings.developerReplayLimit
    ) -> [DeveloperDecisionReplayEntry] {
        let records = (
            quick.map(DeveloperDecisionReplayRecord.quick)
            + balance.map(DeveloperDecisionReplayRecord.balance)
            + mirror.map(DeveloperDecisionReplayRecord.mirror)
        )
        .sorted { $0.timestamp > $1.timestamp }
        .prefix(limit)

        var unmatchedTraces = Dictionary(
            grouping: traces.sorted { $0.createdAt > $1.createdAt },
            by: \.kind
        )

        return records.map { record in
            let trace = matchingTrace(
                for: record,
                unmatchedTraces: &unmatchedTraces
            )
            return DeveloperDecisionReplayEntry(
                record: record,
                trace: trace.map(DeveloperDecisionReplayTraceSummary.init)
            )
        }
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

    private static func isReasonableMatch(trace: DecisionIntelligenceTrace, for timestamp: Date) -> Bool {
        let delta = timestamp.timeIntervalSince(trace.createdAt)
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
