import Foundation
import SwiftData
import BASMemory

public protocol BASAppleCurrentBrainUpdateEntity: PersistentModel {
    static func basMake(from fields: BASCurrentBrainUpdateStoredFields) -> Self
    var basSnapshot: BASCurrentBrainUpdateStoredFields { get }
}

public struct BASAppleCurrentBrainUpdateWriteResult<
    Update: BASAppleCurrentBrainUpdateEntity
> {
    public let orderedUpdates: [BASCurrentBrainUpdateStoredFields]

    public init(orderedUpdates: [BASCurrentBrainUpdateStoredFields]) {
        self.orderedUpdates = orderedUpdates
    }
}

public enum BASAppleCurrentBrainUpdateWriter {
    /// Persists from a package-owned context selected by `context.container`.
    /// Pending changes in `context` are not included, saved, or rolled back.
    public static func persist<Update: BASAppleCurrentBrainUpdateEntity>(
        _ fields: BASCurrentBrainUpdateStoredFields,
        in context: ModelContext,
        maxEntries: Int = BASCurrentBrainPersistenceApplier.defaultUpdateLimit,
        retentionInterval: TimeInterval = BASCurrentBrainPersistenceApplier.defaultRetentionInterval
    ) throws -> BASAppleCurrentBrainUpdateWriteResult<Update> {
        try persist(
            fields,
            in: context,
            maxEntries: maxEntries,
            retentionInterval: retentionInterval,
            using: BASAppleLivePersistenceIO()
        )
    }

    static func persist<
        Update: BASAppleCurrentBrainUpdateEntity,
        IO: BASApplePersistenceIO
    >(
        _ fields: BASCurrentBrainUpdateStoredFields,
        in context: ModelContext,
        maxEntries: Int = BASCurrentBrainPersistenceApplier.defaultUpdateLimit,
        retentionInterval: TimeInterval = BASCurrentBrainPersistenceApplier.defaultRetentionInterval,
        using io: IO
    ) throws -> BASAppleCurrentBrainUpdateWriteResult<Update> {
        try BASApplePersistenceTransaction.perform(
            selectedBy: context,
            using: io
        ) { owned in
            try stage(
                fields,
                in: owned,
                maxEntries: maxEntries,
                retentionInterval: retentionInterval,
                using: io
            )
        }
    }

    static func stage<
        Update: BASAppleCurrentBrainUpdateEntity,
        IO: BASApplePersistenceIO
    >(
        _ fields: BASCurrentBrainUpdateStoredFields,
        in context: ModelContext,
        maxEntries: Int,
        retentionInterval: TimeInterval,
        using io: IO
    ) throws -> BASAppleCurrentBrainUpdateWriteResult<Update> {
        let existing: [Update] = try io.fetch(Update.self, in: context)
        // audit H17: uniquing-guard — was Dictionary(uniqueKeysWithValues:), traps on duplicate key
        var updatesByID = Dictionary(existing.map { ($0.basSnapshot.id, $0) }, uniquingKeysWith: { _, last in last })

        if let current = updatesByID[fields.id] {
            context.delete(current)
        }

        let update = Update.basMake(from: fields)
        context.insert(update)
        updatesByID[fields.id] = update

        let retainedIDs = BASCurrentBrainPersistenceApplier.retainedUpdateIDs(
            in: Array(updatesByID.values).map(\.basSnapshot),
            now: fields.createdAt,
            maxEntries: maxEntries,
            retentionInterval: retentionInterval
        )

        for stale in Array(updatesByID.values) where !retainedIDs.contains(stale.basSnapshot.id) {
            context.delete(stale)
            updatesByID[stale.basSnapshot.id] = nil
        }

        return BASAppleCurrentBrainUpdateWriteResult(
            orderedUpdates: canonicalOrder(Array(updatesByID.values).map(\.basSnapshot))
        )
    }

    private static func canonicalOrder(
        _ updates: [BASCurrentBrainUpdateStoredFields]
    ) -> [BASCurrentBrainUpdateStoredFields] {
        BASCurrentBrainPersistenceApplier.canonicalUpdateOrder(for: updates)
    }
}
