import Testing
@testable import BASAppleAdapters

struct BASAppleTaskGraphLifecycleTests {
    @Test("task graph lifecycle prefers primary over comparative and reflective snapshots")
    func taskGraphLifecyclePrefersPrimarySnapshot() {
        var saved: [String] = []

        let snapshot = BASAppleTaskGraphLifecycleExecutor.refresh(
            snapshotsInPriorityOrder: [
                { "primary" },
                { "comparative" },
                { "reflective" }
            ],
            saveSnapshot: { saved.append($0) },
            clearSnapshot: { saved.append("clear") }
        )

        #expect(snapshot == "primary")
        #expect(saved == ["primary"])
    }

    @Test("task graph lifecycle clears persisted state when no snapshot is available")
    func taskGraphLifecycleClearsWhenNoSnapshotExists() {
        var calls: [String] = []

        let snapshot = BASAppleTaskGraphLifecycleExecutor.refresh(
            snapshotsInPriorityOrder: [
                { Optional<String>.none },
                { Optional<String>.none },
                { Optional<String>.none }
            ],
            saveSnapshot: { calls.append($0) },
            clearSnapshot: { calls.append("clear") }
        )

        #expect(snapshot == nil as String?)
        #expect(calls == ["clear"])
    }
}
