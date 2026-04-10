import Foundation
import SwiftData
import BASAppleAdapters
import BASMemory

enum DecisionEvolutionEngine {
    @discardableResult
    static func recordCheckpoint(
        mode: DecisionMode,
        source: BrainStateUpdateSource,
        brainState: DecisionBrainState,
        context: ModelContext,
        now: Date = .now
    ) -> DecisionEvolutionState {
        let input = BASEvolutionCheckpointPlanner.checkpointInput(
            modeName: mode.rawValue,
            sourceID: source.rawValue,
            brainState: brainState
        )

        let result: BASAppleEvolutionCheckpointWriteResult<DecisionEvolutionCheckpoint> =
            BASAppleEvolutionCheckpointWriter.record(
                input: input,
                in: context,
                createdAt: now,
                maxEntries: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
                retentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval,
                onSaveError: { error in
                    PersistenceIssueRecorder.record(
                        error: error,
                        operation: "recording evolution checkpoints"
                    )
                }
            )

        return result.currentState
    }

    static func currentState(in context: ModelContext) -> DecisionEvolutionState {
        BASEvolutionCheckpointPlanner.currentState(
            from: fetchCheckpoints(in: context).map(\.storedFields)
        )
    }

    private static func fetchCheckpoints(in context: ModelContext) -> [DecisionEvolutionCheckpoint] {
        let descriptor = FetchDescriptor<DecisionEvolutionCheckpoint>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
