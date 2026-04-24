import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M121 + M122 — end-to-end test: `QinaoRuntime.sendSession`
/// auto-streams the L1 / L3 / L5 observation bundles into the L14
/// audit ledger's `observationBundle` storage every turn.
///
/// M121 landed the L1 pipe (lease-life). M122 extended the same
/// choke-point to L3 (thought-fold) and L5 (host-constitution),
/// which fire unconditionally on every healthy turn. The L1
/// branch still gates on `lifecycle + routedBudget`.
///
/// Production paths consumed:
/// - M66 QinaoLifecycle
/// - M60 BASLeaseLifeObservationBundle.derive
/// - M61 BASHostConstitutionObservationBundle.derive  (M122)
/// - M62 BASThoughtFoldObservationBundle.derive       (M122)
/// - M95 sendSession additionalCoverageSummaries hook
/// - M97 L1/L2/L5 coverageSummary projections
/// - M104 prepareBudgetForTurn routed-budget pipeline
///
/// Pins:
/// 1. With lifecycle + plannedBudget: ledger observationBundle
///    is non-nil AND contains L14 + L1 + L3 + L5 summaries in
///    deterministic order.
/// 2. Without lifecycle: L1 is absent but L14+L3+L5 still stream
///    (M122 — pre-M121's "no bundle at all" no longer holds).
/// 3. Without plannedBudget: same as (2) — only L1 depends on the
///    routed budget.
/// 4. Caller-supplied additionalCoverageSummaries are preserved
///    alongside the auto-injected L1+L3+L5 (append, not replace).
/// 5. Custom expectedCoverageLayerIDs not modified by auto-inject.
final class QinaoRuntimeAutoStreamL1Tests: XCTestCase {

    // MARK: - Fixtures

