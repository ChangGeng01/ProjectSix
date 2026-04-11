import Foundation
import SwiftData
import BASMemory

public struct BASAppleCurrentBrainHostLifecycleRuntimeInput: Sendable {
    public var bootstrapInput: BASAppleCurrentBrainBootstrapBridgeInput
    public var checkpointLimit: Int
    public var checkpointRetentionInterval: TimeInterval

    public init(
        bootstrapInput: BASAppleCurrentBrainBootstrapBridgeInput,
        checkpointLimit: Int = BASEvolutionCheckpointPlanner.defaultCheckpointLimit,
        checkpointRetentionInterval: TimeInterval = BASEvolutionCheckpointPlanner.defaultRetentionInterval
    ) {
        self.bootstrapInput = bootstrapInput
        self.checkpointLimit = checkpointLimit
        self.checkpointRetentionInterval = checkpointRetentionInterval
    }
}

public enum BASAppleCurrentBrainHostLifecycleRuntimeExecutor {
    public static func bootstrapAndBuildCurrentBrain<
        Template,
        FailurePattern,
        Update: BASAppleCurrentBrainUpdateEntity,
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        CurrentBrain
    >(
        input: BASAppleCurrentBrainHostLifecycleRuntimeInput,
        in modelContext: ModelContext,
        prepareLifecycleState: () -> Void = {},
        recommendTemplateIDs: (BASCurrentBrainBootstrapPreparation) -> [String],
        selectTemplates: (BASCurrentBrainBootstrapPreparation, [String]) -> [Template],
        selectFailurePatterns: (BASCurrentBrainBootstrapPreparation) -> [FailurePattern],
        mapTemplate: (Template) -> BASAppleCurrentBrainBootstrapHostTemplateInput,
        mapFailurePattern: (FailurePattern) -> BASAppleCurrentBrainBootstrapHostFailurePatternInput,
        onCheckpointSaveError: ((Error) -> Void)? = nil,
        onUpdateSaveError: ((Error) -> Void)? = nil,
        buildCurrentBrain: (BASAppleCurrentBrainLifecycleResult<Update, Checkpoint>) -> CurrentBrain
    ) -> CurrentBrain {
        let lifecycleResult: BASAppleCurrentBrainLifecycleResult<Update, Checkpoint> =
            BASAppleCurrentBrainLifecycleExecutor.bootstrapAndCommit(
                input: input.bootstrapInput,
                in: modelContext,
                createdAt: input.bootstrapInput.now,
                checkpointLimit: input.checkpointLimit,
                checkpointRetentionInterval: input.checkpointRetentionInterval,
                prepareLifecycleState: prepareLifecycleState,
                recommendTemplateIDs: recommendTemplateIDs,
                selectTemplates: selectTemplates,
                selectFailurePatterns: selectFailurePatterns,
                mapTemplate: mapTemplate,
                mapFailurePattern: mapFailurePattern,
                onCheckpointSaveError: onCheckpointSaveError,
                onUpdateSaveError: onUpdateSaveError
            )

        return buildCurrentBrain(lifecycleResult)
    }
}
