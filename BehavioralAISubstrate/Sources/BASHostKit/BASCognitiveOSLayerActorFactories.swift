// MARK: - BASCognitiveOSLayerActorFactories — chapter 三百六一 / M848
//
// Phase P1 G5 partial: pre-configured `BASLayerReferenceActor`
// factories for the **non-Chenglu** 14-layer cognitive OS layers
// (chapter 三百五三 / M840 audit identified 8 layers without
// concrete actor factories: L2, L3, L5, L7, L9, L10, L13, L14)。
//
// This commit ships **3 of 8** (L2 / L3 / L5)。L7 (problem
// decomposition / planner) is deferred to M851 because it depends
// on G6 (AFM tool calling + guided generation,for structured
// planner output)。L9 / L10 / L13 / L14 are P2 (chapter 三百X) per
// the M840 roadmap section 3 phase mapping。
//
// Mirrors the chapter 三百二七 / M814 `BASChengluLayerActorFactories`
// idiom precisely:
//   - typed budget defaults per layer (chapter 一百八十五 anti-
//     magic-number — no inline budget literals)
//   - per-layer factory function with budgetOverride +
//     killSwitchLookup parameters
//   - convenience `makeAllCognitiveOSExtendedActors(...)` returns
//     L2 / L3 / L5 in canonical priority order
//
// ## Layer assignments (per user's vision §7)
//
//   L2 脑肉层: 模型群与路由 — model router (Apple Foundation
//      Models / Gemma local / Core ML / cloud route decision)
//   L3 折叠肺: 上下文压缩 — summarizer / semantic compressor /
//      memory distiller
//   L5 宿纹层: 长期人格与偏好 — personal constitution / preference
//      model / value memory
//   L7 镜刃层: 问题拆解 — planner / task graph / tool planning
//      (DEFERRED to M851 — needs G6 AFM tool calling)
//
// ## Doctrine pins held
//
//   - All BASChengluLayerActorFactories pins apply
//   - 不变量 #1 / #2 / #3 全保 — factories produce hint-class
//     actors (per BASLayerReferenceActor doctrine)
//   - 红线 7 watcher hint only — `observabilityOnly: true` on
//     all default budgets
//   - 单提交口 (L11/L14) 不变 — actor outputs never replace
//     permit/verdict authority
//   - chapter 二百一一 single-source-of-truth — ONE factory per
//     layer
//   - chapter 一百八十五 anti-magic-number — budget constants
//     typed-pinned in `BASCognitiveOSLayerBudgetDefaults`
//   - chapter 三百一六 (M803) BASLayerReferenceActor: factories
//     produce instances of this canonical conformer
//   - chapter 三百二七 (M814) BASChengluLayerActorFactories
//     pattern: this file is the natural extension to non-Chenglu
//     layers (NOT a replacement)
//   - ADR-014 OPT-IN → PROD: hosts that don't construct these
//     actors see zero behavior change

import Foundation
import BASRuntimeCore

// MARK: - Default budget constants

/// Typed default budgets for the non-Chenglu cognitive OS layers
/// (L2 / L3 / L5 / L7)。Hosts override per-layer via factory
/// `budgetOverride:` parameter。Pinned by tests for drift
/// detection。
public enum BASCognitiveOSLayerBudgetDefaults {

    /// L2 (model router):typed dispatch decision feeding the
    /// AFM⇄Gemma router。Aggressive cap because L2 must complete
    /// before LLM dispatch — every ms here delays user-visible
    /// response。
    public static let l2AllocatedMs: Double = 8
    public static let l2HardCapMs: Double = 30

    /// L3 (context compression):summarizer/distiller。Larger cap
    /// because summarization may invoke a small LLM head (AFM
    /// scout role) which has > 100ms latency baseline。Budget
    /// reflects "compress when worth it,skip when not"。
    public static let l3AllocatedMs: Double = 50
    public static let l3HardCapMs: Double = 200

    /// L5 (constitution):reads `BASHostConstitution` boundary
    /// veil + value axes。Pure-function lookup,fast。
    public static let l5AllocatedMs: Double = 5
    public static let l5HardCapMs: Double = 20

    /// L7 (planner / problem decomposition):AFM-driven structured
    /// generation。Reserved for M851 wire-up;budget defined here
    /// for forward-compat。Highest cap among the 4 since planner
    /// may call multiple tools。
    public static let l7AllocatedMs: Double = 100
    public static let l7HardCapMs: Double = 500

