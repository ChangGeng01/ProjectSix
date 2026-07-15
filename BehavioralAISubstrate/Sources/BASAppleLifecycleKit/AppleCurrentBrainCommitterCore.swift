import Foundation
import SwiftData
import BASMemory

public struct BASAppleCurrentBrainCommitWriteResult<
    Update: BASAppleCurrentBrainUpdateEntity,
    Checkpoint: BASAppleEvolutionCheckpointEntity
> {
    public let brainState: BASDecisionBrainState
    public let evolutionState: BASEvolutionState
    public let orderedUpdates: [Update]
    public let orderedCheckpoints: [Checkpoint]
    public let wroteCheckpoint: Bool

    public init(
        brainState: BASDecisionBrainState,
        evolutionState: BASEvolutionState,
        orderedUpdates: [Update],
        orderedCheckpoints: [Checkpoint],
        wroteCheckpoint: Bool
    ) {
        self.brainState = brainState
        self.evolutionState = evolutionState
        self.orderedUpdates = orderedUpdates
        self.orderedCheckpoints = orderedCheckpoints
        self.wroteCheckpoint = wroteCheckpoint
    }
}

public enum BASAppleCurrentBrainCommitter {
    public static func commit<
        Update: BASAppleCurrentBrainUpdateEntity,
        Checkpoint: BASAppleEvolutionCheckpointEntity
    >(
        modeName: String,
        sourceID: String,
        brainState: BASDecisionBrainState,
        persistenceInput: BASCurrentBrainUpdatePersistenceInput,
        in context: ModelContext,
        createdAt: Date = .now,
        checkpointLimit: Int = BASEvolutionCheckpointPlanner.defaultCheckpointLimit,
        checkpointRetentionInterval: TimeInterval = BASEvolutionCheckpointPlanner.defaultRetentionInterval,
        updateLimit: Int = BASCurrentBrainPersistenceApplier.defaultUpdateLimit,
        updateRetentionInterval: TimeInterval = BASCurrentBrainPersistenceApplier.defaultRetentionInterval,
        onCheckpointSaveError: ((Error) -> Void)? = nil,
        onUpdateSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint> {
        let checkpointInput = BASEvolutionCheckpointPlanner.checkpointInput(
            modeName: modeName,
            sourceID: sourceID,
            brainState: brainState
        )

        let checkpointResult: BASAppleEvolutionCheckpointWriteResult<Checkpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: checkpointInput,
                in: context,
                createdAt: createdAt,
                maxEntries: checkpointLimit,
                retentionInterval: checkpointRetentionInterval,
                onSaveError: onCheckpointSaveError
            )

        var committedBrainState = brainState
        committedBrainState.evolutionState = checkpointResult.currentState

        let updateFields = BASCurrentBrainPersistenceApplier.updateFields(
            createdAt: createdAt,
            source: sourceID,
            input: persistenceInput
        )
        let updateResult: BASAppleCurrentBrainUpdateWriteResult<Update> =
            BASAppleCurrentBrainUpdateWriter.persist(
                updateFields,
                in: context,
                maxEntries: updateLimit,
                retentionInterval: updateRetentionInterval,
                onSaveError: onUpdateSaveError
            )

        return BASAppleCurrentBrainCommitWriteResult(
            brainState: committedBrainState,
            evolutionState: checkpointResult.currentState,
            orderedUpdates: updateResult.orderedUpdates,
            orderedCheckpoints: checkpointResult.orderedCheckpoints,
            wroteCheckpoint: checkpointResult.wroteCheckpoint
        )
    }
}
