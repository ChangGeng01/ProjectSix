import XCTest
@testable import BASRuntimeCore
@testable import BASLeaseLife

/// M67 — `BASBudgetFrame.withLiveThermalGuardLevel(_:)` is the value
/// transform that plumbs the L1 lifecycle's live thermal reading
/// into the per-turn budget frame. These tests pin down the two
/// guarantees the helper must make:
///
///   1. It preserves every other field of the source frame byte-for
///      -byte — only `thermalGuardLevel` changes. Callers never have
///      to reconstruct the frame to swap the level.
///   2. The coordinator-backed convenience sources its level from a
///      live `BASLeaseLifeCoordinator` without side effects on the
///      rest of the frame. When no cached reading exists, it forces
///      a sample rather than returning a stale default.
final class BASBudgetFrameLiveThermalTests: XCTestCase {

    // MARK: - Fixture

    /// Produce a budget frame with every optional field populated so
    /// the "preserves everything else" assertion actually means
    /// something. Tests override the two fields they care about
    /// (`thermalGuardLevel` and whatever else is under test).
    private func budget(
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
            leaseID: "lease-xyz",
            leaseExpiresAt: Date(timeIntervalSince1970: 1_700_000_500),
            maintenanceClass: maintenanceClass,
            wakeIntentID: "wake-abc",
            allowedHeads: ["scout.default", "core.default"],
            policyBundleVersion: "policy-v1.3",
            policyDecisionIDs: ["p-1", "p-2"])
    }

    // MARK: - Level-only override

    func testOverridesThermalGuardLevelOnly() {
        let source = budget(thermalGuardLevel: .nominal)
        let routed = source.withLiveThermalGuardLevel(.emergency)

        XCTAssertEqual(routed.thermalGuardLevel, .emergency)

        // Spot check every other field survives verbatim.
        XCTAssertEqual(routed.schemaVersion, source.schemaVersion)
        XCTAssertEqual(routed.runMode, source.runMode)
        XCTAssertEqual(routed.maxLoops, source.maxLoops)
        XCTAssertEqual(routed.maxCandidates, source.maxCandidates)
        XCTAssertEqual(routed.maxDecodeTokens, source.maxDecodeTokens)
        XCTAssertEqual(routed.retrievalDepth, source.retrievalDepth)
        XCTAssertEqual(routed.precisionProfile, source.precisionProfile)
        XCTAssertEqual(routed.deviceRoute, source.deviceRoute)
        XCTAssertEqual(routed.maintenanceAllowed, source.maintenanceAllowed)
        XCTAssertEqual(routed.leaseID, source.leaseID)
        XCTAssertEqual(routed.leaseExpiresAt, source.leaseExpiresAt)
        XCTAssertEqual(routed.maintenanceClass, source.maintenanceClass)
        XCTAssertEqual(routed.wakeIntentID, source.wakeIntentID)
        XCTAssertEqual(routed.allowedHeads, source.allowedHeads)
        XCTAssertEqual(routed.policyBundleVersion,
                       source.policyBundleVersion)
        XCTAssertEqual(routed.policyDecisionIDs,
                       source.policyDecisionIDs)
    }

    func testIdempotentWhenLevelUnchanged() {
        let source = budget(thermalGuardLevel: .watch)
        let routed = source.withLiveThermalGuardLevel(.watch)
        // Value type; encoding should be byte-for-byte stable.
        let a = try? JSONEncoder().encode(source)
        let b = try? JSONEncoder().encode(routed)
        XCTAssertEqual(a, b)
    }

    func testSourceIsNotMutated() {
        let source = budget(thermalGuardLevel: .nominal)
        _ = source.withLiveThermalGuardLevel(.throttle)
        // Source remains nominal even after we derived a routed copy.
        XCTAssertEqual(source.thermalGuardLevel, .nominal)
    }

    func testAllFourGuardLevelsRoundTrip() {
        for level in BASThermalGuardLevel.allCases {
            let routed = budget(thermalGuardLevel: .nominal)
                .withLiveThermalGuardLevel(level)
            XCTAssertEqual(routed.thermalGuardLevel, level,
                "level \(level) must land on the routed frame")
        }
    }

    // MARK: - Coordinator-backed convenience

    func testCoordinatorBackedConveniencePullsFromTwin() async {
        // Seed a coordinator whose thermal reader returns .critical;
        // under the thermal twin's classification that yields guard
        // level `.emergency` for any accumulated pressure.
        let coord = BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: 180,
                clock: { Date(timeIntervalSince1970: 0) }),
            thermal: BASThermalTwin(
                reader: { .critical },
                clock: { Date(timeIntervalSince1970: 0) }),
            scheduler: BASBreathScheduler())

        // Warm the thermal cache so the convenience uses the cached
        // reading path.
        _ = await coord.recordTurn(runMode: .engage, durationSeconds: 1)

        let source = budget(thermalGuardLevel: .nominal)
        let routed = await source.withLiveThermalGuardLevel(
            from: coord)
        XCTAssertEqual(routed.thermalGuardLevel, .emergency)
        // Other fields preserved.
        XCTAssertEqual(routed.runMode, source.runMode)
        XCTAssertEqual(routed.maxLoops, source.maxLoops)
        XCTAssertEqual(routed.allowedHeads, source.allowedHeads)
    }

    func testCoordinatorBackedConvenienceForcesSampleWhenNoCachedReading()
        async {
        // `.serious` (→ `.hot` → guard `.throttle` at zero pressure).
        // No prior recordTurn — the twin has no cached reading, so
        // the convenience must force a fresh sample.
        let coord = BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: 180,
                clock: { Date(timeIntervalSince1970: 0) }),
            thermal: BASThermalTwin(
                reader: { .serious },
                clock: { Date(timeIntervalSince1970: 0) }),
            scheduler: BASBreathScheduler())

        let source = budget(thermalGuardLevel: .nominal)
        let routed = await source.withLiveThermalGuardLevel(
            from: coord)
        XCTAssertEqual(routed.thermalGuardLevel, .throttle)
    }
}
