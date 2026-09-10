// MARK: - BASAgentRouter
// chapter 九百五十六 / M3485 (Phase 1 / ch1)
//
// User design Section 4 sub-system #2: Agent Router — per-turn
// decides which agents activate based on turn context。
//
// Per user's Section 9.2 activation rules:
//   - low risk: Scout + Surface
//   - med risk: + Planner + Risk-light
//   - high risk: + Memory + Critic + HostAlignment + SovereignSentinel
//
// Pure function — no I/O,no actor。 Takes (registry snapshot,
// turn context) → returns `BASAgentActivationPlan`。 Caller (Phase 1
// ch 957 coordinator integration) consumes the plan to actually
// invoke agents。
//
// Watchers are always activated (they emit hints,no cost beyond
// their lease budget)。 The 4 sovereign-LOW agents are always
// activated regardless of risk band (sovereign concerns never sleep)。

import Foundation

/// Three turn-context dimensions that drive activation:
///   - riskBand: low / medium / high — from L11 risk gate
///   - intentScope: which layers the request touches (e.g. memory-heavy
///     vs surface-only)
///   - effortPreference: shallow / standard / deep — from user request
///     or workflow profile
public struct BASAgentRouterContext:
    Sendable, Equatable, Hashable
{
    public enum RiskBand: String, Codable,
        Sendable, Equatable, Hashable, CaseIterable
    {
        case low
        case medium
        case high
    }

    public enum EffortPreference: String, Codable,
        Sendable, Equatable, Hashable, CaseIterable
    {
        case shallow
        case standard
        case deep
    }

    public let riskBand: RiskBand
    public let effortPreference: EffortPreference
    /// Which L1-L14 layers this turn intends to engage。 Empty =
    /// router uses heuristic default。
    public let intentLayers: [Int]
    /// Override:caller may explicitly request specific agent
    /// activation regardless of heuristic。 Empty = use heuristic only。
    public let requestedAgentIDs: [String]

    public init(
        riskBand: RiskBand,
        effortPreference: EffortPreference = .standard,
        intentLayers: [Int] = [],
        requestedAgentIDs: [String] = []
    ) {
        self.riskBand = riskBand
        self.effortPreference = effortPreference
        self.intentLayers = intentLayers
        self.requestedAgentIDs = requestedAgentIDs
    }
}

/// Output of the router — which agents to wake this turn。
public struct BASAgentActivationPlan:
    Sendable, Equatable, Hashable, Codable
{
    /// Agents to activate this turn,in invocation order。
    public let activeAgentIDs: [String]
    /// Per-agent reason code explaining why activated (audit trail)。
    /// Keyed by agentID。 Example: `"risk.high.escalation"`,
    /// `"always-on.sovereign"`,`"requested.user-override"`。
    public let activationReasons: [String: String]
    /// Agents considered + skipped this turn,with reason。
    /// Example: `"deep-cold.budget-deny"`,`"out-of-band.scope"`。
    public let skippedReasons: [String: String]

    public init(
        activeAgentIDs: [String],
        activationReasons: [String: String] = [:],
        skippedReasons: [String: String] = [:]
    ) {
        self.activeAgentIDs = activeAgentIDs
        self.activationReasons = activationReasons
        self.skippedReasons = skippedReasons
    }
}

public enum BASAgentRouter {

    /// Decide activation plan from a registry snapshot + context。
    /// Pure function (snapshot taken by caller)。
    public static func route(
        allSpecs: [BASAgentSpec],
        context ctx: BASAgentRouterContext
    ) -> BASAgentActivationPlan {
        var active: [String] = []
        var reasons: [String: String] = [:]
        var skipped: [String: String] = [:]

        // Step 1: always-on (sovereign-LOW + watchers)
        for spec in allSpecs {
            if spec.visibility == .low {
                active.append(spec.agentID)
                reasons[spec.agentID] = "always-on.sovereign-low"
                continue
            }
            if isWatcher(role: spec.role) {
                active.append(spec.agentID)
                reasons[spec.agentID] = "always-on.watcher"
                continue
            }
        }

        // Step 2: per-risk-band activation
        let bandRoles = rolesForBand(ctx.riskBand)
        for spec in allSpecs {
            guard !active.contains(spec.agentID) else { continue }
            if bandRoles.contains(spec.role) {
                active.append(spec.agentID)
                reasons[spec.agentID] =
                    "risk-band.\(ctx.riskBand.rawValue)"
            } else {
                skipped[spec.agentID] =
                    "out-of-band.risk=\(ctx.riskBand.rawValue)"
            }
        }

        // Step 3: effort preference can pull cold agents in
        if ctx.effortPreference == .deep {
            for spec in allSpecs {
                guard !active.contains(spec.agentID),
                      spec.defaultLeaseProfile == .coldSeat
                else { continue }
                // Re-evaluate: deep effort wakes cold seats
                active.append(spec.agentID)
                reasons[spec.agentID] = "effort.deep-cold-wake"
                skipped.removeValue(forKey: spec.agentID)
            }
        }

        // Step 4: explicit caller overrides win last
        for requestedID in ctx.requestedAgentIDs {
            // Only honor if the requested agent is actually registered
            if allSpecs.contains(where: { $0.agentID == requestedID }) {
                if !active.contains(requestedID) {
                    active.append(requestedID)
                }
                reasons[requestedID] = "requested.user-override"
                skipped.removeValue(forKey: requestedID)
            }
        }

        return BASAgentActivationPlan(
            activeAgentIDs: active,
            activationReasons: reasons,
            skippedReasons: skipped)
    }

    // MARK: - Helpers

    private static func isWatcher(role: BASAgentRole) -> Bool {
        switch role {
        case .anomalyWatcher, .gaslightWatcher,
             .memoryPollutionWatcher, .hostDriftWatcher,
             .toolInjectionWatcher, .axisDeviationWatcher,
             .sanctumLeakWatcher:
            return true
        default:
            return false
        }
    }

    /// Per user's Section 9.2:roles activated per risk band。 Cumulative
    /// (high includes med includes low)。
    private static func rolesForBand(
        _ band: BASAgentRouterContext.RiskBand
    ) -> Set<BASAgentRole> {
        var roles: Set<BASAgentRole> = []
        // All bands: Scout + Surface
        roles.insert(.scout)
        roles.insert(.surface)
        // Med+: Planner + Risk
        if band == .medium || band == .high {
            roles.insert(.planner)
            roles.insert(.risk)
        }
        // High: Memory + Critic + HostAlignment + SovereignSentinel
        if band == .high {
            roles.insert(.memory)
            roles.insert(.critic)
            roles.insert(.hostAlignment)
            roles.insert(.sovereignSentinel)
        }
        return roles
    }
}