    /// Build the canonical default budget for a given layer。
    /// Returns nil for layers not in the cognitive-OS extended
    /// set (i.e. layers covered by `BASChengluLayerBudgetDefaults`
    /// or P2-deferred L9/L10/L13/L14)。
    public static func budget(
        for layer: BASMotherboardLayer14
    ) -> BASLayerSlice? {
        switch layer {
        case .l2:
            return BASLayerSlice(
                layerID: .l2,
                allocatedMs: l2AllocatedMs,
                hardCapMs: l2HardCapMs,
                observabilityOnly: true)
        case .l3:
            return BASLayerSlice(
                layerID: .l3,
                allocatedMs: l3AllocatedMs,
                hardCapMs: l3HardCapMs,
                observabilityOnly: true)
        case .l5:
            return BASLayerSlice(
                layerID: .l5,
                allocatedMs: l5AllocatedMs,
                hardCapMs: l5HardCapMs,
                observabilityOnly: true)
        case .l7:
            return BASLayerSlice(
                layerID: .l7,
                allocatedMs: l7AllocatedMs,
                hardCapMs: l7HardCapMs,
                observabilityOnly: true)
        case .l1, .l4, .l6, .l8, .l11, .l12:
            return nil  // Use BASChengluLayerBudgetDefaults
        case .l9, .l10, .l13, .l14:
            return nil  // P2-deferred
        }
    }
}

// MARK: - Cognitive OS extended layer set

/// The 4 non-Chenglu layers that this factory namespace covers。
/// L7 included for forward-compat (factory exists,wire-up in
/// M851 with G6 AFM tool calling)。
public let cognitiveOSExtendedLayers:
    [BASMotherboardLayer14] = [
    .l2, .l3, .l5, .l7
]

/// L2 / L3 / L5 — the 3 layers with concrete actor factories
/// shipped in M848。L7 is reserved for M851。
public let cognitiveOSExtendedLayersM848:
    [BASMotherboardLayer14] = [
    .l2, .l3, .l5
]

// MARK: - Factories namespace

/// Pre-configured factories for `BASLayerReferenceActor`
/// instances bound to non-Chenglu cognitive OS layers per the
/// chapter 三百五三 / M840 14-layer roadmap。
public enum BASCognitiveOSLayerActorFactories {

    /// L2 (model router) actor。Layer-pinned reference actor that
    /// walks the L2 mesh slot list (canonical map has 3 L2 slots
    /// per `BAS14LayerMeshMap`)。
    ///
    /// Hosts that opt in:
    ///   1. Register heads at `BAS14LayerMeshMap` L2 slots
    ///      (canonical roles: `model-router`, `route-fallback`,
    ///      `cost-predictor`)
    ///   2. Construct the actor via this factory
    ///   3. Consult via the actor's typed cascade dispatch
    public static func makeL2Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASCognitiveOSLayerBudgetDefaults.budget(
                for: .l2)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l2,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    /// L3 (context compression) actor。Layer-pinned reference
    /// actor for summarization / distillation slots (canonical
    /// roles: `summarizer`, `semantic-compressor`,
    /// `memory-distiller`)。
    public static func makeL3Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASCognitiveOSLayerBudgetDefaults.budget(
                for: .l3)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l3,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    /// L5 (personal constitution) actor。Layer-pinned reference
    /// actor for value-axis / preference / goal-spine slots
    /// (canonical roles: `value-axis-evaluator`,
    /// `preference-aligner`, `goal-spine-checker`)。
    ///
    /// Composes naturally with M843 `BASConstitutionEnforcer` —
    /// L5 actor wraps mesh slots that consume `BASHostConstitution`
    /// boundary veil + value axes;the enforcer provides typed
    /// boundary-match helpers used by those slots' inference
    /// closures。
    public static func makeL5Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASCognitiveOSLayerBudgetDefaults.budget(
                for: .l5)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l5,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    // L7 actor factory deferred to M851 — depends on G6 AFM
    // tool calling for structured planner output. Budget
    // constants (l7AllocatedMs / l7HardCapMs) are pre-defined
    // in BASCognitiveOSLayerBudgetDefaults so the M851 wire-up
    // is a 1-method addition (no schema bump).

    /// Build all 3 cognitive-OS-extended layer actors shipped
    /// in M848 (L2 / L3 / L5)。Convenience for hosts that want
    /// the full opt-in extended set wired in one call。
    ///
    /// L7 not included here — when M851 ships its factory,this
    /// helper will be extended to return 4 actors。Tests pin
    /// the M848 count at 3 to detect that future extension。
    public static func makeAllCognitiveOSExtendedActors(
        registry: BASLayerMLHeadRegistry,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> [BASLayerReferenceActor] {
        [
            makeL2Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL3Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL5Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup)
        ]
    }
}
