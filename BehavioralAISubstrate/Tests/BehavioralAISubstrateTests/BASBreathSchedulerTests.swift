import XCTest
@testable import BASRuntimeCore
@testable import BASLeaseLife

final class BASBreathSchedulerTests: XCTestCase {

    // MARK: - Fixtures

    private func request(
        id: String,
        class c: BASMaintenanceClass,
        atSeconds: TimeInterval = 60
    ) -> BASBreathScheduler.Request {
        BASBreathScheduler.Request(
            id: id,
            maintenanceClass: c,
            earliestFireAt: Date(
                timeIntervalSince1970: atSeconds))
    }

    // MARK: - Validation

    func testEmergencyRejectsAllClasses() {
        for c in BASMaintenanceClass.allCases {
            XCTAssertThrowsError(
                try BASBreathScheduler.validate(
                    class: c, at: .emergency))
        }
    }

    func testThrottleAllowsOnlyLight() {
        XCTAssertNoThrow(
            try BASBreathScheduler.validate(
                class: .light, at: .throttle))
        XCTAssertThrowsError(
            try BASBreathScheduler.validate(
                class: .standard, at: .throttle))
        XCTAssertThrowsError(
            try BASBreathScheduler.validate(
                class: .deferred, at: .throttle))
    }

    func testWatchAndNominalAllowAll() {
        for c in BASMaintenanceClass.allCases {
            XCTAssertNoThrow(
                try BASBreathScheduler.validate(
                    class: c, at: .watch))
            XCTAssertNoThrow(
                try BASBreathScheduler.validate(
                    class: c, at: .nominal))
        }
    }

    // MARK: - Scheduling

    func testScheduleAndCancel() async throws {
        let scheduler = BASBreathScheduler()
        let req = request(id: "breath-1", class: .standard)
        let breath = try await scheduler.schedule(
            req, guardLevel: .nominal)
        XCTAssertEqual(breath.request.id, "breath-1")
        let c1 = await scheduler.count()
        XCTAssertEqual(c1, 1)

        try await scheduler.cancel(id: "breath-1")
        let c2 = await scheduler.count()
        XCTAssertEqual(c2, 0)
    }

    func testDuplicateScheduleRejected() async throws {
        let scheduler = BASBreathScheduler()
        _ = try await scheduler.schedule(
            request(id: "dup", class: .light), guardLevel: .nominal)
        do {
            _ = try await scheduler.schedule(
                request(id: "dup", class: .light),
                guardLevel: .nominal)
            XCTFail("expected duplicateRequest")
        } catch BASBreathScheduler.ScheduleError
            .duplicateRequest(let id)
        {
            XCTAssertEqual(id, "dup")
        }
    }

    func testScheduleUnderThrottleRejectsStandard() async throws {
        let scheduler = BASBreathScheduler()
        do {
            _ = try await scheduler.schedule(
                request(id: "std", class: .standard),
                guardLevel: .throttle)
            XCTFail("expected classRejectedAtGuard")
        } catch BASBreathScheduler.ScheduleError
            .classRejectedAtGuard(let guardLevel, let klass)
        {
            XCTAssertEqual(guardLevel, .throttle)
            XCTAssertEqual(klass, .standard)
        }
    }

    // MARK: - Thermal reconciliation

    func testEmergencyCancelsAllExistingBreaths() async throws {
        let scheduler = BASBreathScheduler()
        _ = try await scheduler.schedule(
            request(id: "a", class: .light), guardLevel: .nominal)
        _ = try await scheduler.schedule(
            request(id: "b", class: .standard), guardLevel: .nominal)
        _ = try await scheduler.schedule(
            request(id: "c", class: .deferred), guardLevel: .nominal)
        let c3 = await scheduler.count()
        XCTAssertEqual(c3, 3)

        await scheduler.reconcile(with: .emergency)
        let c4 = await scheduler.count()
        XCTAssertEqual(c4, 0)
    }

