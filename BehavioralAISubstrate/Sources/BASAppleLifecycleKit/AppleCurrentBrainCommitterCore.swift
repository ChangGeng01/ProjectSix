import Foundation
import SwiftData
import BASMemory

public struct BASAppleCurrentBrainCommitWriteResult<
    Update: BASAppleCurrentBrainUpdateEntity,
    Checkpoint: BASAppleEvolutionCheckpointEntity
> {
    public let brainState: BASDecisionBrainState
    public let evolutionState: BASEvolutionState
    public let orderedUpdates: [BASCurrentBrainUpdateStoredFields]
    public let orderedCheckpoints: [BASEvolutionCheckpointStoredFields]
    public let wroteCheckpoint: Bool

    public init(
        brainState: BASDecisionBrainState,
        evolutionState: BASEvolutionState,
        orderedUpdates: [BASCurrentBrainUpdateStoredFields],
        orderedCheckpoints: [BASEvolutionCheckpointStoredFields],
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
    /// Commits checkpoint and update staging through one save in a package-owned
    /// context. The supplied context selects the committed store only; its
    /// pending changes do not participate.
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
        updateRetentionInterval: TimeInterval = BASCurrentBrainPersistenceApplier.defaultRetentionInterval
    ) throws -> BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint> {
        try commit(
            modeName: modeName,
            sourceID: sourceID,
            brainState: brainState,
            persistenceInput: persistenceInput,
            in: context,
            createdAt: createdAt,
            checkpointLimit: checkpointLimit,
            checkpointRetentionInterval: checkpointRetentionInterval,
            updateLimit: updateLimit,
            updateRetentionInterval: updateRetentionInterval,
            using: BASAppleCurrentBrainLivePersistenceIO()
        )
    }

    static func commit<
        Update: BASAppleCurrentBrainUpdateEntity,
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
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
        using io: IO
    ) throws -> BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint> {
        let checkpointInput = BASEvolutionCheckpointPlanner.checkpointInput(
            modeName: modeName,
            sourceID: sourceID,
            brainState: brainState
        )

        return try BASAppleCurrentBrainPersistenceTransaction.perform(
            selectedBy: context,
            using: io
        ) { owned in
            let checkpointResult: BASAppleEvolutionCheckpointWriteResult<Checkpoint> =
                try BASAppleEvolutionCheckpointWriter.stageRecord(
                    input: checkpointInput,
                    in: owned,
                    createdAt: createdAt,
                    maxEntries: checkpointLimit,
                    retentionInterval: checkpointRetentionInterval,
                    using: io
                )

            var committedBrainState = brainState
            committedBrainState.evolutionState = checkpointResult.currentState

            let updateFields = BASCurrentBrainPersistenceApplier.updateFields(
                createdAt: createdAt,
                source: sourceID,
                input: persistenceInput
            )
            let updateResult: BASAppleCurrentBrainUpdateWriteResult<Update> =
                try BASAppleCurrentBrainUpdateWriter.stage(
                    updateFields,
                    in: owned,
                    maxEntries: updateLimit,
                    retentionInterval: updateRetentionInterval,
                    using: io
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
}
