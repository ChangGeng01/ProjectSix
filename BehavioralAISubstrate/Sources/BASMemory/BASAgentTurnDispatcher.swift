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
///
/// chapter 九百六十一 / M3510:added optional `memory` + `critic`
/// inputs。 Default-nil preserves 4-seat caller compat per the
/// same red-line 7 + ADR-014 discipline as ch 960 coordinator wire。
public struct BASAgentTurnInput: Sendable {
    public let turnID: String
    public let scout: BASScoutInput
    public let plannerCandidates: [BASPlannerCandidate]
    public let risk: BASRiskInput
    public let surface: BASSurfaceInput
    /// NEW ch 961:Memory seat input。 Nil = skip Memory emission
    /// (4-seat backward compat for ch 957-960 callers)。
    public let memory: BASMemorySeatInput?
    /// NEW ch 961:Critic seat input。 Nil = skip Critic emission
    /// (4-seat backward compat)。
    public let critic: BASCriticSeatInput?
    /// NEW ch 963:HostAlignment seat input。 Nil = skip
    /// HostAlignment emission (6-seat backward compat for ch
    /// 961-962 callers)。
    public let hostAlignment: BASHostAlignmentInput?
    /// NEW ch 964:SovereignSentinel seat input。 Nil = skip
    /// (7-seat backward compat)。 The sentinel is the
    /// load-bearing sealed-LOW seat — when wired it ALWAYS
    /// runs (no opt-out per-turn);nil only means caller
    /// hasn't wired it at all yet。
    public let sovereignSentinel:
        BASSovereignSentinelInput?
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
        memory: BASMemorySeatInput? = nil,
        critic: BASCriticSeatInput? = nil,
        hostAlignment: BASHostAlignmentInput? = nil,
        sovereignSentinel:
            BASSovereignSentinelInput? = nil,
        priorityContext: BASMergePriorityContext =
            BASMergePriorityContext(),
        nowNanos: Int64 = 0
    ) {
        self.turnID = turnID
        self.scout = scout
        self.plannerCandidates = plannerCandidates
        self.risk = risk
        self.surface = surface
        self.memory = memory
        self.critic = critic
        self.hostAlignment = hostAlignment
        self.sovereignSentinel = sovereignSentinel
        self.priorityContext = priorityContext
        self.nowNanos = nowNanos
    }
}

/// Output of one per-turn dispatch。 Captures everything a
/// caller / replay / audit needs to reconstruct the turn。
///
/// chapter 九百六十二 / M3515:added `evidenceDebt` per-turn
/// summary for cross-agent / cross-turn evidence flow。
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
    /// chapter 九百六十二 — per-turn aggregation of Memory +
    /// Critic signals。 `.empty` when neither seat was wired
    /// (4-seat backward-compat preserves existing semantics)。
    /// Future ch 963+ Planner-v2 will read this for cross-turn
    /// evidence weighting。
    public let evidenceDebt: BASAgentEvidenceDebt

    public init(
        emittedDeltas: [BASAgentDelta],
        mergeResult: BASAgentMergeResult,
        applyOutcomes: [BASAgentDeltaApplicationOutcome],
        finalSeq: Int,
        evidenceDebt: BASAgentEvidenceDebt = .empty
    ) {
        self.emittedDeltas = emittedDeltas
        self.mergeResult = mergeResult
        self.applyOutcomes = applyOutcomes
        self.finalSeq = finalSeq
        self.evidenceDebt = evidenceDebt
    }
}

/// Roster of which agent fills each seat。 Caller provides;the
/// dispatcher uses agentID for delta authorship + writeDomains
/// for the apply step。 Per Single-Writer-Per-Domain each role
/// has a SINGLE registered agent。
///
/// chapter 九百六十一 / M3510:added optional `memory` + `critic`
/// slots。 Default-nil preserves 4-seat caller compat。 If a
/// seat's roster slot is nil,its input is ignored even when
/// non-nil (no agent = no emission)。
public struct BASAgentTurnRoster: Sendable {
    public let scout: BASAgentSpec
    public let planner: BASAgentSpec
    public let risk: BASAgentSpec
    public let surface: BASAgentSpec
    /// NEW ch 961:Memory agent。 Nil = no Memory seat in this
    /// roster (4-seat backward compat)。
    public let memory: BASAgentSpec?
    /// NEW ch 961:Critic agent。 Nil = no Critic seat。
    public let critic: BASAgentSpec?
    /// NEW ch 963:HostAlignment agent。 Nil = no HostAlignment seat。
    public let hostAlignment: BASAgentSpec?
    /// NEW ch 964:SovereignSentinel agent。 Nil = no sentinel
    /// (TURN BEHAVIOR UNCHANGED — but per ADR-014 + plan,
    /// production hosts SHOULD always wire the sentinel)。
    public let sovereignSentinel: BASAgentSpec?