    func testThrottleDropsStandardAndDeferredKeepsLight() async throws {
        let scheduler = BASBreathScheduler()
        _ = try await scheduler.schedule(
            request(id: "light", class: .light), guardLevel: .nominal)
        _ = try await scheduler.schedule(
            request(id: "std", class: .standard), guardLevel: .nominal)
        _ = try await scheduler.schedule(
            request(id: "def", class: .deferred), guardLevel: .nominal)

        await scheduler.reconcile(with: .throttle)
        let remaining = await scheduler.scheduledBreaths()
        XCTAssertEqual(remaining.map(\.request.id), ["light"])
    }

    // MARK: - Bridge wiring

    func testPlatformBridgeReceivesRegisterAndCancel() async throws {
        let bridge = RecordingBridge()
        let scheduler = BASBreathScheduler(bridge: bridge)
        _ = try await scheduler.schedule(
            request(id: "x", class: .light), guardLevel: .nominal)
        try await scheduler.cancel(id: "x")
        let registrations = await bridge.registrations()
        let cancels = await bridge.cancels()
        XCTAssertEqual(registrations, ["x"])
        XCTAssertEqual(cancels, ["x"])
    }

    // MARK: - audit policy-obs-misc LOW-5: concurrent same-id schedule can't both land

    func testConcurrentSameIdScheduleRejectsExactlyOne() async throws {
        let bridge = GatedRegisterBridge()
        let scheduler = BASBreathScheduler(bridge: bridge)
        let req = request(id: "b1", class: .light)

        // Task A enters schedule() and parks inside bridge.register (the suspension point).
        async let aRes = scheduleCatching(scheduler, req)
        await bridge.waitUntilParked()
        // Task B runs while A is parked: it passes the pre-await duplicate check (A hasn't inserted).
        let bRes = await scheduleCatching(scheduler, req)
        await bridge.release()
        let aFinal = await aRes

        let outcomes = [aFinal, bRes]
        let successes = outcomes.filter { if case .success = $0 { return true }; return false }
        let dupes = outcomes.filter {
            if case .failure(let e) = $0,
               case BASBreathScheduler.ScheduleError.duplicateRequest = e { return true }
            return false
        }
        XCTAssertEqual(successes.count, 1, "exactly ONE concurrent same-id schedule may land")
        XCTAssertEqual(dupes.count, 1, "the other must be rejected as duplicate, not double-register")
        let cancels = await bridge.cancelledIDs()
        XCTAssertEqual(cancels, ["b1"], "the loser's own OS registration must be cancelled, not orphaned")
    }
}

/// Free function (not an instance method) so the concurrent `async let` does not capture the
/// non-Sendable XCTestCase `self`.
private func scheduleCatching(
    _ s: BASBreathScheduler, _ r: BASBreathScheduler.Request
) async -> Result<BASBreathScheduler.ScheduledBreath, Error> {
    do { return .success(try await s.schedule(r, guardLevel: .nominal)) }
    catch { return .failure(error) }
}

/// Parks the FIRST register call on a test-held gate so the reentrancy window is forced open.
private actor GatedRegisterBridge: BASBreathScheduler.PlatformBridge {
    private var firstParked = false
    private var gate: CheckedContinuation<Void, Never>?
    private var parkedWaiter: CheckedContinuation<Void, Never>?
    private var didPark = false
    private var cancelled: [String] = []

    func register(_ request: BASBreathScheduler.Request) async -> Bool {
        if !firstParked {
            firstParked = true
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                gate = c; didPark = true
                parkedWaiter?.resume(); parkedWaiter = nil
            }
        }
        return true
    }
    func cancel(id: String) async { cancelled.append(id) }
    func cancelledIDs() -> [String] { cancelled }
    func waitUntilParked() async {
        if didPark { return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in parkedWaiter = c }
    }
    func release() { gate?.resume(); gate = nil }
}

/// Test double. Isolated as an actor so the test can observe what
/// the scheduler forwarded without races.
private actor RecordingBridge: BASBreathScheduler.PlatformBridge {
    private var registered: [String] = []
    private var cancelled: [String] = []

    func register(_ request: BASBreathScheduler.Request) async -> Bool {
        registered.append(request.id)
        return true
    }

    func cancel(id: String) async {
        cancelled.append(id)
    }

    func registrations() -> [String] { registered }
    func cancels() -> [String] { cancelled }
}