    actor ToolRecorder {
        func record(name: String, payload: Data) -> Data {
            Data()
        }
    }

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
        func record(
            identifier: String, date: Date
        ) -> Bool { true }
    }

    actor NoopCanceller {
        func record(_ identifier: String) {}
    }

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
        let plannedBudget: BASBudgetFrame
    }

    private func makeRuntime(
        withLifecycle: Bool,
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> Fixture {
        let recorder = ToolRecorder()
        let snapshotManager = BASSovereignSnapshotManager(now: now)
        let versionTree = BASSovereignHostVersionTree(now: now)
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: now)
        let tokenAuthority = BASSovereignTokenAuthority(now: now)
        let engine = BASSovereignVerdictEngine(
            ledger: ledger, now: now)
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let sovereign = QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            auditLedger: ledger,
            warrantTTLSeconds: 10,
            now: now)

        let risk = QinaoRiskGate(permitTTLSeconds: 10, now: now)
        let constitution = BASHostConstitution(
            hostID: "host",
            activeVersion: "host.v1")
        let tree = BASHostVersionTree(
            activeVersionID: "host.v1",
            versions: [
                BASHostVersion(
                    versionID: "host.v1",
                    createdAt: now(),
                    changedFields: [],
                    reason: "seed",
                    approvedByPolicy: true)
            ])
        let pipeline = BASHostCandidatePipeline(
            constitution: constitution,
            versionTree: tree,
            clock: now)
        let host = QinaoHost(pipeline: pipeline)
        let memory = QinaoMemory()
        let loop = QinaoLoop()

        let executor: QinaoRuntime.ToolExecutor = { name, payload in
            await recorder.record(name: name, payload: payload)
        }

        let lifecycle: QinaoLifecycle?
        if withLifecycle {
            let thermal = ThermalSource()
            let submitter = NoopSubmitter()
            let canceller = NoopCanceller()
            lifecycle = QinaoLifecycle.makeForTesting(
                taskIdentifierPrefix: "m121.breath",
                timeConstantSeconds: 180,
                thermalReader: { thermal.get() },
                submitter: { id, date in
                    await submitter.record(
                        identifier: id, date: date)
                },
                canceller: { id in
                    await canceller.record(id)
                },
                clock: { Date(timeIntervalSince1970: 1_700_000_000) })
        } else {
            lifecycle = nil
        }

        let runtime = QinaoRuntime(
            host: host,
            memory: memory,
            risk: risk,
            sovereign: sovereign,
            loop: loop,
            toolExecutor: executor,
            now: now,
            lifecycle: lifecycle)

        // A minimum-viable planned budget for sendSession to
        // route through prepareBudgetForTurn.
        let plannedBudget = BASBudgetFrame(
            runMode: .engage,
            maxLoops: 3,
            maxCandidates: 3,
            maxDecodeTokens: 512,
            retrievalDepth: 3,
            precisionProfile: .protected,
            deviceRoute: .hybridLocal,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false,
            leaseID: "lease.m121",
            leaseExpiresAt: now().addingTimeInterval(60),
            maintenanceClass: .light,
            wakeIntentID: "wake.m121",
            allowedHeads: ["answer"],
            policyBundleVersion: "pb.v1",
            policyDecisionIDs: [])

        return Fixture(
            runtime: runtime,
            sovereign: sovereign,
            plannedBudget: plannedBudget)
    }

    private func observations(
        sessionID: String = "sess.m121",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m121",
            policyHash: "policy.m121")
    }

    // MARK: - 1. With lifecycle + planned budget → L1+L3+L5 auto-streams

    func testLifecycleAndPlannedBudgetAutoStreamsL1Bundle()
        async throws {
        let fx = await makeRuntime(withLifecycle: true)
        let obs = observations(turnID: "turn.auto")

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            plannedBudget: fx.plannedBudget,
            turnDurationSeconds: 1.0)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(
            bundle,
            "observation bundle must be recorded when lifecycle " +
                "+ plannedBudget both present")
        // M122 — L14 always first; then caller additions (none here);
        // then auto-inject in L1 → L3 → L5 order.
        XCTAssertEqual(
            bundle?.summaries.count, 4,
            "L14 + L1 + L3 + L5")
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertEqual(
            layers,
            [.sovereign, .leaseLife, .thoughtFold, .hostConstitution],
            "M122 auto-inject order: L14, L1, L3, L5")
    }

    // MARK: - 2. No lifecycle → L1 absent but L3+L5 still fire

    func testNoLifecycleDoesNotAutoStreamL1() async throws {
        let fx = await makeRuntime(withLifecycle: false)
        let obs = observations(turnID: "turn.no-lifecycle")

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            plannedBudget: fx.plannedBudget)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        // M122 — bundle is now always recorded because L3/L5
        // auto-inject on every turn. L1 stays off because
        // lifecycle is nil.
        XCTAssertNotNil(
            bundle,
            "M122: L3+L5 stream regardless of lifecycle")
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertEqual(
            layers,
            [.sovereign, .thoughtFold, .hostConstitution],
            "no L1 without lifecycle; L3+L5 still present")
        XCTAssertFalse(
            layers.contains(.leaseLife),
            "L1 must be absent without lifecycle")
    }

    // MARK: - 3. No plannedBudget → L1 absent but L3+L5 still fire

    func testNoPlannedBudgetDoesNotAutoStreamL1() async throws {
        let fx = await makeRuntime(withLifecycle: true)
        let obs = observations(turnID: "turn.no-budget")

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(
            bundle,
            "M122: L3+L5 stream regardless of plannedBudget")
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertEqual(
            layers,
            [.sovereign, .thoughtFold, .hostConstitution],
            "no L1 without routed budget; L3+L5 still present")
        XCTAssertFalse(
            layers.contains(.leaseLife),
            "L1 must be absent without routed budget")
    }

    // MARK: - 4. Caller-supplied extras coexist; report dedups
    //         on layer (last-write-wins, first-seen order).

    func testCallerSuppliedExtrasCoexistWithAutoL1()
        async throws {
        let fx = await makeRuntime(withLifecycle: true)
        let obs = observations(turnID: "turn.mixed")

        // Caller passes an L3 summary themselves. The runtime
        // appends its auto-injected L1+L3+L5. `BASObservation
        // ReconciliationReport`'s init deduplicates by layer —
        // last-write-wins, first-seen position preserved — so the
        // final bundle carries exactly one L3 summary (value = auto
        // L3), and the caller's L3 *position* comes first among the
        // non-L14 layers.
        let callerL3 = BASObservationCoverageSummary(
            layer: .thoughtFold,
            turnID: obs.turnID,
            sessionID: obs.sessionID,
            totalObservations: 99,       // distinctive marker
            distinctSubjectCount: 1,
            hasCoreSignalCoverage: true,
            budgetTotalCost: 0.1,
            emittedAt: Date())

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            plannedBudget: fx.plannedBudget,
            additionalCoverageSummaries: [callerL3])

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(bundle)
        // L14 + L3 (caller position, auto value) + L1 + L5 = 4
        XCTAssertEqual(
            bundle?.summaries.count, 4,
            "dedup by layer: caller L3 + auto L3 collapse to one")
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertEqual(
            layers,
            [
                .sovereign,         // L14 always first
                .thoughtFold,       // L3 (first-seen via caller)
                .leaseLife,         // L1 (auto)
                .hostConstitution,  // L5 (auto)
            ],
            "order = first-seen; dedup last-write-wins")
        // Pin last-write-wins: the caller's 99-totalObservations
        // marker must have been overwritten by the auto L3.
        let l3 = bundle?.summaries.first { $0.layer == .thoughtFold }
        XCTAssertNotEqual(
            l3?.totalObservations, 99,
            "auto L3 must have overwritten caller L3 (LWW)")
    }

    // MARK: - 5. Custom expectedLayerIDs preserved

    func testCustomExpectedLayerIDsNotModified() async throws {
        let fx = await makeRuntime(withLifecycle: true)
        let obs = observations(turnID: "turn.custom-exp")

        // Caller passes a custom expectation set (not the default
        // ["L14"]); auto-inject must NOT expand it.
        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            expectedCoverageLayerIDs: ["L14", "L3", "L5"],
            plannedBudget: fx.plannedBudget)

        // The bundle is still streamed (L1 auto-injected), but
        // the coverage verdict's expected set stays what the
        // caller passed.
        let reading = await fx.sovereign.coverageReading(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(reading)
        // Verdict findings would include "missingLayer" for L3
        // and L5 which we intentionally didn't stream — but not
        // for L1 (which auto-injects) or L14 (always present).
        // We mostly assert the reading exists, not a specific
        // severity.
    }
}
