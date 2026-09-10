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
// `BASAgentTurnRoster` is value-type (up to 9 BASAgentSpecs:4
// mandatory + 5 optional via defaulted-nil slots,per ch 961 +
// ch 963 + ch 964 + ch 965 additive expansions)。
// `BASSharedStateGraph` is an actor (Sendable by construction)。
// `BASAgentTraceLog?` is an optional actor。 The bundle itself
// is Sendable because all components are Sendable。
//
// chapter 九百八十二.5 META-REVIEW MED1 doc-fix:was "4 BASAgentSpecs"
// from ch 960 — never updated as ch 961/963/964/965 added the
// 5 optional seats (Memory + Critic + HostAlignment +
// SovereignSentinel + EvolutionShadow)。

import Foundation

/// Runtime bundle holding the 3 Agent Fabric components a
/// coordinator needs to dispatch one turn。 Value-type wrapper
/// over (roster + graph + optional trace log)。
///
/// chapter 九百六十四.5 USER-PASS-5 D1 doc-fix:was "4-seat
/// roster" from ch 960 — ch 961 added Memory + Critic,ch 963
/// added HostAlignment,ch 964 added SovereignSentinel。
/// chapter 九百八十二.5 META-REVIEW MED1 doc-fix:was "UP TO 8"
/// — ch 965 added EvolutionShadow but this docstring was never
/// updated。 Roster now carries UP TO 9 agents (4 mandatory + 5
/// optional via roster's defaulted-nil slots)。
///
/// chapter 九百六十 USER-PASS-N reminder:if a future review flags
/// "the bundle hides which agent is the writer" — that's by
/// design;the dispatcher passes the roster + agent map to the
/// merge applier which enforces Single-Writer-Per-Domain per
/// ch 956.5 USER-PASS gap #1 + ch 956.11 CR2 atomic-on-failure。
/// chapter 九百九十四 / M3675 — fabric-authoritative mode scaffold:
/// closes plan section 9.1-9.7 "future fabric-authoritative mode"
/// gap deferred since ch 960 observation-only launch。
///
/// The plan specified two modes:
///   - `.observationOnly` (current default since ch 960):dispatcher
///     result is RETURNED to caller but does NOT drive coordinator
///     output。 Caller can record/replay/audit but coordinator's
///     existing per-turn render+risk pipeline is unchanged。
///   - `.authoritative` (future,opt-in):accepted dispatcher
///     deltas drive coordinator output paths。 The fabric's
///     `.renderFrame` delta becomes the actual render frame;
///     the fabric's `.riskField` delta drives the risk gate;
///     etc。 Plan section 9 calls this "Phase 9+" scope。
///
/// Default `.observationOnly` preserves ADR-014 OPT-IN +
/// red-line 7 (byte-equal when fabric unconfigured or in
/// observation mode)。 Setting `.authoritative` requires the
/// host to explicitly opt in。 The substrate scaffolding is
/// shipped here so future host code has a stable entry point;
/// the actual per-mode behavioral wiring (e.g. fabric's
/// `.renderFrame` REPLACES coordinator's existing render frame)
/// is per-consumer host integration work since each host has
/// different downstream consumers of those state objects。
/// **🪜 SCAFFOLD** per `Docs/SCAFFOLD_VS_WIRED.md` — `BASAgentFabricMode`
/// is host-observable but substrate-side BRANCHES ON IT NOWHERE。
/// `.observationOnly` and `.authoritative` produce byte-identical
/// dispatcher / merge / apply outputs。 Per ch 994 + ch 995.9 +
/// ch 996 doctrine,mode is a signal for host's downstream
/// consumer (the code reading
/// `BASAgentFabricHostOutcome.fabricMode`) to decide whether to
/// USE the dispatcher's deltas as observation-only or as
/// authoritative replacements for coordinator output。 The
/// substrate intentionally doesn't switch behavior because
/// per-state-domain replacement is per-host concern。
public enum BASAgentFabricMode: String,
    Sendable, Equatable, Codable, CaseIterable
{
    /// Default mode since ch 960。 Dispatcher runs,result is
    /// returned to caller,coordinator output unchanged。
    case observationOnly

    /// Future mode (substrate-side scaffold ship at ch 994)。
    /// HOST-side semantic:"this turn's accepted deltas SHOULD
    /// drive coordinator output"。 Substrate dispatcher behavior
    /// IDENTICAL to `.observationOnly` — only host's downstream
    /// consumer differs in how it reads the result。
    case authoritative
}

