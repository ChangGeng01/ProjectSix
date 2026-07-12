import Foundation
import BASMemory

public enum BASApplePendingLaunchActionKind: String, Codable, Equatable, Sendable {
    case capture
    case present
    case routedInput
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
                actionKind: .capture,
                scenarioID: scenarioID,
                promptSeed: promptSeed
            )
        }

        if let preferredModeID {
            return BASApplePendingLaunchActionPlan(
                actionKind: .present,
                preferredModeID: preferredModeID,
                promptSeed: promptSeed
            )
        }

        if !promptSeed.isEmpty {
            return BASApplePendingLaunchActionPlan(
                actionKind: .routedInput,
                promptSeed: promptSeed
            )
        }

        return BASApplePendingLaunchActionPlan(
            actionKind: .capture,
            promptSeed: ""
        )
    }
}

public enum BASApplePendingLaunchOutcomeExecutor {
    public static func execute(
        plan: BASApplePendingLaunchActionPlan,
        performCapture: (BASApplePendingLaunchActionPlan) -> Void,
        performPresent: (BASApplePendingLaunchActionPlan) -> Void,
        performRoutedInput: (BASApplePendingLaunchActionPlan) -> Void
    ) {
        switch plan.actionKind {
        case .capture:
            performCapture(plan)
        case .present:
            performPresent(plan)
        case .routedInput:
            performRoutedInput(plan)
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
        performCapture: (BASApplePendingLaunchActionPlan) -> Void,
        performPresent: (BASApplePendingLaunchActionPlan) -> Void,
        performRoutedInput: (BASApplePendingLaunchActionPlan) -> Void
    ) {
        BASApplePendingLaunchOutcomeExecutor.execute(
            plan: BASApplePendingLaunchOutcomeBuilder.resolve(
                preferredModeID: input.preferredModeID,
                scenarioID: input.scenarioID,
                promptSeed: input.promptSeed
            ),
            performCapture: performCapture,
            performPresent: performPresent,
            performRoutedInput: performRoutedInput
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
    public var hasActivePrimaryWorkflow: Bool
    public var hasActiveComparativeWorkflow: Bool
    public var hasActiveReflectiveWorkflow: Bool
    public var hasReflectionContext: Bool

    public init(
        restoreEnabled: Bool,
        hasActivePrimaryWorkflow: Bool,
        hasActiveComparativeWorkflow: Bool,
        hasActiveReflectiveWorkflow: Bool,
        hasReflectionContext: Bool
    ) {
        self.restoreEnabled = restoreEnabled
        self.hasActivePrimaryWorkflow = hasActivePrimaryWorkflow
        self.hasActiveComparativeWorkflow = hasActiveComparativeWorkflow
        self.hasActiveReflectiveWorkflow = hasActiveReflectiveWorkflow
        self.hasReflectionContext = hasReflectionContext
    }
}

public enum BASAppleWorkspaceRestorePlanner {
    public static func shouldRestore(
        eligibility: BASAppleWorkspaceRestoreEligibilityInput,
        modeID: String?
    ) -> Bool {
        guard eligibility.restoreEnabled else { return false }
        guard !eligibility.hasActivePrimaryWorkflow else { return false }
        guard !eligibility.hasActiveComparativeWorkflow else { return false }
        guard !eligibility.hasActiveReflectiveWorkflow else { return false }
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
        restorePrimary: (State) -> Void,
        restoreComparative: (State) -> Void,
        restoreReflective: (State) -> Void,
        selectHomeTab: () -> Void,
        afterRestore: () -> Void
    ) {
        guard let state = loadState() else { return }
        let resolvedMode = modeID(state).flatMap(BASDecisionMode.init(identifier:))
        guard BASAppleWorkspaceRestorePlanner.shouldRestore(
            eligibility: eligibility,
            modeID: resolvedMode?.identifier
        ) else {
            return
        }

        switch resolvedMode {
        case .primary:
            restorePrimary(state)
        case .comparative:
            restoreComparative(state)
        case .reflective:
            restoreReflective(state)
        case nil:
            return
        }

        selectHomeTab()
        afterRestore()
    }
}
