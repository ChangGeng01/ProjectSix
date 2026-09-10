// MARK: - BASSpeculativePrefetcher + zero-copy state bus
// chapter 九百八十一 / M3610 — Phase 8 ch3 + ARC SEAL
//
// User design Section 13.4 + plan PHASE 8 ch3:
//
//   Speculative parallelism + zero-copy state bus:while L6/L7
//   in flight,prefetch Memory + pre-render Compare shell +
//   Guard branch templates。 Pass refs not strings between
//   agents。
//
// ## Two related optimizations
//
// 1. **Speculative prefetch** — start expensive work BEFORE we
//    know it's needed,so when we do need it,it's already
//    ready or partway done。 The risk of speculating wrong is
//    bounded (worst case:we wasted the speculative work)。
//
// 2. **Zero-copy state bus** — agents pass REFERENCES to state
//    graph objects (via `BASZeroCopyStateRef`) instead of
//    re-serializing the payload JSON between agents。 Reduces
//    per-turn allocation + copy cost from O(N×payload-size) to
//    O(N×ref-size)。 Per Swift's Copy-on-Write semantics,
//    value-typed refs are still safe to pass — only the
//    backing store is shared。
//
// ## Pure-fn discipline + lifecycle
//
// Same as ch 979 + ch 980 — pure data + pure functions。
// Caller (coordinator's turn dispatcher) consults the
// prefetcher BEFORE kicking off L6/L7 to know what to
// speculate on。 Caller manages the actual concurrent
// execution (Swift Task groups,etc.) — this layer just
// declares POLICY。
//
// ## Speculation discipline
//
// Per ch 944 H2 + ch 952.4 measurement discipline:every
// speculative prefetch MUST be:
//   - Idempotent (re-running with same input gives same output)
//   - Safe-on-abandon (if turn doesn't need the speculation,
//     no side effect from running it)
//   - Cheap-to-cancel (caller can drop the prefetch if turn
//     turns out high-risk)
//
// We model these as three flags on `BASSpeculativeTask`。

import Foundation

// MARK: - Speculative task descriptor

public struct BASSpeculativeTask:
    Sendable, Equatable, Hashable, Codable
{
    public let taskID: String
    /// What kind of work to prefetch。 Caller-recognized
    /// string,e.g. "memory.recall" / "compare.shell-render"
    /// / "guard.template" / "watcher.warmup"。
    public let workKind: String
    /// Estimated work cost in microseconds。 Used by ch 980
    /// activation planner + ch 981 prefetcher to decide
    /// whether to fire the prefetch within the caller's
    /// budget。
    public let estimatedCostMicros: Int
    /// Idempotency flag — true if running this task twice
    /// produces same output (caller may safely retry or
    /// abandon)。
    public let isIdempotent: Bool
    /// Safe-on-abandon flag — true if abandoning the result
    /// has zero side effect (so caller may abort if turn
    /// pivots)。
    public let isSafeOnAbandon: Bool
    /// Speculation confidence (0.0-1.0) — caller's prior that
    /// this prefetch will be useful。 The prefetcher orders
    /// tasks by descending confidence × benefit / cost。
    public let confidence: Double

    public init(
        taskID: String,
        workKind: String,
        estimatedCostMicros: Int,
        isIdempotent: Bool = true,
        isSafeOnAbandon: Bool = true,
        confidence: Double = 0.5
    ) {
        self.taskID = taskID
        self.workKind = workKind
        self.estimatedCostMicros =
            max(0, estimatedCostMicros)
        self.isIdempotent = isIdempotent
        self.isSafeOnAbandon = isSafeOnAbandon
        self.confidence =
            max(0.0, min(1.0, confidence))
    }
}

// MARK: - Speculation plan (per-turn)

