// MARK: - BASAgentHotColdTier
// chapter 九百八十 / M3605 — Phase 8 ch2:hot/cold agent tier
//
// User design Section 13.3 + plan PHASE 8 ch2:
//
//   Hot/cold agent tier:keep Scout + Risk-light + Sovereign-
//   light + Surface-stub warm in-process。 Deep Planner / deep
//   Critic / Evolution-shadow / advanced-tool cold-start on demand。
//
// ## Why this matters
//
// Per ch 952.4 baseline:cold-start of deep agents costs 50-200ms
// per first-invocation。 If we always cold-start every agent
// every turn,a 9-agent dispatcher pays 50-200ms × 9 = 450-1800ms
// just for warmup。 Hot/cold tier lets us keep the front-edge
// agents (Scout / Risk-light / Sovereign-light / Surface-stub)
// always in-memory and amortize ONLY the deep agents'
// cold-start。
//
// ## What this layer provides
//
// Pure-data tier assignment + activation decision:
//
//   BASAgentTier
//     ├─ .hot     — always in-memory,~5ms wake cost
//     ├─ .cold    — cold-start on demand,~50-200ms wake cost
//     └─ .sealed  — sealed-LOW agents that pre-initialize once
//                   per session (sentinel / action-permit etc.)
//
//   BASAgentTierAssignment — per-role assignment + budget hints
//
//   BASAgentTierActivationPlan — per-turn list of which agents to
//   activate + their tier + budget
//
// Caller (coordinator) consults `BASAgentTierActivationPlanner` to
// decide which agents to invoke this turn based on:
//   - Risk band (low/med/high — high turns activate more)
//   - Latent spine cache hit ratio (high-hit turns skip cold
//     agents)
//   - Caller's per-turn budget envelope
//
// ## Pure-fn discipline
//
// Same as ch 979 — pure functions,no actor,no I/O。 Caller
// owns the actual process/thread lifecycle for hot agents。
// This layer just declares POLICY (which agent is which tier
// + when to activate)。

import Foundation

// MARK: - Tier

public enum BASAgentTier: String,
    Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// Always in-memory。 ~5ms wake cost。 Front-edge agents
    /// that fire EVERY turn (Scout / Risk-light / Sovereign-
    /// light / Surface-stub)。
    case hot
    /// Cold-start on demand。 ~50-200ms wake cost。 Deep agents
    /// that only fire on med+ risk turns or when host requests。
    case cold
    /// Pre-initialized once per session then stays sealed in
    /// place。 ~0ms wake cost。 LOW-tier sovereign agents
    /// (SovereignSentinel / ActionPermit / DeleteRollbackSeal /
    /// MemorySeal)。
    case sealed
}

// MARK: - Tier assignment per role

/// Per-role tier policy。 The default registry below pins the
/// reference assignment;hosts may override per their hardware
/// budget。
public struct BASAgentTierAssignment:
    Sendable, Equatable, Hashable, Codable
{
    public let role: BASAgentRole
    public let tier: BASAgentTier
    /// Per-turn wake budget in microseconds。 Used by the
    /// activation planner to decide whether to skip
    /// cold-starting an agent this turn when budget would
    /// be exceeded。
    public let wakeBudgetMicros: Int
    /// Per-turn token budget hint for this tier (caller may
    /// pass to seat's persona resolver risk context)。
    public let tokenBudgetHint: Int

    public init(
        role: BASAgentRole,
        tier: BASAgentTier,
        wakeBudgetMicros: Int,
        tokenBudgetHint: Int = 0
    ) {
        self.role = role
        self.tier = tier
        self.wakeBudgetMicros = max(0, wakeBudgetMicros)
        self.tokenBudgetHint = max(0, tokenBudgetHint)
    }
}

// MARK: - Reference tier registry

public enum BASAgentTierRegistry {

