// MARK: - BASAgentFabricEnums
// chapter 九百五十三 / M3470 (Phase 0 / ch1)
//
// User design directive (verbatim):「单宿主、单主权、单世界、单记忆宪法,
// 多席位、多人格投影、可见或不可见的协同角色」 + 「多 agents,单大脑;
// 多角色,单主权;多视角,单提交」。
//
// This file defines the supporting enums for the 8 core Agent Fabric
// schemas (BASAgentSpec/Lease/Observation/Delta/Proposal/MergeResult/
// Trace/PersonaSpec)。 All enums are Sendable value types — used as
// fields in the schemas in sibling files。
//
// Phase 0 / Chapter 953 scope: enums + 8 schemas + property tests。
// Zero runtime wiring。 Pure types。

import Foundation

// MARK: - BASAgentRole

/// 9 core agents + 7 watchers + 4 sovereign-sealed = 20 named roles。
///
/// Per user's Section 5 spec:
///   - Core (9): Scout / Memory / Planner / Critic / HostAlignment /
///     Risk / Surface / SovereignSentinel / EvolutionShadow
///   - Watcher (7): Anomaly / Gaslight / MemoryPollution / HostDrift /
///     ToolInjection / AxisDeviation / SanctumLeak
///   - Sovereign-sealed (4): ActionPermit / DeleteRollbackSeal /
///     MemorySeal / CompareModerator + the SovereignSentinel role (also
///     listed under Core)
///
/// Role determines:
///   - layer_affinity[] (which L1-L14 layers an agent reads from)
///   - default visibility tier (HIGH user-customizable / MED partial /
///     LOW sovereign-sealed)
///   - which BASStateDomain it owns as single writer (if any)
public enum BASAgentRole: String, Codable,
    Sendable, Equatable, Hashable, CaseIterable
{
    // Core agents (9) — always available per turn
    case scout
    case memory
    case planner
    case critic
    case hostAlignment
    case risk
    case surface
    case sovereignSentinel
    case evolutionShadow

    // Watcher agents (7) — quiet observers, hints-only
    case anomalyWatcher
    case gaslightWatcher
    case memoryPollutionWatcher
    case hostDriftWatcher
    case toolInjectionWatcher
    case axisDeviationWatcher
    case sanctumLeakWatcher

    // Sovereign-sealed agents (4) — LOW tier, no user customization
    case actionPermit
    case deleteRollbackSeal
    case memorySeal
    case compareModerator
}

// MARK: - BASAgentVisibility

/// 3-tier visibility per user's Section 11.2 + plan's persona scope。
/// Determines whether user can customize this agent's persona overlay。
///
///   - high:full persona overlay allowed (Planner/Critic/Memory/Risk/Surface)
///   - medium:partial overlay allowed (style + cadence only)
///   - low:sovereign-sealed,always force-default,no overlay
public enum BASAgentVisibility: String, Codable,
    Sendable, Equatable, Hashable, CaseIterable
{
    case high
    case medium
    case low
}

// MARK: - BASStateDomain

