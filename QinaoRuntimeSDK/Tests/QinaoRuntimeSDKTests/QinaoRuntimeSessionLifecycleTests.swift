import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M70 — `QinaoRuntime.sendSession` auto-wires `QinaoLifecycle` hooks
/// so every healthy turn threads the live thermal reading into the
/// planned `BASBudgetFrame` and advances the lung/thermal accumulators
/// when the turn finishes cleanly.
///
/// The contract covered here:
///
/// 1. Clean turn + `plannedBudget` + `turnDurationSeconds` + lifecycle →
///    `outcome.routedBudget` carries the live `.thermalGuardLevel`,
///    `outcome.turnRecorded` is non-`nil`, and the lifecycle's lung
///    turn count advances by exactly one.
/// 2. Clean turn with `plannedBudget` but NO lifecycle →
///    `outcome.routedBudget` is identity (the planned frame byte-for-byte)
///    and `outcome.turnRecorded` is `nil` — pre-M70 behavior preserved.
/// 3. Clean turn WITH lifecycle but NO `plannedBudget` → both fields
///    `nil`; pre-M70 call sites (no new params passed) are byte-for-byte
///    unchanged.
/// 4. Severity-driven halt (e.g. `deadStop`) with full M70 args →
///    `outcome.routedBudget` is still present (the caller needs to see
///    the budget the halted turn ran under), but `outcome.turnRecorded`
///    is `nil` — a halted turn must NOT advance the lung or thermal
///    accumulators, because a failed turn would distort the lifecycle's
///    continuous state.
/// 5. Parity-fail path throws before the happy-path record, so the
///    lifecycle's lung turn count is unchanged after the throw.
final class QinaoRuntimeSessionLifecycleTests: XCTestCase {

    // MARK: - Thermal source (shared with QinaoLifecycleTests pattern)

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

