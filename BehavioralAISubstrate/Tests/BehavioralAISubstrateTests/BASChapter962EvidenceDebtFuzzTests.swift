// MARK: - BASChapter962EvidenceDebtFuzzTests
// chapter 九百六十二 / M3515 — Phase 2 close tests
//
// Tests for:
//   - BASAgentEvidenceDebt struct + derive(emitted:memoryInput:criticInput:)
//   - BASAgentTurnResult.evidenceDebt field
//   - Dispatcher computes evidence-debt at turn end
//   - 7 adversarial fuzz scenarios all dispatch deterministically
//     without crashing + produce sensible evidence-debt summaries
//
// These tests serve double duty:
//   1. Pin evidence-debt invariants for cross-turn consumers
//   2. Validate the 6-seat dispatcher under realistic adversarial
//      input shapes (Phase 2 close validation per the plan)

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter962EvidenceDebtFuzzTests: XCTestCase {

    // MARK: - BASAgentEvidenceDebt basics

    func testEvidenceDebt_EmptyDefault() {
        let e = BASAgentEvidenceDebt.empty
        XCTAssertTrue(e.memoryEpisodeArcs.isEmpty)
        XCTAssertTrue(e.memoryConflictClusters.isEmpty)
        XCTAssertTrue(e.critiqueByCandidateID.isEmpty)
        XCTAssertEqual(e.aggregateCritiquePressure, 0.0)
        XCTAssertEqual(e.memoryDeltaCount, 0)
        XCTAssertEqual(e.criticDeltaCount, 0)
    }

    func testEvidenceDebt_NoMemoryNoCritic_AllZero() {
        let debt = BASAgentEvidenceDebt.derive(
            emitted: [],
            memoryInput: nil,
            criticInput: nil)
        XCTAssertEqual(debt, .empty)
    }

    func testEvidenceDebt_MemoryOnly_PopulatesArcs() {
        let mem = BASMemorySeatInput(
            episodeArcs: ["arc-c", "arc-a", "arc-b"],
            conflictClusters: ["cl-1"],
            continuityAnchors: ["anchor-z"],
            recallStrength: 0.7)
        let mockMemoryDelta = BASAgentDelta(
            deltaID: "delta.t1.memory.1",
            agentID: "mem.1",
            targetObjectRef:
                "memoryBundle#episodes-t1",
            deltaType: .merge,
            confidence: 0.7)
        let debt = BASAgentEvidenceDebt.derive(
            emitted: [mockMemoryDelta],
            memoryInput: mem,
            criticInput: nil)
        // IDs sorted in output for determinism
        XCTAssertEqual(
            debt.memoryEpisodeArcs,
            ["arc-a", "arc-b", "arc-c"])
        XCTAssertEqual(
            debt.memoryConflictClusters, ["cl-1"])
        XCTAssertEqual(
            debt.memoryContinuityAnchors, ["anchor-z"])
        XCTAssertEqual(debt.memoryDeltaCount, 1)
        XCTAssertEqual(debt.criticDeltaCount, 0)
        XCTAssertEqual(
            debt.aggregateCritiquePressure, 0.0)
    }

    func testEvidenceDebt_CriticDeltasPopulateSeverityMap() {
        let critic = BASCriticSeatInput(
            candidates: [
                BASCriticCandidate(
                    candidateID: "c1", title: "t",
                    expectedBenefit: 0.1,
                    expectedCost: 0.5,  // severe (cost > 2× benefit)
                    reversibility: 0.5),
                BASCriticCandidate(
                    candidateID: "c2", title: "t",
                    expectedBenefit: 0.9,
                    expectedCost: 0.05,  // no concern
                    reversibility: 0.9),
            ])
        // Mock the Critic delta as it would be emitted
        let mockCriticDelta = BASAgentDelta(
            deltaID: "delta.t1.critic.1",
            agentID: "crit.1",
            targetObjectRef:
                "critiqueField#cf-t1-c1",
            deltaType: .merge,
            patchJson:
                "{\"candidate_id\":\"c1\"," +
                "\"severity\":\"severe\"," +
                "\"benefit\":0.100000," +
                "\"cost\":0.500000," +
                "\"reversibility\":0.500000," +
                "\"superego_level\":0.500000}",
            confidence: 0.95)
        let debt = BASAgentEvidenceDebt.derive(
            emitted: [mockCriticDelta],
            memoryInput: nil,
            criticInput: critic)
        XCTAssertEqual(
            debt.critiqueByCandidateID["c1"], .severe)
        XCTAssertNil(
            debt.critiqueByCandidateID["c2"],
            "ch 962: no delta for c2 → no entry in map")
        // 1 of 2 candidates is concerning + severe → 0.5
        XCTAssertEqual(
            debt.aggregateCritiquePressure,
            0.5, accuracy: 0.001)
        XCTAssertEqual(debt.criticDeltaCount, 1)
    }

    func testEvidenceDebt_AggregatePressureCappedTo1() {
        // All 3 candidates are SEVERE/STRONG → pressure = 1.0
        let critic = BASCriticSeatInput(candidates:
            (1...3).map { i in
                BASCriticCandidate(
                    candidateID: "c\(i)", title: "t",
                    expectedBenefit: 0.1,
                    expectedCost: 0.5,
                    reversibility: 0.5)
            })
        let deltas = (1...3).map { i in
            BASAgentDelta(
                deltaID: "delta.t1.critic.\(i)",
                agentID: "crit.1",
                targetObjectRef:
                    "critiqueField#cf-t1-c\(i)",
                deltaType: .merge,
                patchJson:
                    "{\"candidate_id\":\"c\(i)\"," +
                    "\"severity\":\"severe\"}",
                confidence: 0.95)
        }
        let debt = BASAgentEvidenceDebt.derive(
            emitted: deltas,
            memoryInput: nil,
            criticInput: critic)
        XCTAssertEqual(
            debt.aggregateCritiquePressure, 1.0,
            accuracy: 0.001)
        XCTAssertEqual(debt.criticDeltaCount, 3)
    }

    // MARK: - Dispatcher integration

    func testDispatcher_EvidenceDebtComputedInResult() async {
        let roster =
            BASAgentFabricFuzzScenarios.standardRoster()
        let input =
            BASAgentFabricFuzzScenarios
                .memoryConflictRecallTurn()
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster, graph: graph)
        // Memory recall scenario has 3 memory clusters + 1 critic
        // candidate (no concern for c-recall as cost<benefit + reversible)
        XCTAssertEqual(
            result.evidenceDebt.memoryEpisodeArcs.count, 1)
        XCTAssertEqual(
            result.evidenceDebt.memoryConflictClusters.count, 2)
        XCTAssertEqual(
            result.evidenceDebt.memoryContinuityAnchors.count, 1)
        XCTAssertEqual(
            result.evidenceDebt.memoryDeltaCount, 3,
            "ch 962: 3 memory clusters → 3 deltas")
    }

    func testDispatcher_4SeatPathEvidenceDebtIsEmpty() async {
        // 4-seat backward-compat: no memory/critic in roster or
        // input → evidenceDebt is .empty
        let roster = BASAgentTurnRoster(
            scout: makeAgent(
                "s", .scout, .situationField),
            planner: makeAgent(
                "p", .planner, .candidateFrontier),
            risk: makeAgent("r", .risk, .riskField),
            surface: makeAgent(
                "su", .surface, .renderFrame))
        let input = BASAgentTurnInput(
            turnID: "t1",
            plannerCandidates: [BASPlannerCandidate(
                candidateID: "c1", title: "t",
                actionSummary: "a",
                confidence: 0.8,
                reversibility: 0.9)],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "c1",
                    reversibility: 0.9)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c1",
                riskBand: .low))
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: roster,
            graph: BASSharedStateGraph())
        XCTAssertEqual(
            result.evidenceDebt, .empty,
            "ch 962: 4-seat dispatch → empty evidence-debt")
    }

    // MARK: - Adversarial fuzz scenarios all dispatch cleanly

    /// Generic invariant: every scenario must:
    ///   1. Dispatch without throwing/crashing
    ///   2. Produce deterministic mergeID across calls
    ///   3. Have non-nil result fields
    ///   4. Apply outcomes match accepted count
    func runScenarioInvariants(
        _ name: String,
        _ input: BASAgentTurnInput
    ) async {
        let roster =
            BASAgentFabricFuzzScenarios.standardRoster()
        let r1 = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster,
            graph: BASSharedStateGraph())
        let r2 = await BASAgentTurnDispatcher.dispatch(
            input: input, roster: roster,
            graph: BASSharedStateGraph())
        XCTAssertEqual(
            r1.mergeResult.mergeID,
            r2.mergeResult.mergeID,
            "ch 962 [\(name)]: mergeID must be deterministic")
        XCTAssertEqual(
            r1.emittedDeltas.count,
            r2.emittedDeltas.count,
            "ch 962 [\(name)]: emitted count deterministic")
        let appliedCount = r1.applyOutcomes
            .filter { $0.applied }.count
        XCTAssertEqual(
            appliedCount,
            r1.mergeResult.acceptedDeltaIDs.count,
            "ch 962 [\(name)]: applied count = accepted count")
    }

    func testScenario_CleanLowRisk() async {
        await runScenarioInvariants(
            "clean",
            BASAgentFabricFuzzScenarios.cleanLowRiskTurn())
    }

    func testScenario_ManipulationDetected() async {
        let input = BASAgentFabricFuzzScenarios
            .manipulationDetectedTurn()
        await runScenarioInvariants(
            "manipulation", input)
        // Surface MUST be block-mode (high risk + irreversible)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: BASAgentFabricFuzzScenarios.standardRoster(),
            graph: BASSharedStateGraph())
        let surfaceDelta = result.emittedDeltas.first {
            $0.targetObjectRef.hasPrefix("renderFrame#")
        }
        XCTAssertNotNil(surfaceDelta)
        XCTAssertTrue(
            surfaceDelta!.patchJson.contains(
                "\"mode\":\"block\""),
            "ch 962: manipulation+irreversible → BLOCK surface")
    }

    func testScenario_IrreversibleHighStakes() async {
        let input = BASAgentFabricFuzzScenarios
            .irreversibleHighStakesTurn()
        await runScenarioInvariants("highstakes", input)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: BASAgentFabricFuzzScenarios.standardRoster(),
            graph: BASSharedStateGraph())
        // Critic MUST flag SEVERE
        let critic = result.evidenceDebt
            .critiqueByCandidateID["highstakes1"]
        XCTAssertEqual(
            critic, .severe,
            "ch 962: cost>2×benefit + low reversibility → SEVERE")
    }

    func testScenario_MultiCandidateCascade() async {
        let input = BASAgentFabricFuzzScenarios
            .multiCandidateCriticCascadeTurn()
        await runScenarioInvariants("cascade", input)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: BASAgentFabricFuzzScenarios.standardRoster(),
            graph: BASSharedStateGraph())
        // 4 of 5 candidates concerning → pressure = 0.8
        XCTAssertEqual(
            result.evidenceDebt.aggregateCritiquePressure,
            0.8, accuracy: 0.001)
        // Critic deltas: 4 (one for each concerning candidate)
        XCTAssertEqual(
            result.evidenceDebt.criticDeltaCount, 4)
        // Safe candidate has NO entry in the map
        XCTAssertNil(
            result.evidenceDebt
                .critiqueByCandidateID["csafe"])
    }

    func testScenario_MemoryConflictRecall() async {
        let input = BASAgentFabricFuzzScenarios
            .memoryConflictRecallTurn()
        await runScenarioInvariants("recall", input)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: BASAgentFabricFuzzScenarios.standardRoster(),
            graph: BASSharedStateGraph())
        XCTAssertEqual(
            result.evidenceDebt
                .memoryConflictClusters.count, 2,
            "ch 962: 2 conflict clusters recalled")
        // Sorted: cluster.boundary-touched-B < cluster.prior-rejection-A
        XCTAssertEqual(
            result.evidenceDebt.memoryConflictClusters,
            [
                "cluster.boundary-touched-B",
                "cluster.prior-rejection-A",
            ])
    }

    func testScenario_StrictSuperegoMildBump() async {
        let input = BASAgentFabricFuzzScenarios
            .strictSuperegoMildBumpTurn()
        await runScenarioInvariants("strict", input)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: BASAgentFabricFuzzScenarios.standardRoster(),
            graph: BASSharedStateGraph())
        XCTAssertEqual(
            result.evidenceDebt
                .critiqueByCandidateID["mild1"],
            .mild,
            "ch 962: strict superego + cost>0.5 → MILD")
    }

    func testScenario_AllSignalsActive() async {
        let input = BASAgentFabricFuzzScenarios
            .allSignalsActiveTurn()
        await runScenarioInvariants("all-active", input)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: BASAgentFabricFuzzScenarios.standardRoster(),
            graph: BASSharedStateGraph())
        // With every signal:scout 4 + planner 1 + memory 3 +
        // critic 1 (severe for cost>benefit-by-not-2x + irrev) +
        // risk 1 + surface 1 = 11
        XCTAssertGreaterThan(
            result.emittedDeltas.count, 8,
            "ch 962: max-signal scenario emits many deltas")
        // Evidence-debt fully populated
        XCTAssertFalse(
            result.evidenceDebt.memoryEpisodeArcs.isEmpty)
        XCTAssertFalse(
            result.evidenceDebt.memoryConflictClusters.isEmpty)
        XCTAssertGreaterThan(
            result.evidenceDebt.memoryDeltaCount, 0)
    }

    // MARK: - Cross-turn evidence-debt simulation

    /// Simulates two consecutive turns where turn-1's evidence-debt
    /// IS the context turn-2's caller MIGHT use (future ch 963+
    /// Planner-v2)。 This test just pins that the data flow works
    /// — actual cross-turn weighting is a future chapter。
    func testCrossTurnSimulation_EvidenceDebtCarriesForward() async {
        let roster = BASAgentFabricFuzzScenarios.standardRoster()
        let graph = BASSharedStateGraph()
        // Turn 1: high-stakes input → severe critique recorded
        let t1Result = await BASAgentTurnDispatcher.dispatch(
            input: BASAgentFabricFuzzScenarios
                .irreversibleHighStakesTurn(),
            roster: roster, graph: graph)
        XCTAssertEqual(
            t1Result.evidenceDebt
                .critiqueByCandidateID["highstakes1"],
            .severe)
        // Turn 2: simulated re-proposal of same candidate
        // (in real ch 963+ Planner-v2 would have read t1's
        // evidence-debt + decided NOT to re-propose, but here
        // we just verify the debt is queryable for the decision)
        let t1CritiqueForCand = t1Result.evidenceDebt
            .critiqueByCandidateID["highstakes1"]
        XCTAssertNotNil(t1CritiqueForCand,
            "ch 962: turn-2 caller CAN query turn-1's critique " +
            "by candidate ID — cross-turn evidence flow ready")
    }

    // MARK: - Edge cases

    func testEvidenceDebt_PayloadParseFallsBackOnMalformed() {
        // Critic delta with malformed payload (no severity field)
        let malformed = BASAgentDelta(
            deltaID: "delta.t1.critic.1",
            agentID: "crit.1",
            targetObjectRef: "critiqueField#cf-t1-c1",
            deltaType: .merge,
            patchJson: "{\"unrelated\":\"junk\"}",
            confidence: 0.5)
        let debt = BASAgentEvidenceDebt.derive(
            emitted: [malformed],
            memoryInput: nil,
            criticInput: BASCriticSeatInput(candidates: [
                BASCriticCandidate(
                    candidateID: "c1", title: "t",
                    expectedBenefit: 0.1,
                    expectedCost: 0.5,
                    reversibility: 0.5)]))
        // Falls back to severity = .none on parse failure
        // (NOT Optional.none — c1 IS present in the map,with
        // BASCriticConcernSeverity.none as its value)
        XCTAssertEqual(
            debt.critiqueByCandidateID["c1"],
            BASCriticConcernSeverity.none,
            "ch 962: malformed payload → .none severity " +
            "(graceful degradation)")
    }

    func testEvidenceDebt_IgnoresNonMemoryNonCriticDeltas() {
        // Scout / Planner / Risk / Surface deltas should not
        // affect evidence-debt counts
        let other = BASAgentDelta(
            deltaID: "delta.t1.scout.1",
            agentID: "scout.1",
            targetObjectRef:
                "situationField#pressure-t1",
            deltaType: .merge,
            confidence: 0.8)
        let debt = BASAgentEvidenceDebt.derive(
            emitted: [other],
            memoryInput: nil,
            criticInput: nil)
        XCTAssertEqual(debt.memoryDeltaCount, 0)
        XCTAssertEqual(debt.criticDeltaCount, 0)
    }

    // MARK: - Helpers

    private func makeAgent(
        _ id: String,
        _ role: BASAgentRole,
        _ domain: BASStateDomain
    ) -> BASAgentSpec {
        BASAgentSpec(
            agentID: id, role: role,
            writeDomains: [domain],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }
}
