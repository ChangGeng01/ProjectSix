import Foundation
import SwiftData
import BASMemory

public protocol BASAppleEvolutionCheckpointEntity: PersistentModel {
    static func basMake(from fields: BASEvolutionCheckpointStoredFields) -> Self
    var basSnapshot: BASEvolutionCheckpointStoredFields { get }
}

public struct BASAppleEvolutionCheckpointWriteResult<
    Checkpoint: BASAppleEvolutionCheckpointEntity
> {
    public let orderedCheckpoints: [Checkpoint]
    public let currentState: BASEvolutionState
    public let wroteCheckpoint: Bool

    public init(
        orderedCheckpoints: [Checkpoint],
        currentState: BASEvolutionState,
        wroteCheckpoint: Bool
    ) {
        self.orderedCheckpoints = orderedCheckpoints
        self.currentState = currentState
        self.wroteCheckpoint = wroteCheckpoint
    }
}

public enum BASAppleEvolutionCheckpointWriter {
    public static func record<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        input: BASEvolutionCheckpointInput,
        in context: ModelContext,
        createdAt: Date = .now,
        maxEntries: Int = BASEvolutionCheckpointPlanner.defaultCheckpointLimit,
        retentionInterval: TimeInterval = BASEvolutionCheckpointPlanner.defaultRetentionInterval,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        let existing = fetchCheckpoints(in: context) as [Checkpoint]
        var checkpointsByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.basSnapshot.id, $0) })
        let latest = canonicalOrder(existing).first?.basSnapshot

        if BASEvolutionCheckpointPlanner.shouldDeduplicate(latest: latest, input: input) {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: canonicalOrder(existing),
                currentState: BASEvolutionCheckpointPlanner.currentState(
                    from: existing.map(\.basSnapshot)
                ),
                wroteCheckpoint: false
            )
        }

        let fields = BASEvolutionCheckpointPlanner.checkpointFields(
            createdAt: createdAt,
            latest: latest,
            input: input
        )

        if let current = checkpointsByID[fields.id] {
            context.delete(current)
        }

        let checkpoint = Checkpoint.basMake(from: fields)
        context.insert(checkpoint)
        checkpointsByID[fields.id] = checkpoint

        let retainedIDs = BASEvolutionCheckpointPlanner.retainedCheckpointIDs(
            in: Array(checkpointsByID.values).map(\.basSnapshot),
            now: createdAt,
            maxEntries: maxEntries,
            retentionInterval: retentionInterval
        )

        for stale in Array(checkpointsByID.values) where !retainedIDs.contains(stale.basSnapshot.id) {
            context.delete(stale)
            checkpointsByID[stale.basSnapshot.id] = nil
        }

        do {
            try context.save()
        } catch {
            onSaveError?(error)
        }

        let ordered = canonicalOrder(Array(checkpointsByID.values))
        return BASAppleEvolutionCheckpointWriteResult(
            orderedCheckpoints: ordered,
            currentState: BASEvolutionCheckpointPlanner.currentState(
                from: ordered.map(\.basSnapshot)
            ),
            wroteCheckpoint: true
        )
    }

    public static func attachLineageSummary<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        _ lineageSummary: BASEvolutionLineageSummary,
        for checkpointID: String,
        in context: ModelContext,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        setLineageSummary(
            lineageSummary,
            for: checkpointID,
            in: context,
            onSaveError: onSaveError
        )
    }

    public static func attachLineageSummary<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        _ lineageSummary: BASEvolutionLineageSummary,
        in context: ModelContext,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        let existing = fetchCheckpoints(in: context) as [Checkpoint]
        let ordered = canonicalOrder(existing)

        guard let latestID = ordered.first?.basSnapshot.id else {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: [],
                currentState: .empty,
                wroteCheckpoint: false
            )
        }

        return setLineageSummary(
            lineageSummary,
            for: latestID,
            in: context,
            onSaveError: onSaveError
        )
    }

    public static func setLineageSummary<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        _ lineageSummary: BASEvolutionLineageSummary?,
        for checkpointID: String,
        in context: ModelContext,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        updateCheckpoint(
            checkpointID: checkpointID,
            in: context,
            onSaveError: onSaveError
        ) { checkpoint in
            BASEvolutionCheckpointPlanner.withLineageSummary(
                lineageSummary,
                appliedTo: checkpoint
            )
        }
    }

    public static func setApprovalState<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        _ approvalState: BASEvolutionApprovalState,
        for checkpointID: String,
        in context: ModelContext,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        updateCheckpoint(
            checkpointID: checkpointID,
            in: context,
            onSaveError: onSaveError
        ) { checkpoint in
            BASEvolutionCheckpointPlanner.withApprovalState(
                approvalState,
                appliedTo: checkpoint
            )
        }
    }

    private static func fetchCheckpoints<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        in context: ModelContext
    ) -> [Checkpoint] {
        (try? context.fetch(FetchDescriptor<Checkpoint>())) ?? []
    }

    private static func canonicalOrder<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        _ checkpoints: [Checkpoint]
    ) -> [Checkpoint] {
        checkpoints.sorted { lhs, rhs in
            let lhsFields = lhs.basSnapshot
            let rhsFields = rhs.basSnapshot
            if lhsFields.createdAt == rhsFields.createdAt {
                return lhsFields.id > rhsFields.id
            }
            return lhsFields.createdAt > rhsFields.createdAt
        }
    }

    private static func updateCheckpoint<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        checkpointID: String,
        in context: ModelContext,
        onSaveError: ((Error) -> Void)? = nil,
        transform: (BASEvolutionCheckpointStoredFields) -> BASEvolutionCheckpointStoredFields
    ) -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        let existing = fetchCheckpoints(in: context) as [Checkpoint]
        let ordered = canonicalOrder(existing)

        guard let target = ordered.first(where: { $0.basSnapshot.id == checkpointID }) else {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: ordered,
                currentState: BASEvolutionCheckpointPlanner.currentState(
                    from: ordered.map(\.basSnapshot)
                ),
                wroteCheckpoint: false
            )
        }

        let updatedFields = transform(target.basSnapshot)
        guard updatedFields != target.basSnapshot else {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: ordered,
                currentState: BASEvolutionCheckpointPlanner.currentState(
                    from: ordered.map(\.basSnapshot)
                ),
                wroteCheckpoint: false
            )
        }

        var checkpointsByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.basSnapshot.id, $0) })
        context.delete(target)

        let replacement = Checkpoint.basMake(from: updatedFields)
        context.insert(replacement)
        checkpointsByID[updatedFields.id] = replacement

        do {
            try context.save()
        } catch {
            onSaveError?(error)
        }

        let updatedOrder = canonicalOrder(Array(checkpointsByID.values))
        return BASAppleEvolutionCheckpointWriteResult(
            orderedCheckpoints: updatedOrder,
            currentState: BASEvolutionCheckpointPlanner.currentState(
                from: updatedOrder.map(\.basSnapshot)
            ),
            wroteCheckpoint: false
        )
    }
}
