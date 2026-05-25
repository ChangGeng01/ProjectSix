// MARK: - BASChapter957ScoutPlannerSeatTests
// chapter 九百五十七 / M3490 — Phase 1 ch2:Scout + Planner seat tests
//
// Tests for the two seat wrappers that translate existing service
// outputs (L7 decompose frame → Scout; L9 candidate paths → Planner)
// into `[BASAgentDelta]` proposals for the Agent Fabric merge
// engine。 Per ch 957 design,both seats are pure functions taking
// slim DTOs — these tests pin:
//
//   - Cluster emission semantics (Scout: 4 clusters,Planner: 1 per candidate)
//   - Empty-input → empty-output (Scout `isEmpty` + Planner [])
//   - Deterministic payload encoding (byte-equal across runs for
//     ch 956.5 strong-mergeID hash invariance)
//   - DeltaID format `delta.<turnID>.<seat>.<seq>`
//   - Reason codes accumulate correctly per cluster / per candidate
//   - Confidence flows from input (Planner) or signal count (Scout)
//   - `createdAtNanos` propagates for ch 956.5 gap #5 tie-break
//   - JSON escape edge cases (NUL,quote,backslash,newline)
//
// Per coordinator integration deferral (ch 958+) these tests do
// NOT touch `EBrainRuntimeCoordinator` — that wiring lands later。

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter957ScoutPlannerSeatTests: XCTestCase {

    // MARK: - Helpers

    private func scoutAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "scout.1",
            role: .scout,
            writeDomains: [.situationField],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }

    private func plannerAgent() -> BASAgentSpec {
        BASAgentSpec(
            agentID: "planner.1",
            role: .planner,
            writeDomains: [.candidateFrontier],
            defaultLeaseProfile: .hotSeat,
            visibility: .high)
    }

    // MARK: - Scout seat

    func testScout_EmptyInputEmitsZeroDeltas() {
        let input = BASScoutInput()
        var seq = 0
        let deltas = BASScoutSeat.emit(
            from: input,
            turnID: "t1",
            agentSpec: scoutAgent(),
            seq: &seq)
        XCTAssertEqual(deltas.count, 0,
            "ch 957: empty scout input → zero deltas")
        XCTAssertEqual(seq, 0,
            "ch 957: seq counter unchanged on zero emission")
        XCTAssertTrue(input.isEmpty)
    }

    func testScout_PressureClusterEmitsOneDelta() {
        let input = BASScoutInput(
            pressureSignals: ["stress.high", "time.tight"],
            pressureVectorCount: 1)
        var seq = 0
        let deltas = BASScoutSeat.emit(
            from: input,
            turnID: "t1",
            agentSpec: scoutAgent(),
            seq: &seq)
        XCTAssertEqual(deltas.count, 1)
        XCTAssertEqual(seq, 1)
        let d = deltas[0]
        XCTAssertEqual(d.deltaID, "delta.t1.scout.1")
        XCTAssertEqual(d.agentID, "scout.1")
        XCTAssertEqual(
            d.targetObjectRef,
            "situationField#pressure-t1")
        XCTAssertEqual(d.deltaType, .merge)
        XCTAssertTrue(d.reasonCodes.contains("scout.pressure"))
        XCTAssertTrue(d.reasonCodes.contains {
            $0.hasPrefix("evidence.signal-count=")
        })
        // Confidence: base 0.5 + 0.1 * 3 (2 signals + 1 vector)
        XCTAssertEqual(d.confidence, 0.8, accuracy: 0.001)
        // Payload: deterministic JSON with sorted signals
        XCTAssertEqual(
            d.patchJson,
            "{\"signals\":[\"stress.high\",\"time.tight\"]," +
            "\"vector_count\":1}")
    }

    func testScout_AllFourClustersEmitFourDeltas() {
        let input = BASScoutInput(
            pressureSignals: ["p1"],
            pressureVectorCount: 0,
            manipulationSignals: ["m1"],
            manipulationPatternCount: 0,
            boundaryTouchCount: 1,
            contradictionRecordCount: 2,
            bareContradictions: ["c1", "c2"])
        var seq = 100  // start mid-sequence
        let deltas = BASScoutSeat.emit(
            from: input,
            turnID: "t-multi",
            agentSpec: scoutAgent(),
            seq: &seq)
        XCTAssertEqual(deltas.count, 4,
            "ch 957: 4 active clusters → 4 deltas")
        XCTAssertEqual(seq, 104)
        // Sequence is preserved
        let ids = deltas.map { $0.deltaID }
        XCTAssertEqual(ids, [
            "delta.t-multi.scout.101",
            "delta.t-multi.scout.102",
            "delta.t-multi.scout.103",
            "delta.t-multi.scout.104",
        ])
        let targetRefs = Set(deltas.map { $0.targetObjectRef })
        XCTAssertTrue(targetRefs.contains(
            "situationField#pressure-t-multi"))
        XCTAssertTrue(targetRefs.contains(
            "situationField#manipulation-t-multi"))
        XCTAssertTrue(targetRefs.contains(
            "situationField#boundary-t-multi"))
        XCTAssertTrue(targetRefs.contains(
            "situationField#contradiction-t-multi"))
    }

    func testScout_DeterministicPayloadAcrossCalls() {
        // Critical for ch 956.5 strong-mergeID hash invariance
        let input = BASScoutInput(
            manipulationSignals: ["b-sig", "a-sig", "c-sig"],
            manipulationPatternCount: 2)
        var seq1 = 0, seq2 = 0
        let d1 = BASScoutSeat.emit(
            from: input, turnID: "t1",
            agentSpec: scoutAgent(), seq: &seq1)
        let d2 = BASScoutSeat.emit(
            from: input, turnID: "t1",
            agentSpec: scoutAgent(), seq: &seq2)
        XCTAssertEqual(d1, d2,
            "ch 957: same input MUST produce byte-equal deltas")
        // Sorted signals in payload (deterministic)
        XCTAssertEqual(
            d1[0].patchJson,
            "{\"signals\":[\"a-sig\",\"b-sig\",\"c-sig\"]," +
            "\"pattern_count\":2}")
    }

    func testScout_CreatedAtNanosPropagates() {
        let input = BASScoutInput(pressureSignals: ["p1"])
        var seq = 0
        let deltas = BASScoutSeat.emit(
            from: input, turnID: "t1",
            agentSpec: scoutAgent(), seq: &seq,
            nowNanos: 123_456_789)
        XCTAssertEqual(deltas.count, 1)
        XCTAssertEqual(deltas[0].createdAtNanos, 123_456_789,
            "ch 957: nowNanos propagates for recency tie-break")
    }

    func testScout_JSONEscapeHandlesQuotesAndBackslash() {
        let weird = "has\\backslash\"and-quote"
        let input = BASScoutInput(
            pressureSignals: [weird])
        var seq = 0
        let deltas = BASScoutSeat.emit(
            from: input, turnID: "t1",
            agentSpec: scoutAgent(), seq: &seq)
        XCTAssertEqual(deltas.count, 1)
        // Payload must be parseable JSON
        let data = deltas[0].patchJson.data(using: .utf8)!
        XCTAssertNoThrow(
            try JSONSerialization.jsonObject(with: data),
            "ch 957: JSON escape produces parseable output " +
            "even with quotes/backslashes")
    }

    func testScout_ConfidenceCappedAt1() {
        // 10 manipulation signals × 0.05 + 0.7 base = 1.2 — must clamp
        let input = BASScoutInput(
            manipulationSignals: (0..<10).map { "m\($0)" },
            manipulationPatternCount: 0)
        var seq = 0
        let deltas = BASScoutSeat.emit(
            from: input, turnID: "t1",
            agentSpec: scoutAgent(), seq: &seq)
        XCTAssertEqual(deltas.count, 1)
        XCTAssertEqual(deltas[0].confidence, 1.0,
            "ch 957: confidence capped at 1.0")
    }

    // MARK: - Planner seat

    func testPlanner_EmptyFrontierEmitsZero() {
        var seq = 0
        let deltas = BASPlannerSeat.emit(
            from: [],
            turnID: "t1",
            agentSpec: plannerAgent(),
            seq: &seq)
        XCTAssertEqual(deltas.count, 0)
        XCTAssertEqual(seq, 0)
    }

    func testPlanner_OneCandidateOneDelta() {
        let c = BASPlannerCandidate(
            candidateID: "c-001",
            title: "Apologize first",
            actionSummary: "Send a brief apology before details",
            confidence: 0.85,
            expectedBenefit: 0.7,
            expectedCost: 0.1,
            reversibility: 0.9)
        var seq = 0
        let deltas = BASPlannerSeat.emit(
            from: [c],
            turnID: "t-plan",
            agentSpec: plannerAgent(),
            seq: &seq)
        XCTAssertEqual(deltas.count, 1)
        let d = deltas[0]
        XCTAssertEqual(d.deltaID, "delta.t-plan.planner.1")
        XCTAssertEqual(d.agentID, "planner.1")
        XCTAssertEqual(
            d.targetObjectRef,
            "candidateFrontier#cf-t-plan-c-001")
        XCTAssertEqual(d.deltaType, .add)
        XCTAssertEqual(d.confidence, 0.85, accuracy: 0.001)
        XCTAssertTrue(d.reasonCodes.contains("planner.propose"))
        XCTAssertTrue(
            d.reasonCodes.contains("planner.reversible-high"),
            "reversibility 0.9 ≥ 0.7 → reversible-high")
        XCTAssertTrue(
            d.reasonCodes.contains("planner.net-positive"),
            "benefit 0.7 > cost 0.1 → net-positive")
    }

    func testPlanner_ConfidenceClampedToZeroOne() {
        let cBig = BASPlannerCandidate(
            candidateID: "big", title: "t",
            actionSummary: "a",
            confidence: 5.0)  // bad value from upstream
        let cSmall = BASPlannerCandidate(
            candidateID: "small", title: "t",
            actionSummary: "a",
            confidence: -0.3)
        var seq = 0
        let deltas = BASPlannerSeat.emit(
            from: [cBig, cSmall],
            turnID: "t1",
            agentSpec: plannerAgent(),
            seq: &seq)
        XCTAssertEqual(deltas[0].confidence, 1.0)
        XCTAssertEqual(deltas[1].confidence, 0.0)
    }

    func testPlanner_NoReversibleHighWhenLow() {
        let c = BASPlannerCandidate(
            candidateID: "c1", title: "t",
            actionSummary: "a",
            confidence: 0.5,
            reversibility: 0.5)  // below 0.7 threshold
        var seq = 0
        let deltas = BASPlannerSeat.emit(
            from: [c],
            turnID: "t1",
            agentSpec: plannerAgent(),
            seq: &seq)
        XCTAssertFalse(
            deltas[0].reasonCodes.contains(
                "planner.reversible-high"))
    }

    func testPlanner_DeterministicPayload() {
        let c = BASPlannerCandidate(
            candidateID: "c1", title: "T",
            actionSummary: "A",
            confidence: 0.5,
            expectedBenefit: 0.6,
            expectedCost: 0.2,
            reversibility: 0.8)
        var seq1 = 0, seq2 = 0
        let d1 = BASPlannerSeat.emit(
            from: [c], turnID: "t1",
            agentSpec: plannerAgent(), seq: &seq1)
        let d2 = BASPlannerSeat.emit(
            from: [c], turnID: "t1",
            agentSpec: plannerAgent(), seq: &seq2)
        XCTAssertEqual(d1, d2,
            "ch 957: same candidate → byte-equal delta")
        XCTAssertEqual(
            d1[0].patchJson,
            "{\"candidate_id\":\"c1\"," +
            "\"title\":\"T\"," +
            "\"action\":\"A\"," +
            "\"benefit\":0.600000," +
            "\"cost\":0.200000," +
            "\"reversibility\":0.800000," +
            "\"confidence\":0.500000}")
    }

    func testPlanner_PayloadIsValidJSON() {
        let c = BASPlannerCandidate(
            candidateID: "c-with-\"quote\"",
            title: "Title with\nnewline",
            actionSummary: "Action with \\backslash",
            confidence: 0.5)
        var seq = 0
        let deltas = BASPlannerSeat.emit(
            from: [c], turnID: "t1",
            agentSpec: plannerAgent(), seq: &seq)
        let data = deltas[0].patchJson.data(using: .utf8)!
        XCTAssertNoThrow(
            try JSONSerialization.jsonObject(with: data),
            "ch 957: planner payload always valid JSON " +
            "(handles quotes/backslash/newline)")
    }

    // MARK: - Cross-seat: combined emission scenario

    /// Realistic scenario: Scout emits situationField deltas +
    /// Planner emits candidateFrontier deltas in the same turn。
    /// Both share the same seq counter (per-turn ID space)。
    /// Merge engine accepts all (different targets → no conflict)。
    func testCombined_ScoutAndPlannerInSameTurn() async throws {
        let scout = scoutAgent()
        let planner = plannerAgent()
        let scoutInput = BASScoutInput(
            pressureSignals: ["stress.high"])
        let candidates: [BASPlannerCandidate] = [
            BASPlannerCandidate(
                candidateID: "c1", title: "t",
                actionSummary: "a", confidence: 0.6),
            BASPlannerCandidate(
                candidateID: "c2", title: "t",
                actionSummary: "a", confidence: 0.8),
        ]
        var seq = 0
        var deltas: [BASAgentDelta] = []
        deltas.append(contentsOf: BASScoutSeat.emit(
            from: scoutInput, turnID: "t1",
            agentSpec: scout, seq: &seq))
        deltas.append(contentsOf: BASPlannerSeat.emit(
            from: candidates, turnID: "t1",
            agentSpec: planner, seq: &seq))
        XCTAssertEqual(deltas.count, 3,
            "ch 957: 1 scout + 2 planner = 3 deltas")
        // All unique IDs (no collision across seats)
        let ids = Set(deltas.map { $0.deltaID })
        XCTAssertEqual(ids.count, 3)
        // Merge engine accepts all (different target refs)
        let result = BASAgentMergeEngine.merge(
            deltas,
            context: BASMergePriorityContext(),
            turnID: "t1")
        XCTAssertEqual(result.acceptedDeltaIDs.count, 3,
            "ch 957: no-conflict scout+planner all accepted")
        XCTAssertTrue(result.rejectedDeltaIDs.isEmpty)
        // Apply to graph — both writers get their domains
        let graph = BASSharedStateGraph()
        let outcomes = await BASAgentMergeApplier.apply(
            mergeResult: result,
            deltas: deltas,
            agents: [
                "scout.1": scout,
                "planner.1": planner,
            ],
            graph: graph)
        let appliedCount = outcomes.filter { $0.applied }.count
        XCTAssertEqual(appliedCount, 3,
            "ch 957: all 3 deltas applied to graph")
        let objectCount = await graph.objectCount()
        XCTAssertEqual(objectCount, 3,
            "ch 957: 3 state objects written")
    }
}
