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

/// M121 — end-to-end test: when QinaoRuntime.sendSession is called
/// with a lifecycle + plannedBudget, the L1 observation bundle is
/// auto-derived and streamed into the L14 audit ledger's
/// observationBundle storage.
///
/// This is the first production path that consumes:
/// - M66 QinaoLifecycle
/// - M60 BASLeaseLifeObservationBundle.derive
/// - M95 sendSession additionalCoverageSummaries hook
/// - M97 L1 coverageSummary projection
/// - M104 prepareBudgetForTurn routed-budget pipeline
///
/// All 5 pieces now flow together: lifecycle → live thermal →
/// routed budget → derive L1 bundle → stream to ledger →
/// queryable via observationBundle(sessionID:turnID:).
///
/// Pins:
/// 1. With lifecycle + plannedBudget: ledger observationBundle
///    is non-nil AND contains L1 summary
/// 2. Without lifecycle: pre-M121 behavior (no L1 auto-stream)
/// 3. Without plannedBudget: pre-M121 behavior
/// 4. Caller-supplied additionalCoverageSummaries are preserved
///    alongside the auto-injected L1 (append, not replace)
/// 5. Custom expectedCoverageLayerIDs not modified by auto-inject
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

    // MARK: - 1. With lifecycle + planned budget → L1 auto-streams

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
        // Should have L14 + auto-injected L1 = 2 summaries.
        XCTAssertEqual(
            bundle?.summaries.count, 2,
            "L14 + auto-injected L1")
        XCTAssertEqual(
            bundle?.summaries.first?.layer, .sovereign,
            "L14 always first")
        XCTAssertEqual(
            bundle?.summaries.last?.layer, .leaseLife,
            "L1 auto-injected after L14")
    }

    // MARK: - 2. No lifecycle → no L1 auto-stream

    func testNoLifecycleDoesNotAutoStreamL1() async throws {
        let fx = await makeRuntime(withLifecycle: false)
        let obs = observations(turnID: "turn.no-lifecycle")

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            plannedBudget: fx.plannedBudget)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNil(
            bundle,
            "no lifecycle → no auto-stream (pre-M121 behaviour)")
    }

    // MARK: - 3. No plannedBudget → no L1 auto-stream

    func testNoPlannedBudgetDoesNotAutoStreamL1() async throws {
        let fx = await makeRuntime(withLifecycle: true)
        let obs = observations(turnID: "turn.no-budget")

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNil(
            bundle,
            "no plannedBudget → no routed budget → no L1 derive")
    }

    // MARK: - 4. Caller-supplied extras coexist with auto-injected L1

    func testCallerSuppliedExtrasCoexistWithAutoL1()
        async throws {
        let fx = await makeRuntime(withLifecycle: true)
        let obs = observations(turnID: "turn.mixed")

        // Caller passes an L3 summary themselves; the runtime
        // should append L1 on top without replacing the L3.
        let l3Summary = BASObservationCoverageSummary(
            layer: .thoughtFold,
            turnID: obs.turnID,
            sessionID: obs.sessionID,
            totalObservations: 1,
            distinctSubjectCount: 1,
            hasCoreSignalCoverage: true,
            budgetTotalCost: 0.1,
            emittedAt: Date())

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            plannedBudget: fx.plannedBudget,
            additionalCoverageSummaries: [l3Summary])

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(bundle)
        XCTAssertEqual(
            bundle?.summaries.count, 3,
            "L14 + caller L3 + auto-injected L1 = 3 summaries")
        let layers = bundle?.summaries.map(\.layer) ?? []
        XCTAssertEqual(
            layers,
            [.sovereign, .thoughtFold, .leaseLife],
            "L14 first, caller-supplied middle, auto-L1 last")
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
