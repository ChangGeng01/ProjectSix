// MARK: - BASAgentTurnDispatcher
// chapter 九百五十九 / M3500 — Phase 1 close:per-turn dispatcher
//
// The dispatcher is the FIRST agent fabric primitive that takes
// you from "4 separate seat wrappers" to "one turn happened"。
// It composes:
//
//   Scout.emit() ──┐
//   Planner.emit() ┼──→ MergeEngine.merge() ──→ MergeApplier.apply()
//   Risk.emit() ───┤
//   Surface.emit() ┘
//
// Plus optional trace-log writes for full Root Law 7 replay。
//
// ## Why a standalone function,not a coordinator change
//
// Per the Phase 1 plan + 红线 7 + ADR-014:the coordinator hook
// stays UNCHANGED in ch 959。 The dispatcher is a public
// `async throws` function that ANY caller (test,future
// coordinator integration,SDK consumer) can invoke。 Coordinator
// integration with OPT-IN flag is deferred to Phase 2 ch 960。
//
// ## Pure-async — no actor surface
//
// The dispatcher itself has no state — it just orchestrates
// other actors (graph) + pure functions (seats + merge engine)。
// Caller's TurnInput is value-only;dispatcher returns
// `BASAgentTurnResult` value-only。 Safe to call concurrently
// for different turns (state graph actor handles serialization)。

import Foundation

/// Input bundle for one per-turn dispatch。 Caller (typically the
/// coordinator adapter in ch 960+) builds this from the existing
/// L7 decompose frame + L9 candidate paths + risk gate state +
/// sovereign sentinel state + user preferences。
public struct BASAgentTurnInput: Sendable {
    public let turnID: String
    public let scout: BASScoutInput
    public let plannerCandidates: [BASPlannerCandidate]
    public let risk: BASRiskInput
    public let surface: BASSurfaceInput
    public let priorityContext: BASMergePriorityContext
    /// Monotonic nanosecond timestamp for ch 956.5 USER-PASS gap #5
    /// recency tie-break。 0 = unknown (merge engine falls back to
    /// lex deltaID)。
    public let nowNanos: Int64

    public init(
        turnID: String,
        scout: BASScoutInput = BASScoutInput(),
        plannerCandidates: [BASPlannerCandidate] = [],
        risk: BASRiskInput = BASRiskInput(),
        surface: BASSurfaceInput = BASSurfaceInput(),
        priorityContext: BASMergePriorityContext =
            BASMergePriorityContext(),
        nowNanos: Int64 = 0
    ) {
        self.turnID = turnID
        self.scout = scout
        self.plannerCandidates = plannerCandidates
        self.risk = risk
        self.surface = surface
        self.priorityContext = priorityContext
        self.nowNanos = nowNanos
    }
}

/// Output of one per-turn dispatch。 Captures everything a
/// caller / replay / audit needs to reconstruct the turn。
public struct BASAgentTurnResult: Sendable, Equatable {
    /// All deltas emitted in this turn (before merge resolution)。
    public let emittedDeltas: [BASAgentDelta]
    /// Merge engine's resolution。
    public let mergeResult: BASAgentMergeResult
    /// Per-accepted-delta apply outcomes。
    public let applyOutcomes: [BASAgentDeltaApplicationOutcome]
    /// Final per-turn seq counter value (useful for caller's
    /// next-turn ID generation)。
    public let finalSeq: Int

    public init(
        emittedDeltas: [BASAgentDelta],
        mergeResult: BASAgentMergeResult,
        applyOutcomes: [BASAgentDeltaApplicationOutcome],
        finalSeq: Int
    ) {
        self.emittedDeltas = emittedDeltas
        self.mergeResult = mergeResult
        self.applyOutcomes = applyOutcomes
        self.finalSeq = finalSeq
    }
}

/// Roster of which agent fills each seat。 Caller provides;the
/// dispatcher uses agentID for delta authorship + writeDomains
/// for the apply step。 Per Single-Writer-Per-Domain each role
/// has a SINGLE registered agent。
public struct BASAgentTurnRoster: Sendable {
    public let scout: BASAgentSpec
    public let planner: BASAgentSpec
    public let risk: BASAgentSpec
    public let surface: BASAgentSpec

