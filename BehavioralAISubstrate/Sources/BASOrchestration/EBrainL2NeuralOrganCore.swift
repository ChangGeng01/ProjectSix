// MARK: - EBrainL2NeuralOrganCore — chapter 二百七十五 / M762
//
// Phase Alpha 第一刀:从 EBrainCognitionPlaneCore.swift (5347 LOC)
// 抽出 L2 Neural Organ Runtime types。chapter 一百七十七 vision
// L2 = "脑肉",neural organ runtime — Scout / Core Cortex / Simu
// Ring / Critic Blade / Risk Spine / Permit Knot / Memory Codec
// Ridge / Host Modulation Mesh / Tool Intent Mesh / Consistency
// Lattice / Stub Core / Tissue Router 12 organs。
//
// 抽出 types:
//   - `BASNeuralOrgan` — 12-case organ enum
//   - `BASNeuralMorph` — 8-case morph enum (scout / engage /
//     compare / deepLoop / guard / stub / quarantine /
//     rollbackRebuild)
//   - `BASNeuralPrecisionTier` — 4-case precision tier
//   - `BASNeuralRoutingPolicy` — 8-case routing policy
//   - `BASNeuralOrganPrecision` — per-organ precision binding
//   - `BASNeuralOrganMap` (BASSchemaVersioned) — neural organ
//     map for one turn
//   - `BASCortexPacket` (BASSchemaVersioned) — M107 / L2 §7
//     Core Cortex per-turn output frame
//   - `BASLatentTissueState` — per-organ latent state strings
//   - `BASNeuralCoreFrame` — organ map + tissue state + degraded
//     reason codes
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。Module DAG 不变(BASOrchestration internal split,
// 仍可被同 module 其他 file 引用,无需 import)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保:纯 file org 重构
//   - 红线 7 watcher hint only:types 是 schema definitions 不是
//     decision logic
//   - chapter 二百十一 single-source-of-truth:每 type 仍只 owned
//     by one file (从原 god file 移到此 file)
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五
//     anti-magic-number doctrine:全保

import Foundation
import BASRuntimeCore

public enum BASNeuralOrgan: String, Codable, CaseIterable, Sendable {
    case scoutStrip
    case coreCortex
    case simuRing
    case criticBlade
    case riskSpine
    case permitKnot
    case memoryCodecRidge
    case hostModulationMesh
    case toolIntentMesh
    case consistencyLattice
    case stubCore
    case tissueRouter
}

public enum BASNeuralMorph: String, Codable, CaseIterable, Sendable {
    case scout
    case engage
    case compare
    case deepLoop
    case `guard`
    case stub
    case quarantine
    case rollbackRebuild
}

public enum BASNeuralPrecisionTier: String, Codable, CaseIterable, Sendable {
    case minimal
    case balanced
    case protected
    case full
}

public enum BASNeuralRoutingPolicy: String, Codable, CaseIterable, Sendable {
    case scoutProbe
    case conversationalBalance
    case comparativeFanout
    case deepLoopConvergence
    case protectiveThrottle
    case quarantineIsolation
    case rollbackRecovery
    case stubOnly
}

public struct BASNeuralOrganPrecision: Codable, Equatable, Sendable {
    public var organ: BASNeuralOrgan
    public var tier: BASNeuralPrecisionTier

    public init(
        organ: BASNeuralOrgan,
        tier: BASNeuralPrecisionTier
    ) {
        self.organ = organ
        self.tier = tier
    }
}

public struct BASNeuralOrganMap: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var morph: BASNeuralMorph
    public var activeOrgans: [BASNeuralOrgan]
    public var precisionMap: [BASNeuralOrganPrecision]
    public var routingPolicy: BASNeuralRoutingPolicy
    public var leaseRef: String?
    public var sovereignConstraints: [String]
    public var headGuarantees: [String]

    public init(
        schemaVersion: String = BASNeuralOrganMap.currentSchemaVersion,
        morph: BASNeuralMorph,
        activeOrgans: [BASNeuralOrgan],
        precisionMap: [BASNeuralOrganPrecision] = [],
        routingPolicy: BASNeuralRoutingPolicy,
        leaseRef: String? = nil,
        sovereignConstraints: [String] = [],
        headGuarantees: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.morph = morph
        self.activeOrgans = activeOrgans
        self.precisionMap = precisionMap
        self.routingPolicy = routingPolicy
        self.leaseRef = leaseRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignConstraints = sovereignConstraints
        self.headGuarantees = headGuarantees
    }
}

