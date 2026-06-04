// Host wiring for the multi-round authoritative loop — proves the composition is FUNCTIONAL end-to-end:
// turnResult (decompose + candidates) → fabric input → loop → finalProjection → enriched next request,
// with a REAL fabric runtime. byte-equal-off when observation-only; the enriched turn changes the
// cascade while the sovereign verdict still gates.

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration

#if !os(iOS)
final class BASAgentFabricAuthoritativeTurnTests: XCTestCase {

    private func runtime(mode: BASAgentFabricMode = .authoritative) -> BASAgentFabricRuntime {
        BASAgentFabricRuntime(
            roster: BASAgentTurnRoster(
                scout: BASAgentSpec(agentID: "scout.1", role: .scout, writeDomains: [.situationField],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                planner: BASAgentSpec(agentID: "planner.1", role: .planner, writeDomains: [.candidateFrontier],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                risk: BASAgentSpec(agentID: "risk.1", role: .risk, writeDomains: [.riskField],
                    defaultLeaseProfile: .hotSeat, visibility: .high),
                surface: BASAgentSpec(agentID: "surface.1", role: .surface, writeDomains: [.renderFrame],
                    defaultLeaseProfile: .hotSeat, visibility: .high)),
            graph: BASSharedStateGraph(),
            mode: mode)
    }
    private func decompose() -> BASDecomposeFrame {
        BASDecomposeFrame(pressureSignals: ["urgency", "consequence"], mirrorText: "t")
    }
    private func candidates() -> [BASCandidatePath] {
        [BASCandidatePath(candidateID: "c1", title: "t", actionSummary: "a",
            expectedBenefit: 0.6, expectedCost: 0.3, reversibility: 0.7, confidence: 0.8)]
    }
    private func config(_ maxRounds: Int = 5) -> BASAgentFabricMultiRoundConfig {
        BASAgentFabricMultiRoundConfig(maxRounds: maxRounds, baseTurnID: "T", nowNanos: 1_700_000_000)
    }

    func testLoopResultWithRealFabricProducesProjection() async {
        let r = await BASAgentFabricAuthoritativeTurn.loopResult(
            decomposeFrame: decompose(), candidatePaths: candidates(),
            runtime: runtime(), config: config())
        XCTAssertNotNil(r.finalProjection,
            "the real fabric's seats emit (scout from pressure, planner per candidate) → a usable " +
            "authoritative projection (regression: the projection's delta:-prefix mismatch returned " +
            "nil before the fix)")
        // The content digest is turnID-independent, so the loop CONVERGES with the real fabric (round 2)
        // instead of running to the budget cap on per-round turnID-stamped deltaIDs.
        XCTAssertTrue(r.converged, "stable conclusion content ⇒ the loop converges with the real fabric")
        XCTAssertEqual(r.stopReason, "digest-fixpoint")
        XCTAssertEqual(r.roundsRun, 2, "fixpoint detected on round 2 (content stable from round 0)")
    }

    func testLoopResultIsDeterministic() async {
        func once() async -> BASAgentFabricMultiRoundResult {
            await BASAgentFabricAuthoritativeTurn.loopResult(
                decomposeFrame: decompose(), candidatePaths: candidates(),
                runtime: runtime(), config: config())
        }
        let r1 = await once()
        let r2 = await once()
        XCTAssertEqual(r1.perRoundDigests, r2.perRoundDigests, "fresh-graph runs are deterministic")
        XCTAssertEqual(r1.roundsRun, r2.roundsRun)
        XCTAssertEqual(r1.stopReason, r2.stopReason)
    }

    func testEnrichedNextRequestFoldsConclusions() async throws {
        let next = BASCoordinatorTestStubs.makeStubRequest(userInput: "next prompt")
        let (req, loop) = await BASAgentFabricAuthoritativeTurn.enrichedNextRequest(
            next, decomposeFrame: decompose(), candidatePaths: candidates(),
            runtime: runtime(), config: config())
        XCTAssertNotNil(loop.finalProjection)
        XCTAssertNotEqual(req.userInput, next.userInput,
            "the converged conclusions fold into the next userInput")
        XCTAssertTrue(req.userInput.contains("fabric-authoritative"))
        // The new field is INPUT-only — turnHistory/priorSSMState untouched.
        XCTAssertEqual(req.priorSSMState, next.priorSSMState)
    }

    func testObservationOnlyIsByteEqualOff() async {
        let next = BASCoordinatorTestStubs.makeStubRequest(userInput: "next prompt")
        let (req, loop) = await BASAgentFabricAuthoritativeTurn.enrichedNextRequest(
            next, decomposeFrame: decompose(), candidatePaths: candidates(),
            runtime: runtime(mode: .observationOnly), config: config())
        XCTAssertEqual(req.userInput, next.userInput,
            "observation-only → loop inert → request returned UNCHANGED (byte-equal-off)")
        XCTAssertEqual(loop.stopReason, "mode-inert")
        XCTAssertNil(loop.finalProjection)
    }

    func testEnrichedTurnChangesCascadeAndVerdictStillGates() async throws {
        let next = BASCoordinatorTestStubs.makeStubRequest(userInput: "baseline")
        let (enriched, loop) = await BASAgentFabricAuthoritativeTurn.enrichedNextRequest(
            next, decomposeFrame: decompose(), candidatePaths: candidates(),
            runtime: runtime(), config: config())
        XCTAssertNotNil(loop.finalProjection)

        let brainA = try await BASCognitiveBrain.makeWithDefaults()
        let brainB = try await BASCognitiveBrain.makeWithDefaults()
        let plain = await brainA.process(next.userInput)
        let enrichedTurn = await brainB.process(enriched.userInput)
        XCTAssertNotEqual(plain.decomposeFrame, enrichedTurn.decomposeFrame,
            "the loop's converged conclusions change what the cascade derives")
        XCTAssertNotNil(enrichedTurn.sovereignVerdict,
            "the sovereign verdict still runs on the enriched turn (input-class, sole authority)")
    }
}
#endif