    public init(
        scout: BASAgentSpec,
        planner: BASAgentSpec,
        risk: BASAgentSpec,
        surface: BASAgentSpec,
        memory: BASAgentSpec? = nil,
        critic: BASAgentSpec? = nil,
        hostAlignment: BASAgentSpec? = nil,
        sovereignSentinel: BASAgentSpec? = nil
    ) {
        self.scout = scout
        self.planner = planner
        self.risk = risk
        self.surface = surface
        self.memory = memory
        self.critic = critic
        self.hostAlignment = hostAlignment
        self.sovereignSentinel = sovereignSentinel
    }

    /// `[agentID: spec]` map used by the applier。 Includes
    /// Memory / Critic / HostAlignment / SovereignSentinel
    /// when present。
    public var agentMap: [String: BASAgentSpec] {
        var m: [String: BASAgentSpec] = [
            scout.agentID: scout,
            planner.agentID: planner,
            risk.agentID: risk,
            surface.agentID: surface,
        ]
        if let memory { m[memory.agentID] = memory }
        if let critic { m[critic.agentID] = critic }
        if let hostAlignment {
            m[hostAlignment.agentID] = hostAlignment
        }
        if let sovereignSentinel {
            m[sovereignSentinel.agentID] = sovereignSentinel
        }
        return m
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
        // chapter 九百六十一:Memory + Critic seats — invoked
        // only when BOTH roster slot AND input DTO are present。
        // Ordered AFTER Planner so deltaIDs read in conceptual
        // order (scout → planner → memory → critic → risk →
        // surface)。 Order doesn't affect merge resolution
        // (different targets → no conflict) but stable order
        // makes trace logs reproducible per ch 959 design。
        if let memoryAgent = roster.memory,
           let memoryInput = input.memory {
            emitted.append(contentsOf: BASMemorySeat.emit(
                from: memoryInput,
                turnID: input.turnID,
                agentSpec: memoryAgent,
                seq: &seq,
                nowNanos: input.nowNanos))
        }
        if let criticAgent = roster.critic,
           let criticInput = input.critic {
            emitted.append(contentsOf: BASCriticSeat.emit(
                from: criticInput,
                turnID: input.turnID,
                agentSpec: criticAgent,
                seq: &seq,
                nowNanos: input.nowNanos))
        }
        // chapter 九百六十三:HostAlignment seat — invoked after
        // Critic + before Risk per canonical order (alignment
        // concerns inform Risk's escalation logic when both wired)。
        if let alignAgent = roster.hostAlignment,
           let alignInput = input.hostAlignment {
            emitted.append(
                contentsOf: BASHostAlignmentSeat.emit(
                    from: alignInput,
                    turnID: input.turnID,
                    agentSpec: alignAgent,
                    seq: &seq,
                    nowNanos: input.nowNanos))
        }
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
        // chapter 九百六十四:SovereignSentinel emits LAST per
        // Root Law 4 (单主权) — sees everything other seats
        // emitted this turn,issues final veto verdict。 Order:
        // scout→planner→memory→critic→hostalign→risk→surface→
        // SOVEREIGN (canonical 8-seat order)
        if let sovAgent = roster.sovereignSentinel,
           let sovInput = input.sovereignSentinel {
            emitted.append(
                contentsOf: BASSovereignSentinelSeat.emit(
                    from: sovInput,
                    turnID: input.turnID,
                    agentSpec: sovAgent,
                    seq: &seq,
                    nowNanos: input.nowNanos))
        }

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

        // chapter 九百六十二 / M3515:derive evidence-debt summary
        // from the emitted Memory + Critic deltas + the inputs。
        // O(emitted-count) single pass — minimal added cost。
        let evidence = BASAgentEvidenceDebt.derive(
            emitted: emitted,
            memoryInput: input.memory,
            criticInput: input.critic)

        return BASAgentTurnResult(
            emittedDeltas: emitted,
            mergeResult: mergeResult,
            applyOutcomes: outcomes,
            finalSeq: seq,
            evidenceDebt: evidence)
    }
}
