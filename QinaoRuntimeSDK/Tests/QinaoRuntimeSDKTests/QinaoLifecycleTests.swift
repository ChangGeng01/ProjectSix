import XCTest
import BASRuntimeCore
import BASLeaseLife
@testable import QinaoRuntime

/// M66 — `QinaoLifecycle` closes the wiring gap between the L1
/// Lease & Life primitives and the real device. These tests exercise
/// the lifecycle's contract through the injectable `makeForTesting`
/// factory so every platform signal (thermal reading, OS submit /
/// cancel) is observable without touching the real `BGTaskScheduler`
/// or a hot device.
///
/// Coverage:
///   - Factory shape (`makeSystem` produces a non-nil lifecycle;
///     `makeForTesting` wires the injected closures).
///   - `resample()` picks up the latest thermal reading from the
///     injected reader.
///   - `recordTurn()` updates lung pressure and re-samples thermal.
///   - `currentReading()` / `currentGuardLevel()` return the latest
///     fused reading; fall back to a fresh sample when nothing has
///     been recorded yet.
///   - `scheduleBreath()` routes through the platform bridge — the
///     namespaced identifier reaches the submitter.
///   - Thermal escalation to `.critical` cancels non-light breaths;
///     the canceller observes every cancellation.
///   - `scheduleBreath()` under `.emergency` guard rejects with the
///     documented `thermalEmergencyRejectsAll` error before the
///     submitter is ever called.
final class QinaoLifecycleTests: XCTestCase {

    // MARK: - Recorders

    /// Thread-safe submitter recorder. Tests can flip `submitResult`
    /// to simulate OS rejection.
    actor Submitter {
        var calls: [(identifier: String, date: Date)] = []
        var result: Bool = true

        func record(identifier: String, date: Date) -> Bool {
            calls.append((identifier: identifier, date: date))
            return result
        }
        func setResult(_ v: Bool) { result = v }
        func calledIdentifiers() -> [String] { calls.map { $0.identifier } }
    }

    /// Thread-safe canceller recorder.
    actor Canceller {
        var calls: [String] = []
        func record(_ identifier: String) { calls.append(identifier) }
    }

    /// Thread-safe thermal source. Tests swap `state` to drive
    /// trajectories. Uses a plain lock (rather than an actor) so that
    /// the sync-shape `BASThermalTwin.Reader` closure can read the
    /// current state without bridging async → sync. That bridging
    /// would be unsound under Swift 6 strict concurrency and would
    /// risk deadlock when the reader is called from an actor-isolated
    /// context.
    final class ThermalSource: @unchecked Sendable {
        private let lock = NSLock()
        private var _state: BASThermalTwin.OSThermalState = .nominal
        func get() -> BASThermalTwin.OSThermalState {
            lock.lock(); defer { lock.unlock() }
            return _state
        }
        func set(_ v: BASThermalTwin.OSThermalState) {
            lock.lock(); defer { lock.unlock() }
            _state = v
        }
    }

    // MARK: - Helpers

    private func makeLifecycle(
        prefix: String = "qinao.breath",
        timeConstantSeconds: Double = 180,
        thermal: ThermalSource,
        submitter: Submitter,
        canceller: Canceller,
        clock: @escaping @Sendable () -> Date =
            { Date(timeIntervalSince1970: 1_700_000_000) }
    ) -> QinaoLifecycle {
        QinaoLifecycle.makeForTesting(
            taskIdentifierPrefix: prefix,
            timeConstantSeconds: timeConstantSeconds,
            thermalReader: { thermal.get() },
            submitter: { id, date in
                await submitter.record(identifier: id, date: date)
            },
            canceller: { id in
                await canceller.record(id)
            },
            clock: clock)
    }

    private func request(
        id: String = "breath-1",
        at seconds: Double = 1_700_000_060,
        `class`: BASMaintenanceClass = .light
    ) -> BASBreathScheduler.Request {
        BASBreathScheduler.Request(
            id: id,
            maintenanceClass: `class`,
            earliestFireAt: Date(timeIntervalSince1970: seconds),
            reasonCodes: ["test"])
    }

    // MARK: - Factory shape

    func testMakeSystemProducesLifecycleWithExpectedPrefix() async {
        let lifecycle = QinaoLifecycle.makeSystem(
            taskIdentifierPrefix: "unit.breath")
        XCTAssertEqual(lifecycle.taskIdentifierPrefix, "unit.breath")
        XCTAssertEqual(lifecycle.bridge.taskIdentifierPrefix,
                       "unit.breath")
    }

