import Foundation
import BASRuntimeCore

// MARK: - Reconciler
//
// M21 — L8 Phase 1 progression: the reconciler that consumes
// `BASMemoryTieringProfile` batches, runs `BASMemoryTemperaturePolicy`
// over each, logs every suggestion to `BASMemoryTierTransitionLog`,
// and returns a typed batch outcome.
//
// This actor is deliberately *observational* in M21 — it does not
// mutate `MemoryCore` state. Its output is a plan that a later
// milestone will hand to a mutation writer. Keeping the reconciler
// separate lets the L14 audit surface read the plan, compare it
// against what the mutation writer actually applied, and surface
// any divergence.
//
// Design principles:
//   1. Immutability — the reconciler never rewrites a profile; it
//      consumes a snapshot and emits an outcome.
//   2. Purity of decisions — each transition comes from the pure
//      `BASMemoryTemperaturePolicy`; the reconciler adds only
//      ordering, batching, and logging.
//   3. Audit — every decision is written to the supplied
//      transition log. A caller that cares about audit parity can
//      inspect both the outcome *and* the log snapshot.

/// Typed outcome of a single reconciliation pass.
public struct BASMemoryTieringReconciliationOutcome:
    Sendable, Equatable, Codable
{
    public let evaluatedCount: Int
    public let heldCount: Int
    public let promotedCount: Int
    public let demotedCount: Int
    public let quarantineSuggestedCount: Int
    public let evictSuggestedCount: Int
    /// Ordered per-profile decisions, in the order the reconciler
    /// evaluated them. Consumers can rebuild the full plan from
    /// this list; the summary counters above are convenience.
    public let decisions: [Decision]
    public let startedAt: Date
    public let completedAt: Date

    public struct Decision: Codable, Sendable, Equatable {
        public let profile: BASMemoryTieringProfile
        public let transition: BASMemoryTierTransition

        public init(
            profile: BASMemoryTieringProfile,
            transition: BASMemoryTierTransition
        ) {
            self.profile = profile
            self.transition = transition
        }
    }

    public init(
        evaluatedCount: Int,
        heldCount: Int,
        promotedCount: Int,
        demotedCount: Int,
        quarantineSuggestedCount: Int,
        evictSuggestedCount: Int,
        decisions: [Decision],
        startedAt: Date,
        completedAt: Date
    ) {
        self.evaluatedCount = evaluatedCount
        self.heldCount = heldCount
        self.promotedCount = promotedCount
        self.demotedCount = demotedCount
        self.quarantineSuggestedCount = quarantineSuggestedCount
        self.evictSuggestedCount = evictSuggestedCount
        self.decisions = decisions
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    /// Total mutations that, if applied, would change some atom's
    /// position: promote + demote + quarantine + evict. Excludes
    /// hold, which is a no-op suggestion.
    public var mutationCount: Int {
        promotedCount
            + demotedCount
            + quarantineSuggestedCount
            + evictSuggestedCount
    }

    /// True when the pass produced no mutation suggestions — i.e.,
    /// every profile was `hold`. Useful for early-exit checks in a
    /// governance sweep that runs every N seconds.
    public var isNoOp: Bool {
        mutationCount == 0
    }
}

/// Ordering strategy the reconciler uses when it evaluates a batch.
/// The policy is pure, so order doesn't affect individual decisions,
/// but order *does* affect which decisions land first in the
/// transition log and — in a later wiring — which atoms get moved
/// before a per-pass budget runs out.
public enum BASMemoryTieringReconcilerOrdering: Sendable, Equatable, Codable {
    /// Preserve the order in which profiles arrived. Fastest; no
    /// extra sort.
    case insertionOrder
    /// Evaluate profiles with the highest composite heat first. In
    /// a budgeted pass this lets the reconciler promote hot
    /// candidates before it runs out of budget, at the cost of an
    /// O(n log n) sort.
    case highestHeatFirst
    /// Evaluate profiles most likely to be *dangerous* first:
    /// sensitivity drift + world-context staleness, max of the
    /// two. A budgeted pass then quarantines the worst offenders
    /// before anything else.
    case mostRiskyFirst
}

public actor BASMemoryTieringReconciler {
    private let log: BASMemoryTierTransitionLog
    private let clock: @Sendable () -> Date

    public init(
        log: BASMemoryTierTransitionLog,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.log = log
        self.clock = clock
    }

    /// Evaluate every profile in `profiles`, log each decision,
    /// and return a typed outcome. Never mutates caller state.
    public func reconcile(
        profiles: [BASMemoryTieringProfile],
        ordering: BASMemoryTieringReconcilerOrdering = .insertionOrder
    ) async -> BASMemoryTieringReconciliationOutcome {
        let startedAt = clock()
        let ordered = Self.reorder(profiles, by: ordering)

        var decisions: [
            BASMemoryTieringReconciliationOutcome.Decision
        ] = []
        decisions.reserveCapacity(ordered.count)

        var heldCount = 0
        var promotedCount = 0
        var demotedCount = 0
        var quarantineSuggestedCount = 0
        var evictSuggestedCount = 0

        for profile in ordered {
            let transition = BASMemoryTemperaturePolicy
                .recommendTransition(for: profile)
            switch transition {
            case .hold: heldCount += 1
            case .promote: promotedCount += 1
            case .demote: demotedCount += 1
            case .quarantineSuggest: quarantineSuggestedCount += 1
            case .evictSuggest: evictSuggestedCount += 1
            }
            decisions.append(
                .init(profile: profile, transition: transition))
            await log.record(profile: profile, transition: transition)
        }

        return BASMemoryTieringReconciliationOutcome(
            evaluatedCount: ordered.count,
            heldCount: heldCount,
            promotedCount: promotedCount,
            demotedCount: demotedCount,
            quarantineSuggestedCount: quarantineSuggestedCount,
            evictSuggestedCount: evictSuggestedCount,
            decisions: decisions,
            startedAt: startedAt,
            completedAt: clock())
    }

    /// Pure reordering helper — exposed for testability.
    static func reorder(
        _ profiles: [BASMemoryTieringProfile],
        by ordering: BASMemoryTieringReconcilerOrdering
    ) -> [BASMemoryTieringProfile] {
        switch ordering {
        case .insertionOrder:
            return profiles
        case .highestHeatFirst:
            return profiles.sorted {
                $0.compositeHeat > $1.compositeHeat
            }
        case .mostRiskyFirst:
            return profiles.sorted { a, b in
                let riskA = max(
                    a.sensitivityDrift, a.worldContextStaleness)
                let riskB = max(
                    b.sensitivityDrift, b.worldContextStaleness)
                return riskA > riskB
            }
        }
    }
}
