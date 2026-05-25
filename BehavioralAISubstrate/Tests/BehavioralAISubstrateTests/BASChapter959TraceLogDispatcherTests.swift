// MARK: - BASChapter959TraceLogDispatcherTests
// chapter 九百五十九 / M3500 — Phase 1 close tests
//
// Tests for:
//   - `BASAgentTraceLog` actor (append + read + ring-buffer cap)
//   - `BASAgentTraceEventBuilder` helpers (deterministic payloads)
//   - `BASAgentTurnDispatcher.dispatch(...)` end-to-end
//   - Trace-log integration:every delta emitted + merge + apply
//     produces the expected event count + content
//
// These tests pin the Phase 1 contract:**a coordinator only
// needs to call `BASAgentTurnDispatcher.dispatch(...)` once per
// turn with 4 input DTOs + 4 agents + a graph + optional trace
// log** to get the full agent-fabric behavior。 Phase 2 ch 960+
// will wire that single call into `EBrainRuntimeCoordinator`。

import XCTest
import Foundation
@testable import BASMemory

final class BASChapter959TraceLogDispatcherTests: XCTestCase {

    // MARK: - Test helpers (roster + reasonable defaults)

    private func makeRoster() -> BASAgentTurnRoster {
        BASAgentTurnRoster(
            scout: BASAgentSpec(
                agentID: "scout.1",
                role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            planner: BASAgentSpec(
                agentID: "planner.1",
                role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            risk: BASAgentSpec(
                agentID: "risk.1",
                role: .risk,
                writeDomains: [.riskField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            surface: BASAgentSpec(
                agentID: "surface.1",
                role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high))
    }

    private func nonTrivialInput(
        turnID: String = "t1"
    ) -> BASAgentTurnInput {
        BASAgentTurnInput(
            turnID: turnID,
            scout: BASScoutInput(
                pressureSignals: ["work.deadline"]),
            plannerCandidates: [
                BASPlannerCandidate(
                    candidateID: "c1",
                    title: "Take a break",
                    actionSummary: "5-min break",
                    confidence: 0.8,
                    reversibility: 0.95),
            ],
            risk: BASRiskInput(
                candidates: [BASRiskCandidate(
                    candidateID: "c1",
                    reversibility: 0.95)]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c1",
                riskBand: .low,
                reversibility: 0.95))
    }

    // MARK: - BASAgentTraceLog basics

    func testTraceLog_AppendAssignsSequencePerTurn() async {
        let log = BASAgentTraceLog()
        let e1 = BASAgentTraceEvent(
            turnID: "t1",
            createdAtNanos: 100,
            kind: .deltaEmitted,
            agentID: "a", deltaID: "d1",
            payloadJson: "{}")
        let s1 = await log.append(e1)
        let s2 = await log.append(BASAgentTraceEvent(
            turnID: "t1",
            createdAtNanos: 200,
            kind: .mergeCompleted,
            payloadJson: "{}"))
        XCTAssertEqual(s1, 1,
            "ch 959: first event per turn → seq 1")
        XCTAssertEqual(s2, 2,
            "ch 959: second event per turn → seq 2")
        // Different turn gets its own counter starting at 1
        let s3 = await log.append(BASAgentTraceEvent(
            turnID: "t2",
            createdAtNanos: 300,
            kind: .deltaEmitted,
            agentID: "a", deltaID: "d2",
            payloadJson: "{}"))
        XCTAssertEqual(s3, 1,
            "ch 959: per-turn seq scope")
    }

    func testTraceLog_RespectsCallerSequenceWhenNonZero() async {
        // Replay scenario: caller passes original sequence number
        let log = BASAgentTraceLog()
        let e = BASAgentTraceEvent(
            sequenceNumber: 42,
            turnID: "t1",
            createdAtNanos: 100,
            kind: .deltaEmitted,
            payloadJson: "{}")
        let s = await log.append(e)
        XCTAssertEqual(s, 42)
        // Subsequent auto-assign respects the bumped high-water mark
        let s2 = await log.append(BASAgentTraceEvent(
            turnID: "t1",
            createdAtNanos: 200,
            kind: .mergeCompleted,
            payloadJson: "{}"))
        XCTAssertEqual(s2, 43,
            "ch 959: high-water mark preserved on replay")
    }

    func testTraceLog_EventsForTurnSorted() async {
        let log = BASAgentTraceLog()
        // Out-of-order appends across two turns
        _ = await log.append(BASAgentTraceEvent(
            turnID: "t2",
            createdAtNanos: 300,
            kind: .deltaEmitted,
            payloadJson: "{}"))
        _ = await log.append(BASAgentTraceEvent(
            turnID: "t1",
            createdAtNanos: 100,
            kind: .deltaEmitted,
            payloadJson: "{}"))
        _ = await log.append(BASAgentTraceEvent(
            turnID: "t1",
            createdAtNanos: 200,
            kind: .mergeCompleted,
            payloadJson: "{}"))
        let t1Events = await log.events(forTurn: "t1")
        XCTAssertEqual(t1Events.count, 2)
        XCTAssertEqual(t1Events[0].sequenceNumber, 1)
        XCTAssertEqual(t1Events[1].sequenceNumber, 2)
        let t2Events = await log.events(forTurn: "t2")
        XCTAssertEqual(t2Events.count, 1)
    }

    func testTraceLog_RingBufferDropsOldest() async {
        let log = BASAgentTraceLog(maxEvents: 3)
        for i in 1...5 {
            _ = await log.append(BASAgentTraceEvent(
                turnID: "t1",
                createdAtNanos: Int64(i * 100),
                kind: .deltaEmitted,
                deltaID: "d\(i)",
                payloadJson: "{}"))
        }
        let count = await log.count
        XCTAssertEqual(count, 3,
            "ch 959: ring buffer capped at maxEvents=3")
        let all = await log.allEvents()
        // Oldest 2 dropped, newest 3 remain
        XCTAssertEqual(all[0].deltaID, "d3")
        XCTAssertEqual(all[1].deltaID, "d4")
        XCTAssertEqual(all[2].deltaID, "d5")
    }

    func testTraceLog_TurnIDSetIntrospection() async {
        let log = BASAgentTraceLog()
        for turn in ["alpha", "beta", "gamma"] {
            _ = await log.append(BASAgentTraceEvent(
                turnID: turn,
                createdAtNanos: 0,
                kind: .deltaEmitted,
                payloadJson: "{}"))
        }
        let ids = await log.turnIDs()
        XCTAssertEqual(ids, ["alpha", "beta", "gamma"])
    }

    // MARK: - Builder payload determinism

    func testBuilder_DeltaEmittedPayloadDeterministic() {
        let delta = BASAgentDelta(
            deltaID: "d1",
            agentID: "scout.1",
            targetObjectRef: "situationField#sf-t1",
            deltaType: .merge,
            confidence: 0.85)
        let e1 = BASAgentTraceEventBuilder.deltaEmitted(
            turnID: "t1",
            delta: delta,
            nowNanos: 100)
        let e2 = BASAgentTraceEventBuilder.deltaEmitted(
            turnID: "t1",
            delta: delta,
            nowNanos: 100)
        XCTAssertEqual(e1, e2,
            "ch 959: builder is pure function")
        XCTAssertEqual(
            e1.payloadJson,
            "{\"target_ref\":\"situationField#sf-t1\"," +
            "\"confidence\":0.850000}")
    }

    func testBuilder_MergeCompletedHasCounts() {
        let result = BASAgentMergeResult(
            mergeID: "merge.t1.3.abc",
            acceptedDeltaIDs: ["delta:d1", "delta:d2"],
            rejectedDeltaIDs: ["delta:d3"],
            conflictResolution: [],
            resultingStateRef: "ref",
            mergeReasonCodes: [])
        let e = BASAgentTraceEventBuilder.mergeCompleted(
            turnID: "t1",
            result: result,
            nowNanos: 100)
        XCTAssertEqual(e.kind, .mergeCompleted)
        XCTAssertNil(e.agentID,
            "ch 959: merge events have no agentID owner")
        XCTAssertTrue(
            e.payloadJson.contains("\"accepted\":2"))
        XCTAssertTrue(
            e.payloadJson.contains("\"rejected\":1"))
    }

    func testBuilder_DeltaAppliedPayload() {
        let outcome = BASAgentDeltaApplicationOutcome(
            deltaID: "d1",
            applied: true,
            writtenRef: "candidateFrontier#cf-1",
            errorReason: "")
        let e = BASAgentTraceEventBuilder.deltaApplied(
            turnID: "t1",
            outcome: outcome,
            nowNanos: 100)
        XCTAssertEqual(e.deltaID, "d1")
        XCTAssertTrue(
            e.payloadJson.contains("\"applied\":true"))
        XCTAssertTrue(
            e.payloadJson.contains(
                "\"written_ref\":\"candidateFrontier#cf-1\""))
    }

    // MARK: - Dispatcher

    func testDispatcher_NoTraceLogStillWorks() async {
        // No trace log → no trace overhead, same merge + apply path
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: nonTrivialInput(),
            roster: makeRoster(),
            graph: graph,
            traceLog: nil)
        XCTAssertEqual(result.emittedDeltas.count, 4,
            "ch 959: 4 seats × 1 delta each = 4 emitted")
        XCTAssertEqual(
            result.mergeResult.acceptedDeltaIDs.count, 4)
        let appliedCount = result.applyOutcomes
            .filter { $0.applied }.count
        XCTAssertEqual(appliedCount, 4)
        let graphCount = await graph.objectCount()
        XCTAssertEqual(graphCount, 4)
        XCTAssertEqual(result.finalSeq, 4)
    }

    func testDispatcher_WithTraceLogCapturesEverything() async {
        let graph = BASSharedStateGraph()
        let log = BASAgentTraceLog()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: nonTrivialInput(turnID: "trace-1"),
            roster: makeRoster(),
            graph: graph,
            traceLog: log)
        XCTAssertEqual(result.emittedDeltas.count, 4)
        // Trace log: 4 deltaEmitted + 1 mergeCompleted + 4 deltaApplied = 9
        let events = await log.events(forTurn: "trace-1")
        XCTAssertEqual(events.count, 9,
            "ch 959: 4 emitted + 1 merge + 4 applied = 9 trace events")
        // Kinds in order
        let kinds = events.map { $0.kind }
        XCTAssertEqual(kinds[0..<4],
            ArraySlice([BASAgentTraceEventKind.deltaEmitted,
                        .deltaEmitted, .deltaEmitted,
                        .deltaEmitted]))
        XCTAssertEqual(kinds[4], .mergeCompleted)
        XCTAssertEqual(kinds[5..<9],
            ArraySlice([BASAgentTraceEventKind.deltaApplied,
                        .deltaApplied, .deltaApplied,
                        .deltaApplied]))
        // Sequence numbers monotonically increasing
        for i in 1..<events.count {
            XCTAssertGreaterThan(
                events[i].sequenceNumber,
                events[i-1].sequenceNumber)
        }
    }

    func testDispatcher_DeterministicAcrossInvocations() async {
        // Same input → same emitted deltas (ch 956.5 invariance)
        let r1 = await BASAgentTurnDispatcher.dispatch(
            input: nonTrivialInput(),
            roster: makeRoster(),
            graph: BASSharedStateGraph(),
            traceLog: nil)
        let r2 = await BASAgentTurnDispatcher.dispatch(
            input: nonTrivialInput(),
            roster: makeRoster(),
            graph: BASSharedStateGraph(),
            traceLog: nil)
        XCTAssertEqual(r1.emittedDeltas, r2.emittedDeltas,
            "ch 959: deterministic deltas across runs")
        XCTAssertEqual(r1.mergeResult, r2.mergeResult,
            "ch 959: deterministic merge result (strong mergeID)")
    }

    func testDispatcher_EmptyInputProducesSurfaceSilentStub() async {
        // Empty everything → Scout emits 0, Planner emits 0,
        // Risk emits 0, Surface emits 1 (silentStub fallback)
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: BASAgentTurnInput(turnID: "empty"),
            roster: makeRoster(),
            graph: graph,
            traceLog: nil)
        XCTAssertEqual(result.emittedDeltas.count, 1,
            "ch 959: empty input → only Surface silentStub")
        XCTAssertEqual(
            result.emittedDeltas[0].agentID, "surface.1")
        XCTAssertTrue(
            result.emittedDeltas[0].patchJson.contains(
                "\"mode\":\"silentStub\""))
    }

    func testDispatcher_BlockedSurfaceStillRecorded() async {
        // Surface emits .block when sovereign vetoes — still
        // applied to graph (the block IS the answer for this turn)
        let graph = BASSharedStateGraph()
        let log = BASAgentTraceLog()
        var input = nonTrivialInput(turnID: "blocked")
        input = BASAgentTurnInput(
            turnID: input.turnID,
            scout: input.scout,
            plannerCandidates: input.plannerCandidates,
            risk: input.risk,
            surface: BASSurfaceInput(
                acceptedCandidateID: "c1",
                sovereignVetoed: true),  // BLOCK
            priorityContext: input.priorityContext,
            nowNanos: input.nowNanos)
        let result = await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: makeRoster(),
            graph: graph,
            traceLog: log)
        XCTAssertEqual(result.emittedDeltas.count, 4,
            "ch 959: sovereign-block still emits 4 deltas")
        let surfaceDelta = result.emittedDeltas
            .first { $0.agentID == "surface.1" }
        XCTAssertNotNil(surfaceDelta)
        XCTAssertTrue(
            surfaceDelta!.patchJson.contains(
                "\"mode\":\"block\""))
        // Trace log should still have all 9 events
        let traceCount = await log.events(
            forTurn: "blocked").count
        XCTAssertEqual(traceCount, 9)
    }

