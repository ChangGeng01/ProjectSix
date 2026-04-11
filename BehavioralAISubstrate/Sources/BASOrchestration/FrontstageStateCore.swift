import Foundation
import BASRuntimeCore

public struct BASFrontstagePresentationBehavior: Codable, Sendable, Equatable {
    public var focusGoalsByKindID: [String: String]
    public var baseEvidenceCountByKindID: [String: Int]
    public var lowGearEvidenceClampByKindID: [String: Int]
    public var contextRebuiltSignal: String
    public var staleFieldsSignal: String
    public var filteredEvidenceSignal: String
    public var trimmedEvidenceSignal: String

    public init(
        focusGoalsByKindID: [String: String] = [
            BASAdaptiveTraceKind.quick.rawValue: "Clarify the immediate state before momentum hardens.",
            BASAdaptiveTraceKind.balance.rawValue: "Clarify the active trade-off before committing.",
            BASAdaptiveTraceKind.mirror.rawValue: "Clarify the underlying pattern without forcing closure.",
            BASAdaptiveTraceKind.reminder.rawValue: "Select the stored candidate that best fits the current state."
        ],
        baseEvidenceCountByKindID: [String: Int] = [
            BASAdaptiveTraceKind.quick.rawValue: 2,
            BASAdaptiveTraceKind.balance.rawValue: 1,
            BASAdaptiveTraceKind.mirror.rawValue: 1,
            BASAdaptiveTraceKind.reminder.rawValue: 0
        ],
        lowGearEvidenceClampByKindID: [String: Int] = [
            BASAdaptiveTraceKind.quick.rawValue: 1
        ],
        contextRebuiltSignal: String = "Session rebuild",
        staleFieldsSignal: String = "Stale fields dropped",
        filteredEvidenceSignal: String = "Evidence filtered",
        trimmedEvidenceSignal: String = "Frontstage trimmed"
    ) {
        self.focusGoalsByKindID = focusGoalsByKindID
        self.baseEvidenceCountByKindID = baseEvidenceCountByKindID
        self.lowGearEvidenceClampByKindID = lowGearEvidenceClampByKindID
        self.contextRebuiltSignal = contextRebuiltSignal
        self.staleFieldsSignal = staleFieldsSignal
        self.filteredEvidenceSignal = filteredEvidenceSignal
        self.trimmedEvidenceSignal = trimmedEvidenceSignal
    }

    public static let generic = BASFrontstagePresentationBehavior()

    public func focusGoal(for kind: BASAdaptiveTraceKind) -> String {
        focusGoalsByKindID[kind.rawValue, default: BASFrontstagePresentationBehavior.generic.fallbackFocusGoal(for: kind)]
    }

    public func baseEvidenceCount(for kind: BASAdaptiveTraceKind) -> Int {
        baseEvidenceCountByKindID[kind.rawValue, default: BASFrontstagePresentationBehavior.generic.fallbackBaseEvidenceCount(for: kind)]
    }

    public func lowGearEvidenceClamp(for kind: BASAdaptiveTraceKind) -> Int? {
        lowGearEvidenceClampByKindID[kind.rawValue]
    }

    private func fallbackFocusGoal(for kind: BASAdaptiveTraceKind) -> String {
        switch kind {
        case .quick:
            "Clarify the immediate state before momentum hardens."
        case .balance:
            "Clarify the active trade-off before committing."
        case .mirror:
            "Clarify the underlying pattern without forcing closure."
        case .reminder:
            "Select the stored candidate that best fits the current state."
        }
    }

    private func fallbackBaseEvidenceCount(for kind: BASAdaptiveTraceKind) -> Int {
        switch kind {
        case .quick:
            2
        case .balance, .mirror:
            1
        case .reminder:
            0
        }
    }
}

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
    public var presentationBehavior: BASFrontstagePresentationBehavior

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
        sessionBiases: [String] = [],
        presentationBehavior: BASFrontstagePresentationBehavior = .generic
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
        self.presentationBehavior = presentationBehavior
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
            dangerSignals.append(request.presentationBehavior.contextRebuiltSignal)
        }
        if request.staleFieldCount > 0 {
            dangerSignals.append(request.presentationBehavior.staleFieldsSignal)
        }
        if request.droppedInjectedEvidenceCount > 0 {
            dangerSignals.append(request.presentationBehavior.filteredEvidenceSignal)
        }
        if request.droppedBudgetEvidenceCount > 0 {
            dangerSignals.append(request.presentationBehavior.trimmedEvidenceSignal)
        }
        dangerSignals = Array(dangerSignals.prefix(Constants.frontstageSignalCount))

        let evidenceHeadlines = request.retainedEvidence
            .prefix(
                frontstageEvidenceCount(
                    for: request.kind,
                    strategy: request.strategy,
                    behavior: request.presentationBehavior
                )
            )
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
            focusGoal: request.presentationBehavior.focusGoal(for: request.kind),
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

    private static func frontstageEvidenceCount(
        for kind: BASAdaptiveTraceKind,
        strategy: BASAdaptiveTaskStrategy?,
        behavior: BASFrontstagePresentationBehavior
    ) -> Int {
        let base = behavior.baseEvidenceCount(for: kind)

        guard let strategy else { return base }
        let retrievalAdjusted: Int = switch strategy.retrievalMode {
        case .off:
            max(0, base - 1)
        case .filtered:
            base
        case .adaptive:
            base + 1
        }

        if strategy.runtimeGear == .low,
           let clamp = behavior.lowGearEvidenceClamp(for: kind) {
            return min(clamp, retrievalAdjusted)
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
