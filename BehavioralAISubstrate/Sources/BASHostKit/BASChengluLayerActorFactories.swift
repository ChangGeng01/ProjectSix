// MARK: - BASChengluLayerActorFactories — chapter 三百二七 / M814
//
// Phase F (附录 X) 第七刀:pre-configured `BASLayerReferenceActor`
// factories for each Chenglu canonical layer。Closes v9 §8
// non-promise #3 ("Layer-specific reference actor concrete
// implementations") by giving hosts a typed factory namespace
// instead of requiring them to figure out per-layer configs from
// scratch。
//
// Why factories instead of subclasses:
//   - `BASLayerReferenceActor` (chapter 三百一六) is generic and
//     correctly handles any layer's slot-walk + cascade + budget
//     + kill switch logic
//   - Per-layer concrete subclasses would duplicate the protocol
//     conformance code without adding behavior — anti-pattern per
//     chapter 二百一一 single-source-of-truth doctrine
//   - What hosts ACTUALLY need is a way to construct one config
//     per Chenglu canonical layer with sensible defaults — these
//     factories are that
//
// **0 default behavior change**:factories don't auto-construct
// anything;hosts call `make<Layer>Actor(...)` explicitly and own
// the resulting actor lifecycle。
//
// ## What this ships
//
//   - `BASChengluLayerBudgetDefaults` — typed default budget
//     constants per Chenglu canonical layer (anti-magic-number
//     doctrine — no inline budget literals in factory call sites)
//   - 6 factory functions, one per Chenglu canonical layer:
//       * `makeL1Actor(registry:budgetOverride:killSwitchLookup:)`
//       * `makeL4Actor(...)`
//       * `makeL6Actor(...)`
//       * `makeL8Actor(...)`
//       * `makeL11Actor(...)`
//       * `makeL12Actor(...)`
//   - `makeAllChengluActors(registry:budgetOverride:killSwitchLookup:)`
//     — convenience that returns all 6 actors in priority order
//     (l1 → l4 → l6 → l8 → l11 → l12)
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — factories produce hint-class
//     actors (per BASLayerReferenceActor doctrine)
//   - 红线 7 watcher hint only — `observabilityOnly: true` set on
//     all default budgets
//   - 单提交口 (L11/L14) 不变 — actor outputs never replace
//     permit/verdict authority
//   - chapter 二百一一 single-source-of-truth: ONE factory per
//     canonical layer (no duplication via subclassing)
//   - chapter 一百八十五 anti-magic-number: budget constants
//     typed-pinned in `BASChengluLayerBudgetDefaults`
//   - chapter 三百一六 (M803) BASLayerReferenceActor: factories
//     produce instances of this canonical conformer
//   - chapter 三百二一 (M808) §X.2 doctrine: 6 layers covered
//     mirror canonical 8-slot mapping (l1 has 2 slots but 1
//     actor;l11 has 2 slots but 1 actor)

import Foundation
import BASRuntimeCore

// MARK: - Default budget constants

/// Typed default budgets per Chenglu canonical layer。Hosts can
/// override per-layer via factory's `budgetOverride:` parameter。
/// Pinned by tests for drift detection。
public enum BASChengluLayerBudgetDefaults {

    /// L1 (wake-policy + compute-cost-predictor):both slots are
    /// fast classifiers + regression heads。Aggressive cap
    /// because L1 must complete before main turn dispatch。
    public static let l1AllocatedMs: Double = 5
    public static let l1HardCapMs: Double = 20

    /// L4 (question-type):classifier。
    public static let l4AllocatedMs: Double = 10
    public static let l4HardCapMs: Double = 40

    /// L6 (emotion-classifier):classifier。
    public static let l6AllocatedMs: Double = 10
    public static let l6HardCapMs: Double = 40

    /// L8 (importance-scorer):classifier consulted during memory
    /// retrieval — slightly more budget for retrieval coordination。
    public static let l8AllocatedMs: Double = 15
    public static let l8HardCapMs: Double = 60

