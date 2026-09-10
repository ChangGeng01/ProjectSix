import XCTest
@testable import BASRuntimeCore
@testable import BASLeaseLife

/// Integration tests for the three-piece L1 glue. Each test below
/// demonstrates a scenario that can't be proved by the primitives
/// in isolation — only the coordinator can exhibit them.
final class BASLeaseLifeCoordinatorTests: XCTestCase {

    // MARK: - Happy path

    func testTurnUpdatesLungAndThermal() async {
        let coord = BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: 180,
                clock: { Date(timeIntervalSince1970: 0) }),
            thermal: BASThermalTwin(
                reader: { .fair },
                clock: { Date(timeIntervalSince1970: 0) }),
            scheduler: BASBreathScheduler())

        let result = await coord.recordTurn(
            runMode: .engage, durationSeconds: 1)
        XCTAssertEqual(result.lung.turnCount, 1)
        XCTAssertEqual(result.thermal.thermalLevel, .warm)
        // accumulated pressure low → guard = .watch (warm × <0.3).
        XCTAssertEqual(result.thermal.guardLevel, .watch)
        XCTAssertTrue(result.cancelledBreathIDs.isEmpty)
    }

    // MARK: - Thermal emergency cancels breaths

    func testCriticalThermalCancelsScheduledBreaths() async throws {
        let clock = MutableTestClock(initialEpoch: 0)
        let osState = MutableOSState(initial: .nominal)
        let coord = BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: 180, clock: { clock.now() }),
            thermal: BASThermalTwin(
                reader: { osState.get() }, clock: { clock.now() }),
            scheduler: BASBreathScheduler(clock: { clock.now() }))

        // Schedule breaths while cool.
        _ = try await coord.scheduleBreath(
            BASBreathScheduler.Request(
                id: "standard-1",
                maintenanceClass: .standard,
                earliestFireAt: Date(timeIntervalSince1970: 600)))
        _ = try await coord.scheduleBreath(
            BASBreathScheduler.Request(
                id: "light-1",
                maintenanceClass: .light,
                earliestFireAt: Date(timeIntervalSince1970: 120)))

        // Device goes critical; record a turn to resample.
        osState.set(.critical)
        let result = await coord.recordTurn(
            runMode: .deepLoop, durationSeconds: 1)
        XCTAssertEqual(result.thermal.guardLevel, .emergency)
        XCTAssertEqual(
            result.cancelledBreathIDs.sorted(),
            ["light-1", "standard-1"],
            "emergency cancels every scheduled breath")
    }

    // MARK: - Throttle drops standard but keeps light

    func testThrottleDropsStandardKeepsLight() async throws {
        let osState = MutableOSState(initial: .nominal)
        let coord = BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: 180,
                clock: { Date(timeIntervalSince1970: 0) }),
            thermal: BASThermalTwin(reader: { osState.get() }),
            scheduler: BASBreathScheduler())

        _ = try await coord.scheduleBreath(
            BASBreathScheduler.Request(
                id: "l", maintenanceClass: .light,
                earliestFireAt: Date(timeIntervalSince1970: 100)))
        _ = try await coord.scheduleBreath(
            BASBreathScheduler.Request(
                id: "s", maintenanceClass: .standard,
                earliestFireAt: Date(timeIntervalSince1970: 200)))

        // Device escalates to hot; pressure still low → guard =
        // .throttle. Standard must drop; light survives.
        osState.set(.serious)
        let result = await coord.recordTurn(
            runMode: .engage, durationSeconds: 1)
        XCTAssertEqual(result.thermal.guardLevel, .throttle)
        XCTAssertEqual(result.cancelledBreathIDs, ["s"])
    }

    // MARK: - Accumulated pressure alone pushes guard up

    func testPressureAloneCanTriggerGuardEscalation() async {
        // Device stays nominal but we grind deepLoop for a long time.
        // Load .deepLoop = 0.15/s; 5 seconds → 0.75 pressure → guard
        // should become .watch even though OS thermal is still cool.
        let coord = BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: 180,
                clock: { Date(timeIntervalSince1970: 0) }),
            thermal: BASThermalTwin(
                reader: { .nominal },
                clock: { Date(timeIntervalSince1970: 0) }),
            scheduler: BASBreathScheduler())
        let result = await coord.recordTurn(
            runMode: .deepLoop, durationSeconds: 5)
        XCTAssertGreaterThan(result.lung.pressure, 0.7)
        XCTAssertEqual(result.thermal.guardLevel, .watch,
            "pressure ≥0.7 on nominal should bump guard to .watch")
    }
}

/// Thread-safe mutable OS-state wrapper for tests that transition
/// between thermal states.
final class MutableOSState: @unchecked Sendable {
    private let lock = NSLock()
    private var value: BASThermalTwin.OSThermalState
    init(initial: BASThermalTwin.OSThermalState) { self.value = initial }
    func set(_ newValue: BASThermalTwin.OSThermalState) {
        lock.lock(); value = newValue; lock.unlock()
    }
    func get() -> BASThermalTwin.OSThermalState {
        lock.lock(); defer { lock.unlock() }; return value
    }
}
