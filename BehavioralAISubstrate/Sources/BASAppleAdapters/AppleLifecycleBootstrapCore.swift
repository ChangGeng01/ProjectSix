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
    public var bootstrapTriggerID: String?

    public init(
        kind: BASAppleLifecycleBootstrapActionKind,
        bootstrapTriggerID: String? = nil,
        currentBrainTriggerID: String? = nil
    ) {
        self.kind = kind
        self.bootstrapTriggerID = bootstrapTriggerID ?? currentBrainTriggerID
    }

    public var currentBrainTriggerID: String? {
        bootstrapTriggerID
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case bootstrapTriggerID
        case currentBrainTriggerID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(BASAppleLifecycleBootstrapActionKind.self, forKey: .kind)
        bootstrapTriggerID =
            try container.decodeIfPresent(String.self, forKey: .bootstrapTriggerID) ??
            container.decodeIfPresent(String.self, forKey: .currentBrainTriggerID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(bootstrapTriggerID, forKey: .bootstrapTriggerID)
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

public struct BASAppleLifecycleBootstrapBehavior: Codable, Equatable, Sendable {
    public static let generic = BASAppleLifecycleBootstrapBehavior()

    public var actionsByPhaseID: [String: [BASAppleLifecycleBootstrapAction]]
    public var activeRefreshDefaultModeID: String
    public var activeRefreshDefaultRetrievalModeID: String

    public init(
        actionsByPhaseID: [String: [BASAppleLifecycleBootstrapAction]] = [
            BASAppleLifecycleBootstrapPhase.initialAppearance.rawValue: [
                BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                BASAppleLifecycleBootstrapAction(
                    kind: .refreshCurrentBrain,
                    bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue
                ),
                BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest)
            ],
            BASAppleLifecycleBootstrapPhase.sceneActive.rawValue: [
                BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                BASAppleLifecycleBootstrapAction(
                    kind: .refreshCurrentBrain,
                    bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
                ),
                BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest)
            ]
        ],
        activeRefreshDefaultModeID: String = BASDecisionMode.primaryID,
        activeRefreshDefaultRetrievalModeID: String = BASRetrievalMode.adaptive.rawValue
    ) {
        self.actionsByPhaseID = actionsByPhaseID
        self.activeRefreshDefaultModeID = activeRefreshDefaultModeID
        self.activeRefreshDefaultRetrievalModeID = activeRefreshDefaultRetrievalModeID
    }

    public func actions(for phase: BASAppleLifecycleBootstrapPhase) -> [BASAppleLifecycleBootstrapAction] {
        actionsByPhaseID[phase.rawValue, default: BASAppleLifecycleBootstrapBehavior.generic.actionsByPhaseID[phase.rawValue] ?? []]
    }
}

public enum BASAppleLifecycleBootstrapPlanner {
    public static func actions(
        for phase: BASAppleLifecycleBootstrapPhase,
        behavior: BASAppleLifecycleBootstrapBehavior = .generic
    ) -> [BASAppleLifecycleBootstrapAction] {
        behavior.actions(for: phase)
    }
}

public enum BASAppleLifecycleBootstrapExecutor {
    public static func execute(
        phase: BASAppleLifecycleBootstrapPhase,
        behavior: BASAppleLifecycleBootstrapBehavior = .generic,
        refreshMemoryProjection: () -> Void,
        refreshCurrentBrain: (String) -> Void,
        presentPendingReflection: () -> Void,
        consumePendingLaunchRequest: () -> Void,
        restoreActiveWorkspace: () -> Void,
        refreshPredictedIntervention: () -> Void,
        syncWidgetSnapshot: () -> Void = {}
    ) {
        for action in BASAppleLifecycleBootstrapPlanner.actions(for: phase, behavior: behavior) {
            switch action.kind {
            case .refreshMemoryProjection:
                refreshMemoryProjection()
            case .refreshCurrentBrain:
                refreshCurrentBrain(
                    action.bootstrapTriggerID ?? BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue
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
        promptFragmentsByModeID: [String: [String]],
        modePriority: [String],
        taskGraphModeID: String?,
        taskGraphPromptSeed: String?,
        retrievalModesByModeID: [String: String],
        triggerID: String = BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue,
        behavior: BASAppleLifecycleBootstrapBehavior = .generic
    ) -> BASAppleCurrentBrainRuntimePlan {
        let seed = BASAppleBootstrapStrategyAdapter.resolveActiveSessionSeed(
            promptFragmentsByModeID: promptFragmentsByModeID,
            modePriority: modePriority,
            taskGraphModeID: taskGraphModeID,
            taskGraphPromptSeed: taskGraphPromptSeed,
            defaultModeID: behavior.activeRefreshDefaultModeID
        )

        return BASAppleCurrentBrainRuntimePlan(
            modeID: seed.modeID,
            promptSeed: seed.promptSeed,
            retrievalMode: retrievalModesByModeID[seed.modeID]
                ?? retrievalModesByModeID[behavior.activeRefreshDefaultModeID]
                ?? behavior.activeRefreshDefaultRetrievalModeID,
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
        promptFragmentsByModeID: [String: [String]],
        modePriority: [String],
        taskGraphModeID: String?,
        taskGraphPromptSeed: String?,
        retrievalModesByModeID: [String: String],
        triggerID: String = BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue,
        behavior: BASAppleLifecycleBootstrapBehavior = .generic,
        refreshMemoryProjection: () -> Void,
        bootstrapCurrentBrain: (BASAppleCurrentBrainRuntimePlan) -> CurrentBrain
    ) -> CurrentBrain {
        refreshMemoryProjection()
        return bootstrapCurrentBrain(
            BASAppleCurrentBrainRuntimePlanner.activeRefreshPlan(
                promptFragmentsByModeID: promptFragmentsByModeID,
                modePriority: modePriority,
                taskGraphModeID: taskGraphModeID,
                taskGraphPromptSeed: taskGraphPromptSeed,
                retrievalModesByModeID: retrievalModesByModeID,
                triggerID: triggerID,
                behavior: behavior
            )
        )
    }
}