    /// Per plan PHASE 8 ch2 reference assignment:
    ///   HOT (always in-memory):
    ///     Scout / Risk / Surface / SovereignSentinel
    ///       (Sentinel is sealed-LOW but also kept warm because
    ///        every turn checks it)
    ///   COLD (on-demand):
    ///     Planner / Memory / Critic / HostAlignment /
    ///     EvolutionShadow
    ///   SEALED (pre-init once per session):
    ///     ActionPermit / DeleteRollbackSeal / MemorySeal /
    ///     CompareModerator
    ///   WATCHERS:all hot (read-only,low cost per turn)
    public static let defaultAssignments:
        [BASAgentTierAssignment] = [
            // HOT
            .init(role: .scout, tier: .hot,
                  wakeBudgetMicros: 5_000),
            .init(role: .risk, tier: .hot,
                  wakeBudgetMicros: 5_000),
            .init(role: .surface, tier: .hot,
                  wakeBudgetMicros: 5_000),
            .init(role: .sovereignSentinel, tier: .hot,
                  wakeBudgetMicros: 5_000),
            // COLD
            .init(role: .planner, tier: .cold,
                  wakeBudgetMicros: 100_000,
                  tokenBudgetHint: 2000),
            .init(role: .memory, tier: .cold,
                  wakeBudgetMicros: 80_000,
                  tokenBudgetHint: 1000),
            .init(role: .critic, tier: .cold,
                  wakeBudgetMicros: 100_000,
                  tokenBudgetHint: 1500),
            .init(role: .hostAlignment, tier: .cold,
                  wakeBudgetMicros: 60_000,
                  tokenBudgetHint: 800),
            .init(role: .evolutionShadow, tier: .cold,
                  wakeBudgetMicros: 200_000,
                  tokenBudgetHint: 3000),
            // SEALED
            .init(role: .actionPermit, tier: .sealed,
                  wakeBudgetMicros: 0),
            .init(role: .deleteRollbackSeal, tier: .sealed,
                  wakeBudgetMicros: 0),
            .init(role: .memorySeal, tier: .sealed,
                  wakeBudgetMicros: 0),
            .init(role: .compareModerator, tier: .sealed,
                  wakeBudgetMicros: 0),
            // WATCHERS (all hot — read-only,low cost)
            .init(role: .anomalyWatcher, tier: .hot,
                  wakeBudgetMicros: 2_000),
            .init(role: .gaslightWatcher, tier: .hot,
                  wakeBudgetMicros: 2_000),
            .init(role: .memoryPollutionWatcher, tier: .hot,
                  wakeBudgetMicros: 2_000),
            .init(role: .hostDriftWatcher, tier: .hot,
                  wakeBudgetMicros: 2_000),
            .init(role: .toolInjectionWatcher, tier: .hot,
                  wakeBudgetMicros: 2_000),
            .init(role: .axisDeviationWatcher, tier: .hot,
                  wakeBudgetMicros: 2_000),
            .init(role: .sanctumLeakWatcher, tier: .hot,
                  wakeBudgetMicros: 2_000),
        ]

    /// Lookup tier for a role。 Returns `.cold` as defensive
    /// fallback for unknown roles (safer than `.hot` —
    /// unknown roles cold-start by default)。
    public static func tier(
        for role: BASAgentRole
    ) -> BASAgentTier {
        defaultAssignments.first {
            $0.role == role
        }?.tier ?? .cold
    }

    public static func assignment(
        for role: BASAgentRole
    ) -> BASAgentTierAssignment? {
        defaultAssignments.first { $0.role == role }
    }
}

// MARK: - Activation plan

/// Per-turn decision:which agents to invoke + their priority。
public struct BASAgentTierActivationPlan:
    Sendable, Equatable, Hashable, Codable
{
    /// Roles to activate this turn,sorted by tier (hot first)
    /// then by role rawValue。
    public let activations: [BASAgentRole]
    /// Roles deliberately skipped this turn + reason。 Audit
    /// trail。 Reasons format:`tier-budget-exceeded` /
    /// `low-risk-skip-cold` / `cache-hit-skip`。
    public let skips: [String]
    /// Total estimated wake budget consumed by activations
    /// (microseconds)。
    public let estimatedWakeMicros: Int

    public init(
        activations: [BASAgentRole],
        skips: [String] = [],
        estimatedWakeMicros: Int = 0
    ) {
        self.activations = activations
        self.skips = skips.sorted()
        self.estimatedWakeMicros =
            max(0, estimatedWakeMicros)
    }
}

// MARK: - Activation planner

public enum BASAgentTierActivationPlanner {

