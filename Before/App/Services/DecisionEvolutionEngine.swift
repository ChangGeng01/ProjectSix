import Foundation
import SwiftData
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
        let existing = fetchCheckpoints(in: context).map(\.storedFields)
        let latest = existing.first
        let input = BASEvolutionCheckpointPlanner.checkpointInput(
            modeName: mode.rawValue,
            sourceID: source.rawValue,
            brainState: brainState
        )

        if BASEvolutionCheckpointPlanner.shouldDeduplicate(latest: latest, input: input) {
            return BASEvolutionCheckpointPlanner.currentState(from: existing)
        }

        let checkpoint = DecisionEvolutionCheckpoint(
            storedFields: BASEvolutionCheckpointPlanner.checkpointFields(
                id: UUID().uuidString,
                createdAt: now,
                latest: latest,
                input: input
            )
        )
        context.insert(checkpoint)
        trimOldCheckpoints(in: context, now: now)
        try? context.save()

        return BASEvolutionCheckpointPlanner.currentState(
            from: fetchCheckpoints(in: context).map(\.storedFields)
        )
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

    private static func trimOldCheckpoints(in context: ModelContext, now: Date) {
        let checkpoints = fetchCheckpoints(in: context)
        let retainedIDs = BASEvolutionCheckpointPlanner.retainedCheckpointIDs(
            in: checkpoints.map(\.storedFields),
            now: now,
            maxEntries: BeforePolicy.RuntimeState.evolutionCheckpointLimit,
            retentionInterval: BeforePolicy.RuntimeState.evolutionCheckpointRetentionInterval
        )

        for stale in checkpoints where !retainedIDs.contains(stale.id) {
            context.delete(stale)
        }
    }
}
