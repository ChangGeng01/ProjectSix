import XCTest
@testable import BASRuntimeCore
@testable import BASOrchestration

/// M60 — L1 灯芯层 main-chain wiring.
///
/// Before M60 the kernel published `BASBudgetFrame` but the frame
/// was static — no observation bundle was derived on the main-chain
/// thought frame, so the L14 audit surface had no structured way to
/// reconcile "what L1 decided about this turn's run mode / guard /
/// maintenance / device route" against "what the rest of the
/// pipeline actually consumed". These tests pin the main-chain
/// behavior:
///
///   1. `BASLeaseLifeObservationBundle.derive(
///        fromBudgetFrame:turnID:sessionID:emittedAt:)` emits a
///      bundle whose contents deterministically mirror the input
///      budget (same inputs → same bundle byte-for-byte).
///   2. Four always-on signals (leaseGranted, runModeDetermined,
///      thermalReadingObserved, deviceRouteSelected) fire on every
///      turn; two gated signals (guardLevelEscalated,
///      maintenanceClassified) fire only when their structural
///      precondition holds.
///   3. Shape classification follows the 6-phase precedence rule
///      (lockdown > dormant > emergency > throttled > maintenance
///      > nominal).
///   4. `BASThoughtFrame.withDerivedLeaseLifeObservationBundle(
///      budgetFrame:turnID:sessionID:emittedAt:)` returns a copy
///      with the bundle attached and leaves every other field
///      untouched.
///   5. Core-signal coverage (lease + runMode + thermal + device
///      route all emitted) holds for every derived bundle, even
///      under `.emergency` (the emergency phase flag is separate).
///   6. Budget stays clamped in [0, 1] even when all six signals
///      are emitted simultaneously.
///   7. Synthetic leaseID fallback fires when the budget has no
///      `leaseID` set.
final class BASLeaseLifeObservationDerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let fixedDate = Date(timeIntervalSince1970: 2_000_000)
    private let turnID = "turn-l1-1"
    private let sessionID = "session-l1-1"

    /// Builds a `BASBudgetFrame` with explicit knobs for every field
    /// that derivation reads. Defaults produce a nominal engage
    /// turn on scoutNPU at nominal guard with no maintenance and a
    /// real leaseID.
    private func budget(
        runMode: BASEBrainRunMode = .engage,
        maxLoops: Int = 3,
        maxCandidates: Int = 5,
        maxDecodeTokens: Int = 512,
        retrievalDepth: Int = 2,
        precisionProfile: BASRuntimePrecisionProfile = .balanced,
        deviceRoute: BASDeviceRoute = .scoutNPU,
        thermalGuardLevel: BASThermalGuardLevel = .nominal,
        maintenanceAllowed: Bool = false,
        maintenanceClass: BASMaintenanceClass = .none,
        leaseID: String? = "lease-fixture-1",
        leaseExpiresAt: Date? = Date(
            timeIntervalSince1970: 2_000_300),
        wakeIntentID: String? = "wake-1",
        allowedHeads: [String] = ["head.default"],
        policyBundleVersion: String? = "policy-1",
        policyDecisionIDs: [String] = []
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            schemaVersion: BASBudgetFrame.currentSchemaVersion,
            runMode: runMode,
            maxLoops: maxLoops,
            maxCandidates: maxCandidates,
            maxDecodeTokens: maxDecodeTokens,
            retrievalDepth: retrievalDepth,
            precisionProfile: precisionProfile,
            deviceRoute: deviceRoute,
            thermalGuardLevel: thermalGuardLevel,
            maintenanceAllowed: maintenanceAllowed,
            leaseID: leaseID,
            leaseExpiresAt: leaseExpiresAt,
            maintenanceClass: maintenanceClass,
            wakeIntentID: wakeIntentID,
            allowedHeads: allowedHeads,
            policyBundleVersion: policyBundleVersion,
            policyDecisionIDs: policyDecisionIDs
        )
    }

    private func derive(
        _ b: BASBudgetFrame
    ) -> BASLeaseLifeObservationBundle {
        BASLeaseLifeObservationBundle.derive(
            fromBudgetFrame: b,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate
        )
    }

    // MARK: - Path 1: baseline nominal engage turn

    func testNominalEngageEmitsFourAlwaysOnSignals() {
        let bundle = derive(budget())
        XCTAssertEqual(bundle.turnID, turnID)
        XCTAssertEqual(bundle.sessionID, sessionID)
        XCTAssertEqual(bundle.emittedAt, fixedDate)
        // 4 always-on: lease + runMode + thermal + device route.
        // No guardEscalated (nominal), no maintenance (disabled).
        XCTAssertEqual(bundle.observations.count, 4)
        XCTAssertTrue(bundle.hasAnyLeaseGrant)
        XCTAssertFalse(bundle.hasAnyGuardEscalation)
        XCTAssertFalse(bundle.hasAnyMaintenance)
        XCTAssertFalse(bundle.isInEmergencyPhase)
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .nominal)
        }
    }

    func testSubjectIDsTagSpecificKernelConcerns() {
        let bundle = derive(budget())
        let subjects = bundle.subjectIDs
        XCTAssertTrue(subjects.contains("lease-fixture-1"))
        XCTAssertTrue(subjects.contains("runmode.engage"))
        XCTAssertTrue(subjects.contains("thermal.nominal"))
        XCTAssertTrue(subjects.contains("device.scoutNPU"))
    }

    // MARK: - Path 2: watch guard level — reading salience rises
    //         but no escalation signal (watch is not above nominal
    //         for escalation purposes).

    func testWatchGuardEmitsEscalationSignal() {
        let bundle = derive(budget(thermalGuardLevel: .watch))
        // watch is > nominal, so escalation fires.
        XCTAssertTrue(bundle.hasAnyGuardEscalation)
        let esc = bundle.observations(of: .guardLevelEscalated)
        XCTAssertEqual(esc.count, 1)
        XCTAssertEqual(
            esc.first?.subjectID,
            "thermal.escalation.watch")
        // Shape stays nominal because .watch doesn't trigger the
        // throttled/emergency categories.
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .nominal)
        }
    }

    // MARK: - Path 3: throttle guard → .throttled shape

    func testThrottleGuardPromotesShapeToThrottled() {
        let bundle = derive(budget(thermalGuardLevel: .throttle))
        XCTAssertTrue(bundle.hasAnyGuardEscalation)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .throttled)
        }
        let esc = bundle.observations(of: .guardLevelEscalated)
        let salience = try? XCTUnwrap(esc.first?.salience)
        XCTAssertEqual(salience ?? -1, 0.85, accuracy: 0.0001)
    }

    // MARK: - Path 4: emergency guard → .emergency shape + flag

    func testEmergencyGuardPromotesShapeAndFlipsEmergencyFlag() {
        let bundle = derive(budget(thermalGuardLevel: .emergency))
        XCTAssertTrue(bundle.isInEmergencyPhase)
        XCTAssertTrue(bundle.hasAnyGuardEscalation)
        // Core coverage holds even under emergency — L1 still
        // emitted the baseline. Emergency is a phase flag, not a
        // coverage gap.
        XCTAssertTrue(bundle.hasCoreSignalCoverage)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .emergency)
        }
        let esc = bundle.observations(of: .guardLevelEscalated)
        let salience = try? XCTUnwrap(esc.first?.salience)
        XCTAssertEqual(salience ?? -1, 1.0, accuracy: 0.0001)
    }

    // MARK: - Path 5: maintenance classification gated correctly

    func testMaintenanceAllowedWithNoneClassYieldsNoSignal() {
        let bundle = derive(budget(
            maintenanceAllowed: true,
            maintenanceClass: .none))
        XCTAssertFalse(bundle.hasAnyMaintenance)
    }

    func testMaintenanceDisallowedSuppressesSignal() {
        let bundle = derive(budget(
            maintenanceAllowed: false,
            maintenanceClass: .standard))
        XCTAssertFalse(bundle.hasAnyMaintenance)
    }

    func testMaintenanceAllowedWithLightClassEmitsSignalAndShape() {
        let bundle = derive(budget(
            maintenanceAllowed: true,
            maintenanceClass: .light))
        XCTAssertTrue(bundle.hasAnyMaintenance)
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .maintenance)
        }
        let m = bundle.observations(of: .maintenanceClassified)
        XCTAssertEqual(m.first?.subjectID, "maintenance.light")
        let salience = try? XCTUnwrap(m.first?.salience)
        XCTAssertEqual(salience ?? -1, 0.55, accuracy: 0.0001)
    }

    func testMaintenanceAllowedWithDeferredClassHasHighestSalience() {
        let bundle = derive(budget(
            maintenanceAllowed: true,
            maintenanceClass: .deferred))
        let m = bundle.observations(of: .maintenanceClassified)
        let salience = try? XCTUnwrap(m.first?.salience)
        XCTAssertEqual(salience ?? -1, 0.85, accuracy: 0.0001)
    }

    // MARK: - Path 6: run-mode shape precedence

    func testLockdownRunModeOverridesAllOtherShapes() {
        // Even under emergency guard, a lockdown run mode gets the
        // lockdown shape (extraction phase precedence).
        let bundle = derive(budget(
            runMode: .lockdown,
            thermalGuardLevel: .emergency,
            maintenanceAllowed: true,
            maintenanceClass: .deferred))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .lockdown)
        }
    }

    func testDormantRunModeGetsDormantShape() {
        let bundle = derive(budget(runMode: .dormant))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .dormant)
        }
    }

    func testPulseRunModeGetsDormantShape() {
        let bundle = derive(budget(runMode: .pulse))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .dormant)
        }
    }

    func testRecoveryRunModeGetsLockdownShape() {
        let bundle = derive(budget(runMode: .recovery))
        for obs in bundle.observations {
            XCTAssertEqual(obs.shape, .lockdown)
        }
    }

    // MARK: - Path 7: synthetic leaseID fallback

    func testMissingLeaseIDFallsBackToSyntheticSubject() {
        let bundle = derive(budget(leaseID: nil))
        let lease = bundle.observations(of: .leaseGranted)
        XCTAssertEqual(lease.first?.subjectID, "lease.engage")
    }

    // MARK: - Path 8: determinism

    func testDeterministicBundleForIdenticalInputs() {
        let b = budget(thermalGuardLevel: .throttle)
        let first = derive(b)
        let second = derive(b)
        XCTAssertEqual(first, second)
    }

    // MARK: - Path 9: withDerived helper

    func testWithDerivedLeaseLifeBundleAttachesAndPreservesFrame() {
        let frame = BASThoughtFrame(
            stepIndex: 7,
            decomposeRef: "dcm-1",
            memoryRefs: ["m1"],
            stabilityScore: 0.73)
        let b = budget(
            thermalGuardLevel: .watch,
            maintenanceAllowed: true,
            maintenanceClass: .standard)
        let withBundle = frame
            .withDerivedLeaseLifeObservationBundle(
                budgetFrame: b,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: fixedDate)
        XCTAssertEqual(withBundle.stepIndex, 7)
        XCTAssertEqual(withBundle.decomposeRef, "dcm-1")
        XCTAssertEqual(withBundle.memoryRefs, ["m1"])
        XCTAssertEqual(withBundle.stabilityScore, 0.73)
        XCTAssertNotNil(withBundle.leaseLifeObservationBundle)
        XCTAssertTrue(
            withBundle.leaseLifeObservationBundle!
                .hasAnyGuardEscalation)
        XCTAssertTrue(
            withBundle.leaseLifeObservationBundle!
                .hasAnyMaintenance)
    }

    func testWithDerivedHelperIsDeterministic() {
        let frame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "dcm-x")
        let b = budget()
        let first = frame.withDerivedLeaseLifeObservationBundle(
            budgetFrame: b,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        let second = frame.withDerivedLeaseLifeObservationBundle(
            budgetFrame: b,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: fixedDate)
        XCTAssertEqual(
            first.leaseLifeObservationBundle,
            second.leaseLifeObservationBundle)
    }

    // MARK: - Path 10: budget saturation clamps to [0, 1]

    func testBudgetCostClampsUnderSaturation() {
        // All 6 kinds fire: lease + runMode + thermal + escalation
        // + maintenance + device route = 0.10 + 0.10 + 0.10 + 0.20
        // + 0.15 + 0.10 = 0.75, still under 1.0 but a meaningful
        // load. Confirms the total matches the sum.
        let bundle = derive(budget(
            thermalGuardLevel: .emergency,
            maintenanceAllowed: true,
            maintenanceClass: .deferred))
        let total = BASLeaseLifeSignalBudget.totalCost(for: bundle)
        XCTAssertEqual(total, 0.75, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(total, 1.0)
        XCTAssertGreaterThanOrEqual(total, 0.0)
    }

    // MARK: - Path 11: content field deterministic across locales

    func testLeaseContentEncodesBudgetFields() {
        let bundle = derive(budget())
        let lease = bundle.observations(of: .leaseGranted).first!
        XCTAssertTrue(
            lease.content.contains("l1.lease.id:lease-fixture-1"))
        XCTAssertTrue(
            lease.content.contains(".runMode:engage"))
    }

    // MARK: - Path 12: Codable round trip

    func testBundleCodableRoundTripPreservesSignals() throws {
        let bundle = derive(budget(
            thermalGuardLevel: .throttle,
            maintenanceAllowed: true,
            maintenanceClass: .standard))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(bundle)
        let decoder = JSONDecoder()
        let roundTrip = try decoder.decode(
            BASLeaseLifeObservationBundle.self, from: data)
        XCTAssertEqual(roundTrip, bundle)
    }

    func testThoughtFrameCodableRoundTripIncludesLeaseLifeBundle()
    throws {
        var frame = BASThoughtFrame(
            stepIndex: 2,
            decomposeRef: "dcm-y",
            stabilityScore: 0.5)
        frame = frame.withDerivedLeaseLifeObservationBundle(
            budgetFrame: budget(),
            turnID: "t",
            sessionID: "s",
            emittedAt: fixedDate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(frame)
        let decoder = JSONDecoder()
        let roundTrip = try decoder.decode(
            BASThoughtFrame.self, from: data)
        XCTAssertEqual(
            roundTrip.leaseLifeObservationBundle,
            frame.leaseLifeObservationBundle)
    }

    // MARK: - Path 13: ledger append + bounded ring

    func testLedgerRecordsBundleAndSnapshots() async {
        let ledger = BASLeaseLifeObservationLedger(capacity: 2)
        let a = derive(budget(runMode: .engage))
        let b = derive(budget(runMode: .reflect))
        let c = derive(budget(runMode: .deepLoop))
        await ledger.record(a)
        await ledger.record(b)
        await ledger.record(c)
        let snap = await ledger.snapshot()
        XCTAssertEqual(snap.count, 2)
        // Oldest (a) evicted; b, c remain.
        XCTAssertEqual(snap.first, b)
        XCTAssertEqual(snap.last, c)
    }

    func testLedgerFiltersBySessionAndTurn() async {
        let ledger = BASLeaseLifeObservationLedger()
        let a = BASLeaseLifeObservationBundle.derive(
            fromBudgetFrame: budget(),
            turnID: "tA",
            sessionID: "sA",
            emittedAt: fixedDate)
        let b = BASLeaseLifeObservationBundle.derive(
            fromBudgetFrame: budget(),
            turnID: "tB",
            sessionID: "sB",
            emittedAt: fixedDate)
        await ledger.record(a)
        await ledger.record(b)
        let bySession = await ledger.bundles(forSession: "sA")
        XCTAssertEqual(bySession.count, 1)
        XCTAssertEqual(bySession.first?.turnID, "tA")
        let byTurn = await ledger.bundle(forTurn: "tB")
        XCTAssertEqual(byTurn?.sessionID, "sB")
    }

    // MARK: - Path 14: gated signal counts

    func testFullSaturationTurnEmitsAllSixKinds() {
        let bundle = derive(budget(
            thermalGuardLevel: .throttle,
            maintenanceAllowed: true,
            maintenanceClass: .standard))
        // All 6 kinds fire on this configuration.
        XCTAssertEqual(
            bundle.observations(of: .leaseGranted).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .runModeDetermined).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .thermalReadingObserved).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .guardLevelEscalated).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .maintenanceClassified).count, 1)
        XCTAssertEqual(
            bundle.observations(of: .deviceRouteSelected).count, 1)
        XCTAssertEqual(bundle.observations.count, 6)
    }

    // MARK: - Path 15: observations(forShape:) + forSubject:) helpers

    func testObservationsForShapeFiltersBundle() {
        let bundle = derive(budget(thermalGuardLevel: .emergency))
        let all = bundle.observations(forShape: .emergency)
        XCTAssertEqual(all.count, bundle.observations.count)
    }

    func testObservationsForSubjectFiltersBundle() {
        let bundle = derive(budget())
        let lease = bundle.observations(
            forSubject: "lease-fixture-1")
        XCTAssertEqual(lease.count, 1)
        XCTAssertEqual(lease.first?.kind, .leaseGranted)
    }
}