    /// Compute per-turn activation plan based on:
    ///   - Risk band (low / medium / high)
    ///   - Caller's wake budget (microseconds)
    ///   - Latent spine cache hit ratio (when ≥ 0.7 + low risk,
    ///     skip cold agents)
    ///
    /// Per plan ch 980:
    ///   - LOW risk:hot agents only (Scout + Risk + Surface +
    ///     Sentinel + 7 watchers)
    ///   - MED risk:hot + Planner + Memory
    ///   - HIGH risk:all 9 core + 7 watchers
    public static func plan(
        riskBand: BASRiskAssessmentBand,
        wakeBudgetMicros: Int,
        spineHitRatio: Double = 0.0,
        forceActivate: [BASAgentRole] = []
    ) -> BASAgentTierActivationPlan {
        var activations: [BASAgentRole] = []
        var skips: [String] = []
        var consumed = 0

        // Always-on: hot tier roles
        let hotRoles: [BASAgentRole] = [
            .scout, .risk, .surface,
            .sovereignSentinel,
            .anomalyWatcher, .gaslightWatcher,
            .memoryPollutionWatcher, .hostDriftWatcher,
            .toolInjectionWatcher, .axisDeviationWatcher,
            .sanctumLeakWatcher,
        ]
        for role in hotRoles {
            if let a = BASAgentTierRegistry
                .assignment(for: role)
            {
                consumed += a.wakeBudgetMicros
                activations.append(role)
            }
        }

        // Cache-hit short-circuit: low risk + high cache hit →
        // skip ALL cold agents
        if riskBand == .low && spineHitRatio >= 0.7 {
            skips.append(
                "cache-hit-skip-cold:hit-ratio=" +
                String(format: "%.3f", spineHitRatio))
            // chapter 九百八十一.5 USER-PASS-7 H1 fix:honor
            // forceActivate but ALSO enforce wakeBudget。
            // Previously this path always consumed the budget
            // without checking — caller's forceActivate list
            // could blow past budget silently。 Per the
            // discipline track record (956.11 caught similar
            // budget-bypass bugs),the budget is the operator's
            // explicit constraint;forceActivate cannot
            // implicitly override it。 If budget exceeded,
            // record `forceActivate:budget-exceeded:<role>`
            // skip + still activate (preserving the user's
            // explicit override) but log the breach for the
            // audit ledger。
            for role in forceActivate
                where !activations.contains(role)
            {
                activations.append(role)
                if let a = BASAgentTierRegistry
                    .assignment(for: role)
                {
                    if consumed + a.wakeBudgetMicros >
                        wakeBudgetMicros
                    {
                        skips.append(
                            "forceActivate:budget-exceeded:" +
                            "\(role.rawValue)")
                    }
                    consumed += a.wakeBudgetMicros
                }
            }
            return BASAgentTierActivationPlan(
                activations: activations.sorted {
                    $0.rawValue < $1.rawValue
                },
                skips: skips,
                estimatedWakeMicros: consumed)
        }

        // Cold-tier activation by risk band
        let coldRolesForBand: [BASAgentRole]
        switch riskBand {
        case .low:
            coldRolesForBand = []
        case .medium:
            coldRolesForBand = [.planner, .memory]
        case .high:
            coldRolesForBand = [
                .planner, .memory, .critic,
                .hostAlignment, .evolutionShadow]
        }
        for role in coldRolesForBand {
            guard let a = BASAgentTierRegistry
                .assignment(for: role)
            else { continue }
            if consumed + a.wakeBudgetMicros >
                wakeBudgetMicros
            {
                skips.append(
                    "tier-budget-exceeded:\(role.rawValue)")
                continue
            }
            consumed += a.wakeBudgetMicros
            activations.append(role)
        }

        // Force-activate (e.g. host explicitly requested)。
        // chapter 九百八十一.5 USER-PASS-7 H1 fix:enforce
        // budget on forceActivate too (same fix as cache-hit
        // path above)。
        for role in forceActivate {
            if activations.contains(role) { continue }
            guard let a = BASAgentTierRegistry
                .assignment(for: role)
            else {
                activations.append(role)
                continue
            }
            if consumed + a.wakeBudgetMicros >
                wakeBudgetMicros
            {
                skips.append(
                    "forceActivate:budget-exceeded:" +
                    "\(role.rawValue)")
            }
            consumed += a.wakeBudgetMicros
            activations.append(role)
        }

        return BASAgentTierActivationPlan(
            activations: activations.sorted {
                $0.rawValue < $1.rawValue
            },
            skips: skips,
            estimatedWakeMicros: consumed)
    }
}
