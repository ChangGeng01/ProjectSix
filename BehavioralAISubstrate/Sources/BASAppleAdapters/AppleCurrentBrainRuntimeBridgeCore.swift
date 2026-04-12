import Foundation
import BASMemory

public struct BASAppleCurrentBrainSessionBridgeInput: Codable, Equatable, Sendable {
    public var modeID: String
    public var promptFragments: [String]
    public var sourceSurfaceOverrideID: String?
    public var riskLevelOverrideID: String?
    public var preferredLanguages: [String]
    public var now: Date
    public var projection: BASBrainProjection
    public var taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput?
    public var retrievalMode: String
    public var triggerID: String
    public var bootstrapBehavior: BASCurrentBrainBootstrapBehavior
    public var cognitionBehavior: BASCognitionBehavior

    public init(
        modeID: String,
        promptFragments: [String],
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now,
        projection: BASBrainProjection,
        taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput? = nil,
        retrievalMode: String,
        triggerID: String = BASCurrentBrainBootstrapTrigger.sessionBootstrapID,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        cognitionBehavior: BASCognitionBehavior
    ) {
        self.modeID = modeID
        self.promptFragments = promptFragments
        self.sourceSurfaceOverrideID = sourceSurfaceOverrideID
        self.riskLevelOverrideID = riskLevelOverrideID
        self.preferredLanguages = preferredLanguages
        self.now = now
        self.projection = projection
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.triggerID = triggerID
        self.bootstrapBehavior = bootstrapBehavior
        self.cognitionBehavior = cognitionBehavior
    }
}

public struct BASAppleCurrentBrainActiveRefreshBridgeInput: Codable, Equatable, Sendable {
    public var promptFragmentsByModeID: [String: [String]]
    public var modePriority: [String]
    public var taskGraphModeID: String?
    public var taskGraphPromptSeed: String?
    public var sourceSurfaceOverrideID: String?
    public var riskLevelOverrideID: String?
    public var preferredLanguages: [String]
    public var now: Date
    public var projection: BASBrainProjection
    public var taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput?
    public var retrievalModesByModeID: [String: String]
    public var triggerID: String
    public var lifecycleBehavior: BASAppleLifecycleBootstrapBehavior
    public var bootstrapBehavior: BASCurrentBrainBootstrapBehavior
    public var cognitionBehavior: BASCognitionBehavior

    public init(
        promptFragmentsByModeID: [String: [String]] = [:],
        modePriority: [String] = BASDecisionMode.genericPriorityIDs,
        taskGraphModeID: String? = nil,
        taskGraphPromptSeed: String? = nil,
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now,
        projection: BASBrainProjection,
        taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput? = nil,
        retrievalModesByModeID: [String: String],
        triggerID: String = BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue,
        lifecycleBehavior: BASAppleLifecycleBootstrapBehavior,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        cognitionBehavior: BASCognitionBehavior
    ) {
        self.promptFragmentsByModeID = promptFragmentsByModeID
        self.modePriority = modePriority
        self.taskGraphModeID = taskGraphModeID
        self.taskGraphPromptSeed = taskGraphPromptSeed
        self.sourceSurfaceOverrideID = sourceSurfaceOverrideID
        self.riskLevelOverrideID = riskLevelOverrideID
        self.preferredLanguages = preferredLanguages
        self.now = now
        self.projection = projection
        self.taskGraphHint = taskGraphHint
        self.retrievalModesByModeID = retrievalModesByModeID
        self.triggerID = triggerID
        self.lifecycleBehavior = lifecycleBehavior
        self.bootstrapBehavior = bootstrapBehavior
        self.cognitionBehavior = cognitionBehavior
    }
}

