// MARK: - BASAgentMergeEngine
// chapter 九百五十五 / M3480 (Phase 0 / ch3)
//
// User design Section 9.4 conflict resolution priority:
//
//   Sovereign > Risk > Host > Evidence > Agent priority > Recency
//
// Pure-function merge engine。 Input:`[BASAgentDelta]` from agents
// in the same turn。 Output:`BASAgentMergeResult` with accepted +
// rejected delta IDs + per-conflict resolution audit trail。
//
// Sub-system #6 (Merge & Arbitration Engine) per the Agent Fabric
// architecture。 Defers final adjudication to L10 三我庭 + L11 风闸
// + L14 主权 (downstream in Phase 1+),but resolves intra-turn
// delta conflicts here。
//
// Per Root Law 3 (Single-Writer-Per-Domain),deltas against non-owned
// domains become PROPOSALS routed to the writer。 This merge engine
// handles only the actually-accepted-deltas conflict resolution
// (Phase 1 ch 959 wraps proposal-routing on top)。
//
// Pure pure pure:no actor,no I/O,no shared state。 Same input
// always produces same output。 Property tests (Phase 0 close)
// prove priority invariants across 10K random delta sets。

import Foundation

/// Reason tag categorizing why a delta won/lost in conflict
/// resolution。 Used by the merge engine to compute the priority
/// tier for each delta。
///
/// Per user's Section 9.4 the order is:
///   1. Sovereign — L14 enforcement (highest)
///   2. Risk — L11 risk-field constraints
///   3. Host — L5 host constitution constraints
///   4. Evidence — observation confidence
///   5. AgentPriority — lease priority
///   6. Recency — within same tier,prefer newer
public enum BASMergePriorityTier: Int, Comparable,
    Sendable, Equatable, Hashable
{
    case recency = 0
    case agentPriority = 1
    case evidence = 2
    case host = 3
    case risk = 4
    case sovereign = 5

    public static func < (
        lhs: BASMergePriorityTier,
        rhs: BASMergePriorityTier
    ) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Pure-function context to derive priority tier from delta state。
/// Caller (typically Phase 1 ch 959 coordinator integration) builds
/// this context from the agent specs + risk state + sovereign state。
public struct BASMergePriorityContext:
    Sendable, Equatable, Hashable
{
    /// Agent IDs that are sovereign-authoritative — their deltas
    /// always tier as `.sovereign`。 Typically just the
    /// SovereignSentinel agent (per Single-Writer for
    /// `.sovereignVerdict` domain)。
    public let sovereignAgentIDs: Set<String>

    /// Agent IDs whose deltas tier as `.risk` — typically Risk
    /// agent (per Single-Writer for `.riskField` domain)。
    public let riskAgentIDs: Set<String>

    /// Agent IDs whose deltas tier as `.host` — typically
    /// HostAlignment agent。
    public let hostAgentIDs: Set<String>

    /// Per-agent lease priority lookup。 Higher = stronger preference。
    /// Defaults to 0 if agent not present in map。
    public let agentPriorities: [String: Int]

    /// Evidence-tier confidence threshold。 Deltas with confidence
    /// ≥ this value tier as `.evidence`,below as `.agentPriority`。
    public let evidenceConfidenceFloor: Double

    public init(
        sovereignAgentIDs: Set<String> = [],
        riskAgentIDs: Set<String> = [],
        hostAgentIDs: Set<String> = [],
        agentPriorities: [String: Int] = [:],
        evidenceConfidenceFloor: Double = 0.5
    ) {
        self.sovereignAgentIDs = sovereignAgentIDs
        self.riskAgentIDs = riskAgentIDs
        self.hostAgentIDs = hostAgentIDs
        self.agentPriorities = agentPriorities
        self.evidenceConfidenceFloor = evidenceConfidenceFloor
    }
}

public enum BASAgentMergeEngine {

    /// Derive priority tier for a delta given context。 Pure function。
    public static func tier(
        for delta: BASAgentDelta,
        in ctx: BASMergePriorityContext
    ) -> BASMergePriorityTier {
        if ctx.sovereignAgentIDs.contains(delta.agentID) {
            return .sovereign
        }
        if ctx.riskAgentIDs.contains(delta.agentID) {
            return .risk
        }
        if ctx.hostAgentIDs.contains(delta.agentID) {
            return .host
        }
        if delta.confidence >= ctx.evidenceConfidenceFloor {
            return .evidence
        }
        return .agentPriority
    }

    /// Pure-function merge:resolve conflicts between deltas
    /// targeting the same `targetObjectRef` using priority。
    ///
    /// Deltas targeting different refs never conflict — they're all
    /// accepted。 Within a conflict group:
    ///   1. Highest tier wins
    ///   2. Tie at tier → higher agentPriority wins
    ///   3. Tie at priority → higher delta.confidence wins
    ///   4. Tie at confidence → lexicographic deltaID for determinism
    ///      (recency would require timestamps;deltaID order acts as
    ///      proxy when caller chooses lex-ordered IDs)
    ///
    /// - Parameters:
    ///   - deltas: input deltas from this turn
    ///   - ctx: tier-derivation context (built from agent specs +
    ///     current risk + sovereign state)
    ///   - turnID: caller-supplied turn ID for merge ID generation
    /// - Returns:
    ///   merge result with accepted/rejected delta IDs +
    ///   conflict resolution audit trail
    public static func merge(
        _ deltas: [BASAgentDelta],
        context ctx: BASMergePriorityContext,
        turnID: String
    ) -> BASAgentMergeResult {
        // Group by target ref
        var byTarget: [String: [BASAgentDelta]] = [:]
        for d in deltas {
            byTarget[d.targetObjectRef, default: []].append(d)
        }
        var accepted: [String] = []
        var rejected: [String] = []
        var conflictAudits: [String] = []
        for (ref, group) in byTarget {
            if group.count == 1 {
                accepted.append("delta:\(group[0].deltaID)")
                continue
            }
            // Score each delta in the conflict group
            let winner = pickWinner(group: group, context: ctx)
            for d in group {
                if d.deltaID == winner.deltaID {
                    accepted.append("delta:\(d.deltaID)")
                } else {
                    rejected.append("delta:\(d.deltaID)")
                }
            }
            let winnerTier = tier(for: winner, in: ctx)
            conflictAudits.append(
                "ref=\(ref) group_size=\(group.count) " +
                "winner=delta:\(winner.deltaID) " +
                "tier=\(winnerTier)")
        }
        accepted.sort()
        rejected.sort()
        conflictAudits.sort()
        let mergeID = "merge.\(turnID).\(deltas.count)"
        let reasonCodes = conflictAudits.isEmpty
            ? ["merge.no-conflicts"]
            : [
                "merge.conflicts-resolved=\(conflictAudits.count)",
                "merge.priority=sovereign-risk-host-evidence-" +
                "agent-recency",
            ]
        return BASAgentMergeResult(
            mergeID: mergeID,
            acceptedDeltaIDs: accepted,
            rejectedDeltaIDs: rejected,
            conflictResolution: conflictAudits,
            resultingStateRef: byTarget.keys.sorted()
                .first ?? "(none)",
            mergeReasonCodes: reasonCodes)
    }

    // MARK: - Internal helpers

    /// Tie-breaker order:tier → agentPriority → confidence →
    /// deltaID (lex)。 Returns the winning delta from a non-empty group。
    private static func pickWinner(
        group: [BASAgentDelta],
        context ctx: BASMergePriorityContext
    ) -> BASAgentDelta {
        precondition(!group.isEmpty, "conflict group empty")
        var best = group[0]
        var bestTier = tier(for: best, in: ctx)
        var bestPrio = ctx.agentPriorities[best.agentID] ?? 0
        for d in group.dropFirst() {
            let t = tier(for: d, in: ctx)
            let p = ctx.agentPriorities[d.agentID] ?? 0
            if winsAgainst(
                candidate: d,
                candidateTier: t,
                candidatePriority: p,
                best: best,
                bestTier: bestTier,
                bestPriority: bestPrio)
            {
                best = d
                bestTier = t
                bestPrio = p
            }
        }
        return best
    }

    /// Strict greater-than under (tier > priority > confidence > id-lex)
    private static func winsAgainst(
        candidate: BASAgentDelta,
        candidateTier: BASMergePriorityTier,
        candidatePriority: Int,
        best: BASAgentDelta,
        bestTier: BASMergePriorityTier,
        bestPriority: Int
    ) -> Bool {
        if candidateTier != bestTier {
            return candidateTier > bestTier
        }
        if candidatePriority != bestPriority {
            return candidatePriority > bestPriority
        }
        if candidate.confidence != best.confidence {
            return candidate.confidence > best.confidence
        }
        // Final tie-breaker:lex-ascending deltaID。 Smaller ID wins。
        return candidate.deltaID < best.deltaID
    }
}