    // MARK: - Fixture

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
        let lifecycle: QinaoLifecycle?
    }

    private func makeRuntime(
        lifecycle: QinaoLifecycle? = nil,
        now: @escaping @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1_700_000_000)
        }
    ) async -> Fixture {
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
        let engine = BASSovereignVerdictEngine(ledger: ledger, now: now)
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

        let executor: QinaoRuntime.ToolExecutor = { _, _ in Data() }

        let runtime = QinaoRuntime(
            host: host,
            memory: memory,
            risk: risk,
            sovereign: sovereign,
            loop: loop,
            toolExecutor: executor,
            now: now,
            lifecycle: lifecycle)

        return Fixture(
            runtime: runtime,
            sovereign: sovereign,
            lifecycle: lifecycle)
    }

    private func makeLifecycle(
        thermal: ThermalSource
    ) -> QinaoLifecycle {
        QinaoLifecycle.makeForTesting(
            taskIdentifierPrefix: "test.session",
            timeConstantSeconds: 180,
            thermalReader: { thermal.get() },
            submitter: { _, _ in true },
            canceller: { _ in },
            clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    private func observations(
        sessionID: String = "sess.m70",
        turnID: String = "turn.1",
        build: (inout QinaoSovereignControlPlane.TurnObservations) -> Void
            = { _ in }
    ) -> QinaoSovereignControlPlane.TurnObservations {
        var obs = QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m70",
            policyHash: "policy.hash.m70")
        build(&obs)
        return obs
    }

    private func plannedBudget(
        runMode: BASEBrainRunMode = .engage,
        thermalGuardLevel: BASThermalGuardLevel = .nominal
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: runMode,
            maxLoops: 3,
            maxCandidates: 5,
            maxDecodeTokens: 128,
            retrievalDepth: 4,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: thermalGuardLevel,
            maintenanceAllowed: true,
            leaseID: "lease-m70",
            leaseExpiresAt: Date(timeIntervalSince1970: 1_700_000_500),
            maintenanceClass: .light,
            wakeIntentID: "wake-m70",
            allowedHeads: ["scout.default", "core.default"],
            policyBundleVersion: "policy-v1.3",
            policyDecisionIDs: ["p-1"])
    }

    // MARK: - 1. Full M70 happy path

    func testCleanTurnWithLifecycleAndBudgetRoutesAndRecords() async throws {
        let thermal = ThermalSource()
        thermal.set(.critical)
        let lifecycle = makeLifecycle(thermal: thermal)
        let fx = await makeRuntime(lifecycle: lifecycle)

        let obs = observations()
        let planned = plannedBudget(thermalGuardLevel: .nominal)

        let outcome = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            plannedBudget: planned,
            turnDurationSeconds: 1.5)

        // Routed budget reflects the lifecycle's live reading.
        let routed = try XCTUnwrap(outcome.routedBudget)
        XCTAssertEqual(routed.thermalGuardLevel, .emergency,
            ".critical reader → guard .emergency on the routed frame")
        XCTAssertEqual(routed.runMode, planned.runMode)
        XCTAssertEqual(routed.leaseID, planned.leaseID)
        XCTAssertEqual(routed.allowedHeads, planned.allowedHeads)

        // Turn was recorded; lung count advanced.
        let recorded = try XCTUnwrap(outcome.turnRecorded)
        XCTAssertEqual(recorded.lung.turnCount, 1)
        XCTAssertFalse(outcome.sessionHalted)
    }

    // MARK: - 2. Budget passed but no lifecycle → identity routing

    func testCleanTurnWithBudgetButNoLifecycleRoutesIdentity() async throws {
        let fx = await makeRuntime(lifecycle: nil)
        let obs = observations(sessionID: "sess.m70.no-lifecycle")
        let planned = plannedBudget(thermalGuardLevel: .watch)

        let outcome = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            plannedBudget: planned,
            turnDurationSeconds: 2.0)

        // No lifecycle → routedBudget is identity of plannedBudget.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let routed = try XCTUnwrap(outcome.routedBudget)
        XCTAssertEqual(
            try encoder.encode(routed),
            try encoder.encode(planned),
            "no lifecycle → routedBudget must equal plannedBudget byte-for-byte")

        // No lifecycle → turnRecorded is nil even though duration was passed.
        XCTAssertNil(outcome.turnRecorded,
            "no lifecycle → turnRecorded must be nil")
    }

    // MARK: - 3. Pre-M70 shape: no new params → both outcome fields nil

    func testCleanTurnWithoutBudgetOrDurationPreservesPreM70Shape() async throws {
        let thermal = ThermalSource()
        let lifecycle = makeLifecycle(thermal: thermal)
        let fx = await makeRuntime(lifecycle: lifecycle)
        let obs = observations(sessionID: "sess.m70.pre-shape")

        // Old-style call: no plannedBudget, no turnDurationSeconds.
        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        XCTAssertFalse(outcome.sessionHalted)
        XCTAssertNil(outcome.routedBudget,
            "no plannedBudget → routedBudget must be nil")
        XCTAssertNil(outcome.turnRecorded,
            "no plannedBudget/duration → turnRecorded must be nil")
    }

    // MARK: - 4. Severity halt still routes budget but skips record

    func testDeadStopHaltReturnsRoutedBudgetButSkipsRecord() async throws {
        let thermal = ThermalSource()
        thermal.set(.serious)
        let lifecycle = makeLifecycle(thermal: thermal)
        let fx = await makeRuntime(lifecycle: lifecycle)

        // unauthorizedSelfMutation → BR-007 → minLevel .deadStop with
        // engineOnly parity (nil coordinator severity), so this lands
        // in the auto-halt branch — NOT the parity-fail branch.
        let obs = observations(sessionID: "sess.m70.halt") { o in
            o = QinaoSovereignControlPlane.TurnObservations(
                sessionID: o.sessionID,
                turnID: o.turnID,
                snapshotRef: o.snapshotRef,
                policyHash: o.policyHash,
                unauthorizedSelfMutation: true)
        }
        let planned = plannedBudget(thermalGuardLevel: .nominal)

        let outcome = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: nil,
            plannedBudget: planned,
            turnDurationSeconds: 3.0)

        XCTAssertTrue(outcome.sessionHalted)
        XCTAssertEqual(outcome.audit.severity, .deadStop)
        // Budget was routed — caller still sees what the halted turn ran under.
        let routed = try XCTUnwrap(outcome.routedBudget)
        XCTAssertEqual(routed.thermalGuardLevel, .throttle,
            ".serious live reading → .throttle (halt path still routes)")
        // But the lifecycle's lung accumulator is NOT advanced.
        XCTAssertNil(outcome.turnRecorded,
            "halt path must skip lifecycle recording")

        // Sanity: the lifecycle's lung really did not move.
        // (We record a probe turn now to confirm the count jumps to 1,
        // not 2 — which would imply M70 mistakenly recorded the halt.)
        let probe = await lifecycle.recordTurn(
            runMode: .engage, durationSeconds: 0.1)
        XCTAssertEqual(probe.lung.turnCount, 1,
            "halt must not have advanced lung; probe should land at 1")
    }

    // MARK: - 5. Parity halt throws — no record side effect survives

    func testParityHaltThrowsAndLeavesLifecycleUntouched() async throws {
        let thermal = ThermalSource()
        let lifecycle = makeLifecycle(thermal: thermal)
        let fx = await makeRuntime(lifecycle: lifecycle)

        // runtimeUnstableInHighRisk → engine demands ≥ shadowLock;
        // coordinator reported .pass → laxer parity.
        let obs = observations(sessionID: "sess.m70.parity") { o in
            o = QinaoSovereignControlPlane.TurnObservations(
                sessionID: o.sessionID,
                turnID: o.turnID,
                snapshotRef: o.snapshotRef,
                policyHash: o.policyHash,
                runtimeUnstableInHighRisk: true)
        }
        let planned = plannedBudget()

        do {
            _ = try await fx.runtime.sendSession(
                obs,
                coordinatorSeverity: .pass,
                plannedBudget: planned,
                turnDurationSeconds: 2.5)
            XCTFail("expected auditParityFailure")
        } catch QinaoRuntime.TurnError.auditParityFailure {
            // Expected; the parity throw must leave the lifecycle untouched.
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // A probe turn should advance the lung to 1, not 2 — proving the
        // parity-throw path did NOT record a turn.
        let probe = await lifecycle.recordTurn(
            runMode: .engage, durationSeconds: 0.1)
        XCTAssertEqual(probe.lung.turnCount, 1,
            "parity throw must not have recorded a turn on the lifecycle")
    }
}
