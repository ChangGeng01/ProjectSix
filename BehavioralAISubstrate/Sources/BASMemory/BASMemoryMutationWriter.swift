import Foundation

/// M215 — apply reconciler decisions to a memory store.
///
/// ## Where this fits
///
/// `BASMemoryTieringReconciler.reconcile(profiles:)` returns a
/// `BASMemoryTieringReconciliationOutcome` containing one
/// `Decision` per atom — `.hold / .promote / .demote /
/// .quarantineSuggest / .evictSuggest`. Pre-M215 the decision
/// stayed in the audit log only; nothing actually moved atoms
/// between tiers or removed them.
///
/// `BASMemoryMutationWriter` closes that gap. Hosts build a
/// writer with a `BASMemoryAtomStore`, then call
/// `apply(outcome:)` to execute every decision.
///
/// ## Per-transition behavior
///
/// - `.hold`: no store mutation (counted as `skipped`).
/// - `.promote(_, to, _)` / `.demote(_, to, _)`: call
///   `store.updateTier(forID:to:)` with `decision.profile.atomID`.
/// - `.quarantineSuggest`: call
///   `store.updateGovernanceStatus(forID:to: .quarantined)`.
/// - `.evictSuggest`: call `store.remove(forID:)`.
///
/// All store calls return found/not-found booleans; the writer
/// counts them and returns a typed `MutationOutcome` — never
/// throws on a missing atom because the reconciler may have run
/// against a snapshot that's slightly stale relative to the
/// store. "Apply what you can, report what you couldn't" beats
/// "abort on first miss".
///
/// ## Thread safety
///
/// `BASMemoryMutationWriter` is a public actor. The store is
/// reached via the `BASMemoryAtomStore` protocol; conformers
/// supply their own isolation. The writer makes one store call
/// per decision; it does not batch.
public actor BASMemoryMutationWriter {
    private let store: any BASMemoryAtomStore

    public init(store: any BASMemoryAtomStore) {
        self.store = store
    }

    public func apply(
        outcome: BASMemoryTieringReconciliationOutcome
    ) async -> MutationOutcome {
        var applied = 0
        var skipped = 0
        var notFound = 0

        for decision in outcome.decisions {
            let atomID = decision.profile.atomID
            switch decision.transition {
            case .hold:
                skipped += 1
            case .promote(_, let to, _):
                if await store.updateTier(
                    forID: atomID, to: to)
                {
                    applied += 1
                } else {
                    notFound += 1
                }
            case .demote(_, let to, _):
                if await store.updateTier(
                    forID: atomID, to: to)
                {
                    applied += 1
                } else {
                    notFound += 1
                }
            case .quarantineSuggest:
                if await store.updateGovernanceStatus(
                    forID: atomID, to: .quarantined)
                {
                    applied += 1
                } else {
                    notFound += 1
                }
            case .evictSuggest:
                if await store.remove(forID: atomID) != nil {
                    applied += 1
                } else {
                    notFound += 1
                }
            }
        }

        return MutationOutcome(
            evaluated: outcome.decisions.count,
            applied: applied,
            skipped: skipped,
            notFound: notFound)
    }

    /// Per-`apply(outcome:)` summary. `evaluated == applied +
    /// skipped + notFound` is an invariant that all hold-vs-
    /// active-vs-stale transitions are accounted for.
    public struct MutationOutcome:
        Sendable, Equatable, Hashable
    {
        public let evaluated: Int
        public let applied: Int
        public let skipped: Int
        public let notFound: Int

        public init(
            evaluated: Int,
            applied: Int,
            skipped: Int,
            notFound: Int
        ) {
            self.evaluated = evaluated
            self.applied = applied
            self.skipped = skipped
            self.notFound = notFound
        }

        /// `true` iff every decision either applied or was a
        /// hold (no missing atoms). Hosts use this as the
        /// "store is in sync with reconciler" probe.
        public var isFullyApplied: Bool {
            notFound == 0
        }
    }
}
