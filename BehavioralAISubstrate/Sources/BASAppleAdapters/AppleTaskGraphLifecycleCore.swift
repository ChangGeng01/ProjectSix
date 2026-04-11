import Foundation

public enum BASAppleTaskGraphLifecycleExecutor {
    public static func refresh<Snapshot>(
        quickSnapshot: () -> Snapshot?,
        balanceSnapshot: () -> Snapshot?,
        mirrorSnapshot: () -> Snapshot?,
        saveSnapshot: (Snapshot) -> Void,
        clearSnapshot: () -> Void
    ) -> Snapshot? {
        let snapshot = quickSnapshot() ?? balanceSnapshot() ?? mirrorSnapshot()

        if let snapshot {
            saveSnapshot(snapshot)
        } else {
            clearSnapshot()
        }

        return snapshot
    }
}
