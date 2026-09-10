// MARK: - SampleHostFourteenLayerSmokeProfile (FourteenLayerSmokeProfile)
//
// chapter 二百十三 / M794 — extracted from SampleHostModel.swift
// (main enum + per-iter profile factory) + SampleHostBenchSafetyKit
// (per-layer-index lookup) + SampleHostBenchIterContext (Equatable
// extension). Consolidates 3-site definition into ONE file.
//
// Pre-this-batch (chapter 一百九十一/一百九十二):
//   - Main enum + Profile struct + layers[] + profile(forIter:)
//     in SampleHostModel.swift (~120 LOC)
//   - profile(forLayerIndex:) extension in SampleHostBenchSafetyKit
//     (~6 LOC)
//   - Equatable extension in SampleHostBenchIterContext.swift (~16 LOC)
//   Three sites for one type. Anti-doctrine.
//
// Post-this-batch:
//   - Single file owns the 14-layer profile invariant.
//   - Bench loop callers + PressureMixer + iter context all read
//     from the same source.
//   - chapter 二百十一 single-source-of-truth doctrine extended.
//
// Doctrine pins:
//   - Doctrine: signature combinations chosen so substrate's
//     per-layer logic (wake / breath / lung / horizon / ...)
//     gets meaningful exercise. NOT a perfect 1:1 mapping —
//     substrate is multi-layer per turn — but skews iter
//     distribution toward distinct layer activations.
//   - Profile is `Sendable + Equatable` (Equatable was added in
//     chapter 二百十 carve-out for `SampleHostBenchIterContext`
//     auto-derived equality; consolidated here so the doctrine
//     lives next to the type).
//   - 不变量 #1-#3 / Red line 7: ✓ pure data, no decision.

import Foundation
import BASHostKit

enum FourteenLayerSmokeProfile {
    /// Per-layer profile struct.
    struct Profile: Sendable, Equatable {
        let layerIndex: Int           // 1...14
        let layerName: String
        let tone: String
        let domain: String
        let stake: String
        let timeframe: String
        let confidant: String
        let askShape: String
        let risk: BASHostRiskLevel
        let workflow: BASHostWorkflowProfile
        let kind: BASHostSessionKind
    }

    /// Each layer's most-distinctive smoke profile.
    /// Doctrine: signature combinations chosen so substrate's
    /// per-layer logic (wake / breath / lung / horizon / ...)
    /// gets meaningful exercise. NOT a perfect 1:1 mapping —
    /// substrate is multi-layer per turn — but skews iter
    /// distribution toward distinct layer activations.
    static let layers: [Profile] = [
        Profile(layerIndex: 1, layerName: "L1-wake",
            tone: "anxious", domain: "financial",
            stake: "low", timeframe: "minutes",
            confidant: "friend", askShape: "narrative",
            risk: .low, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 2, layerName: "L2-breath",
            tone: "agentic", domain: "work",
            stake: "modest", timeframe: "hours",
            confidant: "expert", askShape: "decision-tree",
            risk: .medium, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 3, layerName: "L3-lung",
            tone: "vulnerable", domain: "relational",
            stake: "high", timeframe: "days",
            confidant: "friend", askShape: "narrative",
            risk: .medium, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 4, layerName: "L4-horizon",
            tone: "curious", domain: "creative",
            stake: "low", timeframe: "weeks",
            confidant: "decision-system",
            askShape: "single-action",
            risk: .low, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 5, layerName: "L5-host",
            tone: "authoritative", domain: "identity",
            stake: "very-high", timeframe: "months",
            confidant: "expert", askShape: "decision-tree",
            risk: .medium, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 6, layerName: "L6-context",
            tone: "confused", domain: "ethical",
            stake: "high", timeframe: "lifetime",
            confidant: "stranger", askShape: "narrative",
            risk: .high, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 7, layerName: "L7-mirror",
            tone: "grieving", domain: "trauma",
            stake: "irreversible", timeframe: "past-unresolved",
            confidant: "friend", askShape: "narrative",
            risk: .high, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 8, layerName: "L8-memory",
            tone: "agentic", domain: "parenting",
            stake: "high", timeframe: "lifetime",
            confidant: "expert", askShape: "decision-tree",
            risk: .medium, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 9, layerName: "L9-candidates",
            tone: "anxious", domain: "medical",
            stake: "very-high", timeframe: "days",
            confidant: "expert", askShape: "single-action",
            risk: .high, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 10, layerName: "L10-tribunal",
            tone: "confused", domain: "ethical",
            stake: "irreversible",
            timeframe: "non-reversible-after-act",
            confidant: "decision-system",
            askShape: "decision-tree",
            risk: .high, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 11, layerName: "L11-risk-gate",
            tone: "angry", domain: "existential",
            stake: "non-reversible-after-act",
            timeframe: "minutes",
            confidant: "stranger",
            askShape: "single-action",
            risk: .high, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 12, layerName: "L12-surface",
            tone: "vulnerable", domain: "relational",
            stake: "high", timeframe: "days",
            confidant: "friend", askShape: "narrative",
            risk: .medium, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 13, layerName: "L13-evolution",
            tone: "agentic", domain: "creative",
            stake: "modest", timeframe: "weeks",
            confidant: "decision-system",
            askShape: "decision-tree",
            risk: .low, workflow: .reflective,
            kind: .interactive),
        Profile(layerIndex: 14, layerName: "L14-reflection",
            tone: "curious", domain: "existential",
            stake: "modest", timeframe: "months",
            confidant: "expert", askShape: "narrative",
            risk: .low, workflow: .reflective,
            kind: .interactive),
    ]

    static func profile(forIter iter: Int) -> Profile {
        return layers[iter % layers.count]
    }

    /// M719 chapter 一百九十二 — Look up the layer profile for a
    /// layer index 1-14. Centralized so PressureMixer + bench loop
    /// share the same source. Returns nil for out-of-range idx.
    static func profile(forLayerIndex idx: Int) -> Profile? {
        guard idx >= 1 && idx <= layers.count else { return nil }
        return layers[idx - 1]
    }
}