    func testMakeForTestingWiresInjectedPrefix() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        let lifecycle = makeLifecycle(
            prefix: "t.breath",
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)
        XCTAssertEqual(lifecycle.taskIdentifierPrefix, "t.breath")
        XCTAssertEqual(lifecycle.bridge.taskIdentifierPrefix, "t.breath")
    }

    // MARK: - resample() pulls the latest thermal reading

    func testResamplePicksUpLatestThermalState() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        thermal.set(.fair)
        let r1 = await lifecycle.resample()
        XCTAssertEqual(r1.thermal.osState, .fair)
        XCTAssertEqual(r1.thermal.thermalLevel, .warm)

        thermal.set(.critical)
        let r2 = await lifecycle.resample()
        XCTAssertEqual(r2.thermal.osState, .critical)
        XCTAssertEqual(r2.thermal.thermalLevel, .critical)
        XCTAssertEqual(r2.thermal.guardLevel, .emergency)
    }

    // MARK: - recordTurn() accumulates pressure

    func testRecordTurnIncrementsLungPressure() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        let recorded = await lifecycle.recordTurn(
            runMode: .deepLoop, durationSeconds: 2.0)
        XCTAssertGreaterThan(recorded.lung.pressure, 0.0,
            "deepLoop for 2s should raise pressure above baseline")
        XCTAssertEqual(recorded.lung.turnCount, 1)
    }

    // MARK: - currentReading / currentGuardLevel

    func testCurrentReadingForcesSampleWhenNothingYet() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        thermal.set(.serious)
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        let reading = await lifecycle.currentReading()
        XCTAssertEqual(reading.osState, .serious)
        XCTAssertEqual(reading.thermalLevel, .hot)
        XCTAssertEqual(reading.guardLevel, .throttle)
    }

    func testCurrentGuardLevelReflectsLatestResample() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        thermal.set(.nominal)
        _ = await lifecycle.resample()
        let g1 = await lifecycle.currentGuardLevel()
        XCTAssertEqual(g1, .nominal)

        thermal.set(.critical)
        _ = await lifecycle.resample()
        let g2 = await lifecycle.currentGuardLevel()
        XCTAssertEqual(g2, .emergency)
    }

    // MARK: - scheduleBreath routes through the bridge

    func testScheduleBreathNamespacesIdentifierViaSubmitter() async throws {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        thermal.set(.nominal)
        let lifecycle = makeLifecycle(
            prefix: "myapp.breath",
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        _ = await lifecycle.resample()
        _ = try await lifecycle.scheduleBreath(
            request(id: "b-abc", class: .light))

        let identifiers = await submitter.calledIdentifiers()
        XCTAssertEqual(identifiers, ["myapp.breath.b-abc"])
    }

    // MARK: - Thermal escalation cancels non-light breaths

    func testEmergencyEscalationCancelsScheduledBreaths() async throws {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        thermal.set(.nominal)
        let lifecycle = makeLifecycle(
            prefix: "heat.breath",
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        _ = await lifecycle.resample()
        _ = try await lifecycle.scheduleBreath(
            request(id: "light-1", class: .light))
        _ = try await lifecycle.scheduleBreath(
            request(id: "deferred-1",
                    at: 1_700_000_120,
                    class: .deferred))

        // Escalate thermal — lifecycle.resample() folds it into the
        // scheduler via BASLeaseLifeCoordinator.
        thermal.set(.critical)
        _ = await lifecycle.resample()

        let cancelled = await canceller.calls
        // Under `.emergency` the scheduler cancels ALL — both
        // identifiers must have been handed to the canceller.
        XCTAssertEqual(
            Set(cancelled),
            Set(["heat.breath.light-1", "heat.breath.deferred-1"]))
    }

    // MARK: - scheduleBreath rejects under .emergency

    func testScheduleBreathUnderEmergencyRejectsBeforeSubmit() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        _ = await lifecycle.resample()

        do {
            _ = try await lifecycle.scheduleBreath(
                request(id: "denied", class: .light))
            XCTFail("expected emergency rejection")
        } catch let e as BASBreathScheduler.ScheduleError {
            XCTAssertEqual(e, .thermalEmergencyRejectsAll)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let calls = await submitter.calls.count
        XCTAssertEqual(calls, 0,
            "submitter must not be called when the scheduler rejects")
    }

    // MARK: - Actor accessors

    func testActorAccessorsReturnSameInstances() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        let twinA = await lifecycle.thermalActor()
        let twinB = await lifecycle.thermalActor()
        XCTAssertTrue(twinA === twinB)

        let schedA = await lifecycle.schedulerActor()
        let schedB = await lifecycle.schedulerActor()
        XCTAssertTrue(schedA === schedB)

        let lungA = await lifecycle.lungActor()
        let lungB = await lifecycle.lungActor()
        XCTAssertTrue(lungA === lungB)
    }

    // MARK: - M69 applyLiveThermalGuardLevel(to:)

    private func plannedBudget(
        thermalGuardLevel: BASThermalGuardLevel = .nominal,
        maintenanceClass: BASMaintenanceClass = .light
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .engage,
            maxLoops: 3,
            maxCandidates: 5,
            maxDecodeTokens: 128,
            retrievalDepth: 4,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: thermalGuardLevel,
            maintenanceAllowed: true,
            leaseID: "lease-m69",
            leaseExpiresAt: Date(timeIntervalSince1970: 1_700_000_500),
            maintenanceClass: maintenanceClass,
            wakeIntentID: "wake-m69",
            allowedHeads: ["scout.default", "core.default"],
            policyBundleVersion: "policy-v1.3",
            policyDecisionIDs: ["p-1", "p-2"])
    }

    func testApplyLiveThermalRoutesCriticalIntoEmergency() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        let planned = plannedBudget(thermalGuardLevel: .nominal)
        let routed = await lifecycle.applyLiveThermalGuardLevel(
            to: planned)

        // Thermal twin under `.critical` → guardLevel `.emergency`.
        XCTAssertEqual(routed.thermalGuardLevel, .emergency)
        // Every other field byte-stable: JSON encoding over an
        // identity override (planned already has .nominal) would not
        // be equal here, but we can at least spot-check the 16 other
        // fields explicitly.
        XCTAssertEqual(routed.schemaVersion, planned.schemaVersion)
        XCTAssertEqual(routed.runMode, planned.runMode)
        XCTAssertEqual(routed.maxLoops, planned.maxLoops)
        XCTAssertEqual(routed.maxCandidates, planned.maxCandidates)
        XCTAssertEqual(routed.maxDecodeTokens, planned.maxDecodeTokens)
        XCTAssertEqual(routed.retrievalDepth, planned.retrievalDepth)
        XCTAssertEqual(routed.precisionProfile,
                       planned.precisionProfile)
        XCTAssertEqual(routed.deviceRoute, planned.deviceRoute)
        XCTAssertEqual(routed.maintenanceAllowed,
                       planned.maintenanceAllowed)
        XCTAssertEqual(routed.leaseID, planned.leaseID)
        XCTAssertEqual(routed.leaseExpiresAt, planned.leaseExpiresAt)
        XCTAssertEqual(routed.maintenanceClass,
                       planned.maintenanceClass)
        XCTAssertEqual(routed.wakeIntentID, planned.wakeIntentID)
        XCTAssertEqual(routed.allowedHeads, planned.allowedHeads)
        XCTAssertEqual(routed.policyBundleVersion,
                       planned.policyBundleVersion)
        XCTAssertEqual(routed.policyDecisionIDs,
                       planned.policyDecisionIDs)
    }

    func testApplyLiveThermalForcesSampleWhenCold() async {
        // No prior `recordTurn` / `resample` — the lifecycle has
        // never observed a turn. The routing must still read live.
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        thermal.set(.serious)
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        let planned = plannedBudget(thermalGuardLevel: .nominal)
        let routed = await lifecycle.applyLiveThermalGuardLevel(
            to: planned)

        // `.serious` → thermal level `.hot` → guard `.throttle`
        // at zero pressure.
        XCTAssertEqual(routed.thermalGuardLevel, .throttle)
    }

    func testApplyLiveThermalLeavesNominalWhenDeviceIsNominal() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        thermal.set(.nominal)
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        // Warm the cache with an explicit resample so we cover the
        // `currentReading() → cached` branch, not the cold fallback.
        _ = await lifecycle.resample()

        let planned = plannedBudget(thermalGuardLevel: .throttle)
        let routed = await lifecycle.applyLiveThermalGuardLevel(
            to: planned)

        // Live reading wins over the caller's planned value.
        XCTAssertEqual(routed.thermalGuardLevel, .nominal,
            "live reading must override the planned value")
    }

    func testApplyLiveThermalDoesNotMutateSource() async {
        let thermal = ThermalSource()
        let submitter = Submitter()
        let canceller = Canceller()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(
            thermal: thermal,
            submitter: submitter,
            canceller: canceller)

        let planned = plannedBudget(thermalGuardLevel: .nominal)
        _ = await lifecycle.applyLiveThermalGuardLevel(to: planned)

        // Source budget is a value type — the derived routed copy
        // must not retroactively change the caller's frame.
        XCTAssertEqual(planned.thermalGuardLevel, .nominal,
            "applyLiveThermal* must not mutate the source frame")
    }
}