/// M107 — L2 whitepaper §7 `CortexPacket` coverage.
///
/// The cortex packet is the Core Cortex organ's **per-turn compact
/// output frame**: a bundle of semantic + structural + modulation
/// + risk + seed + checksum fields that downstream organs (Simu
/// Ring / Critic Blade / Risk Spine / Permit Knot) consume to
/// produce candidate frontiers, counterfactuals, and critiques.
///
/// Pre-M107 the `BASNeuralOrgan.coreCortex` case existed in the
/// organ enum but the packet shape itself was whitepaper-only.
/// M107 lands the Swift struct so substrate + Qinao layers can
/// build, serialize, and audit cortex packets end-to-end.
///
/// Field semantics (from whitepaper §7):
/// - `semanticFrame`: compact string summary of the primary
///   semantic claim the cortex produced for this turn.
/// - `structureSlots`: slot-map of structural roles (subject /
///   verb / object / time / place / reason / …); keys are
///   slot names, values are filled content. Kept as
///   `[String: String]` so the slot vocabulary can evolve without
///   a schema bump.
/// - `hostModSummary`: compact summary of how the Host Modulation
///   Mesh shaped this packet (boundary / style / consent
///   adjustments applied upstream).
/// - `riskSummary`: compact summary from the Risk Spine of what
///   risk vectors this packet triggers.
/// - `candidateSeed`: minimal seed string downstream candidate
///   generation uses to produce candidates (title + prompt
///   fragment).
/// - `consistencyChecksum`: digest the Consistency Lattice uses
///   to verify internal coherence across organs. Caller
///   computes; runtime verifies.
public struct BASCortexPacket: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var semanticFrame: String
    public var structureSlots: [String: String]
    public var hostModSummary: String
    public var riskSummary: String
    public var candidateSeed: String
    public var consistencyChecksum: String

    public init(
        schemaVersion: String = BASCortexPacket.currentSchemaVersion,
        semanticFrame: String,
        structureSlots: [String: String] = [:],
        hostModSummary: String,
        riskSummary: String,
        candidateSeed: String,
        consistencyChecksum: String
    ) {
        self.schemaVersion = schemaVersion
        self.semanticFrame = semanticFrame
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.structureSlots = structureSlots
        self.hostModSummary = hostModSummary
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.riskSummary = riskSummary
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateSeed = candidateSeed
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.consistencyChecksum = consistencyChecksum
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// An empty-valued packet — useful as a fallback when the
    /// cortex organ degrades and emits only a stub. Downstream
    /// organs that see an empty semanticFrame can trace this
    /// back to the cortex degradation branch.
    public static let empty = BASCortexPacket(
        semanticFrame: "",
        structureSlots: [:],
        hostModSummary: "",
        riskSummary: "",
        candidateSeed: "",
        consistencyChecksum: "")
}

public struct BASLatentTissueState: Equatable, Sendable {
    public var scoutState: String?
    public var cortexState: String?
    public var simuState: String?
    public var criticState: String?
    public var riskState: String?
    public var permitState: String?
    public var memoryCodecState: String?
    public var hostModState: String?
    public var toolIntentState: String?
    public var consistencyState: String?
    public var stubState: String?

    public init(
        scoutState: String? = nil,
        cortexState: String? = nil,
        simuState: String? = nil,
        criticState: String? = nil,
        riskState: String? = nil,
        permitState: String? = nil,
        memoryCodecState: String? = nil,
        hostModState: String? = nil,
        toolIntentState: String? = nil,
        consistencyState: String? = nil,
        stubState: String? = nil
    ) {
        self.scoutState = scoutState
        self.cortexState = cortexState
        self.simuState = simuState
        self.criticState = criticState
        self.riskState = riskState
        self.permitState = permitState
        self.memoryCodecState = memoryCodecState
        self.hostModState = hostModState
        self.toolIntentState = toolIntentState
        self.consistencyState = consistencyState
        self.stubState = stubState
    }
}

public struct BASNeuralCoreFrame: Equatable, Sendable {
    public var organMap: BASNeuralOrganMap
    public var tissueState: BASLatentTissueState
    public var degradedReasonCodes: [String]

    public init(
        organMap: BASNeuralOrganMap,
        tissueState: BASLatentTissueState = BASLatentTissueState(),
        degradedReasonCodes: [String] = []
    ) {
        self.organMap = organMap
        self.tissueState = tissueState
        self.degradedReasonCodes = degradedReasonCodes
    }
}
