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

/// M124 — 筋脉: cross-surface integrity verification.
///
/// M121/M122 (blood) landed L1+L3+L5 auto-streaming. M123
/// (skeleton) landed per-turn `BASSovereignFrame` aggregation.
/// M124 (tendons) stitches them together with a structural
/// verifier: given a `(sessionID, turnID)` the control plane
/// returns a `TurnResidue` bundling all three parallel surfaces
/// (coverage reading + observation bundle + sovereign frame) and
/// a pure `verifyTurnResidue(_:)` method that flags any
/// cross-surface drift as structured findings.
///
/// Pins:
///   1. Healthy turn → residue complete + verification valid.
///   2. Absent frame → `.missingSovereignFrame` finding.
///   3. Absent bundle → `.missingObservationBundle` finding.
///   4. Frame with wrong convention → frame-id mismatch finding.
///   5. Cross-surface disagreement on sessionID/turnID is flagged.
final class QinaoRuntimeTurnResidueTests: XCTestCase {

    // MARK: - Fixture

    actor ToolRecorder {
        func record(name: String, payload: Data) -> Data { Data() }
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
            hostID: "host.m124",
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

        return Fixture(
            runtime: runtime, sovereign: sovereign)
    }

    private func observations(
        sessionID: String = "sess.m124",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m124",
            policyHash: "policy.m124")
    }

    // MARK: - 1. Healthy turn → complete + valid

    func testHealthyTurnProducesCompleteValidResidue()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.happy")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let residue = await fx.sovereign.turnResidue(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertTrue(
            residue.isComplete,
            "healthy turn has all three surfaces")
        XCTAssertNotNil(residue.coverageReading)
        XCTAssertNotNil(residue.observationBundle)
        XCTAssertNotNil(residue.sovereignFrame)

        let verification = await fx.sovereign
            .verifyTurnResidue(residue)
        XCTAssertTrue(
            verification.isValid,
            "no findings on healthy turn")
        XCTAssertEqual(verification.findings, [])
    }

    // MARK: - 2. Never-sent turn → missing everything

    func testUnsentTurnHasEmptyResidue() async throws {
        let fx = await makeRuntime()
        // Note: no sendSession call.

        let residue = await fx.sovereign.turnResidue(
            sessionID: "ghost.sess", turnID: "ghost.turn")
        XCTAssertFalse(residue.isComplete)
        XCTAssertNil(residue.coverageReading)
        XCTAssertNil(residue.observationBundle)
        XCTAssertNil(residue.sovereignFrame)

        let verification = await fx.sovereign
            .verifyTurnResidue(residue)
        XCTAssertFalse(verification.isValid)
        XCTAssertTrue(
            verification.findings.contains(.missingCoverage))
        XCTAssertTrue(
            verification.findings.contains(
                .missingObservationBundle))
        XCTAssertTrue(
            verification.findings.contains(
                .missingSovereignFrame))
    }

    // MARK: - 3. Synthetic frame with wrong frameID convention

    func testFrameIDConventionDrift() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.drift")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        // Overwrite the recorded frame with a mis-named frameID
        // to simulate a corrupt / drifted aggregator.
        let badFrame = BASSovereignFrame(
            frameID: "mismatch.id.0",  // wrong convention
            sessionID: obs.sessionID,
            turnID: obs.turnID,
            thoughtFoldRef:
                "fold." + obs.sessionID + "." + obs.turnID,
            policyHash: obs.policyHash)
        await fx.sovereign.recordSovereignFrame(badFrame)

        let residue = await fx.sovereign.turnResidue(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let verification = await fx.sovereign
            .verifyTurnResidue(residue)
        XCTAssertFalse(verification.isValid)
        let hasConventionFinding = verification.findings.contains {
            if case .frameIDConventionMismatch(
                let expected, let got) = $0
            {
                return expected == "frame.sess.m124.turn.drift"
                    && got == "mismatch.id.0"
            }
            return false
        }
        XCTAssertTrue(
            hasConventionFinding,
            ".frameIDConventionMismatch must flag bad frameID")
    }

    // MARK: - 4. Synthetic thoughtFoldRef drift

    func testThoughtFoldRefDrift() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.fold-drift")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        // Overwrite with a frame whose thoughtFoldRef drifts.
        let badFrame = BASSovereignFrame(
            frameID: "frame." + obs.sessionID + "." + obs.turnID,
            sessionID: obs.sessionID,
            turnID: obs.turnID,
            thoughtFoldRef: "not.a.fold",
            policyHash: obs.policyHash)
        await fx.sovereign.recordSovereignFrame(badFrame)

        let residue = await fx.sovereign.turnResidue(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let verification = await fx.sovereign
            .verifyTurnResidue(residue)
        let hasRefFinding = verification.findings.contains {
            if case .thoughtFoldRefConventionMismatch(
                let expected, let got) = $0
            {
                return expected ==
                    "fold.sess.m124.turn.fold-drift"
                    && got == "not.a.fold"
            }
            return false
        }
        XCTAssertTrue(
            hasRefFinding,
            ".thoughtFoldRefConventionMismatch must flag drift")
    }

    // MARK: - 5. Session/turn mismatch between bundle and frame

    func testCrossSurfaceSessionTurnMismatchFlagged()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.happy")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        // Swap in a frame that claims a different (session, turn).
        // This is not possible via the normal recordSovereignFrame
        // path (which keys on the frame's own sessionID+turnID) —
        // we call it directly to simulate a corrupt write from a
        // hypothetical external injector.
        //
        // We can't force-mismatch via sendSession, so build a
        // parallel storage scenario manually: record a frame whose
        // sessionID disagrees with the bundle we'll construct the
        // mismatched TurnResidue for.
        let mismatchedFrame = BASSovereignFrame(
            frameID: "frame.other.sess.other.turn",
            sessionID: "other.sess",
            turnID: "other.turn",
            thoughtFoldRef: "fold.other.sess.other.turn",
            policyHash: "p")
        // Manually bundle these inconsistent pieces into a residue
        // and verify — this tests the `verify` function's cross-
        // surface logic independent of how the residue was
        // obtained.
        let residue = QinaoSovereignControlPlane.TurnResidue(
            sessionID: obs.sessionID,
            turnID: obs.turnID,
            coverageReading: await fx.sovereign.coverageReading(
                sessionID: obs.sessionID, turnID: obs.turnID),
            observationBundle:
                await fx.sovereign.observationBundle(
                    sessionID: obs.sessionID,
                    turnID: obs.turnID),
            sovereignFrame: mismatchedFrame)

        let verification = await fx.sovereign
            .verifyTurnResidue(residue)
        XCTAssertFalse(verification.isValid)
        let hasSessionMismatch = verification.findings.contains {
            if case .sessionIDMismatch = $0 { return true }
            return false
        }
        let hasTurnMismatch = verification.findings.contains {
            if case .turnIDMismatch = $0 { return true }
            return false
        }
        XCTAssertTrue(
            hasSessionMismatch,
            ".sessionIDMismatch must fire")
        XCTAssertTrue(
            hasTurnMismatch, ".turnIDMismatch must fire")
    }
}
