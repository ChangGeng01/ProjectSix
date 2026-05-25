// MARK: - BASAgentFabricRuntime
// chapter 九百六十 / M3505 — Phase 2 ch1:coordinator wire (OPT-IN)
//
// The "runtime" bundle holds everything the per-turn dispatcher
// needs:agent roster (who fills each seat),shared state graph
// (where deltas are applied),optional trace log (for replay)。
// One instance per coordinator;passed at init time;default-nil
// preserves byte-equal behavior per 红线 7 + ADR-014 OPT-IN。
//
// ## Why a value-type bundle vs a protocol
//
// The plan called for a `BASAgentFabric` protocol。 For ch 960
// (FIRST per-turn touch),a struct of three references suffices
// — no abstraction is needed yet because there's only one
// implementation。 Promoting to protocol becomes valuable when
// SDK consumers (Phase 6 ch 973) need to substitute custom seat
// rosters,but for the initial coordinator wire the concrete
// struct is the safest minimal surface。
//
// ## Sendable
//
// `BASAgentTurnRoster` is value-type (4 BASAgentSpecs)。
// `BASSharedStateGraph` is an actor (Sendable by construction)。
// `BASAgentTraceLog?` is an optional actor。 The bundle itself
// is Sendable because all components are Sendable。

import Foundation

/// Runtime bundle holding the 3 Agent Fabric components a
/// coordinator needs to dispatch one turn。 Value-type wrapper
/// over (roster + graph + optional trace log)。
///
/// chapter 九百六十四.5 USER-PASS-5 D1 doc-fix:was "4-seat
/// roster" from ch 960 — ch 961 added Memory + Critic,ch 963
/// added HostAlignment,ch 964 added SovereignSentinel。 Roster
/// now carries UP TO 8 agents (4 mandatory + 4 optional via
/// roster's defaulted-nil slots)。
///
/// chapter 九百六十 USER-PASS-N reminder:if a future review flags
/// "the bundle hides which agent is the writer" — that's by
/// design;the dispatcher passes the roster + agent map to the
/// merge applier which enforces Single-Writer-Per-Domain per
/// ch 956.5 USER-PASS gap #1 + ch 956.11 CR2 atomic-on-failure。
public struct BASAgentFabricRuntime: Sendable {

    /// 4-seat roster:Scout / Planner / Risk / Surface。 Each
    /// agent's `writeDomains` is enforced at apply time。
    public let roster: BASAgentTurnRoster

    /// Shared state graph actor that accepted deltas write to。
    /// Single instance per coordinator — Single-Writer-Per-Domain
    /// is enforced inside the actor (per-agent writeDomains +
    /// global writer registry per ch 956.5 gap #1)。
    public let graph: BASSharedStateGraph

    /// Optional event-sourced trace log。 Nil = no tracing
    /// (lowest overhead;suitable for production until trace
    /// consumers exist)。 Non-nil = full Root Law 7 可回放 capture
    /// (4 deltaEmitted + 1 mergeCompleted + 4 deltaApplied per
    /// typical turn,~9 events × ~250 bytes = ~2.3 KB / turn)。
    public let traceLog: BASAgentTraceLog?

    public init(
        roster: BASAgentTurnRoster,
        graph: BASSharedStateGraph,
        traceLog: BASAgentTraceLog? = nil
    ) {
        self.roster = roster
        self.graph = graph
        self.traceLog = traceLog
    }

    /// Convenience:dispatch one turn through this runtime。 The
    /// coordinator's per-turn helper calls this。 Defaults to
    /// using the runtime's `traceLog` (caller can override by
    /// passing a different one,e.g. for per-turn isolated logs)。
    ///
    /// Returns `BASAgentTurnResult` — caller decides what to do
    /// with it。 In observation-only mode (ch 960) the result is
    /// recorded but doesn't change coordinator output;in future
    /// fabric-authoritative mode (ch 961+) the result's surface
    /// delta drives the actual render frame。
    public func dispatchTurn(
        input: BASAgentTurnInput,
        traceLogOverride: BASAgentTraceLog? = nil
    ) async -> BASAgentTurnResult {
        await BASAgentTurnDispatcher.dispatch(
            input: input,
            roster: roster,
            graph: graph,
            traceLog: traceLogOverride ?? traceLog)
    }
}
