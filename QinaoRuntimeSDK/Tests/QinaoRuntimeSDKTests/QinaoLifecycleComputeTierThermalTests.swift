import XCTest
import BASRuntimeCore
import BASLeaseLife
@testable import QinaoRuntime

/// M104 — `QinaoLifecycle.computeTierThermalSnapshot()` projection
/// contract tests.
///
/// M102 shipped the substrate-side `BASComputeTierThermalSnapshot`
/// + `BASComputeRouter`. M104 bridges the scalar `BASThermalTwin`
/// signal that lifecycle already reads into a three-tier snapshot,
/// so hosts can feed router decisions without waiting for the full
/// platform-adapter tier-specific pressure readers.
///
/// Covered contracts:
///
/// 1. level-to-headroom mapping is deterministic and clamped:
///    .nominal=1.0, .warm=0.7, .hot=0.3, .critical=0.0
/// 2. Snapshot contains exactly three readings (one per tier)
///    with the same level + headroom under today's scalar
///    projection
/// 3. observedAt / snapshotAt round-trip from the parameter
/// 4. Snapshot plumbed into a `BASComputeRouter` produces a
///    routing decision (NPU first at nominal since all tiers
///    tie; fallback when critical)
final class QinaoLifecycleComputeTierThermalTests: XCTestCase {

    // MARK: - Fixtures (parallel to QinaoLifecycleTests)

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

    actor NoopSubmitter {
        func record(identifier: String, date: Date) -> Bool {
            true
        }
    }

    actor NoopCanceller {
        func record(_ identifier: String) {}
    }

    private func makeLifecycle(
        thermal: ThermalSource
    ) -> QinaoLifecycle {
        let submitter = NoopSubmitter()
        let canceller = NoopCanceller()
        return QinaoLifecycle.makeForTesting(
            taskIdentifierPrefix: "m104.breath",
            timeConstantSeconds: 180,
            thermalReader: { thermal.get() },
            submitter: { id, date in
                await submitter.record(
                    identifier: id, date: date)
            },
            canceller: { id in await canceller.record(id) },
            clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    // MARK: - 1. Level → headroom mapping

    func testHeadroomMappingNominalIsOne() {
        XCTAssertEqual(
            QinaoLifecycle.headroom(for: .nominal), 1.0)
    }

    func testHeadroomMappingWarmIsPointSeven() {
        XCTAssertEqual(
            QinaoLifecycle.headroom(for: .warm), 0.7)
    }

    func testHeadroomMappingHotIsPointThree() {
        XCTAssertEqual(
            QinaoLifecycle.headroom(for: .hot), 0.3)
    }

    func testHeadroomMappingCriticalIsZero() {
        XCTAssertEqual(
            QinaoLifecycle.headroom(for: .critical), 0.0)
    }

    // MARK: - 2. Snapshot shape

    func testSnapshotHasOneReadingPerTier() async {
        let thermal = ThermalSource()
        thermal.set(.nominal)
        let lifecycle = makeLifecycle(thermal: thermal)

        let snap = await lifecycle.computeTierThermalSnapshot()
        let tiers = Set(snap.readings.map(\.tier))
        XCTAssertEqual(
            tiers,
            Set([.cpu, .gpu, .npu]),
            "all three tiers represented")
        XCTAssertEqual(snap.readings.count, 3)
    }

    func testSnapshotAllTiersShareLevelAndHeadroomUnderScalar()
        async {
        let thermal = ThermalSource()
        thermal.set(.fair)  // maps to BASThermalLevel.warm
        let lifecycle = makeLifecycle(thermal: thermal)

        let snap = await lifecycle.computeTierThermalSnapshot()
        let cpu = snap.reading(for: .cpu)
        let gpu = snap.reading(for: .gpu)
        let npu = snap.reading(for: .npu)
        XCTAssertEqual(cpu?.level, .warm)
        XCTAssertEqual(gpu?.level, .warm)
        XCTAssertEqual(npu?.level, .warm)
        XCTAssertEqual(cpu?.headroom ?? -1, 0.7, accuracy: 1e-9)
        XCTAssertEqual(gpu?.headroom ?? -1, 0.7, accuracy: 1e-9)
        XCTAssertEqual(npu?.headroom ?? -1, 0.7, accuracy: 1e-9)
    }

    // MARK: - 3. observedAt round-trips

    func testSnapshotObservedAtRoundTripsFromParameter() async {
        let thermal = ThermalSource()
        let lifecycle = makeLifecycle(thermal: thermal)
        let t = Date(timeIntervalSince1970: 123_456_789)

        let snap = await lifecycle
            .computeTierThermalSnapshot(observedAt: t)
        XCTAssertEqual(snap.snapshotAt, t)
        for reading in snap.readings {
            XCTAssertEqual(reading.observedAt, t,
                "each tier reading inherits the snapshot's timestamp")
        }
    }

    // MARK: - 4. End-to-end with BASComputeRouter

    func testNominalSnapshotRoutesToNPUByDefault() async {
        let thermal = ThermalSource()
        thermal.set(.nominal)
        let lifecycle = makeLifecycle(thermal: thermal)

        let snap = await lifecycle.computeTierThermalSnapshot()
        let router = BASComputeRouter()  // default preference NPU>GPU>CPU
        XCTAssertEqual(
            router.route(snapshot: snap), .npu,
            "nominal → all 1.0 headroom → preference tiebreak = NPU")
    }

    func testCriticalSnapshotFallsThroughToCoolestTier() async {
        let thermal = ThermalSource()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(thermal: thermal)

        let snap = await lifecycle.computeTierThermalSnapshot()
        let router = BASComputeRouter(minHeadroom: 0.1)
        // All tiers at 0.0 headroom → below floor → fallback
        // returns coolestTier, which under equal-headroom is the
        // first-inserted tier (CPU by the lifecycle's iteration
        // order in computeTierThermalSnapshot).
        let tier = router.route(snapshot: snap)
        XCTAssertNotNil(tier, "must fall back rather than return nil")
        XCTAssertTrue(
            [.cpu, .gpu, .npu].contains(tier!),
            "fallback picks one of the three tiers")
    }

    // MARK: - 5. Mid-session thermal drift reflects in snapshot

    func testSnapshotReflectsCurrentThermalStateAfterDrift()
        async {
        let thermal = ThermalSource()
        thermal.set(.nominal)
        let lifecycle = makeLifecycle(thermal: thermal)

        _ = await lifecycle.resample()
        let coolSnap = await lifecycle
            .computeTierThermalSnapshot()
        XCTAssertEqual(
            coolSnap.reading(for: .cpu)?.headroom ?? -1,
            1.0,
            accuracy: 1e-9)

        thermal.set(.serious)  // BASThermalLevel.hot
        _ = await lifecycle.resample()
        let hotSnap = await lifecycle
            .computeTierThermalSnapshot()
        XCTAssertEqual(
            hotSnap.reading(for: .cpu)?.headroom ?? -1,
            0.3,
            accuracy: 1e-9,
            "snapshot picks up the drifted thermal state")
    }
}
