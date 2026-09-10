// MARK: - BASCognitiveOSP2LayerActorFactories — chapter 三百六八 / M855
//
// Phase P2 G10 (advanced): pre-configured `BASLayerReferenceActor`
// factories for the **last 4 of 14** cognitive OS layers (L9 / L10
// / L13 / L14)。Closes the M840 audit gap on concrete actor
// factories — combined with chapter 三百二七 (M814) Chenglu set
// (L1/L4/L6/L8/L11/L12) + chapter 三百六一 (M848) extended set
// (L2/L3/L5),this completes typed actor factories for **all 14
// layers**。
//
// ## Layer assignments (per user's vision §7)
//
//   L9  梦环层: 多路径推演 — multi-agent / tree search /
//      scenario simulation
//   L10 三我庭: 仲裁 — utility scoring / self-ego-superego
//      arbitration
//   L13 蜕变炉: 学习进化 — evaluation harness / adapter / MLX
//      training / memory promotion
//   L14 隐层: 元控制 — red team / constitutional layer /
//      adversarial calibration
//
// ## Roadmap context
//
// M840 placed L9/L10/L13/L14 in P2 (advanced) phase pending more
// substrate work。This commit ships them earlier than originally
// scheduled because:
//   - The factory pattern is mechanical (mirrors M848 +
//     M814 byte-for-byte)
//   - Completing the 14-layer typed actor set unblocks
//     hosts that want to wire all layers together (eg.
//     SampleHost coordination)
//   - Per ADR-014 OPT-IN doctrine,opt-in actors that don't
//     yet have populated mesh slots are no-ops at runtime
//     (cascade returns `.noHeadsRegistered`),so shipping
//     factories doesn't pre-empt the actual head registration
//     that may come later
//
// ## Doctrine pins held
//
//   - All BASChengluLayerActorFactories / BASCognitiveOSLayerActor
//     Factories pins apply
//   - 不变量 #1 / #2 / #3 全保 — factories produce hint-class
//     actors per BASLayerReferenceActor doctrine
//   - 红线 7 watcher hint only — observabilityOnly=true on all
//     default budgets
//   - 单提交口 (L11/L14) 不变 — note: L14 ACTOR is hint-class;
//     the L14 RED TEAM doctrine is still hint-class observability。
//     The substrate gate at L11 is unaffected。L14 actor's mesh
//     slots are red-team / adversarial / constitutional-calibration
//     heads — they emit hints,never decide。
//   - chapter 二百一一 single-source-of-truth — extended set
//     disjoint from Chenglu canonical + cognitive-OS-extended
//     (M848) sets;each layer has exactly ONE factory site
//   - chapter 一百八十五 anti-magic-number — budget constants
//     typed-pinned in `BASCognitiveOSP2LayerBudgetDefaults`
//   - chapter 三百一六 (M803) BASLayerReferenceActor reuse
//   - chapter 三百二七 (M814) factory pattern mirrored
//   - ADR-014 OPT-IN → PROD — hosts that don't construct these
//     actors keep zero behavior change

import Foundation
import BASRuntimeCore

// MARK: - Default budget constants

/// Typed default budgets for the P2 advanced cognitive OS layers
/// (L9 / L10 / L13 / L14)。Hosts override per-layer via factory
/// `budgetOverride:` parameter。Pinned by tests for drift
/// detection。
public enum BASCognitiveOSP2LayerBudgetDefaults {

    /// L9 (multi-path / tree search):scenario expansion may
    /// involve simulating multiple decode paths。Larger budget
    /// because tree-search step count is configurable per host。
    public static let l9AllocatedMs: Double = 80
    public static let l9HardCapMs: Double = 400

    /// L10 (arbitration / self-ego-superego):utility scoring
    /// across candidates。Quick — pure scalar product over
    /// already-computed candidate utilities。
    public static let l10AllocatedMs: Double = 6
    public static let l10HardCapMs: Double = 25