public struct BASSpeculationPlan:
    Sendable, Equatable, Hashable, Codable
{
    public let turnID: String
    /// Tasks that fit within budget — caller fires these
    /// concurrently with L6/L7。 Sorted by descending
    /// confidence (highest-payoff first)。
    public let fire: [BASSpeculativeTask]
    /// Tasks skipped due to budget。 Audit trail。 Each entry
    /// is a `taskID:skip-reason` string,sorted。
    public let skipped: [String]
    /// Total estimated cost (microseconds) of `fire`。
    public let totalEstimatedCostMicros: Int

    public init(
        turnID: String,
        fire: [BASSpeculativeTask],
        skipped: [String] = [],
        totalEstimatedCostMicros: Int = 0
    ) {
        self.turnID = turnID
        self.fire = fire
        self.skipped = skipped.sorted()
        self.totalEstimatedCostMicros =
            max(0, totalEstimatedCostMicros)
    }
}

// MARK: - Prefetcher

public enum BASSpeculativePrefetcher {

    /// Compute speculation plan given caller's budget。 Tasks
    /// are sorted by `confidence × (1 / cost)` heuristic
    /// (highest payoff first),then greedily added to `fire`
    /// until budget exhausts。 Non-safe-on-abandon tasks ALWAYS
    /// included regardless of budget if they're necessary
    /// (caller can't drop them mid-turn)。 In Phase 8 ch3 we
    /// only include safe-on-abandon tasks — but the field is
    /// there for future explicit-safety-required tasks。
    public static func plan(
        turnID: String,
        tasks: [BASSpeculativeTask],
        wakeBudgetMicros: Int
    ) -> BASSpeculationPlan {
        // Filter to safe-on-abandon AND idempotent
        let eligible = tasks.filter {
            $0.isSafeOnAbandon && $0.isIdempotent
        }
        // Score: confidence / max(1, cost) for sorting
        let scored = eligible.map { t -> (BASSpeculativeTask, Double) in
            let score = t.confidence /
                max(1.0, Double(t.estimatedCostMicros))
            return (t, score)
        }.sorted {
            $0.1 > $1.1  // highest score first
        }

        var fire: [BASSpeculativeTask] = []
        var skipped: [String] = []
        var consumed = 0
        for (task, _) in scored {
            if consumed + task.estimatedCostMicros >
                wakeBudgetMicros
            {
                skipped.append(
                    "\(task.taskID):budget-exceeded")
                continue
            }
            fire.append(task)
            consumed += task.estimatedCostMicros
        }
        // Non-eligible tasks are reported as skipped with
        // their reason
        for task in tasks
            where !task.isSafeOnAbandon ||
                  !task.isIdempotent
        {
            let reason = !task.isSafeOnAbandon
                ? "not-safe-on-abandon"
                : "not-idempotent"
            skipped.append("\(task.taskID):\(reason)")
        }

        return BASSpeculationPlan(
            turnID: turnID,
            fire: fire,
            skipped: skipped,
            totalEstimatedCostMicros: consumed)
    }

