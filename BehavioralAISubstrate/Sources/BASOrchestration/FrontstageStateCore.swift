import Foundation
import BASRuntimeCore

public struct BASFrontstageCompilationRequest: Codable, Sendable, Equatable {
    public var kind: BASAdaptiveTraceKind
    public var activeStateSignalCount: Int
    public var openTextSignalCount: Int
    public var retainedEvidence: [String]
    public var retainedEvidenceCount: Int
    public var droppedEvidenceCount: Int
    public var droppedInjectedEvidenceCount: Int
    public var droppedDuplicateEvidenceCount: Int
    public var droppedBudgetEvidenceCount: Int
    public var strategy: BASAdaptiveTaskStrategy?
    public var contextWasRebuilt: Bool
    public var staleFieldCount: Int
    public var anchorTitles: [String]
    public var dominantSignalTitles: [String]
    public var suppressedBehaviors: [String]
    public var memoryHeadlines: [String]
    public var sessionBiases: [String]

    public init(
        kind: BASAdaptiveTraceKind,
        activeStateSignalCount: Int,
        openTextSignalCount: Int,
        retainedEvidence: [String],
        retainedEvidenceCount: Int,
        droppedEvidenceCount: Int,
        droppedInjectedEvidenceCount: Int,
        droppedDuplicateEvidenceCount: Int,
        droppedBudgetEvidenceCount: Int,
        strategy: BASAdaptiveTaskStrategy? = nil,
        contextWasRebuilt: Bool = false,
        staleFieldCount: Int = 0,
        anchorTitles: [String] = [],
        dominantSignalTitles: [String] = [],
        suppressedBehaviors: [String] = [],
        memoryHeadlines: [String] = [],
        sessionBiases: [String] = []
    ) {
        self.kind = kind
        self.activeStateSignalCount = activeStateSignalCount
        self.openTextSignalCount = openTextSignalCount
        self.retainedEvidence = retainedEvidence
        self.retainedEvidenceCount = retainedEvidenceCount
        self.droppedEvidenceCount = droppedEvidenceCount
        self.droppedInjectedEvidenceCount = droppedInjectedEvidenceCount
        self.droppedDuplicateEvidenceCount = droppedDuplicateEvidenceCount
        self.droppedBudgetEvidenceCount = droppedBudgetEvidenceCount
        self.strategy = strategy
        self.contextWasRebuilt = contextWasRebuilt
        self.staleFieldCount = staleFieldCount
        self.anchorTitles = anchorTitles
        self.dominantSignalTitles = dominantSignalTitles
        self.suppressedBehaviors = suppressedBehaviors
        self.memoryHeadlines = memoryHeadlines
        self.sessionBiases = sessionBiases
    }
}

public enum BASFrontstageStateCompiler {
    public static func compile(
        _ request: BASFrontstageCompilationRequest
    ) -> BASFrontstageState {
        var dangerSignals = request.dominantSignalTitles
            .prefix(Constants.frontstageSignalCount)
            .map { compact($0, fallback: $0, limit: Constants.frontstageSignalLimit) }

        if request.contextWasRebuilt {
            dangerSignals.append("Session rebuild")
        }
        if request.staleFieldCount > 0 {
            dangerSignals.append("Stale fields dropped")
        }
        if request.droppedInjectedEvidenceCount > 0 {
            dangerSignals.append("Evidence filtered")
        }
        if request.droppedBudgetEvidenceCount > 0 {
            dangerSignals.append("Frontstage trimmed")
        }
        dangerSignals = Array(dangerSignals.prefix(Constants.frontstageSignalCount))

        let evidenceHeadlines = request.retainedEvidence
            .prefix(frontstageEvidenceCount(for: request.kind, strategy: request.strategy))
            .map { compact($0, fallback: $0, limit: Constants.frontstageEvidenceLimit) }

        let anchorHeadlines = Array(
            request.anchorTitles
                .map { compact($0, fallback: $0, limit: Constants.frontstageEvidenceLimit) }
                .prefix(Constants.frontstageSignalCount)
        )

        let memoryHeadlines = Array(
            request.memoryHeadlines
                .map { compact($0, fallback: $0, limit: Constants.brainHeadlineLimit) }
                .prefix(Constants.frontstageSignalCount)
        )

        let suppressionHints = Array(
            request.suppressedBehaviors
                .map { compact($0, fallback: $0, limit: Constants.frontstageSignalLimit) }
                .prefix(Constants.frontstageSignalCount)
        )

        let sessionBiases = Array(
            request.sessionBiases
                .map { compact($0, fallback: $0, limit: Constants.sessionBiasLimit) }
                .prefix(Constants.frontstageSignalCount)
        )

        return BASFrontstageState(
            focusGoal: focusGoal(for: request.kind),
            activeStateSignalCount: request.activeStateSignalCount,
            openTextSignalCount: request.openTextSignalCount,
            dangerSignals: dangerSignals,
            evidenceHeadlines: evidenceHeadlines,
            anchorHeadlines: anchorHeadlines,
            memoryHeadlines: memoryHeadlines,
            retainedEvidenceCount: request.retainedEvidenceCount,
            droppedEvidenceCount: request.droppedEvidenceCount,
            droppedInjectedEvidenceCount: request.droppedInjectedEvidenceCount,
            droppedDuplicateEvidenceCount: request.droppedDuplicateEvidenceCount,
            droppedBudgetEvidenceCount: request.droppedBudgetEvidenceCount,
            suppressionHints: suppressionHints,
            sessionBiases: sessionBiases
        )
    }

    private enum Constants {
        static let frontstageSignalCount = 3
        static let frontstageSignalLimit = 48
        static let frontstageEvidenceLimit = 96
        static let brainHeadlineLimit = 110
        static let sessionBiasLimit = 72
    }

    private static func focusGoal(
        for kind: BASAdaptiveTraceKind
    ) -> String {
        switch kind {
        case .quick:
            "Interrupt the automatic reaction before it locks in."
        case .balance:
            "Surface the real trade-off before choosing a side."
        case .mirror:
            "Name the core tension without forcing a yes-no answer."
        case .reminder:
            "Pick the one reminder that best fits the current state."
        }
    }

    private static func frontstageEvidenceCount(
        for kind: BASAdaptiveTraceKind,
        strategy: BASAdaptiveTaskStrategy?
    ) -> Int {
        let base: Int = switch kind {
        case .quick:
            2
        case .balance, .mirror:
            1
        case .reminder:
            0
        }

        guard let strategy else { return base }
        let retrievalAdjusted: Int = switch strategy.retrievalMode {
        case .off:
            max(0, base - 1)
        case .filtered:
            base
        case .adaptive:
            base + 1
        }

        if strategy.runtimeGear == .low && kind == .quick {
            return min(1, retrievalAdjusted)
        }

        return retrievalAdjusted
    }

    private static func compact(
        _ value: String,
        fallback: String,
        limit: Int
    ) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        guard !trimmed.isEmpty else { return fallback }
        let collapsed = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return fallback }
        if collapsed.count <= limit {
            return collapsed
        }

        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
