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
    public let orderedCheckpoints: [BASEvolutionCheckpointStoredFields]
    public let currentState: BASEvolutionState
    public let wroteCheckpoint: Bool

    public init(
        orderedCheckpoints: [BASEvolutionCheckpointStoredFields],
        currentState: BASEvolutionState,
        wroteCheckpoint: Bool
    ) {
        self.orderedCheckpoints = orderedCheckpoints
        self.currentState = currentState
        self.wroteCheckpoint = wroteCheckpoint
    }
}

/// Every public operation uses a package-owned context selected by the supplied
/// `ModelContext.container`. Pending caller changes are never included, saved,
/// or rolled back.
public enum BASAppleEvolutionCheckpointWriter {
    public static func record<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        input: BASEvolutionCheckpointInput,
        in context: ModelContext,
        createdAt: Date = .now,
        maxEntries: Int = BASEvolutionCheckpointPlanner.defaultCheckpointLimit,
        retentionInterval: TimeInterval = BASEvolutionCheckpointPlanner.defaultRetentionInterval
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try record(
            input: input,
            in: context,
            createdAt: createdAt,
            maxEntries: maxEntries,
            retentionInterval: retentionInterval,
            using: BASAppleCurrentBrainLivePersistenceIO()
        )
    }

    static func record<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        input: BASEvolutionCheckpointInput,
        in context: ModelContext,
        createdAt: Date = .now,
        maxEntries: Int = BASEvolutionCheckpointPlanner.defaultCheckpointLimit,
        retentionInterval: TimeInterval = BASEvolutionCheckpointPlanner.defaultRetentionInterval,
        using io: IO
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try BASAppleCurrentBrainPersistenceTransaction.perform(
            selectedBy: context,
            using: io
        ) { owned in
            try stageRecord(
                input: input,
                in: owned,
                createdAt: createdAt,
                maxEntries: maxEntries,
                retentionInterval: retentionInterval,
                using: io
            )
        }
    }

    static func stageRecord<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        input: BASEvolutionCheckpointInput,
        in context: ModelContext,
        createdAt: Date,
        maxEntries: Int,
        retentionInterval: TimeInterval,
        using io: IO
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        let existing: [Checkpoint] = try io.fetch(Checkpoint.self, in: context)
        // audit H17: uniquing-guard — was Dictionary(uniqueKeysWithValues:), traps on duplicate key
        var checkpointsByID = Dictionary(existing.map { ($0.basSnapshot.id, $0) }, uniquingKeysWith: { _, last in last })
        let orderedExisting = canonicalEntityOrder(existing).map(\.basSnapshot)
        let latest = orderedExisting.first

        if BASEvolutionCheckpointPlanner.shouldDeduplicate(latest: latest, input: input) {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: orderedExisting,
                currentState: BASEvolutionCheckpointPlanner.currentState(
                    from: orderedExisting
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

        let ordered = canonicalEntityOrder(Array(checkpointsByID.values)).map(\.basSnapshot)
        return BASAppleEvolutionCheckpointWriteResult(
            orderedCheckpoints: ordered,
            currentState: BASEvolutionCheckpointPlanner.currentState(from: ordered),
            wroteCheckpoint: true
        )
    }

    public static func attachLineageSummary<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        _ lineageSummary: BASEvolutionLineageSummary,
        for checkpointID: String,
        in context: ModelContext
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try attachLineageSummary(
            lineageSummary,
            for: checkpointID,
            in: context,
            using: BASAppleCurrentBrainLivePersistenceIO()
        )
    }

    static func attachLineageSummary<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        _ lineageSummary: BASEvolutionLineageSummary,
        for checkpointID: String,
        in context: ModelContext,
        using io: IO
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try setLineageSummary(
            lineageSummary,
            for: checkpointID,
            in: context,
            using: io
        )
    }

    public static func attachLineageSummary<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        _ lineageSummary: BASEvolutionLineageSummary,
        in context: ModelContext
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try attachLineageSummary(
            lineageSummary,
            in: context,
            using: BASAppleCurrentBrainLivePersistenceIO()
        )
    }

    static func attachLineageSummary<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        _ lineageSummary: BASEvolutionLineageSummary,
        in context: ModelContext,
        using io: IO
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try BASAppleCurrentBrainPersistenceTransaction.perform(
            selectedBy: context,
            using: io
        ) { owned in
            let existing: [Checkpoint] = try io.fetch(Checkpoint.self, in: owned)
            let ordered = canonicalEntityOrder(existing)

            guard let latestID = ordered.first?.basSnapshot.id else {
                return BASAppleEvolutionCheckpointWriteResult(
                    orderedCheckpoints: [],
                    currentState: .empty,
                    wroteCheckpoint: false
                )
            }

            return stageUpdateCheckpoint(
                checkpointID: latestID,
                existing: existing,
                in: owned
            ) { checkpoint in
                BASEvolutionCheckpointPlanner.withLineageSummary(
                    lineageSummary,
                    appliedTo: checkpoint
                )
            }
        }
    }

    public static func setLineageSummary<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        _ lineageSummary: BASEvolutionLineageSummary?,
        for checkpointID: String,
        in context: ModelContext
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try setLineageSummary(
            lineageSummary,
            for: checkpointID,
            in: context,
            using: BASAppleCurrentBrainLivePersistenceIO()
        )
    }

    static func setLineageSummary<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        _ lineageSummary: BASEvolutionLineageSummary?,
        for checkpointID: String,
        in context: ModelContext,
        using io: IO
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try updateCheckpoint(
            checkpointID: checkpointID,
            in: context,
            using: io
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
        in context: ModelContext
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try setApprovalState(
            approvalState,
            for: checkpointID,
            in: context,
            using: BASAppleCurrentBrainLivePersistenceIO()
        )
    }

    static func setApprovalState<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        _ approvalState: BASEvolutionApprovalState,
        for checkpointID: String,
        in context: ModelContext,
        using io: IO
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try updateCheckpoint(
            checkpointID: checkpointID,
            in: context,
            using: io
        ) { checkpoint in
            BASEvolutionCheckpointPlanner.withApprovalState(
                approvalState,
                appliedTo: checkpoint
            )
        }
    }

    public static func revokeCheckpoints<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        for request: BASForgetRequest,
        in context: ModelContext
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try revokeCheckpoints(
            for: request,
            in: context,
            using: BASAppleCurrentBrainLivePersistenceIO()
        )
    }

    static func revokeCheckpoints<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        for request: BASForgetRequest,
        in context: ModelContext,
        using io: IO
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try BASAppleCurrentBrainPersistenceTransaction.perform(
            selectedBy: context,
            using: io
        ) { owned in
            try stageRevocation(for: request, in: owned, using: io)
        }
    }

    private static func stageRevocation<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        for request: BASForgetRequest,
        in context: ModelContext,
        using io: IO
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        let existing: [Checkpoint] = try io.fetch(Checkpoint.self, in: context)
        let orderedEntities = canonicalEntityOrder(existing)
        let ordered = orderedEntities.map(\.basSnapshot)

        guard forgetRequestTargetsCheckpoints(request) else {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: ordered,
                currentState: BASEvolutionCheckpointPlanner.currentState(from: ordered),
                wroteCheckpoint: false
            )
        }

        let revokedIDs = Set(
            ordered
                .filter { matchesForgetRequest(request, checkpoint: $0) }
                .map(\.id)
        )

        guard revokedIDs.isEmpty == false else {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: ordered,
                currentState: BASEvolutionCheckpointPlanner.currentState(from: ordered),
                wroteCheckpoint: false
            )
        }

        let survivingSnapshots = relinkedSnapshots(
            from: ordered.filter { !revokedIDs.contains($0.id) }
        )

        for checkpoint in existing {
            context.delete(checkpoint)
        }
        let replacements = survivingSnapshots.map(Checkpoint.basMake(from:))
        for checkpoint in replacements {
            context.insert(checkpoint)
        }

        let updatedOrder = canonicalEntityOrder(replacements).map(\.basSnapshot)
        return BASAppleEvolutionCheckpointWriteResult(
            orderedCheckpoints: updatedOrder,
            currentState: BASEvolutionCheckpointPlanner.currentState(from: updatedOrder),
            wroteCheckpoint: false
        )
    }

    private static func canonicalEntityOrder<Checkpoint: BASAppleEvolutionCheckpointEntity>(
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

    private static func updateCheckpoint<
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        IO: BASAppleCurrentBrainPersistenceIO
    >(
        checkpointID: String,
        in context: ModelContext,
        using io: IO,
        transform: (BASEvolutionCheckpointStoredFields) -> BASEvolutionCheckpointStoredFields
    ) throws -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        try BASAppleCurrentBrainPersistenceTransaction.perform(
            selectedBy: context,
            using: io
        ) { owned in
            let existing: [Checkpoint] = try io.fetch(Checkpoint.self, in: owned)
            return stageUpdateCheckpoint(
                checkpointID: checkpointID,
                existing: existing,
                in: owned,
                transform: transform
            )
        }
    }

    private static func stageUpdateCheckpoint<Checkpoint: BASAppleEvolutionCheckpointEntity>(
        checkpointID: String,
        existing: [Checkpoint],
        in context: ModelContext,
        transform: (BASEvolutionCheckpointStoredFields) -> BASEvolutionCheckpointStoredFields
    ) -> BASAppleEvolutionCheckpointWriteResult<Checkpoint> {
        let orderedEntities = canonicalEntityOrder(existing)
        let ordered = orderedEntities.map(\.basSnapshot)

        guard let target = orderedEntities.first(where: { $0.basSnapshot.id == checkpointID }) else {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: ordered,
                currentState: BASEvolutionCheckpointPlanner.currentState(from: ordered),
                wroteCheckpoint: false
            )
        }

        let updatedFields = transform(target.basSnapshot)
        guard updatedFields != target.basSnapshot else {
            return BASAppleEvolutionCheckpointWriteResult(
                orderedCheckpoints: ordered,
                currentState: BASEvolutionCheckpointPlanner.currentState(from: ordered),
                wroteCheckpoint: false
            )
        }

        // audit H17: uniquing-guard — was Dictionary(uniqueKeysWithValues:), traps on duplicate key
        var checkpointsByID = Dictionary(existing.map { ($0.basSnapshot.id, $0) }, uniquingKeysWith: { _, last in last })
        context.delete(target)

        let replacement = Checkpoint.basMake(from: updatedFields)
        context.insert(replacement)
        checkpointsByID[updatedFields.id] = replacement

        let updatedOrder = canonicalEntityOrder(Array(checkpointsByID.values)).map(\.basSnapshot)
        return BASAppleEvolutionCheckpointWriteResult(
            orderedCheckpoints: updatedOrder,
            currentState: BASEvolutionCheckpointPlanner.currentState(from: updatedOrder),
            wroteCheckpoint: false
        )
    }

    private static func forgetRequestTargetsCheckpoints(
        _ request: BASForgetRequest
    ) -> Bool {
        request.executedSteps.contains("checkpoint_exports_revoked")
            || request.cascadeScope.contains("checkpoints")
    }

    private static func matchesForgetRequest(
        _ request: BASForgetRequest,
        checkpoint: BASEvolutionCheckpointStoredFields
    ) -> Bool {
        let targetRefs = Set(
            request.targetRefs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        guard targetRefs.isEmpty == false else {
            return false
        }

        return targetRefs.isDisjoint(with: checkpointReferences(for: checkpoint)) == false
    }

    private static func checkpointReferences(
        for checkpoint: BASEvolutionCheckpointStoredFields
    ) -> Set<String> {
        var refs = Set<String>()
        refs.insert(checkpoint.id)
        refs.insert(checkpoint.sourceID)
        refs.insert(checkpoint.fingerprint)
        if let previousCheckpointID = checkpoint.previousCheckpointID,
           previousCheckpointID.isEmpty == false {
            refs.insert(previousCheckpointID)
        }
        if let lineageSummary = checkpoint.lineageSummary {
            refs.formUnion(lineageReferences(for: lineageSummary))
        }
        return refs
    }

    private static func lineageReferences(
        for lineageSummary: BASEvolutionLineageSummary
    ) -> Set<String> {
        var refs = Set<String>()
        refs.insert(lineageSummary.sessionID)
        refs.insert(lineageSummary.thoughtFoldChecksum)
        refs.formUnion(lineageSummary.updateTicketSummaries.filter { !$0.isEmpty })
        if let governanceSummary = lineageSummary.governanceSummary {
            if let dreamLoopStoppingMode = governanceSummary.dreamLoopStoppingMode,
               dreamLoopStoppingMode.isEmpty == false {
                refs.insert("dream_loop_stop:\(dreamLoopStoppingMode)")
            }
            if let dreamLoopReservationMode = governanceSummary.dreamLoopReservationMode,
               dreamLoopReservationMode.isEmpty == false {
                refs.insert("dream_loop_reservation:\(dreamLoopReservationMode)")
            }
            refs.formUnion(governanceSummary.dreamLoopSignalRefs.filter { !$0.isEmpty })
            refs.formUnion(governanceSummary.dreamLoopRemandTargets.filter { !$0.isEmpty })
        }
        if let foldedLungSummary = lineageSummary.foldedLungSummary {
            refs.formUnion(foldedLungReferences(for: foldedLungSummary))
        }
        return refs
    }

    private static func foldedLungReferences(
        for foldedLungSummary: BASEvolutionFoldedLungSummary
    ) -> Set<String> {
        var refs: Set<String> = [
            foldedLungSummary.resumeID,
            foldedLungSummary.sourceFoldID,
            foldedLungSummary.rollbackAnchorID,
            foldedLungSummary.safeSnapshotRef,
            foldedLungSummary.integrityHash
        ]
        if let morphGraphID = foldedLungSummary.morphGraphID,
           morphGraphID.isEmpty == false {
            refs.insert(morphGraphID)
        }
        if let hotColdMapID = foldedLungSummary.hotColdMapID,
           hotColdMapID.isEmpty == false {
            refs.insert(hotColdMapID)
        }
        if let precisionProfileID = foldedLungSummary.precisionProfileID,
           precisionProfileID.isEmpty == false {
            refs.insert(precisionProfileID)
        }
        if let lungStateRef = foldedLungSummary.lungStateRef,
           lungStateRef.isEmpty == false {
            refs.insert(lungStateRef)
        }
        if let breathSchedulerID = foldedLungSummary.breathSchedulerID,
           breathSchedulerID.isEmpty == false {
            refs.insert(breathSchedulerID)
        }
        if let thermalExchangeID = foldedLungSummary.thermalExchangeID,
           thermalExchangeID.isEmpty == false {
            refs.insert(thermalExchangeID)
        }
        if let integrityWeaveID = foldedLungSummary.integrityWeaveID,
           integrityWeaveID.isEmpty == false {
            refs.insert(integrityWeaveID)
        }
        if let integrityTrustedSnapshotRef = foldedLungSummary.integrityTrustedSnapshotRef,
           integrityTrustedSnapshotRef.isEmpty == false {
            refs.insert(integrityTrustedSnapshotRef)
        }
        if let integrityVerificationHash = foldedLungSummary.integrityVerificationHash,
           integrityVerificationHash.isEmpty == false {
            refs.insert(integrityVerificationHash)
        }
        if let hostVersionRef = foldedLungSummary.hostVersionRef,
           hostVersionRef.isEmpty == false {
            refs.insert(hostVersionRef)
        }
        if let cacheStateRef = foldedLungSummary.cacheStateRef,
           cacheStateRef.isEmpty == false {
            refs.insert(cacheStateRef)
        }
        refs.formUnion(dynamicFoldedLungReferences(for: foldedLungSummary))
        refs.formUnion(foldedLungSummary.foldRefs.filter { !$0.isEmpty })
        refs.formUnion(foldedLungSummary.invalidatedResumeFrameIDs.filter { !$0.isEmpty })
        refs.formUnion(foldedLungSummary.invalidatedCacheRefs.filter { !$0.isEmpty })
        refs.formUnion(foldedLungSummary.invalidatedFoldRefs.filter { !$0.isEmpty })
        refs.formUnion(foldedLungSummary.quarantinedFoldRefs.filter { !$0.isEmpty })
        return refs
    }

    private static func dynamicFoldedLungReferences(
        for foldedLungSummary: BASEvolutionFoldedLungSummary
    ) -> Set<String> {
        guard let encodedSummary = try? JSONEncoder().encode(foldedLungSummary),
              let payload = try? JSONSerialization.jsonObject(with: encodedSummary) as? [String: Any] else {
            return []
        }

        var refs = Set<String>()
        insertStringReference(named: "organDeltaPlanID", from: payload, into: &refs)
        insertStringArrayReferences(named: "organDeltaActivatePackageIDs", from: payload, into: &refs)
        insertStringArrayReferences(named: "organDeltaPreloadPackageIDs", from: payload, into: &refs)
        insertStringArrayReferences(named: "organDeltaEvictPackageIDs", from: payload, into: &refs)
        insertStringArrayReferences(named: "organDeltaRetainPackageIDs", from: payload, into: &refs)
        insertStringArrayReferences(named: "organDeltaRollbackSafePackageIDs", from: payload, into: &refs)

        if let packageRecords = payload["organPackageRecords"] as? [[String: Any]] {
            for record in packageRecords {
                if let packageID = record["packageID"] as? String,
                   packageID.isEmpty == false {
                    refs.insert(packageID)
                }
            }
        }

        return refs
    }

    private static func insertStringReference(
        named key: String,
        from payload: [String: Any],
        into refs: inout Set<String>
    ) {
        if let value = payload[key] as? String,
           value.isEmpty == false {
            refs.insert(value)
        }
    }

    private static func insertStringArrayReferences(
        named key: String,
        from payload: [String: Any],
        into refs: inout Set<String>
    ) {
        if let values = payload[key] as? [String] {
            refs.formUnion(values.filter { !$0.isEmpty })
        }
    }

    private static func relinkedSnapshots(
        from snapshots: [BASEvolutionCheckpointStoredFields]
    ) -> [BASEvolutionCheckpointStoredFields] {
        let orderedOldestFirst = snapshots.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }
            return lhs.createdAt < rhs.createdAt
        }

        var previousCheckpointID: String?
        return orderedOldestFirst.map { checkpoint in
            defer { previousCheckpointID = checkpoint.id }
            return BASEvolutionCheckpointStoredFields(
                id: checkpoint.id,
                createdAt: checkpoint.createdAt,
                fingerprint: checkpoint.fingerprint,
                previousCheckpointID: previousCheckpointID,
                modeName: checkpoint.modeName,
                sourceID: checkpoint.sourceID,
                identityRole: checkpoint.identityRole,
                boundaryMode: checkpoint.boundaryMode,
                calibrationStatus: checkpoint.calibrationStatus,
                diffSummary: checkpoint.diffSummary,
                approvalState: checkpoint.approvalState,
                rollbackReady: checkpoint.rollbackReady,
                brainStateSnapshot: checkpoint.brainStateSnapshot,
                lineageSummary: checkpoint.lineageSummary
            )
        }
    }
}
