import Testing
@testable import BASAppleAdapters

struct BASAppleTaskGraphLifecycleTests {
    @Test("task graph lifecycle prefers quick over balance and mirror snapshots")
    func taskGraphLifecyclePrefersQuickSnapshot() {
        var saved: [String] = []

        let snapshot = BASAppleTaskGraphLifecycleExecutor.refresh(
            quickSnapshot: { "quick" },
            balanceSnapshot: { "balance" },
            mirrorSnapshot: { "mirror" },
            saveSnapshot: { saved.append($0) },
            clearSnapshot: { saved.append("clear") }
        )

        #expect(snapshot == "quick")
        #expect(saved == ["quick"])
    }

    @Test("task graph lifecycle clears persisted state when no snapshot is available")
    func taskGraphLifecycleClearsWhenNoSnapshotExists() {
        var calls: [String] = []

        let snapshot = BASAppleTaskGraphLifecycleExecutor.refresh(
            quickSnapshot: { Optional<String>.none },
            balanceSnapshot: { Optional<String>.none },
            mirrorSnapshot: { Optional<String>.none },
            saveSnapshot: { calls.append($0) },
            clearSnapshot: { calls.append("clear") }
        )

        #expect(snapshot == nil as String?)
        #expect(calls == ["clear"])
    }
}
