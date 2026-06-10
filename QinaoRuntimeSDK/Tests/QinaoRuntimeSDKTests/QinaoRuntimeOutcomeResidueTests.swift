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

    // M155 — migrated to shared QinaoTestFixture.


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
        let fx = await QinaoTestFixture.make(hostID: "host.m128")
        let obs = observations(turnID: "turn.happy")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        XCTAssertNotNil(
            outcome.residue,
            "healthy TurnOutcome must carry residue")
    }

    // MARK: - 2. Residue IDs match observations

    func testResidueSessionAndTurnIDsMatch() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m128")
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
        let fx = await QinaoTestFixture.make(hostID: "host.m128")
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
        let fx = await QinaoTestFixture.make(hostID: "host.m128")
        let obs = observations(turnID: "turn.verify")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let residue = try XCTUnwrap(outcome.residue)
        let verification = fx.sovereign
            .verifyTurnResidue(residue)
        XCTAssertTrue(verification.isValid)
        XCTAssertTrue(verification.findings.isEmpty)
    }

    // MARK: - 5. Direct-construct outcome may have nil residue

    func testDirectConstructOutcomeAllowsNilResidue() {
        // Host-authored TurnOutcome (e.g. in test fixtures) should
        // still compile with nil residue — the init default gives
        // backward-compat to pre-M128 host code. M145 note:
        // surfaceDecision is now non-optional; direct construction
        // MUST supply a value but residue is still optional.
        let decision = QinaoRuntime.deriveSurfaceDecision(
            auditSeverity: .pass,
            coverageSeverity: .clean,
            auditRef: "audit.direct")
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
            sessionHalted: false,
            surfaceDecision: decision)
        XCTAssertNil(
            outcome.residue,
            "direct-constructed outcome with no residue: nil")
        XCTAssertEqual(
            outcome.surfaceDecision.surface, .draftShell,
            "M145: non-optional surfaceDecision directly readable")
    }
}
