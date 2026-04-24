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

/// M128 — TurnOutcome.residue direct expose (API overlap 收敛).
///
/// Pre-M128 a host wanting the observation bundle / sovereign
/// frame / render frame after sendSession had to make three
/// separate `sovereign.turnResidue(...)` round-trips. M128
/// attaches a `TurnResidue` to the outcome so one sendSession
/// call delivers everything.
///
/// Pins:
///   1. Healthy turn outcome carries a non-nil residue.
///   2. residue.sessionID / .turnID match the TurnObservations.
///   3. residue.isComplete == true on healthy turn.
///   4. Verifying via sovereign returns valid (no findings).
///   5. Auto-halt (rollback severity) turn also carries residue.
///   6. Direct-construct TurnOutcome (host test fixture) allows
///      nil residue (backward-compat / init-default behavior).
final class QinaoRuntimeOutcomeResidueTests: XCTestCase {

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
    }

    private func makeRuntime(
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> Fixture {
        actor ToolRecorder {
            func record(name: String, payload: Data) -> Data {
                Data()
            }
        }
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
            hostID: "host.m128",
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
            host: host, memory: memory, risk: risk,
            sovereign: sovereign, loop: loop,
            toolExecutor: executor, now: now, lifecycle: nil)
        return Fixture(runtime: runtime, sovereign: sovereign)
    }

    private func observations(
        sessionID: String = "sess.m128",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m128",
            policyHash: "policy.m128")
    }

    // MARK: - 1. Healthy turn outcome carries residue

    func testHealthyTurnOutcomeCarriesResidue() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.happy")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        XCTAssertNotNil(
            outcome.residue,
            "healthy TurnOutcome must carry residue")
    }

    // MARK: - 2. Residue IDs match observations

    func testResidueSessionAndTurnIDsMatch() async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.match",
            turnID: "turn.match")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let residue = try XCTUnwrap(outcome.residue)
        XCTAssertEqual(residue.sessionID, obs.sessionID)
        XCTAssertEqual(residue.turnID, obs.turnID)
    }

    // MARK: - 3. Residue isComplete on healthy turn

    func testResidueIsCompleteOnHealthyTurn() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.complete")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let residue = try XCTUnwrap(outcome.residue)
        XCTAssertTrue(
            residue.isComplete,
            "healthy residue has coverage + bundle + frame")
        XCTAssertNotNil(residue.coverageReading)
        XCTAssertNotNil(residue.observationBundle)
        XCTAssertNotNil(residue.sovereignFrame)
    }

    // MARK: - 4. Residue verifies clean on healthy turn

    func testResidueVerifiesValidOnHealthyTurn() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.verify")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let residue = try XCTUnwrap(outcome.residue)
        let verification = await fx.sovereign
            .verifyTurnResidue(residue)
        XCTAssertTrue(verification.isValid)
        XCTAssertTrue(verification.findings.isEmpty)
    }

    // MARK: - 5. Direct-construct outcome may have nil residue

    func testDirectConstructOutcomeAllowsNilResidue() {
        // Host-authored TurnOutcome (e.g. in test fixtures) should
        // still compile with nil residue — the init default gives
        // backward-compat to pre-M128 host code.
        let outcome = QinaoRuntime.TurnOutcome(
            audit: QinaoSovereignControlPlane.AuditReport(
                sessionID: "sess.direct",
                turnID: "turn.direct",
                severity: .pass,
                coordinatorSeverity: .pass,
                parity: .match,
                reasonCodes: [],
                auditRef: "audit.direct"),
            coverage: QinaoSovereignControlPlane.CoverageReading(
                sessionID: "sess.direct",
                turnID: "turn.direct",
                severity: .clean,
                findings: [],
                emittedAt: Date()),
            sessionHalted: false)
        XCTAssertNil(
            outcome.residue,
            "direct-constructed outcome with no residue: nil")
    }
}
