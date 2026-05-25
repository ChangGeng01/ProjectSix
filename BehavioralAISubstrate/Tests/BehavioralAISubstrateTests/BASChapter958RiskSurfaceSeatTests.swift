// MARK: - BASChapter958RiskSurfaceSeatTests
// chapter 九百五十八 / M3495 — Phase 1 ch3:Risk + Surface seat tests
//
// Same pure-fn + slim-DTO pattern as ch 957 Scout/Planner。 These
// tests pin:
//
//   Risk:
//     - Zero-candidate input → zero deltas
//     - Per-candidate delta emission with confidence by band
//     - 6 risk-assessment rule branches (manipulation / boundary
//       irreversible / boundary med / pressure irreversible /
//       reversibility low / baseline clear)
//     - Reason codes accumulate correctly
//     - Deterministic JSON payload
//
//   Surface:
//     - Always emits exactly one delta (no zero-delta path)
//     - 7 mode-picker rule branches (sovereign / permit /
//       risk-high-irreversible / risk-high-reversible / risk-med-
//       irreversible / user-compare / accepted / no-candidate)
//     - Mode → confidence mapping
//     - Deterministic JSON payload incl. nullable candidate_id
//
//   Combined: Scout+Planner+Risk+Surface in one turn → 4 seats
//     all emit successfully through the merge engine + applier。

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter958RiskSurfaceSeatTests: XCTestCase {

    // MARK: - Helpers

    private func riskAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "risk.1",
            role: .risk,
            writeDomains: [.riskField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }

    private func surfaceAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "surface.1",
            role: .surface,
            writeDomains: [.renderFrame],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }

    // MARK: - Risk seat

    func testRisk_EmptyCandidatesEmitsZero() {
        let input = BASRiskInput()
        var seq = 0
        let deltas = BASRiskSeat.emit(
            from: input,
            turnID: "t1",
            agentSpec: riskAgent(),
            seq: &seq)
        XCTAssertEqual(deltas.count, 0,
            "ch 958: no candidates → zero risk deltas")
    }

    func testRisk_ManipulationDetectedAlwaysHigh() {
        // Even safe (high reversibility) candidate → HIGH risk
        // when manipulation is in the situation field
        let input = BASRiskInput(
            candidates: [BASRiskCandidate(
                candidateID: "c1",
                reversibility: 0.99)],
            manipulationDetected: true)
        var seq = 0
        let d = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq)
        XCTAssertEqual(d.count, 1)
        // Confidence for HIGH band = 0.95
        XCTAssertEqual(d[0].confidence, 0.95, accuracy: 0.001)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "risk.manipulation-detected"))
        XCTAssertTrue(d[0].reasonCodes.contains(
            "risk.elevation=manipulation"))
        XCTAssertTrue(d[0].patchJson.contains("\"band\":\"high\""))
    }

    func testRisk_BoundaryIrreversibleIsHigh() {
        let input = BASRiskInput(
            candidates: [BASRiskCandidate(
                candidateID: "c1",
                reversibility: 0.2)],  // < 0.5
            boundaryTouched: true)
        var seq = 0
        let d = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.95)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "risk.elevation=boundary-irreversible"))
    }

    func testRisk_BoundaryReversibleIsMedium() {
        let input = BASRiskInput(
            candidates: [BASRiskCandidate(
                candidateID: "c1",
                reversibility: 0.8)],
            boundaryTouched: true)
        var seq = 0
        let d = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.75)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"band\":\"medium\""))
    }

    func testRisk_PressureIrreversibleIsHigh() {
        let input = BASRiskInput(
            candidates: [BASRiskCandidate(
                candidateID: "c1",
                reversibility: 0.2)],
            pressureLevel: 0.9)  // ≥ 0.8
        var seq = 0
        let d = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.95)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "risk.elevation=pressure"))
    }

    func testRisk_LowReversibilityIsMedium() {
        let input = BASRiskInput(
            candidates: [BASRiskCandidate(
                candidateID: "c1",
                reversibility: 0.2)])
        var seq = 0
        let d = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.75)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "risk.reversibility-low"))
    }

    func testRisk_BaselineClearIsLow() {
        let input = BASRiskInput(
            candidates: [BASRiskCandidate(
                candidateID: "c1",
                reversibility: 0.9)])
        var seq = 0
        let d = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq)
        XCTAssertEqual(d[0].confidence, 0.55)
        XCTAssertTrue(d[0].reasonCodes.contains(
            "risk.baseline-clear"))
        XCTAssertTrue(d[0].patchJson.contains("\"band\":\"low\""))
    }

    func testRisk_MultipleCandidatesIndependent() {
        // 3 candidates, mixed risk — each gets own delta
        let input = BASRiskInput(candidates: [
            BASRiskCandidate(
                candidateID: "safe",
                reversibility: 0.9),
            BASRiskCandidate(
                candidateID: "risky",
                reversibility: 0.1),
            BASRiskCandidate(
                candidateID: "irreversible",
                reversibility: 0.05),
        ])
        var seq = 100
        let d = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq)
        XCTAssertEqual(d.count, 3)
        XCTAssertEqual(seq, 103)
        // IDs preserve sequence
        XCTAssertEqual(d[0].deltaID, "delta.t1.risk.101")
        XCTAssertEqual(d[1].deltaID, "delta.t1.risk.102")
        XCTAssertEqual(d[2].deltaID, "delta.t1.risk.103")
        // Distinct target refs (per candidate)
        XCTAssertEqual(
            d[0].targetObjectRef, "riskField#rf-t1-safe")
        XCTAssertEqual(
            d[1].targetObjectRef, "riskField#rf-t1-risky")
        XCTAssertEqual(
            d[2].targetObjectRef,
            "riskField#rf-t1-irreversible")
    }

    func testRisk_DeterministicPayload() {
        let input = BASRiskInput(
            candidates: [BASRiskCandidate(
                candidateID: "c1",
                reversibility: 0.5,
                expectedBenefit: 0.8,
                expectedCost: 0.3)],
            pressureLevel: 0.5,
            manipulationDetected: false,
            boundaryTouched: false)
        var seq1 = 0, seq2 = 0
        let d1 = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq1)
        let d2 = BASRiskSeat.emit(
            from: input, turnID: "t1",
            agentSpec: riskAgent(), seq: &seq2)
        XCTAssertEqual(d1, d2,
            "ch 958: deterministic risk payload across calls")
    }

    // MARK: - Surface seat

    func testSurface_SovereignVetoBlocks() {
        let input = BASSurfaceInput(
            acceptedCandidateID: "c1",
            actionPermitGranted: true,
            riskBand: .low,
            sovereignVetoed: true)
        var seq = 0
        let d = BASSurfaceSeat.emit(
            from: input, turnID: "t1",
            agentSpec: surfaceAgent(), seq: &seq)
        XCTAssertEqual(d.count, 1)
        XCTAssertTrue(d[0].patchJson.contains("\"mode\":\"block\""))
        XCTAssertTrue(d[0].reasonCodes.contains(
            "surface.sovereign-veto"))
        XCTAssertEqual(d[0].confidence, 0.95)
    }

    func testSurface_PermitDeniedBlocks() {
        let input = BASSurfaceInput(
            acceptedCandidateID: "c1",
            actionPermitGranted: false,
            riskBand: .low)
        var seq = 0
        let d = BASSurfaceSeat.emit(
            from: input, turnID: "t1",
            agentSpec: surfaceAgent(), seq: &seq)
        XCTAssertTrue(d[0].patchJson.contains("\"mode\":\"block\""))
        XCTAssertTrue(d[0].reasonCodes.contains(
            "surface.permit-denied"))
    }

    func testSurface_HighRiskIrreversibleBlocks() {
        let input = BASSurfaceInput(
            acceptedCandidateID: "c1",
            riskBand: .high,
            reversibility: 0.3)  // < 0.7
        var seq = 0
        let d = BASSurfaceSeat.emit(
            from: input, turnID: "t1",
            agentSpec: surfaceAgent(), seq: &seq)
        XCTAssertTrue(d[0].patchJson.contains("\"mode\":\"block\""))
        XCTAssertTrue(d[0].reasonCodes.contains(
            "surface.risk-high-irreversible"))
    }

    func testSurface_HighRiskReversibleDelays() {
        let input = BASSurfaceInput(
            acceptedCandidateID: "c1",
            riskBand: .high,
            reversibility: 0.85)  // ≥ 0.7
        var seq = 0
        let d = BASSurfaceSeat.emit(
            from: input, turnID: "t1",
            agentSpec: surfaceAgent(), seq: &seq)
        XCTAssertTrue(d[0].patchJson.contains("\"mode\":\"delay\""))
        XCTAssertTrue(d[0].reasonCodes.contains(
            "surface.risk-high-but-reversible"))
        XCTAssertEqual(d[0].confidence, 0.8)
    }

    func testSurface_MediumIrreversibleDelays() {
        let input = BASSurfaceInput(
            acceptedCandidateID: "c1",
            riskBand: .medium,
            reversibility: 0.3)
        var seq = 0
        let d = BASSurfaceSeat.emit(
            from: input, turnID: "t1",
            agentSpec: surfaceAgent(), seq: &seq)
        XCTAssertTrue(d[0].patchJson.contains("\"mode\":\"delay\""))
    }

    func testSurface_UserRequestedCompare() {
        let input = BASSurfaceInput(
            acceptedCandidateID: "c1",
            riskBand: .low,
            userRequestsCompare: true)
        var seq = 0
        let d = BASSurfaceSeat.emit(
            from: input, turnID: "t1",
            agentSpec: surfaceAgent(), seq: &seq)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"mode\":\"compare\""))
        XCTAssertEqual(d[0].confidence, 0.85)
    }

    func testSurface_AcceptedCandidateAnswers() {
        let input = BASSurfaceInput(
            acceptedCandidateID: "c1",
            riskBand: .low)
        var seq = 0
        let d = BASSurfaceSeat.emit(
            from: input, turnID: "t1",
            agentSpec: surfaceAgent(), seq: &seq)
        XCTAssertTrue(d[0].patchJson.contains("\"mode\":\"answer\""))
        XCTAssertEqual(d[0].confidence, 0.7)
    }

    func testSurface_NoCandidateSilentStub() {
        let input = BASSurfaceInput(
            acceptedCandidateID: nil,
            riskBand: .low)
        var seq = 0
        let d = BASSurfaceSeat.emit(
            from: input, turnID: "t1",
            agentSpec: surfaceAgent(), seq: &seq)
        XCTAssertTrue(d[0].patchJson.contains(
            "\"mode\":\"silentStub\""))
        XCTAssertTrue(d[0].patchJson.contains(
            "\"candidate_id\":null"))
        XCTAssertEqual(d[0].confidence, 0.95)
    }

    func testSurface_AlwaysEmitsExactlyOneDelta() {
        // Surface invariant:always exactly 1 delta per turn
        let inputs: [BASSurfaceInput] = [
            BASSurfaceInput(),
            BASSurfaceInput(acceptedCandidateID: "c1"),
            BASSurfaceInput(sovereignVetoed: true),
            BASSurfaceInput(
                acceptedCandidateID: "c1",
                riskBand: .high),
        ]
        for (i, input) in inputs.enumerated() {
            var seq = 0
            let d = BASSurfaceSeat.emit(
                from: input,
                turnID: "t\(i)",
                agentSpec: surfaceAgent(),
                seq: &seq)
            XCTAssertEqual(d.count, 1,
                "ch 958: input \(i) must emit exactly 1 delta")
            XCTAssertEqual(d[0].deltaType, .replace,
                "ch 958: render frame is singleton — type=.replace")
        }
    }

    // MARK: - All-4-seats combined end-to-end

    /// Realistic scenario: Scout + Planner + Risk + Surface all
    /// emit in one turn,merge engine accepts all (no conflicts),
    /// applier writes everything to graph。 Proves the full Phase 1
    /// seat layer works as a unit。
    func testCombined_AllFourSeatsInOneTurn() async throws {
        let scout = BASAgentSpec(
            agentID: "scout.1", role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let planner = BASAgentSpec(
            agentID: "planner.1", role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
        let risk = riskAgent()
        let surface = surfaceAgent()
        let agents: [String: BASAgentSpec] = [
            "scout.1": scout,
            "planner.1": planner,
            "risk.1": risk,
            "surface.1": surface,
        ]
        // Inputs reflecting a moderate-pressure turn with one
        // safe candidate
        let scoutInput = BASScoutInput(
            pressureSignals: ["work.deadline"])
        let candidate = BASPlannerCandidate(
            candidateID: "c1", title: "Suggest break",
            actionSummary: "Take a 5-min break",
            confidence: 0.8,
            expectedBenefit: 0.7,
            expectedCost: 0.1,
            reversibility: 0.95)
        let riskInput = BASRiskInput(
            candidates: [BASRiskCandidate(
                candidateID: "c1",
                reversibility: 0.95,
                expectedBenefit: 0.7,
                expectedCost: 0.1)],
            pressureLevel: 0.6)
        let surfaceInput = BASSurfaceInput(
            acceptedCandidateID: "c1",
            actionPermitGranted: true,
            riskBand: .low,
            reversibility: 0.95)
        // Emit from all 4 seats with shared seq counter
        var seq = 0
        var deltas: [BASAgentDelta] = []
        deltas.append(contentsOf: BASScoutSeat.emit(
            from: scoutInput, turnID: "t1",
            agentSpec: scout, seq: &seq))
        deltas.append(contentsOf: BASPlannerSeat.emit(
            from: [candidate], turnID: "t1",
            agentSpec: planner, seq: &seq))
        deltas.append(contentsOf: BASRiskSeat.emit(
            from: riskInput, turnID: "t1",
            agentSpec: risk, seq: &seq))
        deltas.append(contentsOf: BASSurfaceSeat.emit(
            from: surfaceInput, turnID: "t1",
            agentSpec: surface, seq: &seq))
        // 1 scout (pressure) + 1 planner + 1 risk + 1 surface = 4
        XCTAssertEqual(deltas.count, 4,
            "ch 958: 4 seats × 1 emission each = 4 deltas")
        // All unique IDs across seats
        let ids = Set(deltas.map { $0.deltaID })
        XCTAssertEqual(ids.count, 4)
        // Merge: all 4 different targets → all accepted
        let result = BASAgentMergeEngine.merge(
            deltas,
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertEqual(result.acceptedDeltaIDs.count, 4)
        XCTAssertTrue(result.rejectedDeltaIDs.isEmpty)
        // Apply to graph — 4 state objects in 4 domains
        let graph = BASSharedStateGraph()
        let outcomes = await BASAgentMergeApplier.apply(
            mergeResult: result,
            deltas: deltas,
            agents: agents,
            graph: graph)
        let appliedCount = outcomes.filter { $0.applied }.count
        XCTAssertEqual(appliedCount, 4,
            "ch 958: all 4 deltas applied successfully")
        let objectCount = await graph.objectCount()
        XCTAssertEqual(objectCount, 4)
        // Verify each agent claimed its expected domain
        let scoutWriter = await graph.writerForDomain(
            .situationField)
        XCTAssertEqual(scoutWriter, "scout.1")
        let plannerWriter = await graph.writerForDomain(
            .candidateFrontier)
        XCTAssertEqual(plannerWriter, "planner.1")
        let riskWriter = await graph.writerForDomain(
            .riskField)
        XCTAssertEqual(riskWriter, "risk.1")
        let surfaceWriter = await graph.writerForDomain(
            .renderFrame)
        XCTAssertEqual(surfaceWriter, "surface.1")
    }
}