    /// L13 (evolution / shadow training / promotion):runs offline
    /// alongside main turn,so budget is generous but capped。
    /// Hosts using strict-realtime flow override to a smaller cap。
    public static let l13AllocatedMs: Double = 200
    public static let l13HardCapMs: Double = 1000

    /// L14 (red team / meta-control):adversarial mutation +
    /// calibration heads。Aggressive cap — L14 is observation-
    /// class and shouldn't slow turn dispatch。
    public static let l14AllocatedMs: Double = 10
    public static let l14HardCapMs: Double = 40

    /// Build the canonical default budget for a given layer。
    /// Returns nil for layers covered by other factory namespaces
    /// (Chenglu canonical / M848 cognitive-OS-extended)。
    public static func budget(
        for layer: BASMotherboardLayer14
    ) -> BASLayerSlice? {
        switch layer {
        case .l9:
            return BASLayerSlice(
                layerID: .l9,
                allocatedMs: l9AllocatedMs,
                hardCapMs: l9HardCapMs,
                observabilityOnly: true)
        case .l10:
            return BASLayerSlice(
                layerID: .l10,
                allocatedMs: l10AllocatedMs,
                hardCapMs: l10HardCapMs,
                observabilityOnly: true)
        case .l13:
            return BASLayerSlice(
                layerID: .l13,
                allocatedMs: l13AllocatedMs,
                hardCapMs: l13HardCapMs,
                observabilityOnly: true)
        case .l14:
            return BASLayerSlice(
                layerID: .l14,
                allocatedMs: l14AllocatedMs,
                hardCapMs: l14HardCapMs,
                observabilityOnly: true)
        case .l1, .l4, .l6, .l8, .l11, .l12:
            return nil  // BASChengluLayerBudgetDefaults
        case .l2, .l3, .l5, .l7:
            return nil  // BASCognitiveOSLayerBudgetDefaults
        }
    }
}

// MARK: - Layer set

/// The 4 P2 advanced layers that this factory namespace covers。
public let cognitiveOSP2Layers:
    [BASMotherboardLayer14] = [
    .l9, .l10, .l13, .l14
]

// MARK: - Factories namespace

/// Pre-configured factories for `BASLayerReferenceActor`
/// instances bound to the P2 advanced cognitive OS layers。
public enum BASCognitiveOSP2LayerActorFactories {

    /// L9 (multi-path reasoning / tree search) actor。
    public static func makeL9Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASCognitiveOSP2LayerBudgetDefaults.budget(
                for: .l9)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l9,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    /// L10 (arbitration / self-ego-superego scoring) actor。
    public static func makeL10Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASCognitiveOSP2LayerBudgetDefaults.budget(
                for: .l10)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l10,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    /// L13 (蜕变炉 / evolution / shadow training) actor。
    public static func makeL13Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASCognitiveOSP2LayerBudgetDefaults.budget(
                for: .l13)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l13,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    /// L14 (隐层 / meta-control / red team) actor。
    public static func makeL14Actor(
        registry: BASLayerMLHeadRegistry,
        budgetOverride: BASLayerSlice? = nil,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> BASLayerReferenceActor {
        let budget = budgetOverride
            ?? BASCognitiveOSP2LayerBudgetDefaults.budget(
                for: .l14)!
        return BASLayerReferenceActor(
            config: BASLayerReferenceActorConfig(
                layerID: .l14,
                budget: budget,
                registry: registry,
                killSwitchLookup: killSwitchLookup))
    }

    /// Build all 4 P2 advanced cognitive-OS-extended layer
    /// actors (L9 → L10 → L13 → L14)。
    public static func makeAllP2Actors(
        registry: BASLayerMLHeadRegistry,
        killSwitchLookup:
            @escaping @Sendable (BASLayerKillSwitchID)
                -> BASLayerKillSwitchState?
            = BASChengluLayerActorFactories
                .noopKillSwitchLookup
    ) -> [BASLayerReferenceActor] {
        [
            makeL9Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL10Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL13Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup),
            makeL14Actor(
                registry: registry,
                killSwitchLookup: killSwitchLookup)
        ]
    }
}
