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

    // M155 — migrated to shared QinaoTestFixture.


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
        let fx = await QinaoTestFixture.make(hostID: "host.m148")
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
        let fx = await QinaoTestFixture.make(hostID: "host.m148")
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
            // M163 — percent-escaped per syntheticRef convention.
            "situation.sess%2Em148.turn%2Esitu")
    }

    func testDecomposeFrameWithMirrorPopulatesMirrorRef()
        async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m148")
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
            // M163 — percent-escaped per syntheticRef convention.
            "mirror.sess%2Em148.turn%2Emir")
    }

    func testRenderedOutputPopulatesToneRef() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m148")
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
            // M163 — percent-escaped per syntheticRef convention.
            "tone.sess%2Em148.turn%2Etone")
    }

    func testForceCurveRefJointGate() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m148")
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
            // M163 — percent-escaped per syntheticRef convention.
            "force-curve.sess%2Em148.turn%2Ewith-risk")
    }

    func testAllFourWithFullSources() async throws {
        let fx = await QinaoTestFixture.make(hostID: "host.m148")
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