    /// Default speculation tasks for the canonical 9-seat
    /// turn。 Caller may customize per host but this provides
    /// the reference set per plan Section 13.4。
    public static func defaultTasks(
        riskBand: BASRiskAssessmentBand
    ) -> [BASSpeculativeTask] {
        var tasks: [BASSpeculativeTask] = [
            // Memory recall — always speculative + safe
            .init(
                taskID: "spec.memory.recall",
                workKind: "memory.recall",
                estimatedCostMicros: 30_000,
                isIdempotent: true,
                isSafeOnAbandon: true,
                confidence: 0.7),
            // Compare-mode shell render — only beneficial when
            // compare mode requested,but cheap + idempotent
            .init(
                taskID: "spec.compare.shell-render",
                workKind: "compare.shell-render",
                estimatedCostMicros: 8_000,
                isIdempotent: true,
                isSafeOnAbandon: true,
                confidence: 0.4),
            // Guard branch templates — pre-render the
            // "blocked / delayed / silenced" surface templates
            // so high-risk turn doesn't pay render cost
            .init(
                taskID: "spec.guard.templates",
                workKind: "guard.template",
                estimatedCostMicros: 5_000,
                isIdempotent: true,
                isSafeOnAbandon: true,
                // Confidence proportional to risk band
                confidence: riskBand == .high
                    ? 0.9
                    : (riskBand == .medium ? 0.5 : 0.2)),
            // Watcher warmup — load the 7 watcher pattern
            // sets into memory before scout output arrives
            .init(
                taskID: "spec.watcher.warmup",
                workKind: "watcher.warmup",
                estimatedCostMicros: 3_000,
                isIdempotent: true,
                isSafeOnAbandon: true,
                confidence: 0.85),
        ]
        // High-risk turns add critic+sentinel prefetch
        if riskBand == .high {
            tasks.append(.init(
                taskID: "spec.critic.warmup",
                workKind: "critic.warmup",
                estimatedCostMicros: 20_000,
                isIdempotent: true,
                isSafeOnAbandon: true,
                confidence: 0.85))
        }
        return tasks
    }
}

// MARK: - Zero-copy state ref (the bus)

/// Slim REFERENCE-NOT-VALUE to a state graph object。 Agents
/// pass this instead of re-serializing the payload JSON。
/// `BASSharedStateGraph` already stores the actual payload
/// once,keyed by `domain#objectID`;this ref is just a typed
/// pointer to that key + a version hint。
///
/// Per Single-Writer-Per-Domain (ch 953) + ch 956.5 USER-PASS
/// gap fix:every state-graph object has a stable
/// `(domain, objectID)` key + a monotonic version counter。
/// The zero-copy ref carries both,so a stale ref can be
/// detected (caller compares ref.versionAtRead vs
/// graph.versionFor(domain:objectID:) and refetches if newer)。
public struct BASZeroCopyStateRef:
    Sendable, Equatable, Hashable, Codable
{
    public let domain: BASStateDomain
    public let objectID: String
    /// Version at the time the ref was created。 Used for
    /// stale-ref detection。
    public let versionAtRead: Int64
    /// Nanos timestamp when the ref was created。 Trace replay。
    public let createdAtNanos: Int64

    public init(
        domain: BASStateDomain,
        objectID: String,
        versionAtRead: Int64,
        createdAtNanos: Int64 = 0
    ) {
        self.domain = domain
        self.objectID = objectID
        self.versionAtRead = max(0, versionAtRead)
        self.createdAtNanos = createdAtNanos
    }

    /// Canonical object-ref string compatible with the state
    /// graph's `parse(ref:)` API (ch 954)。
    public var objectRef: String {
        "\(domain.rawValue)#\(objectID)"
    }
}

// MARK: - Bus statistics (for arc-seal performance metrics)

public struct BASZeroCopyBusStat:
    Sendable, Equatable, Hashable, Codable
{
    public let turnID: String
    /// Count of refs passed between agents (without
    /// re-serializing payload)。
    public let refCount: Int
    /// Count of stale-ref refetches (caller noticed the
    /// versionAtRead was out of date and re-read)。
    public let staleRefetches: Int
    /// Total bytes saved by passing refs instead of serializing
    /// payloads (estimated)。
    public let bytesSavedEstimate: Int

    public init(
        turnID: String,
        refCount: Int = 0,
        staleRefetches: Int = 0,
        bytesSavedEstimate: Int = 0
    ) {
        self.turnID = turnID
        self.refCount = max(0, refCount)
        self.staleRefetches = max(0, staleRefetches)
        self.bytesSavedEstimate =
            max(0, bytesSavedEstimate)
    }

    /// Cache-hit ratio for refs — high ratio means most refs
    /// were still fresh (low stale-refetch overhead)。
    public var freshRatio: Double {
        let total = refCount + staleRefetches
        if total == 0 { return 1.0 }  // identity case
        return Double(refCount) / Double(total)
    }
}
