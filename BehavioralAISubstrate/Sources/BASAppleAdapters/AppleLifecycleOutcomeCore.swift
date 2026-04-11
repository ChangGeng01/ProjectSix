import Foundation
import BASMemory

public enum BASApplePendingLaunchActionKind: String, Codable, Equatable, Sendable {
    case quickCapture
    case openMode
    case routedPrompt
}

public struct BASApplePendingLaunchActionPlan: Codable, Equatable, Sendable {
    public var actionKind: BASApplePendingLaunchActionKind
    public var preferredModeID: String?
    public var scenarioID: String?
    public var promptSeed: String

    public init(
        actionKind: BASApplePendingLaunchActionKind,
        preferredModeID: String? = nil,
        scenarioID: String? = nil,
        promptSeed: String
    ) {
        self.actionKind = actionKind
        self.preferredModeID = preferredModeID
        self.scenarioID = scenarioID
        self.promptSeed = promptSeed
    }
}

public enum BASApplePendingLaunchOutcomeBuilder {
    public static func resolve(
        preferredModeID: String?,
        scenarioID: String?,
        promptSeed: String?
    ) -> BASApplePendingLaunchActionPlan {
        let promptSeed = promptSeed?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if let scenarioID {
            return BASApplePendingLaunchActionPlan(
                actionKind: .quickCapture,
                scenarioID: scenarioID,
                promptSeed: promptSeed
            )
        }

        if let preferredModeID {
            return BASApplePendingLaunchActionPlan(
                actionKind: .openMode,
                preferredModeID: preferredModeID,
                promptSeed: promptSeed
            )
        }

        if !promptSeed.isEmpty {
            return BASApplePendingLaunchActionPlan(
                actionKind: .routedPrompt,
                promptSeed: promptSeed
            )
        }

        return BASApplePendingLaunchActionPlan(
            actionKind: .quickCapture,
            promptSeed: ""
        )
    }
}

public enum BASApplePendingLaunchOutcomeExecutor {
    public static func execute(
        plan: BASApplePendingLaunchActionPlan,
        performQuickCapture: (BASApplePendingLaunchActionPlan) -> Void,
        performOpenMode: (BASApplePendingLaunchActionPlan) -> Void,
        performRoutedPrompt: (BASApplePendingLaunchActionPlan) -> Void
    ) {
        switch plan.actionKind {
        case .quickCapture:
            performQuickCapture(plan)
        case .openMode:
            performOpenMode(plan)
        case .routedPrompt:
            performRoutedPrompt(plan)
        }
    }
}

public struct BASApplePendingLaunchRuntimeInput: Codable, Equatable, Sendable {
    public var preferredModeID: String?
    public var scenarioID: String?
    public var promptSeed: String?

    public init(
        preferredModeID: String? = nil,
        scenarioID: String? = nil,
        promptSeed: String? = nil
    ) {
        self.preferredModeID = preferredModeID
        self.scenarioID = scenarioID
        self.promptSeed = promptSeed
    }
}

public enum BASApplePendingLaunchRuntimeExecutor {
    public static func execute(
        input: BASApplePendingLaunchRuntimeInput,
        performQuickCapture: (BASApplePendingLaunchActionPlan) -> Void,
        performOpenMode: (BASApplePendingLaunchActionPlan) -> Void,
        performRoutedPrompt: (BASApplePendingLaunchActionPlan) -> Void
    ) {
        BASApplePendingLaunchOutcomeExecutor.execute(
            plan: BASApplePendingLaunchOutcomeBuilder.resolve(
                preferredModeID: input.preferredModeID,
                scenarioID: input.scenarioID,
                promptSeed: input.promptSeed
            ),
            performQuickCapture: performQuickCapture,
            performOpenMode: performOpenMode,
            performRoutedPrompt: performRoutedPrompt
        )
    }
}

public enum BASAppleLifecycleEntrySourceExecutor {
    public static func execute<Envelope, PendingRequest>(
        consumeHandoff: () -> Envelope?,
        handleHandoff: (Envelope) -> Void,
        consumePendingRequest: () -> PendingRequest?,
        handlePendingRequest: (PendingRequest) -> Void
    ) {
        if let envelope = consumeHandoff() {
            handleHandoff(envelope)
            return
        }

        guard let request = consumePendingRequest() else { return }
        handlePendingRequest(request)
    }
}

public struct BASAppleWorkspaceRestoreEligibilityInput: Codable, Equatable, Sendable {
    public var restoreEnabled: Bool
    public var hasActiveQuickSession: Bool
    public var hasActiveBalanceSession: Bool
    public var hasActiveMirrorSession: Bool
    public var hasReflectionContext: Bool

    public init(
        restoreEnabled: Bool,
        hasActiveQuickSession: Bool,
        hasActiveBalanceSession: Bool,
        hasActiveMirrorSession: Bool,
        hasReflectionContext: Bool
    ) {
        self.restoreEnabled = restoreEnabled
        self.hasActiveQuickSession = hasActiveQuickSession
        self.hasActiveBalanceSession = hasActiveBalanceSession
        self.hasActiveMirrorSession = hasActiveMirrorSession
        self.hasReflectionContext = hasReflectionContext
    }
}

public enum BASAppleWorkspaceRestorePlanner {
    public static func shouldRestore(
        eligibility: BASAppleWorkspaceRestoreEligibilityInput,
        modeID: String?
    ) -> Bool {
        guard eligibility.restoreEnabled else { return false }
        guard !eligibility.hasActiveQuickSession else { return false }
        guard !eligibility.hasActiveBalanceSession else { return false }
        guard !eligibility.hasActiveMirrorSession else { return false }
        guard !eligibility.hasReflectionContext else { return false }
        guard modeID != nil else { return false }
        return true
    }
}

public enum BASAppleWorkspaceRestoreExecutor {
    public static func execute<State>(
        eligibility: BASAppleWorkspaceRestoreEligibilityInput,
        loadState: () -> State?,
        modeID: (State) -> String?,
        restoreQuick: (State) -> Void,
        restoreBalance: (State) -> Void,
        restoreMirror: (State) -> Void,
        selectHomeTab: () -> Void,
        afterRestore: () -> Void
    ) {
        guard let state = loadState() else { return }
        guard BASAppleWorkspaceRestorePlanner.shouldRestore(
            eligibility: eligibility,
            modeID: modeID(state)
        ) else {
            return
        }

        switch modeID(state) {
        case BASDecisionMode.quick.rawValue:
            restoreQuick(state)
        case BASDecisionMode.balance.rawValue:
            restoreBalance(state)
        case BASDecisionMode.mirror.rawValue:
            restoreMirror(state)
        default:
            return
        }

        selectHomeTab()
        afterRestore()
    }
}
