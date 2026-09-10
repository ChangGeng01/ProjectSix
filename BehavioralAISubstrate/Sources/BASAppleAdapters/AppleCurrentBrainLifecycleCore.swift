import Foundation
import SwiftData
import BASMemory

public struct BASAppleCurrentBrainLifecycleResult<
    Update: BASAppleCurrentBrainUpdateEntity,
    Checkpoint: BASAppleEvolutionCheckpointEntity
> {
    public var triggerID: String
    public var modeID: String
    public var sourceSurfaceID: String
    public var riskLevelID: String
    public var loadedAt: Date
    public var brainState: BASDecisionBrainState
    public var dominantGoal: String?
    public var activeConstraints: [String]
    public var activeTemplateIDs: [String]
    public var failureGuardIDs: [String]
    public var commit: BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint>

    public init(
        triggerID: String,
        modeID: String,
        sourceSurfaceID: String,
        riskLevelID: String,
        loadedAt: Date,
        brainState: BASDecisionBrainState,
        dominantGoal: String?,
        activeConstraints: [String],
        activeTemplateIDs: [String],
        failureGuardIDs: [String],
        commit: BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint>
    ) {
        self.triggerID = triggerID
        self.modeID = modeID
        self.sourceSurfaceID = sourceSurfaceID
        self.riskLevelID = riskLevelID
        self.loadedAt = loadedAt
        self.brainState = brainState
        self.dominantGoal = dominantGoal
        self.activeConstraints = activeConstraints
        self.activeTemplateIDs = activeTemplateIDs
        self.failureGuardIDs = failureGuardIDs
        self.commit = commit
    }
}

public enum BASAppleCurrentBrainLifecycleExecutor {
    public static func bootstrapAndCommit<
        Template,
        FailurePattern,
        Update: BASAppleCurrentBrainUpdateEntity,
        Checkpoint: BASAppleEvolutionCheckpointEntity
    >(
        input: BASAppleCurrentBrainBootstrapBridgeInput,
        in modelContext: ModelContext,
        createdAt: Date = .now,
        checkpointLimit: Int = BASEvolutionCheckpointPlanner.defaultCheckpointLimit,
        checkpointRetentionInterval: TimeInterval = BASEvolutionCheckpointPlanner.defaultRetentionInterval,
        prepareLifecycleState: () -> Void = {},
        recommendTemplateIDs: (BASCurrentBrainBootstrapPreparation) -> [String],
        selectTemplates: (BASCurrentBrainBootstrapPreparation, [String]) -> [Template],
        selectFailurePatterns: (BASCurrentBrainBootstrapPreparation) -> [FailurePattern],
        mapTemplate: (Template) -> BASAppleCurrentBrainBootstrapHostTemplateInput,
        mapFailurePattern: (FailurePattern) -> BASAppleCurrentBrainBootstrapHostFailurePatternInput
    ) throws -> BASAppleCurrentBrainLifecycleResult<Update, Checkpoint> {
        prepareLifecycleState()

        let committed: BASAppleCurrentBrainBootstrapBridgeResult<Update, Checkpoint> =
            try BASAppleCurrentBrainBootstrapBridgeBuilder.bootstrapAndCommit(
                input: input,
                in: modelContext,
                createdAt: createdAt,
                checkpointLimit: checkpointLimit,
                checkpointRetentionInterval: checkpointRetentionInterval,
                recommendTemplateIDs: recommendTemplateIDs,
                selectTemplates: selectTemplates,
                selectFailurePatterns: selectFailurePatterns,
                mapTemplate: mapTemplate,
                mapFailurePattern: mapFailurePattern
            )

        return BASAppleCurrentBrainLifecycleResult<Update, Checkpoint>(
            triggerID: input.triggerID,
            modeID: input.modeID,
            sourceSurfaceID: committed.sourceSurfaceID,
            riskLevelID: committed.riskLevelID,
            loadedAt: input.now,
            brainState: committed.brainState,
            dominantGoal: committed.dominantGoal,
            activeConstraints: committed.activeConstraints,
            activeTemplateIDs: committed.activeTemplateIDs,
            failureGuardIDs: committed.failureGuardIDs,
            commit: committed.commit
        )
    }
}
