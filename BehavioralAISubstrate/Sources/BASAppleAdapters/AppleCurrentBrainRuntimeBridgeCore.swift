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
        triggerID: String = BASCurrentBrainBootstrapTrigger.sessionPrime.rawValue
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
    }
}

public struct BASAppleCurrentBrainActiveRefreshBridgeInput: Codable, Equatable, Sendable {
    public var quickPromptFragments: [String]?
    public var balancePromptFragments: [String]?
    public var mirrorPromptFragments: [String]?
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

    public init(
        quickPromptFragments: [String]? = nil,
        balancePromptFragments: [String]? = nil,
        mirrorPromptFragments: [String]? = nil,
        taskGraphModeID: String? = nil,
        taskGraphPromptSeed: String? = nil,
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now,
        projection: BASBrainProjection,
        taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput? = nil,
        retrievalModesByModeID: [String: String],
        triggerID: String = BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue
    ) {
        self.quickPromptFragments = quickPromptFragments
        self.balancePromptFragments = balancePromptFragments
        self.mirrorPromptFragments = mirrorPromptFragments
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
    }
}

public enum BASAppleCurrentBrainRuntimeBridgeBuilder {
    public static func sessionBootstrapInput(
        from input: BASAppleCurrentBrainSessionBridgeInput
    ) -> BASAppleCurrentBrainBootstrapBridgeInput {
        let runtimePlan = BASAppleCurrentBrainRuntimePlanner.sessionPrimePlan(
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
            retrievalMode: runtimePlan.retrievalMode
        )
    }

    public static func activeBootstrapInput(
        from input: BASAppleCurrentBrainActiveRefreshBridgeInput
    ) -> BASAppleCurrentBrainBootstrapBridgeInput {
        let runtimePlan = BASAppleCurrentBrainRuntimePlanner.activeRefreshPlan(
            quickPromptFragments: input.quickPromptFragments,
            balancePromptFragments: input.balancePromptFragments,
            mirrorPromptFragments: input.mirrorPromptFragments,
            taskGraphModeID: input.taskGraphModeID,
            taskGraphPromptSeed: input.taskGraphPromptSeed,
            retrievalModesByModeID: input.retrievalModesByModeID,
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
            retrievalMode: runtimePlan.retrievalMode
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
        retrievalMode: String
    ) -> BASAppleCurrentBrainBootstrapBridgeInput {
        BASAppleCurrentBrainBootstrapBridgeInput(
            modeID: modeID,
            prompt: prompt,
            triggerID: triggerID,
            sourceSurfaceOverrideID: sourceSurfaceOverrideID,
            riskLevelOverrideID: riskLevelOverrideID,
            preferredLanguages: preferredLanguages,
            now: now,
            projection: projection,
            embeddingScores: [],
            taskGraphHeadline: taskGraphHint?.headline,
            taskGraphActiveNodeCount: taskGraphHint?.activeNodeCount,
            taskGraphHasResumeCandidate: taskGraphHint?.hasResumeCandidate,
            taskGraphResumeHint: taskGraphHint?.resumeHint,
            retrievalMode: retrievalMode
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