/// 9 state domains in the shared state graph (Phase 0 ch 954)。
/// Per Single-Writer-Per-Domain invariant,each domain has exactly
/// one writer agent role; others may read or propose deltas。
///
/// Mapping (from plan Single-Writer table):
///   - situationField → Scout / L6 cortexCheck
///   - canonicalCognitiveFrame → L7 thoughtFold
///   - memoryBundle → Memory agent (L8)
///   - candidateFrontier → Planner agent (L9)
///   - critiqueField → Critic agent (NEW ch 961 — see below)
///   - riskField → Risk agent (L11)
///   - actionPermit → Risk + L11 windGate
///   - renderFrame → Surface agent (L12)
///   - sovereignVerdict → L14 SovereignSentinel (NO write,ever)
///   - hostVersion → L5 + L14 (L13 proposes only)
///   - evolutionProposal → EvolutionShadow (NEW ch 965 — see below)
///
/// chapter 九百六十一 / M3510:`critiqueField` added。 Original
/// plan said "Critic emits CritiqueDelta against Planner's
/// CandidateFrontier" — but Single-Writer-Per-Domain (ch 956.5
/// USER-PASS gap #1) says only Planner can write to
/// `.candidateFrontier`。 Two clean fixes:
///   (a) proposal-routing (deferred to Phase 2+)
///   (b) Critic owns own domain `.critiqueField`,Planner reads
/// Phase 2 ch2 takes (b) — cleaner separation, no merge-engine
/// proposal-routing complexity, future Planner v2 reads critiques
/// from this domain when re-proposing candidates next turn。
///
/// chapter 九百六十五 / M3530:`evolutionProposal` added。 Phase 3
/// close — EvolutionShadow owns this domain。 CRITICAL invariant:
/// EvolutionShadow CANNOT write `.hostVersion` (sovereign-locked
/// per Single-Writer table — only L5 + L14 own it,L13 proposes
/// only)。 The EvolutionShadow seat proposes UpdateTicket +
/// RuleCandidate + HostChangeCandidate via `.evolutionProposal`,
/// which Phase 3+ ShadowTrial pipeline consumes — NEVER effective
/// same turn (consumer is the future async ShadowTrial,not any
/// in-turn seat)。 Per plan Phase 3 ch3:never-effective-same-turn
/// invariant prevents evolution candidates from racing the live
/// decision graph。
public enum BASStateDomain: String, Codable,
    Sendable, Equatable, Hashable, CaseIterable
{
    case situationField
    case canonicalCognitiveFrame
    case memoryBundle
    case candidateFrontier
    case critiqueField
    case alignmentField  // chapter 九百六十三 — HostAlignment owns
    case riskField
    case actionPermit
    case renderFrame
    case sovereignVerdict
    case hostVersion
    case evolutionProposal  // chapter 九百六十五 — EvolutionShadow owns
}

// MARK: - BASAgentProposalType

/// 7 proposal types per user's Section 7.5。 Determines how the merge
/// engine (Phase 0 ch 955) routes the proposal during conflict
/// resolution。
public enum BASAgentProposalType: String, Codable,
    Sendable, Equatable, Hashable, CaseIterable
{
    case candidate   // Planner contributing to CandidateFrontier
    case critique    // Critic flagging issues with a proposal
    case risk        // Risk agent adding risk evidence
    case surface     // Surface agent shaping render
    case memory      // Memory agent attaching evidence bundle
    case host        // HostAlignment proposing alignment delta
    case evolution   // EvolutionShadow proposing rule/host candidate
}

// MARK: - BASAgentDeltaType

/// 5 delta operations the proposal engine supports。 Used by the merge
/// engine (Phase 0 ch 955) to compose proposals into resulting state。
///
///   - add:append to a collection-typed state field
///   - remove:delete a referenced element
///   - replace:swap one element for another
///   - merge:combine partial overlay with existing element
///   - annotate:attach metadata without changing primary value
public enum BASAgentDeltaType: String, Codable,
    Sendable, Equatable, Hashable, CaseIterable
{
    case add
    case remove
    case replace
    case merge
    case annotate
}

// MARK: - BASAgentLeaseProfile

/// Pre-canned lease profiles per agent role per user's Section 5。
/// `BASAgentSpec.default_lease_profile` references one of these;
/// `BASAgentLease` (per-turn instance) is materialized from the
/// profile when the Agent Router activates the agent。
///
///   - hotSeat:always warm,low latency budget (Scout / Risk-light /
///     Sovereign-light / Surface-stub per user's Section 13.3)
///   - coldSeat:cold start on demand,larger budget (deep Planner /
///     deep Critic / Evolution-shadow / advanced-tool)
///   - watcher:read-only,no delta-write budget,quiet observer
///   - sovereign:special profile for L14 SovereignSentinel — no
///     budget cap (sovereign concerns override)
public enum BASAgentLeaseProfile: String, Codable,
    Sendable, Equatable, Hashable, CaseIterable
{
    case hotSeat
    case coldSeat
    case watcher
    case sovereign
}
