// MARK: - BASAgentLeaseManager
// chapter 九百五十六 / M3485 (Phase 1 / ch1)
//
// User design Section 4 sub-system #3: Agent Lease Manager — per-turn
// materializes `BASAgentLease` instances from agent specs +
// `BASAgentLeaseProfile`。
//
// Per Root Law 7 (可回放) + ADR-014 OPT-IN: leases are immutable
// per-turn snapshots。 If an agent exhausts budget mid-turn it gets
// a clean cut,no extension — keeps replay determinism。
//
// Pure-function-ish:produces leases deterministically from
// (spec, profile, turnID, baseBudget) input。 No I/O,no shared state。
// Mirrors `BASOrganRegistry` resolution pattern but for lease grants。

import Foundation

/// Configuration for a single lease grant — caller-tunable knobs
/// the lease manager uses to scale per-agent budgets per turn。
public struct BASAgentLeaseBaseBudget:
    Sendable, Equatable, Hashable, Codable
{
    /// Wall-clock millisecond budget for a hot-seat agent at standard
    /// effort。 Cold-seat / sovereign / watcher derive from this。
    public let hotSeatBaseMs: Int

    /// Maximum token budget for hot seat (when wrapping LLM)。
    /// Non-LLM agents always get 0。
    public let hotSeatBaseTokens: Int

    /// Effort-preference multipliers — `1.0` standard,higher for
    /// deep。 Shallow uses `0.5`。 Multiplied into hot/cold budgets。
    public let shallowMultiplier: Double
    public let standardMultiplier: Double
    public let deepMultiplier: Double

    public init(
        hotSeatBaseMs: Int = 200,
        hotSeatBaseTokens: Int = 1024,
        shallowMultiplier: Double = 0.5,
        standardMultiplier: Double = 1.0,
        deepMultiplier: Double = 3.0
    ) {
        self.hotSeatBaseMs = hotSeatBaseMs
        self.hotSeatBaseTokens = hotSeatBaseTokens
        self.shallowMultiplier = shallowMultiplier
        self.standardMultiplier = standardMultiplier
        self.deepMultiplier = deepMultiplier
    }

    public static let `default` = BASAgentLeaseBaseBudget()
}

public enum BASAgentLeaseManager {

    /// Materialize a `BASAgentLease` for one agent for one turn。
    /// Pure function。
    ///
    /// - Parameters:
    ///   - spec: the registered agent spec (provides profile + domains)
    ///   - turnID: caller-supplied turn ID for lease ID generation
    ///   - effort: per-turn effort preference (drives budget multiplier)
    ///   - baseBudget: hot-seat baseline that scales per profile
    ///   - turnStartMs: unix epoch ms at turn start (lease expiresAt
    ///     derived from this + maxMs)
    ///   - sequenceInTurn: integer ordering for unique lease ID
    public static func materialize(
        spec: BASAgentSpec,
        turnID: String,
        effort: BASAgentRouterContext.EffortPreference,
        baseBudget: BASAgentLeaseBaseBudget = .default,
        turnStartMs: Int64,
        sequenceInTurn: Int = 0
    ) -> BASAgentLease {
        let effortMul = multiplier(
            for: effort, base: baseBudget)
        let profileMul = profileMultiplier(
            for: spec.defaultLeaseProfile)
        let maxMs = max(
            10,
            Int(Double(baseBudget.hotSeatBaseMs) * effortMul
                * profileMul))
        let maxTokens = needsLLMTokens(for: spec.defaultLeaseProfile)
            ? Int(Double(baseBudget.hotSeatBaseTokens) * effortMul)
            : 0
        // Allowed domains = read + write (the union of what spec
        // declared as accessible),excluding forbidden domains
        let forbidden = Set(spec.forbiddenDomains)
        let allowed = (spec.readDomains + spec.writeDomains)
            .filter { !forbidden.contains($0) }
        let leaseID =
            "\(spec.agentID).turn-\(turnID).\(sequenceInTurn)"
        return BASAgentLease(
            leaseID: leaseID,
            agentID: spec.agentID,
            turnID: turnID,
            maxMs: maxMs,
            maxTokens: maxTokens,
            maxStateReads: stateReadsCeiling(
                for: spec.defaultLeaseProfile),
            maxDeltaWrites: deltaWritesCeiling(
                for: spec.defaultLeaseProfile,
                writeDomains: spec.writeDomains),
            allowedDomains: Array(Set(allowed)).sorted {
                $0.rawValue < $1.rawValue
            },
            expiresAtMs: turnStartMs + Int64(maxMs),
            priority: defaultPriority(
                for: spec.defaultLeaseProfile))
    }

    /// Batch materialize leases for all active agents from an
    /// activation plan (Phase 1 ch 957 coordinator integration uses
    /// this to set up all per-turn leases in one go)。
    public static func materializeAll(
        plan: BASAgentActivationPlan,
        registry: [BASAgentSpec],
        turnID: String,
        effort: BASAgentRouterContext.EffortPreference,
        baseBudget: BASAgentLeaseBaseBudget = .default,
        turnStartMs: Int64
    ) -> [BASAgentLease] {
        let specByID = Dictionary(
            uniqueKeysWithValues: registry.map { ($0.agentID, $0) })
        var leases: [BASAgentLease] = []
        for (i, agentID) in plan.activeAgentIDs.enumerated() {
            guard let spec = specByID[agentID] else { continue }
            leases.append(materialize(
                spec: spec,
                turnID: turnID,
                effort: effort,
                baseBudget: baseBudget,
                turnStartMs: turnStartMs,
                sequenceInTurn: i))
        }
        return leases
    }

    // MARK: - Profile-derived budget helpers

    private static func multiplier(
        for effort: BASAgentRouterContext.EffortPreference,
        base: BASAgentLeaseBaseBudget
    ) -> Double {
        switch effort {
        case .shallow: return base.shallowMultiplier
        case .standard: return base.standardMultiplier
        case .deep: return base.deepMultiplier
        }
    }

    private static func profileMultiplier(
        for profile: BASAgentLeaseProfile
    ) -> Double {
        switch profile {
        case .hotSeat: return 1.0
        case .coldSeat: return 5.0   // cold seats get larger budget
                                      // when they DO activate
        case .watcher: return 0.1    // very small — quiet observers
        case .sovereign: return 10.0 // sovereign concerns get headroom
        }
    }

    private static func needsLLMTokens(
        for profile: BASAgentLeaseProfile
    ) -> Bool {
        switch profile {
        case .hotSeat, .coldSeat: return true
        case .watcher, .sovereign: return false
        }
    }

    private static func stateReadsCeiling(
        for profile: BASAgentLeaseProfile
    ) -> Int {
        switch profile {
        case .hotSeat: return 50
        case .coldSeat: return 500
        case .watcher: return 20
        case .sovereign: return 1000  // sovereign may need full view
        }
    }

    private static func deltaWritesCeiling(
        for profile: BASAgentLeaseProfile,
        writeDomains: [BASStateDomain]
    ) -> Int {
        // Agent that owns no write domains gets 0 delta writes
        guard !writeDomains.isEmpty else { return 0 }
        switch profile {
        case .hotSeat: return 10
        case .coldSeat: return 50
        case .watcher: return 0    // watchers never write
        case .sovereign: return 100
        }
    }

    private static func defaultPriority(
        for profile: BASAgentLeaseProfile
    ) -> Int {
        switch profile {
        case .hotSeat: return 5
        case .coldSeat: return 3
        case .watcher: return 1
        case .sovereign: return Int.max  // sovereign always wins
        }
    }
}
