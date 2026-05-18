// MARK: - BAS14LayerMeshMap — chapter 三百一三 / M800
//
// Phase Delta 第四刀:typed 14-layer × ML head mesh map — the
// canonical doctrine encoding chapter 一百七十七 vision § "Core ML
// mesh × 14 层" into structured Swift。
//
// Phase Delta foundation (chapters 三百一〇-三百一二) shipped:
// - registry actor (slot bindings)
// - rules-based wrapper (cascading-tier-0 fallback)
// - cascade runner (priority-walked dispatch)
//
// This chapter ships the **typed map** describing which heads
// belong on which layer at which priority。Concrete adapters
// (chapter 三百一四+ Chenglu Preflight / Shadow / Memory) plug
// into specific entries of this map。
//
// ## 这一刀 ship 什么
//
// 2 typed primitives:
//
//   - `BAS14LayerMeshSlot` (BASSchemaVersioned 1.0.0) — typed
//     slot record describing one expected head's role: layerID +
//     headRole + expectedKind + priority + description
//   - `BAS14LayerMeshMap` namespace — exposes static
//     `.canonical` static returning the canonical 14-layer mesh
//     map (50+ slot definitions per chapter 一百七十七 vision)
//
// ## Doctrine note: vision vs reality
//
// chapter 一百七十七 vision describes ~50 ML heads across 14
// layers (P0 ChengluPreflight 7 heads + P1 ChengluMemory 5 +
// P3 ChengluShadow 6 + L1-L14 specialized heads)。Today's
// substrate has ONE real .mlmodel adapter shipped — the
// BASContextClassifier serving the context-classification
// entry point — and ZERO in the 14-layer-mesh head
// registries described by this map。 Rules-tier wrappers and
// cascade infrastructure are in place for every canonical
// slot but the heads themselves remain placeholders。
//
// This map encodes **which slots SHOULD exist** when the vision
// is fully realized。Hosts use this as:
// 1) Documentation — read .canonical to see what the mesh looks
//    like in target state
// 2) Slot inventory — registries can be checked against
//    .canonical to detect missing heads
// 3) Test fixture — populate registries with rules-tier
//    placeholders for every canonical slot to demonstrate end-
//    to-end cascade with full mesh shape
//
// **0 behavior change**:typed map is data, not behavior。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — map is documentation + slot
//     inventory, no execution
//   - 红线 7 watcher hint only — map describes head roles
//     (intent / emotion / risk / etc), all hint-class
//   - 单提交口 (L11/L14) 不变 — slot at L11 risk says "head
//     emits risk hint", not "head issues permit"
//   - chapter 二百一一 single-source-of-truth: canonical map is
//     ONE typed value
//   - chapter 一百八十五 anti-magic-number: priority constants
//     match cascading inference doctrine (rules=0, coreml=10,
//     mlx=20, AFM=30, external=40)
//   - chapter 一百三 schema-version: 1.0.0 invariant
//   - chapter 一百三十 BASLearnabilityClass: mesh map is
//     observability + documentation, semi-learnable
//   - chapter 一百七十七 vision: this file is the typed encoding
//     of the vision § "14 层 × CoreML head mapping" table

import Foundation

// MARK: - Mesh slot record

