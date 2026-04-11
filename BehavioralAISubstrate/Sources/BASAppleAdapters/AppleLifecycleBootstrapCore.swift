import Foundation
import BASMemory
import BASRuntimeCore

public enum BASAppleLifecycleBootstrapPhase: String, Codable, Equatable, Sendable, CaseIterable {
    case initialAppearance
    case sceneActive
}

public enum BASAppleLifecycleBootstrapActionKind: String, Codable, Equatable, Sendable, CaseIterable {
    case refreshMemoryProjection
    case refreshCurrentBrain
    case presentPendingReflection
    case consumePendingLaunchRequest
    case restoreActiveWorkspace
    case refreshPredictedIntervention
    case syncWidgetSnapshot
}

public struct BASAppleLifecycleBootstrapAction: Codable, Equatable, Sendable {
    public var kind: BASAppleLifecycleBootstrapActionKind
    public var currentBrainTriggerID: String?

    public init(
        kind: BASAppleLifecycleBootstrapActionKind,
        currentBrainTriggerID: String? = nil
    ) {
        self.kind = kind
        self.currentBrainTriggerID = currentBrainTriggerID
    }
}

public struct BASAppleCurrentBrainRuntimePlan: Codable, Equatable, Sendable {
    public var modeID: String
    public var promptSeed: String
    public var retrievalMode: String
    public var triggerID: String

    public init(
        modeID: String,
        promptSeed: String,
        retrievalMode: String,
        triggerID: String
    ) {
        self.modeID = modeID
        self.promptSeed = promptSeed
        self.retrievalMode = retrievalMode
        self.triggerID = triggerID
    }
}

public enum BASAppleLifecycleBootstrapPlanner {
    public static func actions(
        for phase: BASAppleLifecycleBootstrapPhase
    ) -> [BASAppleLifecycleBootstrapAction] {
        switch phase {
        case .initialAppearance:
            [
                BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                BASAppleLifecycleBootstrapAction(
                    kind: .refreshCurrentBrain,
                    currentBrainTriggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue
                ),
                BASAppleLifecycleBootstrapAction(kind: .presentPendingReflection),
                BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest),
                BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace),
                BASAppleLifecycleBootstrapAction(kind: .refreshPredictedIntervention),
                BASAppleLifecycleBootstrapAction(kind: .syncWidgetSnapshot)
            ]
        case .sceneActive:
            [
                BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                BASAppleLifecycleBootstrapAction(
                    kind: .refreshCurrentBrain,
                    currentBrainTriggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
                ),
                BASAppleLifecycleBootstrapAction(kind: .presentPendingReflection),
                BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest),
                BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace),
                BASAppleLifecycleBootstrapAction(kind: .refreshPredictedIntervention)
            ]
        }
    }
}

public enum BASAppleLifecycleBootstrapExecutor {
    public static func execute(
        phase: BASAppleLifecycleBootstrapPhase,
        refreshMemoryProjection: () -> Void,
        refreshCurrentBrain: (String) -> Void,
        presentPendingReflection: () -> Void,
        consumePendingLaunchRequest: () -> Void,
        restoreActiveWorkspace: () -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        for action in BASAppleLifecycleBootstrapPlanner.actions(for: phase) {
            switch action.kind {
            case .refreshMemoryProjection:
                refreshMemoryProjection()
            case .refreshCurrentBrain:
                refreshCurrentBrain(
                    action.currentBrainTriggerID ?? BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue
                )
            case .presentPendingReflection:
                presentPendingReflection()
            case .consumePendingLaunchRequest:
                consumePendingLaunchRequest()
            case .restoreActiveWorkspace:
                restoreActiveWorkspace()
            case .refreshPredictedIntervention:
                refreshPredictedIntervention()
            case .syncWidgetSnapshot:
                syncWidgetSnapshot()
            }
        }
    }
}

public enum BASAppleCurrentBrainRuntimePlanner {
    public static func sessionPrimePlan(
        modeID: String,
        promptFragments: [String],
        retrievalMode: String,
        triggerID: String = BASCurrentBrainBootstrapTrigger.sessionPrime.rawValue
    ) -> BASAppleCurrentBrainRuntimePlan {
        BASAppleCurrentBrainRuntimePlan(
            modeID: modeID,
            promptSeed: BASAppleBootstrapStrategyAdapter.promptSeed(fragments: promptFragments),
            retrievalMode: retrievalMode,
            triggerID: triggerID
        )
    }

    public static func activeRefreshPlan(
        quickPromptFragments: [String]?,
        balancePromptFragments: [String]?,
        mirrorPromptFragments: [String]?,
        taskGraphModeID: String?,
        taskGraphPromptSeed: String?,
        retrievalModesByModeID: [String: String],
        triggerID: String = BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue,
        defaultModeID: String = BASDecisionMode.quick.rawValue,
        defaultRetrievalMode: String = BASRetrievalMode.adaptive.rawValue
    ) -> BASAppleCurrentBrainRuntimePlan {
        let seed = BASAppleBootstrapStrategyAdapter.resolveActiveSessionSeed(
            quickPromptFragments: quickPromptFragments,
            balancePromptFragments: balancePromptFragments,
            mirrorPromptFragments: mirrorPromptFragments,
            taskGraphModeID: taskGraphModeID,
            taskGraphPromptSeed: taskGraphPromptSeed,
            defaultModeID: defaultModeID
        )

        return BASAppleCurrentBrainRuntimePlan(
            modeID: seed.modeID,
            promptSeed: seed.promptSeed,
            retrievalMode: retrievalModesByModeID[seed.modeID]
                ?? retrievalModesByModeID[defaultModeID]
                ?? defaultRetrievalMode,
            triggerID: triggerID
        )
    }
}

public enum BASAppleCurrentBrainRuntimeExecutor {
    public static func primeSession<CurrentBrain>(
        modeID: String,
        promptFragments: [String],
        retrievalMode: String,
        refreshMemoryProjection: () -> Void,
        bootstrapCurrentBrain: (BASAppleCurrentBrainRuntimePlan) -> CurrentBrain,
        afterBootstrap: (CurrentBrain) -> Void
    ) -> CurrentBrain {
        refreshMemoryProjection()
        let currentBrain = bootstrapCurrentBrain(
            BASAppleCurrentBrainRuntimePlanner.sessionPrimePlan(
                modeID: modeID,
                promptFragments: promptFragments,
                retrievalMode: retrievalMode
            )
        )
        afterBootstrap(currentBrain)
        return currentBrain
    }

    public static func refreshActiveBrain<CurrentBrain>(
        quickPromptFragments: [String]?,
        balancePromptFragments: [String]?,
        mirrorPromptFragments: [String]?,
        taskGraphModeID: String?,
        taskGraphPromptSeed: String?,
        retrievalModesByModeID: [String: String],
        triggerID: String = BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue,
        refreshMemoryProjection: () -> Void,
        bootstrapCurrentBrain: (BASAppleCurrentBrainRuntimePlan) -> CurrentBrain
    ) -> CurrentBrain {
        refreshMemoryProjection()
        return bootstrapCurrentBrain(
            BASAppleCurrentBrainRuntimePlanner.activeRefreshPlan(
                quickPromptFragments: quickPromptFragments,
                balancePromptFragments: balancePromptFragments,
                mirrorPromptFragments: mirrorPromptFragments,
                taskGraphModeID: taskGraphModeID,
                taskGraphPromptSeed: taskGraphPromptSeed,
                retrievalModesByModeID: retrievalModesByModeID,
                triggerID: triggerID
            )
        )
    }
}
