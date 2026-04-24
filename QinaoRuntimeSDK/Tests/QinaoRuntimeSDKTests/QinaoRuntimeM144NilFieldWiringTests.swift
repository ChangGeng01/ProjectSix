import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASPolicy
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M144 — fill remaining nil fields on sovereignFrame +
/// renderFrame from the caller-supplied `thoughtFrame`'s
/// `riskCard` / `actionPermit` / `agencyReservation`.
///
/// Neither BASRiskCard, BASActionPermit, nor BASAgencyReservation
/// carries a natural stable ID in its schema, so M144 synthesizes
/// deterministic refs of the form `"<prefix>.<sessionID>.<turnID>"`
/// when the corresponding object is present.
///
/// Pins:
///   1. thoughtFrame without riskCard/permit/reservation → all
///      three nil on both frames (backward-compat identity).
///   2. thoughtFrame with riskCard → sovereignFrame.riskCardRef
///      populated with synthetic ref.
///   3. thoughtFrame with actionPermit → BOTH frames'
///      actionPermitRef populated with same synthetic ref
///      (sovereign + render agree).
///   4. thoughtFrame with agencyReservation → renderFrame's
///      agencyReservationRef populated.
///   5. No thoughtFrame → all three fields stay nil on both
///      frames.
final class QinaoRuntimeM144NilFieldWiringTests: XCTestCase {

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
            hostID: "host.m144",
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

    private func obs(
        sessionID: String = "sess.m144",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    private func makeThoughtFrame(
        withRisk: Bool = false,
        withPermit: Bool = false,
        withReservation: Bool = false
    ) -> BASThoughtFrame {
        let card: BASRiskCard? = withRisk
            ? BASRiskCard(
                totalRisk: 0.3,
                riskLevel: .medium,
                factors: [],
                uncertainty: 0.2,
                irreversibility: 0.1,
                manipulationStrength: 0.0,
                gsiScore: 0.0,
                recommendedMode: .answer,
                stackedModes: [],
                assertionCeiling: "")
            : nil
        let permit: BASActionPermit? = withPermit
            ? BASActionPermit(
                mode: .answer,
                assertionCeiling: "",
                toolScope: "",
                memoryScope: "",
                outputLengthCap: 0,
                tonePolicy: "",
                templatePolicy: "")
            : nil
        let reservation: BASAgencyReservation? = withReservation
            ? BASAgencyReservation(mode: .retainChoice)
            : nil
        return BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "decomp.m144",
            riskCard: card,
            actionPermit: permit,
            agencyReservation: reservation,
            stabilityScore: 0.7)
    }

    // MARK: - 1. No thoughtFrame → all three fields nil

    func testNoThoughtFrameLeavesAllRefsNil() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.nil")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertNil(sf?.riskCardRef)
        XCTAssertNil(sf?.actionPermitRef)
        XCTAssertNil(rf?.actionPermitRef)
        XCTAssertNil(rf?.agencyReservationRef)
    }

    // MARK: - 2. riskCard present → sovereignFrame.riskCardRef set

    func testRiskCardPopulatesRiskCardRef() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.risk")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeThoughtFrame(withRisk: true))
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(
            sf?.riskCardRef,
            "risk-card.sess.m144.turn.risk",
            "synthetic ref deterministic per (sess, turn)")
    }

    // MARK: - 3. actionPermit → BOTH frames agree on ref

    func testActionPermitPopulatesBothFramesConsistently()
        async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.permit")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeThoughtFrame(withPermit: true))
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        let expected = "permit.sess.m144.turn.permit"
        XCTAssertEqual(sf?.actionPermitRef, expected)
        XCTAssertEqual(rf?.actionPermitRef, expected)
        XCTAssertEqual(
            sf?.actionPermitRef, rf?.actionPermitRef,
            "sovereign and render agree on permit ref")
    }

    // MARK: - 4. agencyReservation → renderFrame only

    func testAgencyReservationPopulatesRenderFrame() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.agency")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeThoughtFrame(
                withReservation: true))
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(
            rf?.agencyReservationRef,
            "agency-reservation.sess.m144.turn.agency")
    }

    // MARK: - 5. All three present → all three populated

    func testAllThreeSourcesPopulateAllThreeRefs() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.all")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: makeThoughtFrame(
                withRisk: true,
                withPermit: true,
                withReservation: true))
        let sf = await fx.sovereign.sovereignFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertNotNil(sf?.riskCardRef)
        XCTAssertNotNil(sf?.actionPermitRef)
        XCTAssertNotNil(rf?.actionPermitRef)
        XCTAssertNotNil(rf?.agencyReservationRef)
    }
}
