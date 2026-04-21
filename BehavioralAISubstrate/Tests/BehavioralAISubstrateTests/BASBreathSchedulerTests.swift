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