    /// L11 (risk-scorer + safety-action-selector):both slots are
    /// fast classifiers feeding L11 risk gate。Aggressive cap so
    /// risk hint doesn't block permit synthesis。
    public static let l11AllocatedMs: Double = 8
    public static let l11HardCapMs: Double = 30

    /// L12 (density-controller):regression head feeding surface
    /// rendering。Larger cap since rendering is downstream-heavy
    /// and length prediction stability matters more than speed。
    public static let l12AllocatedMs: Double = 12
    public static let l12HardCapMs: Double = 50

    /// Build the canonical default budget for a given layer。
    /// Returns nil for layers not in the Chenglu canonical set
    /// (l2/l3/l5/l7/l9/l10/l13/l14)。
    public static func budget(
        for layer: BASMotherboardLayer14
    ) -> BASLayerSlice? {
        switch layer {
        case .l1:
            return BASLayerSlice(
                layerID: .l1,
                allocatedMs: l1AllocatedMs,
                hardCapMs: l1HardCapMs,
                observabilityOnly: true)
        case .l4:
            return BASLayerSlice(
                layerID: .l4,
                allocatedMs: l4AllocatedMs,
                hardCapMs: l4HardCapMs,
                observabilityOnly: true)
        case .l6:
            return BASLayerSlice(
                layerID: .l6,
                allocatedMs: l6AllocatedMs,
                hardCapMs: l6HardCapMs,
                observabilityOnly: true)
        case .l8:
            return BASLayerSlice(
                layerID: .l8,
                allocatedMs: l8AllocatedMs,
                hardCapMs: l8HardCapMs,
                observabilityOnly: true)
        case .l11:
            return BASLayerSlice(
                layerID: .l11,
                allocatedMs: l11AllocatedMs,
                hardCapMs: l11HardCapMs,
                observabilityOnly: true)
        case .l12:
            return BASLayerSlice(
                layerID: .l12,
                allocatedMs: l12AllocatedMs,
                hardCapMs: l12HardCapMs,
                observabilityOnly: true)
        case .l2, .l3, .l5, .l7, .l9, .l10, .l13, .l14:
            return nil  // Not in Chenglu canonical set
        }
    }
}

// MARK: - Factories namespace

/// Pre-configured factories for `BASLayerReferenceActor` instances
/// bound to Chenglu canonical layers per附录 X §X.2 doctrine。
public enum BASChengluLayerActorFactories {

    /// Default no-op kill switch lookup that never reports active
    /// switches。Used when factory caller doesn't pass an explicit
    /// killSwitchLookup。Hosts that need real kill switch handling
    /// pass their own。
    public static let noopKillSwitchLookup:
        @Sendable (BASLayerKillSwitchID)
            -> BASLayerKillSwitchState? =
        { _ in nil }

    // MARK: - Per-layer factories

    public static func makeL1Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASChengluLayerBudgetDefaults.budget(for: .l1)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l1,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    public static func makeL4Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASChengluLayerBudgetDefaults.budget(for: .l4)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l4,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    public static func makeL6Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASChengluLayerBudgetDefaults.budget(for: .l6)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l6,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    public static func makeL8Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASChengluLayerBudgetDefaults.budget(for: .l8)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l8,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    public static func makeL11Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASChengluLayerBudgetDefaults.budget(for: .l11)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l11,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    public static func makeL12Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASChengluLayerBudgetDefaults.budget(for: .l12)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l12,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    /// Build all 6 Chenglu canonical-layer actors in priority
    /// order (l1 → l4 → l6 → l8 → l11 → l12)。Convenience for
    /// hosts that want the full set wired in one call。
    public static func makeAllChengluActors(
        registry: BASLayerMLHeadRegistry,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = noopKillSwitchLookup
    ) -> [BASLayerReferenceActor] {
        [
            makeL1Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL4Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL6Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL8Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL11Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL12Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup)
        ]
    }
}
