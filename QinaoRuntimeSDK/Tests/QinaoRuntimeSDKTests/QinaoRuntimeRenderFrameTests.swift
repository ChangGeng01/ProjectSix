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

/// M127 — 皮肤扩深: `BASRenderFrame` per-turn build.
///
/// M117 shipped 17 L12 surface types; M125 activated 5 of them
/// (BASSurfaceDecision + 4 axis enums). M127 activates `BASRenderFrame`
/// — the 13-ref L12 aggregator — by building one per healthy turn
/// and recording it on `QinaoSovereignControlPlane` parallel
/// storage. 7 of 13 refs are populated deterministically; 5 remain
/// nil with documented future-wiring hooks (actionPermitRef,
/// agencyReservationRef, situationRef, mirrorRef, toneProfileRef,
/// forceCurveRef).
///
/// Pins:
///   1. Every healthy turn records a render frame.
///   2. frameID convention "render.<session>.<turn>".
///   3. mergedChoiceRef == L3 fold's "fold.<session>.<turn>".
///   4. hostStyleRef == L5 constitution.activeVersion.
///   5. sovereignSurfaceRef back-references the sovereign frame's
///      frameID (render→sovereign link).
///   6. outputSurfaceRef / disclosureProfileRef / substituteRef all
///      match the surface decision's projection.
///   7. Re-emit replaces in place (LWW).
final class QinaoRuntimeRenderFrameTests: XCTestCase {

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
            hostID: "host.m127",
            activeVersion: "host.v3")
        let tree = BASHostVersionTree(
            activeVersionID: "host.v3",
            versions: [
                BASHostVersion(
                    versionID: "host.v3",
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
        sessionID: String = "sess.m127",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m127",
            policyHash: "policy.m127")
    }

    // MARK: - 1. Healthy turn records render frame

    func testHealthyTurnRecordsRenderFrame() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.record")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let rf = await fx.sovereign.renderFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(
            rf,
            "healthy turn must produce a BASRenderFrame")
    }

    // MARK: - 2. frameID convention

    func testRenderFrameIDConvention() async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.convention",
            turnID: "turn.convention")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let rfOpt = await fx.sovereign.renderFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let rf = try XCTUnwrap(rfOpt)
        XCTAssertEqual(
            rf.frameID,
            "render.sess.convention.turn.convention",
            "frameID = 'render.<session>.<turn>'")
    }

    // MARK: - 3. mergedChoiceRef → L3 fold

    func testMergedChoiceRefMatchesL3FoldID() async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.m3",
            turnID: "turn.m3")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let rfOpt = await fx.sovereign.renderFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let rf = try XCTUnwrap(rfOpt)
        XCTAssertEqual(
            rf.mergedChoiceRef,
            "fold.sess.m3.turn.m3",
            "mergedChoiceRef = L3 fold's deterministic foldID")
    }

    // MARK: - 4. hostStyleRef → L5 constitution.activeVersion

    func testHostStyleRefMatchesActiveVersion() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.style")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let rfOpt = await fx.sovereign.renderFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let rf = try XCTUnwrap(rfOpt)
        XCTAssertEqual(
            rf.hostStyleRef, "host.v3",
            "hostStyleRef = L5 constitution.activeVersion")
    }

    // MARK: - 5. sovereignSurfaceRef back-references sovereign frame

    func testSovereignSurfaceRefMatchesSovereignFrameID()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.sovlink")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let rfOpt = await fx.sovereign.renderFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let rf = try XCTUnwrap(rfOpt)
        let sfOpt = await fx.sovereign.sovereignFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let sf = try XCTUnwrap(sfOpt)
        XCTAssertEqual(
            rf.sovereignSurfaceRef, sf.frameID,
            "render→sovereign link must be the frameID")
    }

    // MARK: - 6. outputSurfaceRef / disclosure / substitute refs

    func testSurfaceDecisionDerivedRefs() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.refs")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let rfOpt = await fx.sovereign.renderFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let rf = try XCTUnwrap(rfOpt)
        // Healthy .pass → draftShell surface / user-affirm agency /
        // {minimal|reasoned} disclosure / .render substitute.
        XCTAssertEqual(rf.outputSurfaceRef, "draft-shell")
        // Substitute kind raw value for .render == "render"
        XCTAssertEqual(rf.substituteRef, "render")
        // Disclosure profile ref is either minimal or reasoned for
        // healthy path (coverage-dependent); both are valid.
        XCTAssertTrue(
            rf.disclosureProfileRef == "minimal"
                || rf.disclosureProfileRef == "reasoned",
            "disclosure profile ∈ {minimal, reasoned}")
    }

    // MARK: - 7. Re-emit replaces in place (LWW)

    func testReEmitReplacesRenderFrameInPlace() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.rewrite")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let c1 = await fx.sovereign.renderFrameCount()

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let c2 = await fx.sovereign.renderFrameCount()

        XCTAssertEqual(c1, c2, "re-emit must not accrete")
        XCTAssertEqual(c1, 1, "one frame per (sess, turn)")
    }

    // MARK: - 8. Nil refs stay nil (documented future-wiring)

    func testFiveRefsStayNilPerDocumentedScope() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.nils")

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let rfOpt = await fx.sovereign.renderFrame(
            sessionID: obs.sessionID, turnID: obs.turnID)
        let rf = try XCTUnwrap(rfOpt)
        // 5 refs stay nil pending future wiring:
        XCTAssertNil(
            rf.actionPermitRef,
            "actionPermitRef — future M127+n permit wiring")
        XCTAssertNil(
            rf.agencyReservationRef,
            "agencyReservationRef — future L11 wiring")
        XCTAssertNil(
            rf.situationRef,
            "situationRef — future L7 wiring")
        XCTAssertNil(
            rf.mirrorRef,
            "mirrorRef — future L7 mirror-blade wiring")
        XCTAssertNil(
            rf.toneProfileRef,
            "toneProfileRef — future L12 tone engine")
        XCTAssertNil(
            rf.forceCurveRef,
            "forceCurveRef — future L12 force-curve engine")
    }
}
