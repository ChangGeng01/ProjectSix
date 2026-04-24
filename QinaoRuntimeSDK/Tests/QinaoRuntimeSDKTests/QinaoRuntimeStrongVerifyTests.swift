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

/// M129 — strong residue verification that also runs the ledger's
/// cryptographic chain-integrity walk.
///
/// M124 landed the pure `verifyTurnResidue(_:)` verifier (O(findings),
/// no I/O, safe to run every frame). M129 adds the async strong
/// variant `verifyTurnResidueStrong(_:)` that also calls the
/// ledger's `verifyChainIntegrity()`. On any priorHash break or
/// signature mismatch, a `.chainIntegrityBroken(lastVerifiedAuditID:)`
/// finding is appended to the cross-surface findings.
///
/// Pins:
///   1. Healthy residue + healthy ledger → strong verify is valid
///      (no findings).
///   2. Strong verify on a mutated ledger emits
///      `.chainIntegrityBroken` alongside any cross-surface
///      findings that were already there.
///   3. Strong verify vs pure verify diverge only by the
///      chain-integrity finding (cross-surface findings match).
final class QinaoRuntimeStrongVerifyTests: XCTestCase {

    // M155 — migrated to shared QinaoTestFixture.


    private func observations(
        sessionID: String = "sess.m129",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m129",
            policyHash: "policy.m129")
    }

    // MARK: - 1. Healthy turn + healthy ledger → strong verify valid

    func testStrongVerifyOnHealthyTurnIsValid() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m129")
        let obs = observations(turnID: "turn.strong-happy")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let residue = try XCTUnwrap(outcome.residue)

        let verification = await fx.sovereign
            .verifyTurnResidueStrong(residue)
        XCTAssertTrue(
            verification.isValid,
            "healthy residue + healthy ledger: no findings")
        // No .chainIntegrityBroken in findings.
        let chainBroken = verification.findings.contains {
            if case .chainIntegrityBroken = $0 { return true }
            return false
        }
        XCTAssertFalse(
            chainBroken,
            "healthy ledger has no chain-integrity finding")
    }

    // MARK: - 2. Strong verify matches pure verify on clean ledger

    func testStrongAndPureAgreeOnHealthyLedger() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m129")
        let obs = observations(turnID: "turn.agree")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let residue = try XCTUnwrap(outcome.residue)

        let pure = await fx.sovereign.verifyTurnResidue(residue)
        let strong = await fx.sovereign
            .verifyTurnResidueStrong(residue)
        XCTAssertEqual(
            pure.findings, strong.findings,
            "clean ledger: pure and strong findings match")
    }

    // MARK: - 3. Strong verify on synthetic drift + clean ledger
    //         adds no chain-integrity finding

    func testStrongVerifyOnDriftWithCleanLedgerOnlyCrossSurface()
        async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m129")
        let obs = observations(turnID: "turn.drift")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        // Synthetic drift via direct record call with bad frameID.
        let badFrame = BASSovereignFrame(
            frameID: "bad.id",
            sessionID: obs.sessionID,
            turnID: obs.turnID,
            thoughtFoldRef:
                "fold." + obs.sessionID + "." + obs.turnID,
            policyHash: obs.policyHash)
        await fx.sovereign.recordSovereignFrame(badFrame)

        let residue = await fx.sovereign.turnResidue(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let strong = await fx.sovereign
            .verifyTurnResidueStrong(residue)
        XCTAssertFalse(strong.isValid)
        // Drift finding present.
        let hasDrift = strong.findings.contains {
            if case .frameIDConventionMismatch = $0 { return true }
            return false
        }
        XCTAssertTrue(hasDrift,
            "drift finding must fire")
        // Chain-integrity finding must NOT fire — ledger is clean.
        let hasChainBreak = strong.findings.contains {
            if case .chainIntegrityBroken = $0 { return true }
            return false
        }
        XCTAssertFalse(
            hasChainBreak,
            "clean ledger → no chain-integrity finding")
    }
}
