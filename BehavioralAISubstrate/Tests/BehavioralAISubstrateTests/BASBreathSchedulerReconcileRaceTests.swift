import XCTest
@testable import BASLeaseLife

/// audit F10 (2026-07-12) — a schedule() parked at `bridge.register` when a thermal-emergency
/// reconcile runs must fail CLOSED on wake, not land a live OS registration the reconcile's
/// cancelAll couldn't see.
final class BASBreathSchedulerReconcileRaceTests: XCTestCase {

    /// A bridge whose FIRST `register` parks on a gate so the test can run a concurrent
    /// reconcile while a schedule() is suspended mid-register.
    private actor GateBridge: BASBreathScheduler.PlatformBridge {
        private(set) var registered: [String] = []
        private(set) var cancelled: [String] = []
        private var gate: CheckedContinuation<Void, Never>?

        func register(_ request: BASBreathScheduler.Request) async -> Bool {
            if registered.isEmpty {
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in gate = c }
            }
            registered.append(request.id); return true
        }
        func cancel(id: String) async { cancelled.append(id) }
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

    func testScheduleParkedAtRegisterFailsClosedOnEmergencyReconcile() async throws {
        let bridge = GateBridge()
        let scheduler = BASBreathScheduler(bridge: bridge)

        // Start a schedule; it parks inside bridge.register (the reentrancy window).
        let request = req("A")
        let scheduling = Task { () -> Bool in
            do {
                _ = try await scheduler.schedule(request, guardLevel: .nominal)
                return false  // did NOT fail closed (bug)
            } catch {
                return true   // failed closed (expected)
            }
        }
        while await !bridge.gateIsWaiting() { await Task.yield() }

        // Emergency reconcile runs while the schedule is suspended (it can't see the in-flight
        // request). This sets currentGuardLevel = .emergency.
        await scheduler.reconcile(with: .emergency)

        // Wake the parked register → schedule() re-validates against the now-emergency level,
        // cancels its own registration, and throws.
        await bridge.openGate()
        let failedClosed = await scheduling.value
        XCTAssertTrue(failedClosed, "the parked schedule must throw after an emergency reconcile")

        let remaining = await scheduler.count()
        XCTAssertEqual(remaining, 0,
            "the parked schedule must NOT land a live breath after an emergency reconcile")
        let cancelled = await bridge.cancelledSet
        XCTAssertTrue(cancelled.contains("A"),
            "the schedule must cancel its own now-illegal OS registration")
    }
}
