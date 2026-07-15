import Foundation

public enum BASAppleTaskGraphLifecycleExecutor {
    public static func refresh<Snapshot>(
        snapshotsInPriorityOrder: [() -> Snapshot?],
        saveSnapshot: (Snapshot) -> Void,
        clearSnapshot: () -> Void
    ) -> Snapshot? {
        let snapshot = snapshotsInPriorityOrder.lazy.compactMap { $0() }.first

        if let snapshot {
            saveSnapshot(snapshot)
        } else {
            clearSnapshot()
        }

        return snapshot
    }
}
