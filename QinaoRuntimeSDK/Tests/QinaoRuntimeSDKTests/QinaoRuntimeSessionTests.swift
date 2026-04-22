import XCTest
import CryptoKit
import BASRuntimeCore
import BASMemory
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M15 — `QinaoRuntime.sendSession` main-path turn audit.
///
/// These tests prove that every turn — not just every tool call — now
/// passes through an independent sovereign audit. The three-signature
/// gate still protects side-effect execution; `sendSession` raises the
/// floor to *every* turn so planning, memory writes, and host-candidate
/// activity cannot slip through without a second authority signing the
/// outcome.
///
/// Contract covered here:
///
/// 1. Clean engage turn → `sessionHalted == false`, no throw.
/// 2. Fail-closed on `coordinatorLaxer` parity → `auditParityFailure`
///    thrown *and* the session is marked halted before return.
/// 3. A session halted before the call refuses with
///    `sessionAlreadyHalted` without running the audit.
/// 4. An audit severity of `.deadStop` auto-halts the session and
///    returns `sessionHalted == true` on the outcome — the halt
///    reason is persisted as `audit-severity:deadStop`.
/// 5. An audit severity outside the auto-halt set (e.g. `.quarantine`)
///    returns cleanly without halting, letting the host decide.
final class QinaoRuntimeSessionTests: XCTestCase {

    // MARK: - Fixture

    actor ToolRecorder {
        var callCount = 0
        func record(name: String, payload: Data) -> Data {
            callCount += 1
            return Data()
        }
    }

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
    }

    private func makeRuntime(
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

        let executor: QinaoRuntime.ToolExecutor = { name, payload in
            await recorder.record(name: name, payload: payload)
        }

        let runtime = QinaoRuntime(
            host: host,
            memory: memory,
            risk: risk,
            sovereign: sovereign,
            loop: loop,
            toolExecutor: executor,
            now: now)

        return Fixture(runtime: runtime, sovereign: sovereign)
    }

    private func observations(
        sessionID: String = "sess.audit",
        turnID: String = "turn.1",
        build: (inout QinaoSovereignControlPlane.TurnObservations) -> Void
            = { _ in }
    ) -> QinaoSovereignControlPlane.TurnObservations {
        // Defaults produce a clean `.pass` engage turn; the `build`
        // closure lets each test flip exactly the fields it needs.
        var obs = QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.1",
            policyHash: "policy.hash.1")
        build(&obs)
        return obs
    }

    // MARK: - Clean turn

    func testCleanTurnPassesWithoutHalting() async throws {
        let fx = await makeRuntime()
        let obs = observations()

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        XCTAssertFalse(outcome.sessionHalted)
        XCTAssertEqual(outcome.audit.severity, .pass)
        XCTAssertEqual(outcome.audit.parity, .match)
        let halted = await fx.sovereign.isSessionHalted(obs.sessionID)
        XCTAssertFalse(halted)
    }

    // MARK: - Laxer-parity fail-closed

    func testLaxerParityFailsClosedAndMarksHalted() async throws {
        let fx = await makeRuntime()
        // runtimeUnstableInHighRisk → engine must emit ≥ .shadowLock.
        // Coordinator reported `.pass` → laxer.
        let obs = observations { o in
            o = QinaoSovereignControlPlane.TurnObservations(
                sessionID: o.sessionID,
                turnID: o.turnID,
                snapshotRef: o.snapshotRef,
                policyHash: o.policyHash,
                runtimeUnstableInHighRisk: true)
        }

        do {
            _ = try await fx.runtime.sendSession(
                obs, coordinatorSeverity: .pass)
            XCTFail("expected auditParityFailure")
        } catch QinaoRuntime.TurnError.auditParityFailure(
            let sessionID, let severity, let auditRef) {
            XCTAssertEqual(sessionID, obs.sessionID)
            XCTAssertGreaterThanOrEqual(severity, .shadowLock)
            XCTAssertFalse(auditRef.isEmpty)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // Fail-closed: the session must be halted before the throw.
        let halted = await fx.sovereign.isSessionHalted(obs.sessionID)
        XCTAssertTrue(halted)
        let reason = await fx.sovereign.haltReason(
            sessionID: obs.sessionID)
        XCTAssertEqual(reason, "audit-parity:coordinator-laxer")
    }

    // MARK: - Pre-halted refusal

    func testPreHaltedSessionRefusesBeforeAuditing() async throws {
        let fx = await makeRuntime()
        let sessionID = "sess.already.halted"
        await fx.sovereign.markSessionHalted(
            sessionID: sessionID,
            reason: "manual-pre-halt")
        let obs = observations(sessionID: sessionID)

        do {
            _ = try await fx.runtime.sendSession(
                obs, coordinatorSeverity: .pass)
            XCTFail("expected sessionAlreadyHalted")
        } catch QinaoRuntime.TurnError.sessionAlreadyHalted(let id) {
            XCTAssertEqual(id, sessionID)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Severity-driven auto-halt

    func testDeadStopSeverityAutoHalts() async throws {
        let fx = await makeRuntime()
        // unauthorizedSelfMutation → BR-007 → minLevel .deadStop.
        // coordinatorSeverity = nil → engineOnly parity (acceptable),
        // so the laxer-parity branch never fires and we land squarely
        // in the severity-driven auto-halt path.
        let obs = observations { o in
            o = QinaoSovereignControlPlane.TurnObservations(
                sessionID: o.sessionID,
                turnID: o.turnID,
                snapshotRef: o.snapshotRef,
                policyHash: o.policyHash,
                unauthorizedSelfMutation: true)
        }

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: nil)

        XCTAssertTrue(outcome.sessionHalted)
        XCTAssertEqual(outcome.audit.severity, .deadStop)
        XCTAssertEqual(outcome.audit.parity, .engineOnly)
        let halted = await fx.sovereign.isSessionHalted(obs.sessionID)
        XCTAssertTrue(halted)
        let reason = await fx.sovereign.haltReason(
            sessionID: obs.sessionID)
        XCTAssertEqual(reason, "audit-severity:deadStop")
    }

    func testQuarantineSeverityDoesNotAutoHalt() async throws {
        let fx = await makeRuntime()
        // hostRemovalBypassed → BR-005 → minLevel .quarantine.
        // Quarantine is NOT in the auto-halt set — the host decides.
        // coordinatorSeverity = .quarantine → match parity → clean
        // return with severity surfaced but session still live.
        let obs = observations { o in
            o = QinaoSovereignControlPlane.TurnObservations(
                sessionID: o.sessionID,
                turnID: o.turnID,
                snapshotRef: o.snapshotRef,
                policyHash: o.policyHash,
                hostRemovalBypassed: true)
        }

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .quarantine)

        XCTAssertFalse(outcome.sessionHalted)
        XCTAssertEqual(outcome.audit.severity, .quarantine)
        XCTAssertEqual(outcome.audit.parity, .match)
        let halted = await fx.sovereign.isSessionHalted(obs.sessionID)
        XCTAssertFalse(halted)
    }
}
