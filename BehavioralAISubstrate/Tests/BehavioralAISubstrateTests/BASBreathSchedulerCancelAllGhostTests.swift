import XCTest
@testable import BASLeaseLife

/// audit M-p / x-concurrency MED-7 — `cancelAll` snapshotted `scheduled.keys`, then awaited a cancel
/// per id, then `removeAll()`. Because the scheduler is an actor, a concurrent `schedule()`
/// completing during the await added a breath (+ a LIVE platform registration) AFTER the snapshot;
/// the trailing `removeAll()` wiped it from the dict WITHOUT cancelling its registration → a GHOST
/// maintenance wakeup survived a thermal-emergency cancelAll.
final class BASBreathSchedulerCancelAllGhostTests: XCTestCase {

    /// A bridge whose FIRST `cancel` parks on a gate, so the test can deterministically run a
    /// concurrent `schedule` while `cancelAll` is suspended mid-loop.
    private actor GateBridge: BASBreathScheduler.PlatformBridge {
        private(set) var registered: [String] = []
        private(set) var cancelled: [String] = []
        private var gate: CheckedContinuation<Void, Never>?

        func register(_ request: BASBreathScheduler.Request) async -> Bool {
            registered.append(request.id); return true
        }
        func cancel(id: String) async {
            if cancelled.isEmpty {
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in gate = c }
            }
            cancelled.append(id)
        }
        func gateIsWaiting() -> Bool { gate != nil }
        func openGate() { gate?.resume(); gate = nil }
        var registeredSet: Set<String> { Set(registered) }
        var cancelledSet: Set<String> { Set(cancelled) }
    }

    private func req(_ id: String) -> BASBreathScheduler.Request {
        BASBreathScheduler.Request(
            id: id, maintenanceClass: .light,
            earliestFireAt: Date(timeIntervalSince1970: 1_000))
    }

    func testCancelAllCancelsConcurrentlyScheduledBreath() async throws {
        let bridge = GateBridge()
        let scheduler = BASBreathScheduler(bridge: bridge)
        _ = try await scheduler.schedule(req("A"), guardLevel: .nominal)
        _ = try await scheduler.schedule(req("B"), guardLevel: .nominal)

        // Start cancelAll; it parks on the gate inside its first cancel.
        async let cancelling: Void = scheduler.cancelAll()
        while await !bridge.gateIsWaiting() { await Task.yield() }

        // cancelAll is suspended → this schedule adds C to the POST-snapshot state.
        _ = try await scheduler.schedule(req("C"), guardLevel: .nominal)

        await bridge.openGate()
        await cancelling

        let registered = await bridge.registeredSet
        let cancelled = await bridge.cancelledSet
        XCTAssertEqual(registered, ["A", "B", "C"], "all three were registered")
        XCTAssertEqual(cancelled, registered,
            "cancelAll must cancel EVERY registration, including one added during its await (no ghost)")
        let remaining = await scheduler.count()
        XCTAssertEqual(remaining, 0, "scheduled must be empty after cancelAll")
    }
}