    func testDispatcher_FinalSeqReflectsAllEmissions() async {
        // 1 candidate → Scout 1 + Planner 1 + Risk 1 + Surface 1 = seq 4
        let r1 = await BASAgentTurnDispatcher.dispatch(
            input: nonTrivialInput(),
            roster: makeRoster(),
            graph: BASSharedStateGraph(),
            traceLog: nil)
        XCTAssertEqual(r1.finalSeq, 4)
        // 3 candidates → 1 + 3 + 3 + 1 = 8
        let multi = BASAgentTurnInput(
            turnID: "t1",
            scout: BASScoutInput(
                pressureSignals: ["x"]),
            plannerCandidates: [
                BASPlannerCandidate(
                    candidateID: "c1",
                    title: "a", actionSummary: "a",
                    confidence: 0.8),
                BASPlannerCandidate(
                    candidateID: "c2",
                    title: "b", actionSummary: "b",
                    confidence: 0.7),
                BASPlannerCandidate(
                    candidateID: "c3",
                    title: "c", actionSummary: "c",
                    confidence: 0.6),
            ],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "c1", reversibility: 0.9),
                BASRiskCandidate(
                    candidateID: "c2", reversibility: 0.9),
                BASRiskCandidate(
                    candidateID: "c3", reversibility: 0.9),
            ]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c1",
                riskBand: .low))
        let r2 = await BASAgentTurnDispatcher.dispatch(
            input: multi,
            roster: makeRoster(),
            graph: BASSharedStateGraph(),
            traceLog: nil)
        XCTAssertEqual(r2.finalSeq, 8)
        XCTAssertEqual(r2.emittedDeltas.count, 8)
    }

    func testDispatcher_GraphPersistsAcceptedDeltasOnly() async {
        // If two seats target the same ref + same domain, only the
        // winner is applied to the graph。 Construct a scenario
        // where Risk's risk-field write CONFLICTS by hand-crafted
        // input is hard via current public API。 Easier: confirm
        // happy path applies exactly len(accepted) objects。
        let graph = BASSharedStateGraph()
        let result = await BASAgentTurnDispatcher.dispatch(
            input: nonTrivialInput(),
            roster: makeRoster(),
            graph: graph,
            traceLog: nil)
        let count = await graph.objectCount()
        XCTAssertEqual(
            count, result.mergeResult.acceptedDeltaIDs.count,
            "ch 959: graph objects = accepted delta count")
    }
}