public enum BASAppleCurrentBrainRuntimeBridgeBuilder {
    public static func sessionBootstrapInput(
        from input: BASAppleCurrentBrainSessionBridgeInput
    ) -> BASAppleCurrentBrainBootstrapBridgeInput {
        let runtimePlan = BASAppleCurrentBrainRuntimePlanner.sessionBootstrapPlan(
            modeID: input.modeID,
            promptFragments: input.promptFragments,
            retrievalMode: input.retrievalMode,
            triggerID: input.triggerID
        )
        return bootstrapInput(
            modeID: runtimePlan.modeID,
            prompt: runtimePlan.promptSeed,
            triggerID: runtimePlan.triggerID,
            sourceSurfaceOverrideID: input.sourceSurfaceOverrideID,
            riskLevelOverrideID: input.riskLevelOverrideID,
            preferredLanguages: input.preferredLanguages,
            now: input.now,
            projection: input.projection,
            taskGraphHint: input.taskGraphHint,
            retrievalMode: runtimePlan.retrievalMode,
            bootstrapBehavior: input.bootstrapBehavior,
            cognitionBehavior: input.cognitionBehavior
        )
    }

    public static func activeBootstrapInput(
        from input: BASAppleCurrentBrainActiveRefreshBridgeInput
    ) -> BASAppleCurrentBrainBootstrapBridgeInput {
        let runtimePlan = BASAppleCurrentBrainRuntimePlanner.activeRefreshPlan(
            promptFragmentsByModeID: input.promptFragmentsByModeID,
            modePriority: input.modePriority,
            taskGraphModeID: input.taskGraphModeID,
            taskGraphPromptSeed: input.taskGraphPromptSeed,
            retrievalModesByModeID: input.retrievalModesByModeID,
            triggerID: input.triggerID,
            behavior: input.lifecycleBehavior
        )
        return bootstrapInput(
            modeID: runtimePlan.modeID,
            prompt: runtimePlan.promptSeed,
            triggerID: runtimePlan.triggerID,
            sourceSurfaceOverrideID: input.sourceSurfaceOverrideID,
            riskLevelOverrideID: input.riskLevelOverrideID,
            preferredLanguages: input.preferredLanguages,
            now: input.now,
            projection: input.projection,
            taskGraphHint: input.taskGraphHint,
            retrievalMode: runtimePlan.retrievalMode,
            bootstrapBehavior: input.bootstrapBehavior,
            cognitionBehavior: input.cognitionBehavior
        )
    }

    private static func bootstrapInput(
        modeID: String,
        prompt: String,
        triggerID: String,
        sourceSurfaceOverrideID: String?,
        riskLevelOverrideID: String?,
        preferredLanguages: [String],
        now: Date,
        projection: BASBrainProjection,
        taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput?,
        retrievalMode: String,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        cognitionBehavior: BASCognitionBehavior
    ) -> BASAppleCurrentBrainBootstrapBridgeInput {
        BASAppleCurrentBrainBootstrapBridgeInputBuilder.build(
            modeID: modeID,
            prompt: prompt,
            triggerID: triggerID,
            sourceSurfaceOverrideID: sourceSurfaceOverrideID,
            riskLevelOverrideID: riskLevelOverrideID,
            preferredLanguages: preferredLanguages,
            now: now,
            projection: projection,
            embeddingScores: [],
            taskGraphHint: taskGraphHint,
            retrievalMode: retrievalMode,
            bootstrapBehavior: bootstrapBehavior,
            cognitionBehavior: cognitionBehavior
        )
    }
}

public enum BASAppleCurrentBrainRuntimeBridgeExecutor {
    public static func primeSession<CurrentBrain>(
        input: BASAppleCurrentBrainSessionBridgeInput,
        refreshMemoryProjection: () -> Void = {},
        bootstrapCurrentBrain: (BASAppleCurrentBrainBootstrapBridgeInput) -> CurrentBrain,
        afterBootstrap: (CurrentBrain) -> Void
    ) -> CurrentBrain {
        refreshMemoryProjection()
        let currentBrain = bootstrapCurrentBrain(
            BASAppleCurrentBrainRuntimeBridgeBuilder.sessionBootstrapInput(from: input)
        )
        afterBootstrap(currentBrain)
        return currentBrain
    }

    public static func refreshActiveBrain<CurrentBrain>(
        input: BASAppleCurrentBrainActiveRefreshBridgeInput,
        refreshMemoryProjection: () -> Void = {},
        bootstrapCurrentBrain: (BASAppleCurrentBrainBootstrapBridgeInput) -> CurrentBrain
    ) -> CurrentBrain {
        refreshMemoryProjection()
        return bootstrapCurrentBrain(
            BASAppleCurrentBrainRuntimeBridgeBuilder.activeBootstrapInput(from: input)
        )
    }
}