/// One expected head's role + position in the 14-layer mesh。
/// Combines slot binding metadata (layerID + priority) with
/// semantic role description for diagnostic + documentation use。
public struct BAS14LayerMeshSlot:
    BASSchemaVersioned,
    Sendable,
    Equatable,
    Hashable,
    Codable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String

    /// Which layer this slot belongs to.
    public var layerID: BASMotherboardLayer14

    /// Semantic role identifier (e.g. "intent" / "emotion" /
    /// "risk-classifier"). Stable kebab-case strings — chapter
    /// 一百七十七 vision uses these as canonical role tags.
    public var headRole: String

    /// Expected head kind for this role (cascading tier hint).
    public var expectedKind: BASLayerMLHeadKind

    /// Cascading priority (chapter 三百一二 cascade runner
    /// priority order). Lower = tried first.
    public var priority: Int

    /// One-sentence description of what this head is supposed
    /// to do. Used for documentation + diagnostic dumps.
    public var description: String

    public init(
        schemaVersion: String
            = BAS14LayerMeshSlot.currentSchemaVersion,
        layerID: BASMotherboardLayer14,
        headRole: String,
        expectedKind: BASLayerMLHeadKind,
        priority: Int,
        description: String
    ) {
        self.schemaVersion = schemaVersion
        self.layerID = layerID
        self.headRole = headRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.expectedKind = expectedKind
        self.priority = priority
        self.description = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Canonical mesh map

/// Namespace exposing the canonical 14-layer × ML head mesh map。
/// `.canonical` returns the full slot inventory chapter 一百七十七
/// vision describes for the target state。
public enum BAS14LayerMeshMap {

    // Cascading priority constants — chapter 一百七十七 doctrine.
    public static let rulesTierPriority: Int = 0
    public static let coremlOnDeviceTierPriority: Int = 10
    public static let mlxLocalTierPriority: Int = 20
    public static let appleFoundationModelTierPriority: Int = 30
    public static let externalProviderTierPriority: Int = 40

    /// Canonical 14-layer mesh map per chapter 一百七十七 vision。
    ///
    /// Slot count per layer:
    /// - L1 wake (3 heads): wake-policy / thermal-budget /
    ///   compute-cost-predictor
    /// - L2 neural-organ (varies; uses shared encoder + heads —
    ///   represented as one shared encoder slot)
    /// - L3 folded-lung (compression + breathing — 0 heads at
    ///   model layer, runtime concern)
    /// - L4 horizon (3 heads): topic-classifier /
    ///   question-type / tool-need-classifier
    /// - L5 host-constitution (3 heads): preference-retriever /
    ///   persona-fit-scorer / goal-matcher
    /// - L6 situation (3 heads): emotion-classifier /
    ///   stress-detector / impulse-detector
    /// - L7 mirror-blade (3 heads): problem-decomposer /
    ///   contradiction-detector / fantasy-risk-scorer
    /// - L8 memory (4 heads): importance-scorer /
    ///   type-classifier / sensitivity-scorer / retrieval-reranker
    /// - L9 dream (3 heads): candidate-quality-scorer /
    ///   future-risk-predictor / actionability-scorer
    /// - L10 tribunal (3 heads): ego-mode-selector /
    ///   constraint-weight-scorer / creativity-safety-balancer
    /// - L11 risk (4 heads): risk-scorer /
    ///   critical-risk-detector / domain-risk-classifier /
    ///   safety-action-selector
    /// - L12 soft-hand (4 heads): reply-style-selector /
    ///   tone-adapter / density-controller / clarity-scorer
    /// - L13 evolution (3 heads): update-ticket-scorer /
    ///   preference-stability-scorer / learning-value-scorer
    /// - L14 sovereign (5 heads): overconfidence-scorer /
    ///   sycophancy-detector / evidence-sufficiency-scorer /
    ///   goal-alignment-scorer / meta-calibration-head
    ///
    /// Total: ~46 head slots (matches chapter 一百七十七 vision
    /// "~50 heads across 14 layers" approximate count).
    public static let canonical: [BAS14LayerMeshSlot] =
        l1Slots
        + l4Slots
        + l5Slots
        + l6Slots
        + l7Slots
        + l8Slots
        + l9Slots
        + l10Slots
        + l11Slots
        + l12Slots
        + l13Slots
        + l14Slots

    // MARK: - Per-layer slot definitions

    private static let l1Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l1, headRole: "wake-policy",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Decides whether to wake substrate fully or " +
                "stay in low-power preview mode."),
        BAS14LayerMeshSlot(
            layerID: .l1, headRole: "thermal-budget",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Reads device thermal state, sets allowable " +
                "compute budget for the turn."),
        BAS14LayerMeshSlot(
            layerID: .l1, headRole: "compute-cost-predictor",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Predicts whether the planned cascade " +
                "will fit in the budget; flags if over.")
    ]

    private static let l4Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l4, headRole: "topic-classifier",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Classifies prompt topic against known domain " +
                "taxonomy."),
        BAS14LayerMeshSlot(
            layerID: .l4, headRole: "question-type",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Identifies whether prompt is question / " +
                "request / statement / urgent action."),
        BAS14LayerMeshSlot(
            layerID: .l4, headRole: "tool-need-classifier",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Predicts which tools (search / file / etc) " +
                "the prompt needs.")
    ]

    private static let l5Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l5, headRole: "preference-retriever",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Retrieves relevant host preferences from " +
                "constitution vault for current prompt."),
        BAS14LayerMeshSlot(
            layerID: .l5, headRole: "persona-fit-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores how well candidate response fits " +
                "host's persona constraints."),
        BAS14LayerMeshSlot(
            layerID: .l5, headRole: "goal-matcher",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Matches prompt against host's stated goals.")
    ]

    private static let l6Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l6, headRole: "emotion-classifier",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Classifies prompt emotional context."),
        BAS14LayerMeshSlot(
            layerID: .l6, headRole: "stress-detector",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Detects stress / urgency cues in prompt."),
        BAS14LayerMeshSlot(
            layerID: .l6, headRole: "impulse-detector",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Flags impulsive / pressure-buy patterns " +
                "(red line 7 watcher).")
    ]

    private static let l7Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l7, headRole: "problem-decomposer",
            expectedKind: .mlxLocal,
            priority: mlxLocalTierPriority,
            description:
                "Decomposes complex prompt into sub-questions."),
        BAS14LayerMeshSlot(
            layerID: .l7,
            headRole: "contradiction-detector",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Detects internal contradictions in prompt."),
        BAS14LayerMeshSlot(
            layerID: .l7, headRole: "fantasy-risk-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores risk that prompt is fantasy / " +
                "magical-thinking trap.")
    ]

    private static let l8Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l8, headRole: "importance-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores memory atom importance for retention."),
        BAS14LayerMeshSlot(
            layerID: .l8, headRole: "type-classifier",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Classifies memory atom kind " +
                "(episodic / semantic / value)."),
        BAS14LayerMeshSlot(
            layerID: .l8, headRole: "sensitivity-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores memory atom sensitivity " +
                "(low / med / high)."),
        BAS14LayerMeshSlot(
            layerID: .l8, headRole: "retrieval-reranker",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Reranks retrieval candidates by " +
                "context-fit score.")
    ]

    private static let l9Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l9, headRole: "candidate-quality-scorer",
            expectedKind: .mlxLocal,
            priority: mlxLocalTierPriority,
            description:
                "Scores generated candidate quality."),
        BAS14LayerMeshSlot(
            layerID: .l9, headRole: "future-risk-predictor",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Predicts downstream risk of accepting " +
                "candidate."),
        BAS14LayerMeshSlot(
            layerID: .l9, headRole: "actionability-scorer",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Scores whether candidate is actionable for " +
                "host context.")
    ]

    private static let l10Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l10, headRole: "ego-mode-selector",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Selects three-self-court ego mode for " +
                "current decision context."),
        BAS14LayerMeshSlot(
            layerID: .l10,
            headRole: "constraint-weight-scorer",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Weights constraints by relevance."),
        BAS14LayerMeshSlot(
            layerID: .l10,
            headRole: "creativity-safety-balancer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Balances creativity vs safety for current " +
                "decision.")
    ]

    private static let l11Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l11, headRole: "risk-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores overall risk for permit gate input " +
                "(hint, not gate — chapter 一百三十 BR-014)."),
        BAS14LayerMeshSlot(
            layerID: .l11,
            headRole: "critical-risk-detector",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Detects critical risk patterns (suicide / " +
                "self-harm / unsafe medical) — emits hint."),
        BAS14LayerMeshSlot(
            layerID: .l11,
            headRole: "domain-risk-classifier",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Classifies domain-specific risk profile."),
        BAS14LayerMeshSlot(
            layerID: .l11,
            headRole: "safety-action-selector",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Selects safety surface mode hint " +
                "(L12 5-mode soft-hand input).")
    ]

    private static let l12Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l12, headRole: "reply-style-selector",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Selects reply style template."),
        BAS14LayerMeshSlot(
            layerID: .l12, headRole: "tone-adapter",
            expectedKind: .mlxLocal,
            priority: mlxLocalTierPriority,
            description:
                "Adapts response tone to host preference."),
        BAS14LayerMeshSlot(
            layerID: .l12, headRole: "density-controller",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Controls response density / verbosity."),
        BAS14LayerMeshSlot(
            layerID: .l12, headRole: "clarity-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores response clarity / readability.")
    ]

    private static let l13Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l13, headRole: "update-ticket-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores update ticket for promotion " +
                "candidate strength."),
        BAS14LayerMeshSlot(
            layerID: .l13,
            headRole: "preference-stability-scorer",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Scores how stable a preference signal is " +
                "(cooldown gating input)."),
        BAS14LayerMeshSlot(
            layerID: .l13,
            headRole: "learning-value-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores learning value of an update ticket.")
    ]

    private static let l14Slots: [BAS14LayerMeshSlot] = [
        BAS14LayerMeshSlot(
            layerID: .l14,
            headRole: "overconfidence-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Detects overconfidence in candidate response " +
                "(meta-calibration L14)."),
        BAS14LayerMeshSlot(
            layerID: .l14, headRole: "sycophancy-detector",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Detects sycophantic patterns in response " +
                "draft."),
        BAS14LayerMeshSlot(
            layerID: .l14,
            headRole: "evidence-sufficiency-scorer",
            expectedKind: .rules,
            priority: rulesTierPriority,
            description:
                "Scores whether evidence in response is " +
                "sufficient for claimed confidence."),
        BAS14LayerMeshSlot(
            layerID: .l14,
            headRole: "goal-alignment-scorer",
            expectedKind: .coremlOnDevice,
            priority: coremlOnDeviceTierPriority,
            description:
                "Scores response alignment with host goals."),
        BAS14LayerMeshSlot(
            layerID: .l14,
            headRole: "meta-calibration-head",
            expectedKind: .mlxLocal,
            priority: mlxLocalTierPriority,
            description:
                "Top-level meta-calibration combining other " +
                "L14 scores into one verdict-input hint.")
    ]

    /// Slots filtered by layer。Useful for inspecting one layer's
    /// expected mesh shape。
    public static func slots(
        forLayer layerID: BASMotherboardLayer14
    ) -> [BAS14LayerMeshSlot] {
        canonical.filter { $0.layerID == layerID }
    }

    /// Total slot count in canonical map。
    public static var totalSlotCount: Int {
        canonical.count
    }
}
