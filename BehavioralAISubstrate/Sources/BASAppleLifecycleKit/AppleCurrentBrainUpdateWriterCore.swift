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
    public let orderedUpdates: [Update]

    public init(orderedUpdates: [Update]) {
        self.orderedUpdates = orderedUpdates
    }
}

public enum BASAppleCurrentBrainUpdateWriter {
    public static func persist<Update: BASAppleCurrentBrainUpdateEntity>(
        _ fields: BASCurrentBrainUpdateStoredFields,
        in context: ModelContext,
        maxEntries: Int = BASCurrentBrainPersistenceApplier.defaultUpdateLimit,
        retentionInterval: TimeInterval = BASCurrentBrainPersistenceApplier.defaultRetentionInterval,
        onSaveError: ((Error) -> Void)? = nil
    ) -> BASAppleCurrentBrainUpdateWriteResult<Update> {
        let existing = fetchUpdates(in: context) as [Update]
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

        do {
            try context.save()
        } catch {
            onSaveError?(error)
        }

        return BASAppleCurrentBrainUpdateWriteResult(
            orderedUpdates: canonicalOrder(Array(updatesByID.values))
        )
    }

    private static func fetchUpdates<Update: BASAppleCurrentBrainUpdateEntity>(
        in context: ModelContext
    ) -> [Update] {
        (try? context.fetch(FetchDescriptor<Update>())) ?? []
    }

    private static func canonicalOrder<Update: BASAppleCurrentBrainUpdateEntity>(
        _ updates: [Update]
    ) -> [Update] {
        let ordering = Dictionary(
            uniqueKeysWithValues: BASCurrentBrainPersistenceApplier
                .canonicalUpdateOrder(for: updates.map(\.basSnapshot))
                .enumerated()
                .map { ($0.element.id, $0.offset) }
        )
        return updates.sorted { lhs, rhs in
            let lhsIndex = ordering[lhs.basSnapshot.id] ?? Int.max
            let rhsIndex = ordering[rhs.basSnapshot.id] ?? Int.max
            if lhsIndex == rhsIndex {
                return lhs.basSnapshot.id.uuidString < rhs.basSnapshot.id.uuidString
            }
            return lhsIndex < rhsIndex
        }
    }
}