    public init(
        scout: BASAgentSpec,
        planner: BASAgentSpec,
        risk: BASAgentSpec,
        surface: BASAgentSpec
    ) {
        self.scout = scout
        self.planner = planner
        self.risk = risk
        self.surface = surface
    }

    /// `[agentID: spec]` map used by the applier (which needs
    /// to look up agent by ID to check writeDomains)。
    public var agentMap: [String: BASAgentSpec] {
        [
            scout.agentID: scout,
            planner.agentID: planner,
            risk.agentID: risk,
            surface.agentID: surface,
        ]
    }
}

public enum BASAgentTurnDispatcher {

    /// Dispatch one turn:invoke all 4 seats with a shared seq
    /// counter,merge their deltas,apply accepted deltas to the
    /// state graph,optionally record events to the trace log。
    ///
    /// - Parameters:
    ///   - input: per-turn DTO bundle
    ///   - roster: who fills each seat
    ///   - graph: shared state graph (mutated by accepted deltas)
    ///   - traceLog: optional event-sourced trace log。 Nil =
    ///     no tracing (lowest overhead)。 When set:writes
    ///     deltaEmitted per delta + mergeCompleted + deltaApplied
    ///     per outcome。
    /// - Returns: turn result with all deltas + merge resolution
    ///   + per-delta apply outcomes
    public static func dispatch(
        input: BASAgentTurnInput,
        roster: BASAgentTurnRoster,
        graph: BASSharedStateGraph,
        traceLog: BASAgentTraceLog? = nil
    ) async -> BASAgentTurnResult {
        var seq = 0
        var emitted: [BASAgentDelta] = []

        // Phase A: emit deltas from all 4 seats in canonical order
        // (Scout → Planner → Risk → Surface)。 The seat ORDER
        // doesn't affect merge result — merge engine sorts /
        // resolves by priority + recency,not by emission order —
        // but a stable order makes the trace log reproducible。
        emitted.append(contentsOf: BASScoutSeat.emit(
            from: input.scout,
            turnID: input.turnID,
            agentSpec: roster.scout,
            seq: &seq,
            nowNanos: input.nowNanos))
        emitted.append(contentsOf: BASPlannerSeat.emit(
            from: input.plannerCandidates,
            turnID: input.turnID,
            agentSpec: roster.planner,
            seq: &seq,
            nowNanos: input.nowNanos))
        emitted.append(contentsOf: BASRiskSeat.emit(
            from: input.risk,
            turnID: input.turnID,
            agentSpec: roster.risk,
            seq: &seq,
            nowNanos: input.nowNanos))
        emitted.append(contentsOf: BASSurfaceSeat.emit(
            from: input.surface,
            turnID: input.turnID,
            agentSpec: roster.surface,
            seq: &seq,
            nowNanos: input.nowNanos))

        // Trace each emitted delta
        if let traceLog {
            for d in emitted {
                await traceLog.append(
                    BASAgentTraceEventBuilder.deltaEmitted(
                        turnID: input.turnID,
                        delta: d,
                        nowNanos: input.nowNanos))
            }
        }

        // Phase B: merge
        let mergeResult = BASAgentMergeEngine.merge(
            emitted,
            context: input.priorityContext,
            turnID: input.turnID)
        if let traceLog {
            await traceLog.append(
                BASAgentTraceEventBuilder.mergeCompleted(
                    turnID: input.turnID,
                    result: mergeResult,
                    nowNanos: input.nowNanos))
        }

        // Phase C: apply accepted deltas to the graph
        let outcomes = await BASAgentMergeApplier.apply(
            mergeResult: mergeResult,
            deltas: emitted,
            agents: roster.agentMap,
            graph: graph)
        if let traceLog {
            for o in outcomes {
                await traceLog.append(
                    BASAgentTraceEventBuilder.deltaApplied(
                        turnID: input.turnID,
                        outcome: o,
                        nowNanos: input.nowNanos))
            }
        }

        return BASAgentTurnResult(
            emittedDeltas: emitted,
            mergeResult: mergeResult,
            applyOutcomes: outcomes,
            finalSeq: seq)
    }
}