public struct BASAgentFabricRuntime: Sendable {

    /// Up-to-9-seat roster:4 mandatory (Scout / Planner / Risk /
    /// Surface) + 5 optional (Memory / Critic / HostAlignment /
    /// SovereignSentinel / EvolutionShadow,each default-nil)。
    /// Each agent's `writeDomains` is enforced at apply time。
    /// chapter 九百八十二.5 META-REVIEW MED1 doc-fix:was "4-seat"
    /// since ch 960 — never expanded as cascade added optional
    /// slots。
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

    /// chapter 九百九十四 / M3675 — fabric-authoritative mode
    /// scaffold。 Default `.observationOnly` preserves ADR-014
    /// OPT-IN + ch 960 + red-line 7 byte-equality。 Setting
    /// `.authoritative` signals to the host that accepted
    /// dispatcher deltas SHOULD drive coordinator output paths
    /// — but the actual per-state-domain replacement logic is
    /// host-side responsibility since each host has different
    /// downstream consumers。
    public let mode: BASAgentFabricMode

    public init(
        roster: BASAgentTurnRoster,
        graph: BASSharedStateGraph,
        traceLog: BASAgentTraceLog? = nil,
        mode: BASAgentFabricMode = .observationOnly
    ) {
        self.roster = roster
        self.graph = graph
        self.traceLog = traceLog
        self.mode = mode
    }

    /// chapter 九百九十七 / M3690 — production wire-up of
    /// Single-Writer-Per-Domain。 Closes the final invariant gap
    /// that 17 N-pass review rounds missed:`BASAgentRegistry` is
    /// orphan from production (dispatcher uses
    /// `BASAgentTurnRoster` directly,never the registry),so
    /// `registry.wire(toGraph:)` only enforced SWPD at TEST
    /// scope。 Production write path relied on `writeObject`'s
    /// AUTO-CLAIM behavior (`BASSharedStateGraph` line 394-403)
    /// → first-writer-wins race。
    ///
    /// This method bypasses the registry entirely and wires the
    /// ROSTER's writeDomains directly into the graph via the
    /// atomic `registerWriterBatch(claims:)` API (ch 996.9)。
    /// Hosts call this ONCE after constructing the runtime,
    /// BEFORE first dispatch。 Idempotent for same-agent same-
    /// domain claims per registerWriterBatch's contract。
    ///
    /// `BASAgentFabricHostPipeline.runTurn(...)` calls this
    /// automatically on first dispatch (lazy-once,gated by
    /// `wiredFlag`)。 Hosts that bypass the pipeline can call
    /// it explicitly。
    ///
    /// Throws if any roster seats have overlapping
    /// writeDomains — the dispatcher would later auto-claim
    /// race so failing-fast at setup is correct。
    public func wireRosterToGraph() async throws {
        var claims:
            [(agentID: String, domain: BASStateDomain)] = []
        // 4 mandatory seats
        let mandatory: [BASAgentSpec] = [
            roster.scout,
            roster.planner,
            roster.risk,
            roster.surface,
        ]
        for spec in mandatory {
            for domain in spec.writeDomains {
                claims.append(
                    (agentID: spec.agentID, domain: domain))
            }
        }
        // 5 optional seats
        for optSpec in [
            roster.memory,
            roster.critic,
            roster.hostAlignment,
            roster.sovereignSentinel,
            roster.evolutionShadow,
        ] {
            guard let spec = optSpec else { continue }
            for domain in spec.writeDomains {
                claims.append(
                    (agentID: spec.agentID, domain: domain))
            }
        }
        try await graph.registerWriterBatch(claims: claims)
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
