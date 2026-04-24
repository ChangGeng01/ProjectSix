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

/// M148 — wire remaining 4 `BASRenderFrame` optional fields:
/// situationRef / mirrorRef / toneProfileRef / forceCurveRef.
/// Closes self-critique #6 on the render side.
///
/// Pins:
///   1. No source params → all 4 fields nil
///   2. decomposeFrame → situationRef populated (synthetic)
///   3. decomposeFrame with mirrorDraft → mirrorRef populated
///   4. renderedOutput → toneProfileRef populated
///   5. renderedOutput + thoughtFrame.riskCard → forceCurveRef
///      populated (joint gate)
///   6. All sources present → all 4 populated
final class QinaoRuntimeM148RenderNilsTests: XCTestCase {

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
            hostID: "host.m148",
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
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m148",
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    func testNoSourceParamsLeavesAllFourNil() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.none")
        _ = try await fx.runtime.sendSession(
            o, coordinatorSeverity: .pass)
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertNil(rf?.situationRef)
        XCTAssertNil(rf?.mirrorRef)
        XCTAssertNil(rf?.toneProfileRef)
        XCTAssertNil(rf?.forceCurveRef)
    }

    func testDecomposeFramePopulatesSituation() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.situ")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            decomposeFrame: BASDecomposeFrame(
                facts: ["f1"], goals: ["g1"]))
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(
            rf?.situationRef,
            "situation.sess.m148.turn.situ")
    }

    func testDecomposeFrameWithMirrorPopulatesMirrorRef()
        async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.mir")
        let draft = BASMirrorDraft(
            draftID: "draft.x",
            mode: .soft,
            summary: "summary",
            toneGuard: "neutral")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            decomposeFrame: BASDecomposeFrame(
                mirrorText: "test",
                mirrorDraft: draft))
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(
            rf?.mirrorRef,
            "mirror.sess.m148.turn.mir")
    }

    func testRenderedOutputPopulatesToneRef() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.tone")
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            thoughtFrame: BASThoughtFrame(
                stepIndex: 0, decomposeRef: "d",
                stabilityScore: 0.5),
            renderedOutput: BASRenderedOutput(
                mode: .answer,
                headline: "h",
                body: "b"))
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertEqual(
            rf?.toneProfileRef,
            "tone.sess.m148.turn.tone")
    }

    func testForceCurveRefJointGate() async throws {
        let fx = await makeRuntime()
        // renderedOutput WITHOUT risk card → no forceCurveRef
        let o1 = obs(turnID: "turn.no-risk")
        _ = try await fx.runtime.sendSession(
            o1,
            coordinatorSeverity: .pass,
            thoughtFrame: BASThoughtFrame(
                stepIndex: 0, decomposeRef: "d",
                stabilityScore: 0.5),
            renderedOutput: BASRenderedOutput(
                mode: .answer, headline: "h", body: "b"))
        let rf1 = await fx.sovereign.renderFrame(
            sessionID: o1.sessionID, turnID: o1.turnID)
        XCTAssertNil(
            rf1?.forceCurveRef,
            "no risk card → no forceCurve joint gate")

        // renderedOutput WITH risk card → forceCurveRef populated
        let o2 = obs(turnID: "turn.with-risk")
        let card = BASRiskCard(
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
        _ = try await fx.runtime.sendSession(
            o2,
            coordinatorSeverity: .pass,
            thoughtFrame: BASThoughtFrame(
                stepIndex: 0, decomposeRef: "d",
                riskCard: card, stabilityScore: 0.5),
            renderedOutput: BASRenderedOutput(
                mode: .answer, headline: "h", body: "b"))
        let rf2 = await fx.sovereign.renderFrame(
            sessionID: o2.sessionID, turnID: o2.turnID)
        XCTAssertEqual(
            rf2?.forceCurveRef,
            "force-curve.sess.m148.turn.with-risk")
    }

    func testAllFourWithFullSources() async throws {
        let fx = await makeRuntime()
        let o = obs(turnID: "turn.all")
        let draft = BASMirrorDraft(
            draftID: "d.x",
            mode: .soft,
            summary: "",
            toneGuard: "neutral")
        let card = BASRiskCard(
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
        _ = try await fx.runtime.sendSession(
            o,
            coordinatorSeverity: .pass,
            contextFrame: nil,
            decomposeFrame: BASDecomposeFrame(
                mirrorText: "t", mirrorDraft: draft),
            memoryBundle: nil,
            thoughtFrame: BASThoughtFrame(
                stepIndex: 0, decomposeRef: "d",
                riskCard: card, stabilityScore: 0.5),
            updateTickets: [],
            neuralOrganMap: nil,
            renderedOutput: BASRenderedOutput(
                mode: .answer, headline: "h", body: "b"))
        let rf = await fx.sovereign.renderFrame(
            sessionID: o.sessionID, turnID: o.turnID)
        XCTAssertNotNil(rf?.situationRef)
        XCTAssertNotNil(rf?.mirrorRef)
        XCTAssertNotNil(rf?.toneProfileRef)
        XCTAssertNotNil(rf?.forceCurveRef)
    }
}
