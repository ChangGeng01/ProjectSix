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
    /// targeting the same `targetObjectRef` using priority + handle
    /// explicit `dependencies` + `conflictRefs` per chapter 956.5
    /// USER-PASS gap #3 fix。
    ///
    /// Processing order (chapter 956.5 strict mode):
    ///   1. Topological sort by `dependencies` — a delta D depends on
    ///      [d1, d2] means D is processed AFTER d1 and d2。 Cycles
    ///      caught by sort,reject all participants with reason
    ///      `dependency-cycle`。
    ///   2. For each delta in topo order:if any of its dependencies
    ///      was rejected → reject with reason `dependency-unsatisfied`。
    ///   3. Group surviving deltas by `targetObjectRef`。 Singleton
    ///      groups → accept。 Multi-delta groups → conflict resolution。
    ///   4. Within conflict group OR for explicit conflictRefs pairs:
    ///      a. Highest tier wins (sovereign > risk > host > evidence >
    ///         agentPriority > recency)
    ///      b. Tie at tier → higher agentPriority wins
    ///      c. Tie at priority → higher delta.confidence wins
    ///      d. Tie at confidence → **higher createdAtNanos wins**
    ///         (chapter 956.5 USER-PASS gap #5 fix: real timestamp
    ///         recency, was lex deltaID proxy)
    ///      e. Tie at recency (or both 0) → lex-smaller deltaID
    ///         (final deterministic break)
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
        // chapter 九百五十六.11 USER-PASS-4 CR1 fix:reject duplicate
        // deltaIDs at engine entry。 Without this guard,downstream
        // `Dictionary(uniqueKeysWithValues:)` calls at lines below
        // (surviving deltas) would TRAP at runtime — DoS via crafted
        // input。 Reject the WHOLE batch with `duplicate-delta-id`
        // reason so callers can audit + retry without crash。
        var seenIDs = Set<String>()
        var duplicateIDs: [String] = []
        for d in deltas {
            if !seenIDs.insert(d.deltaID).inserted {
                duplicateIDs.append(d.deltaID)
            }
        }
        if !duplicateIDs.isEmpty {
            let dupSorted = Array(Set(duplicateIDs)).sorted()
            let rejected = deltas.map { "delta:\($0.deltaID)" }
                .sorted()
            let audit = dupSorted.map {
                "delta:\($0) rejected reason=duplicate-delta-id"
            }
            return BASAgentMergeResult(
                mergeID: strongMergeID(
                    turnID: turnID,
                    deltaIDs: deltas.map { $0.deltaID }),
                acceptedDeltaIDs: [],
                rejectedDeltaIDs: rejected,
                conflictResolution: audit,
                resultingStateRef: "(none)",
                mergeReasonCodes: [
                    "merge.rejected-batch",
                    "merge.duplicate-delta-ids=" +
                        "\(dupSorted.count)",
                ])
        }
        // chapter 九百五十六.5 USER-PASS gap #3: topo-sort with
        // dependencies + reject cycles + propagate
        // dependency-unsatisfied。
        //
        // Three-pass ordering (correct propagation):
        //   1. Cycle participants → reject up-front。
        //   2. Per-target conflict resolution → winners tentatively
        //      accepted,losers rejected。 Run BEFORE dep propagation
        //      because losers may be deps of downstream deltas — those
        //      downstream deltas must then reject too。
        //   3. Re-iterate sortedDeltas in TOPO ORDER and propagate:
        //      any accepted delta whose dependency is now in
        //      rejectedSet → demote with dependency-unsatisfied。
        //      Topo order ensures chain rejection (d4 loses → d1
        //      depends on d4 → d3 depends on d1 all cascade)。
        let topoResult = topologicalSort(deltas)
        var acceptedSet = Set<String>()
        var rejectedSet = Set<String>()
        var conflictAudits: [String] = []
        // Pass 1: cycle participants
        for cycleID in topoResult.cycleParticipantDeltaIDs {
            rejectedSet.insert(cycleID)
            conflictAudits.append(
                "delta:\(cycleID) rejected reason=dependency-cycle")
        }
        let sortableDeltas = topoResult.sortedDeltas
        // Pass 2: per-target conflict resolution。 Skip cycle
        // participants (already rejected)。
        var byTarget: [String: [BASAgentDelta]] = [:]
        for d in sortableDeltas {
            byTarget[d.targetObjectRef, default: []].append(d)
        }
        for (ref, group) in byTarget {
            if group.count == 1 {
                acceptedSet.insert(group[0].deltaID)
                continue
            }
            let winner = pickWinner(group: group, context: ctx)
            for d in group {
                if d.deltaID == winner.deltaID {
                    acceptedSet.insert(d.deltaID)
                } else {
                    rejectedSet.insert(d.deltaID)
                }
            }
            let winnerTier = tier(for: winner, in: ctx)
            conflictAudits.append(
                "ref=\(ref) group_size=\(group.count) " +
                "winner=delta:\(winner.deltaID) " +
                "tier=\(winnerTier)")
        }
        // Pass 3: dep-unsatisfied propagation in TOPO ORDER。 Any
        // accepted delta whose dep was rejected (cycle / conflict /
        // earlier chain) is demoted with dependency-unsatisfied
        // reason。 Topo order guarantees chain cascade。
        for d in sortableDeltas {
            guard acceptedSet.contains(d.deltaID) else { continue }
            let depRejected = d.dependencies.contains { depRef in
                let depID = depRef.hasPrefix("delta:")
                    ? String(depRef.dropFirst("delta:".count))
                    : depRef
                return rejectedSet.contains(depID)
            }
            if depRejected {
                acceptedSet.remove(d.deltaID)
                rejectedSet.insert(d.deltaID)
                conflictAudits.append(
                    "delta:\(d.deltaID) rejected " +
                    "reason=dependency-unsatisfied")
            }
        }
        // chapter 九百五十六.5 USER-PASS gap #3 fix: also enforce
        // explicit conflictRefs across surviving accepted deltas。
        // If delta A is accepted but conflicts with delta B that's
        // also accepted (no target-ref collision but declared
        // adversarial),tier-resolve the pair and reject the loser。
        let surviving = sortableDeltas.filter {
            acceptedSet.contains($0.deltaID)
        }
        let acceptedByID = Dictionary(
            uniqueKeysWithValues: surviving.map { ($0.deltaID, $0) })
        var explicitConflictDemotions = Set<String>()
        for d in surviving {
            for conflictRef in d.conflictRefs {
                let conflictID = conflictRef.hasPrefix("delta:")
                    ? String(
                        conflictRef.dropFirst("delta:".count))
                    : conflictRef
                guard let other =
                    acceptedByID[conflictID],
                    !explicitConflictDemotions
                        .contains(d.deltaID),
                    !explicitConflictDemotions
                        .contains(conflictID)
                else { continue }
                // Tier-resolve the explicit pair
                let pair = [d, other]
                let pairWinner = pickWinner(
                    group: pair, context: ctx)
                let pairLoser = pairWinner.deltaID == d.deltaID
                    ? other : d
                explicitConflictDemotions
                    .insert(pairLoser.deltaID)
                conflictAudits.append(
                    "explicit-conflict " +
                    "winner=delta:\(pairWinner.deltaID) " +
                    "loser=delta:\(pairLoser.deltaID) " +
                    "reason=explicit-conflict")
            }
        }
        for demoted in explicitConflictDemotions {
            acceptedSet.remove(demoted)
            rejectedSet.insert(demoted)
        }
        let accepted = acceptedSet
            .map { "delta:\($0)" }.sorted()
        let rejected = rejectedSet
            .map { "delta:\($0)" }.sorted()
        conflictAudits.sort()
        // chapter 九百五十六.5 USER-PASS gap #4 fix: strong mergeID
        // via deterministic content hash of (turnID + sorted delta
        // IDs)。 Previously `merge.<turnID>.<count>` collided when
        // two merges in same turn produced same delta count。 Now
        // FNV-1a 64-bit hex over canonical inputs gives ≤2^-64
        // collision probability。
        let mergeID = strongMergeID(
            turnID: turnID, deltaIDs: deltas.map { $0.deltaID })
        let reasonCodes = conflictAudits.isEmpty
            ? ["merge.no-conflicts"]
            : [
                "merge.conflicts-resolved=\(conflictAudits.count)",
                "merge.priority=sovereign-risk-host-evidence-" +
                "agent-recency",
            ]
        // chapter 九百五十六.11 USER-PASS-4 CR3 fix:resultingStateRef
        // must reference an ACCEPTED delta's target,not just any
        // group key。 Previously returned the lex-smallest target of
        // any conflict group including those whose winner was later
        // demoted by dep-unsatisfied or explicit-conflict passes,
        // misleading audit consumers。 Now: derived from the
        // post-pass-3 + post-explicit-conflict accepted set。
        let deltasByID = Dictionary(
            uniqueKeysWithValues:
                deltas.map { ($0.deltaID, $0) })
        let acceptedTargets = acceptedSet
            .compactMap { deltasByID[$0]?.targetObjectRef }
        let resultingRef = acceptedTargets.sorted().first
            ?? "(none)"
        return BASAgentMergeResult(
            mergeID: mergeID,
            acceptedDeltaIDs: accepted,
            rejectedDeltaIDs: rejected,
            conflictResolution: conflictAudits,
            resultingStateRef: resultingRef,
            mergeReasonCodes: reasonCodes)
    }

    // MARK: - Topological sort (USER-PASS gap #3 fix)

    /// chapter 九百五十六.5 USER-PASS gap #3 fix: topo sort by
    /// `dependencies`。 Returns sorted deltas + cycle participants
    /// (deltas in a dependency cycle,must be rejected)。 Uses
    /// Kahn's algorithm — pure function。
    private struct TopoResult {
        let sortedDeltas: [BASAgentDelta]
        let cycleParticipantDeltaIDs: Set<String>
    }

    private static func topologicalSort(
        _ deltas: [BASAgentDelta]
    ) -> TopoResult {
        // chapter 九百五十六.6 perf rewrite:proper O(V+E) Kahn。
        // Previous impl was O(n³ log n) (nested scan + per-append sort)。
        // Measured on macOS:128 deltas took 7.3ms p99,512 took 119ms
        // — way over the 1ms p99 budget。 Algorithmic fix below brings
        // 512 deltas to <200μs p99 (validated by ch 956.6 bench)。
        //
        // Algorithm:
        //   1. ONE pass to strip "delta:" prefixes from all dep refs +
        //      build canonical depIDs per delta。
        //   2. Build forward adjacency map (depID → [dependentDeltaID])
        //      ONCE — O(V + E) total。
        //   3. Compute in-degree from canonical depIDs — O(V + E)。
        //   4. Seed queue with all in-degree-0 deltas in lex order
        //      ONCE (priority queue would be overkill;final order
        //      among same-rank deltas is conflict-resolution's job
        //      not topo-sort's,so lex stable order suffices)。
        //   5. Standard Kahn loop:dequeue → emit → for each
        //      dependent decrement;if 0,enqueue。 Total O(V + E)。
        //
        // Cycle detection:any delta NOT in sorted output is in a cycle
        // (or depends on a cycle)。
        let n = deltas.count
        // Index by deltaID — O(V)
        var indexByID = [String: Int]()
        indexByID.reserveCapacity(n)
        for (i, d) in deltas.enumerated() {
            indexByID[d.deltaID] = i
        }
        // Resolve dependencies to in-set deltaIDs once。 External
        // deps (depID not in input) are dropped per caller contract。
        var resolvedDeps: [[Int]] = Array(
            repeating: [], count: n)
        for (i, d) in deltas.enumerated() {
            if d.dependencies.isEmpty { continue }
            var deps: [Int] = []
            deps.reserveCapacity(d.dependencies.count)
            for depRef in d.dependencies {
                let depID = depRef.hasPrefix("delta:")
                    ? String(depRef.dropFirst("delta:".count))
                    : depRef
                if let depIdx = indexByID[depID] {
                    deps.append(depIdx)
                }
            }
            resolvedDeps[i] = deps
        }
        // Forward adjacency: depIdx → [dependentIdx]。 O(V + E)
        var dependents: [[Int]] = Array(repeating: [], count: n)
        var inDegree: [Int] = Array(repeating: 0, count: n)
        for i in 0..<n {
            for depIdx in resolvedDeps[i] {
                dependents[depIdx].append(i)
                inDegree[i] += 1
            }
        }
        // Seed queue with in-degree-0 deltas in lex deltaID order。
        // Lex order is for determinism only — actual tie-breaks
        // happen in pickWinner / winsAgainst,not topo sort。
        var seedIndices: [Int] = []
        seedIndices.reserveCapacity(n)
        for i in 0..<n where inDegree[i] == 0 {
            seedIndices.append(i)
        }
        seedIndices.sort {
            deltas[$0].deltaID < deltas[$1].deltaID
        }
        // Kahn's main loop with a simple index-based queue。 Pop via
        // head pointer (O(1) amortized) — Array.removeFirst is O(n)
        // and was a hot path in the old impl。
        var queueHead = 0
        var queue = seedIndices
        var sorted: [BASAgentDelta] = []
        sorted.reserveCapacity(n)
        while queueHead < queue.count {
            let currentIdx = queue[queueHead]
            queueHead += 1
            sorted.append(deltas[currentIdx])
            for dependentIdx in dependents[currentIdx] {
                inDegree[dependentIdx] -= 1
                if inDegree[dependentIdx] == 0 {
                    queue.append(dependentIdx)
                }
            }
        }
        // Cycle participants = those never reached
        var emittedSet = Set<String>()
        emittedSet.reserveCapacity(sorted.count)
        for d in sorted { emittedSet.insert(d.deltaID) }
        var cycleIDs = Set<String>()
        for d in deltas where !emittedSet.contains(d.deltaID) {
            cycleIDs.insert(d.deltaID)
        }
        return TopoResult(
            sortedDeltas: sorted,
            cycleParticipantDeltaIDs: cycleIDs)
    }

    // MARK: - Strong mergeID (USER-PASS gap #4 fix)

    /// chapter 九百五十六.5 USER-PASS gap #4 fix: strong mergeID via
    /// FNV-1a 64-bit hash over canonical inputs。 Format:
    /// `merge.<turnID>.<count>.<hex16>`。 Two merges with same
    /// turnID + count but different delta IDs get different mergeIDs
    /// (collision probability ≤ 2^-64 ≈ 5.4e-20)。
    private static func strongMergeID(
        turnID: String,
        deltaIDs: [String]
    ) -> String {
        let canonical = turnID + "|" + deltaIDs.sorted()
            .joined(separator: ",")
        let hash = fnv1a64(canonical)
        // chapter 九百五十六.9 — MUST use %016llx,not %016x:Swift
        // `String(format:)` follows C printf conventions where `%x`
        // reads variadic arg as `unsigned int` (32-bit) → upper
        // 32 bits of UInt64 silently truncated。 Caught by ch 956.9
        // cross-language Rust parity test。 Previously every mergeID
        // had only 32 bits of entropy,not 64。
        return "merge.\(turnID).\(deltaIDs.count)." +
               String(format: "%016llx", hash)
    }

    /// FNV-1a 64-bit hash。 Standard non-cryptographic hash,
    /// strong enough for content-id deduplication at our scale。
    /// For cryptographic strength,future revision can swap to
    /// SHA-256 via CryptoKit (sub-ms on iPhone Air for our payload
    /// sizes per ch 952.4 measurements)。
    private static func fnv1a64(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    // MARK: - Internal helpers

    /// Tie-breaker order per ch 956.5:tier → agentPriority →
    /// confidence → **createdAtNanos** (USER-PASS gap #5 fix:
    /// real timestamp,was lex deltaID proxy) → deltaID (lex,
    /// final deterministic break)
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

    /// Strict greater-than under
    /// (tier > priority > confidence > recency-timestamp > id-lex)
    /// per chapter 九百五十六.5 USER-PASS gap #5 fix。
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
        // chapter 九百五十六.5 USER-PASS gap #5 fix:real timestamp
        // recency。 0 = unknown timestamp (skip — fall through to
        // lex deltaID tie-break)。 Higher createdAtNanos = MORE
        // RECENT = wins。
        if candidate.createdAtNanos != 0
            || best.createdAtNanos != 0,
           candidate.createdAtNanos != best.createdAtNanos
        {
            return candidate.createdAtNanos > best.createdAtNanos
        }
        // Final tie-breaker:lex-ascending deltaID。 Smaller ID wins。
        return candidate.deltaID < best.deltaID
    }
}
