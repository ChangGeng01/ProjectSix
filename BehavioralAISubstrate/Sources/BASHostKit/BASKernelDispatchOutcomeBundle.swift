// MARK: - BASKernelDispatchOutcomeBundle
// chapter 四百七十六 / M1281 — first REAL low-entropy generic
// migration in the substrate。 Closes part of the chapter 473
// deep-review "低熵复杂系统 1/10" gap with substantive
// evidence rather than typealias scaffolding。
//
// ## Why this exists (system entropy framing)
//
// `BASBundle<Item>` shipped at M1088 (chapter 429) as one
// of 5 low-entropy generic primitives。 The doctrine note
// said:
//
//   > "existing concrete bundles (BASMemoryBundle, etc.)
//   >  keep their shapes for back-compat;NEW item-list
//   >  bundles SHOULD use this generic"
//
// But across chapters 429-475 NO new bundle type adopted
// the generic — every new aggregate was a hand-rolled
// concrete struct。 The "1,282 sprawl types" critique at
// chapter 473 deep-review was correct:scaffolding shipped
// but no actual migrations happened。
//
// `BASKernelDispatchOutcomeBundle` is the FIRST real
// adoption。 It aggregates per-stage outcomes from the
// M1273 BASKernelRegistryDispatchExecutor's outcome
// handler:
//
//   typealias BASKernelDispatchOutcomeBundle =
//       BASBundle<BASKernelDispatchOutcomeBundleItem>
//
// `BASKernelDispatchOutcomeBundleItem` carries (stage tag
// + typed outcome + sequence index)。 Schedulers + audit
// replay consume this bundle to:
//
//   - Learn which kernel keys actually dispatch vs fall
//     back per turn
//   - Detect kernel registry / hint mismatches loudly
//     (consecutive .fallbackNoKernel outcomes = misconfigured
//     registry)
//   - Tune future scheduling decisions based on observed
//     dispatch patterns
//
// ## What this ships (M1281)
//
//   - `BASKernelDispatchOutcomeBundleItem` typed item
//     struct
//   - `BASKernelDispatchOutcomeBundle` typealias to
//     `BASBundle<...>`
//   - `BASKernelDispatchOutcomeBundle` convenience
//     accessors: counts per outcome category +
//     dispatch ratio
//   - First REAL BASBundle<Item> typealias migration —
//     proof that the M1088 generic actually carries
//     production payload
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed outcome enum + typed
//     bundle item struct
//   - chapter 二百一一 — single source-of-truth (one
//     bundle aggregating dispatch outcomes)
//   - chapter 三百九二 — replay-determinism (Codable +
//     sortedKeys JSON-stable)
//   - chapter 四百二十九 entropy class — closes the
//     "scaffold but no migration" gap with first real
//     adoption
//   - ADR-014 OPT-IN — additive only。 No existing
//     surface mutated。 Schedulers + audit consumers
//     opt-in to read this bundle
//   - 红线 7 — hint-only (bundle is observation;
//     scheduler tunes from it but never mutates it)

import Foundation
import BASRuntimeCore

// MARK: - Typed item

/// One entry in a `BASKernelDispatchOutcomeBundle` —
/// pins (stage tag + typed outcome + sequence index)
/// for one kernel-registry-dispatch attempt during a
/// turn。
public struct BASKernelDispatchOutcomeBundleItem:
    Equatable, Hashable, Codable, Sendable
{

    /// Raw value of the stage that dispatched (e.g.
    /// "stage-a-power-clock")。 Carried as String for
    /// Codable stability across stage-enum evolutions。
    public let stageRawValue: String

    /// Typed outcome from the M1273
    /// BASKernelRegistryDispatchExecutor。
    public let outcome: BASKernelRegistryDispatchOutcome

    /// Monotonic sequence index within the turn (0-based)。
    /// Lets replay reorder entries deterministically if
    /// shuffled by parallel-group dispatch。
    public let sequenceIndex: Int

    public init(
        stageRawValue: String,
        outcome: BASKernelRegistryDispatchOutcome,
        sequenceIndex: Int
    ) {
        self.stageRawValue = stageRawValue
        self.outcome = outcome
        self.sequenceIndex = sequenceIndex
    }
}

// MARK: - Generic bundle alias

/// First REAL adoption of `BASBundle<Item>` (M1088 generic)
/// in the substrate。 Aggregates per-turn kernel-dispatch
/// outcomes for scheduler tuning + audit replay。
public typealias BASKernelDispatchOutcomeBundle =
    BASBundle<BASKernelDispatchOutcomeBundleItem>

// MARK: - Convenience accessors

extension BASBundle
    where Item == BASKernelDispatchOutcomeBundleItem
{

    /// Count of items where outcome == .dispatched
    /// (kernel actually ran via registry dispatch)。
    public var dispatchedCount: Int {
        items.filter {
            $0.outcome == .dispatched
        }.count
    }

    /// Count of items where outcome was any of the 4
    /// fallback variants。
    public var fallbackCount: Int {
        items.filter {
            $0.outcome != .dispatched
        }.count
    }

    /// Ratio of dispatched-to-total stages。 1.0 means
    /// every stage with a kernel key actually dispatched
    /// through the registry。 0.0 means every stage fell
    /// back。 Returns 0 for empty bundles to avoid
    /// divide-by-zero。
    public var dispatchedRatio: Double {
        guard !items.isEmpty else { return 0 }
        return Double(dispatchedCount)
            / Double(items.count)
    }

    /// Count of items matching a specific outcome
    /// category。 Useful for tuning observations like
    /// "did we see a spike of .fallbackNoKernel,
    /// suggesting registry misconfiguration"。
    public func count(
        of outcome: BASKernelRegistryDispatchOutcome
    ) -> Int {
        items.filter { $0.outcome == outcome }.count
    }
}
