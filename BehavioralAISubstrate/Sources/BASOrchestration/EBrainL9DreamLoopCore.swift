// MARK: - EBrainL9DreamLoopCore — chapter 二百七十六 / M763
//
// Phase Alpha 第二刀:从 EBrainCognitionPlaneCore.swift 抽出 L9
// dream-loop types。chapter 一百七十七 vision L9 = "梦环" — 候选
// 前沿 / 反事实分支 / 后果投影 / 红队 / 守护枝 / 比较板。
//
// 抽出 18 types(M114 L9 whitepaper §5 parity cluster):
//   - BASThoughtLoopStopReason / BASCandidatePathStatus /
//     BASSovereignBreakSuggestedAction (3 enums)
//   - BASThoughtLoopState (BASSchemaVersioned aggregator)
//   - BASCounterfactualBranch / BASOutcomeProjection /
//     BASAdversarialBrief / BASHostAlignmentMap (4 schema types)
//   - BASCandidateFrontier (with custom Codable for backward-compat)
//   - BASCounterfactualBundle / BASCritiqueBundle (2 bundles)
//   - BASUncertaintyLedger / BASEvidenceDebt (2 ledgers)
//   - BASConvergenceStoppingMode / BASConvergenceCertificate
//   - BASLoopLeaseReceipt (lease accounting)
//   - BASSovereignBreakpointSuggestedAction /
//     BASSovereignBreakpointHint (2 sovereign break types)
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。Module DAG 不变。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保:纯 file org 重构
//   - 红线 7 watcher hint only:types 是 schema definitions
//   - chapter 二百十一 single-source-of-truth:types 仍 owned by
//     one file (god file → dedicated file)

import Foundation
import BASRuntimeCore

// MARK: - M114 L9 whitepaper §5 parity

/// L9 dream-loop stop reason. Matches whitepaper §5.1
/// `ThoughtLoopState.stop_reason` vocabulary.
public enum BASThoughtLoopStopReason:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case converged
    case leaseEnd
    case sovereignCut
    case guardTakeover
    case pending
}

/// L9 candidate path status. Matches whitepaper §5.2
/// `CandidatePath.status` vocabulary.
public enum BASCandidatePathStatus:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case active
    case dominated
    /// L12 soft-hand guard branch. Swift keyword-escaped.
    case `guard`
    case delayed
    case cut
}

/// L9 sovereign-break suggested action. Matches whitepaper §5.12
/// `SovereignBreakpointHint.suggested_action` vocabulary.
public enum BASSovereignBreakSuggestedAction:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case shrink
    case cut
    case freeze
    case stop
}

/// L9 whitepaper §5.1 `ThoughtLoopState` — the aggregator state
/// of one dream-loop turn. Binds the canonical frame + memory
/// bundle + active frontier refs + counterfactual / projection /
/// adversarial lists + uncertainty / evidence-debt / convergence
/// / lease refs + sovereign breakpoints + stop reason.
public struct BASThoughtLoopState: BASSchemaVersioned,
    Equatable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var loopID: String
    public var canonicalFrameRef: String?
    public var memoryBundleRef: String?
    public var activeFrontierRef: String?
    public var counterfactualRefs: [String]
    public var projectionRefs: [String]
    public var adversarialRefs: [String]
    public var uncertaintyRef: String?
    public var evidenceDebtRef: String?
    public var convergenceRef: String?
    public var leaseRef: String?
    public var sovereignBreakRefs: [String]
    public var stopReason: BASThoughtLoopStopReason

    public init(
        schemaVersion: String
            = BASThoughtLoopState.currentSchemaVersion,
        loopID: String,
        canonicalFrameRef: String? = nil,
        memoryBundleRef: String? = nil,
        activeFrontierRef: String? = nil,
        counterfactualRefs: [String] = [],
        projectionRefs: [String] = [],
        adversarialRefs: [String] = [],
        uncertaintyRef: String? = nil,
        evidenceDebtRef: String? = nil,
        convergenceRef: String? = nil,
        leaseRef: String? = nil,
        sovereignBreakRefs: [String] = [],
        stopReason: BASThoughtLoopStopReason = .pending
    ) {
        self.schemaVersion = schemaVersion
        self.loopID = loopID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.canonicalFrameRef = canonicalFrameRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryBundleRef = memoryBundleRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.activeFrontierRef = activeFrontierRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.counterfactualRefs = counterfactualRefs
        self.projectionRefs = projectionRefs
        self.adversarialRefs = adversarialRefs
        self.uncertaintyRef = uncertaintyRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.evidenceDebtRef = evidenceDebtRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.convergenceRef = convergenceRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.leaseRef = leaseRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignBreakRefs = sovereignBreakRefs
        self.stopReason = stopReason
    }
}

/// L9 whitepaper §5.4 `CounterfactualBranch` — one branch emitted
/// by the counterfactual manifold that perturbs one condition from
/// a parent candidate and projects the shift.
public struct BASCounterfactualBranch: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var branchID: String
    public var alteredCondition: String
    public var parentCandidateRef: String
    public var projectedShift: String
    public var uncertainty: Double
    public var dependencyRefs: [String]

    public init(
        schemaVersion: String
            = BASCounterfactualBranch.currentSchemaVersion,
        branchID: String,
        alteredCondition: String,
        parentCandidateRef: String,
        projectedShift: String = "",
        uncertainty: Double = 0,
        dependencyRefs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.branchID = branchID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.alteredCondition = alteredCondition
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.parentCandidateRef = parentCandidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.projectedShift = projectedShift
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.uncertainty = min(1, max(0, uncertainty))
        self.dependencyRefs = dependencyRefs
    }
}

/// L9 whitepaper §5.5 `OutcomeProjection` — per-candidate future
/// projection covering short/mid/worst-case + reversibility loss
/// + affected domains + confidence band.
public struct BASOutcomeProjection: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var projectionID: String
    public var candidateRef: String
    public var shortTerm: String
    public var midTerm: String
    public var worstCase: String
    /// [0, 1] how much reversibility is lost by following this
    /// candidate (higher = harder to undo).
    public var reversibilityLoss: Double
    public var affectedDomains: [String]
    /// [0, 1] confidence in the projection.
    public var confidenceBand: Double

    public init(
        schemaVersion: String
            = BASOutcomeProjection.currentSchemaVersion,
        projectionID: String,
        candidateRef: String,
        shortTerm: String = "",
        midTerm: String = "",
        worstCase: String = "",
        reversibilityLoss: Double = 0,
        affectedDomains: [String] = [],
        confidenceBand: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.projectionID = projectionID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.shortTerm = shortTerm
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.midTerm = midTerm
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.worstCase = worstCase
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.reversibilityLoss = min(1, max(0, reversibilityLoss))
        self.affectedDomains = affectedDomains
        self.confidenceBand = min(1, max(0, confidenceBand))
    }
}

/// L9 whitepaper §5.6 `AdversarialBrief` — a red-team brief against
/// one candidate, scoring evidence gap / emotional bias /
/// manipulation risk / boundary conflict / host misalignment /
/// overall severity.
public struct BASAdversarialBrief: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var briefID: String
    public var candidateRef: String
    /// [0, 1] evidence gap severity.
    public var evidenceGap: Double
    /// [0, 1] emotional bias severity.
    public var emotionalBias: Double
    /// [0, 1] manipulation risk severity.
    public var manipulationRisk: Double
    /// [0, 1] boundary conflict severity.
    public var boundaryConflict: Double
    /// [0, 1] host misalignment severity.
    public var hostMisalignment: Double
    /// [0, 1] aggregate severity the adversarial court assigns.
    public var severity: Double

    public init(
        schemaVersion: String
            = BASAdversarialBrief.currentSchemaVersion,
        briefID: String,
        candidateRef: String,
        evidenceGap: Double = 0,
        emotionalBias: Double = 0,
        manipulationRisk: Double = 0,
        boundaryConflict: Double = 0,
        hostMisalignment: Double = 0,
        severity: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.briefID = briefID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.evidenceGap = min(1, max(0, evidenceGap))
        self.emotionalBias = min(1, max(0, emotionalBias))
        self.manipulationRisk = min(1, max(0, manipulationRisk))
        self.boundaryConflict = min(1, max(0, boundaryConflict))
        self.hostMisalignment = min(1, max(0, hostMisalignment))
        self.severity = min(1, max(0, severity))
    }
}

/// L9 whitepaper §5.7 `HostAlignmentMap` — per-candidate analysis
/// of which host goals it aligns with / which values it violates
/// / which relations it impacts / overall long-term alignment.
public struct BASHostAlignmentMap: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateRef: String
    public var alignedGoals: [String]
    public var violatedValues: [String]
    public var relationImpactRefs: [String]
    /// [0, 1] long-term alignment with host constitution. Higher
    /// = more aligned.
    public var longTermAlignmentScore: Double

    public init(
        schemaVersion: String
            = BASHostAlignmentMap.currentSchemaVersion,
        candidateRef: String,
        alignedGoals: [String] = [],
        violatedValues: [String] = [],
        relationImpactRefs: [String] = [],
        longTermAlignmentScore: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.candidateRef = candidateRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.alignedGoals = alignedGoals
        self.violatedValues = violatedValues
        self.relationImpactRefs = relationImpactRefs
        self.longTermAlignmentScore = min(
            1, max(0, longTermAlignmentScore))
    }
}

public struct BASCandidateFrontier: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.1.0"

    public var schemaVersion: String
    public var candidateIDs: [String]
    public var dominanceOrder: [String]
    public var reversiblePaths: [String]
    public var guardPaths: [String]
    public var frontierWidth: Int
    public var diversityScore: Double
    public var delayedPaths: [String]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case candidateIDs
        case dominanceOrder
        case reversiblePaths
        case guardPaths
        case frontierWidth
        case diversityScore
        case delayedPaths
    }

    public init(
        schemaVersion: String = BASCandidateFrontier.currentSchemaVersion,
        candidateIDs: [String],
        dominanceOrder: [String],
        reversiblePaths: [String] = [],
        guardPaths: [String] = [],
        frontierWidth: Int,
        diversityScore: Double = 0,
        delayedPaths: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.candidateIDs = candidateIDs
        self.dominanceOrder = dominanceOrder
        self.reversiblePaths = reversiblePaths
        self.guardPaths = guardPaths
        self.frontierWidth = max(0, frontierWidth)
        self.diversityScore = min(max(diversityScore, 0), 1)
        self.delayedPaths = delayedPaths
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let candidateIDs = try container.decodeIfPresent([String].self, forKey: .candidateIDs) ?? []

        self.init(
            schemaVersion: try container.decodeIfPresent(String.self, forKey: .schemaVersion)
                ?? "1.0.0",
            candidateIDs: candidateIDs,
            dominanceOrder: try container.decodeIfPresent([String].self, forKey: .dominanceOrder) ?? [],
            reversiblePaths: try container.decodeIfPresent([String].self, forKey: .reversiblePaths) ?? [],
            guardPaths: try container.decodeIfPresent([String].self, forKey: .guardPaths) ?? [],
            frontierWidth: try container.decodeIfPresent(Int.self, forKey: .frontierWidth) ?? candidateIDs.count,
            diversityScore: try container.decodeIfPresent(Double.self, forKey: .diversityScore) ?? 0,
            delayedPaths: try container.decodeIfPresent([String].self, forKey: .delayedPaths) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(candidateIDs, forKey: .candidateIDs)
        try container.encode(dominanceOrder, forKey: .dominanceOrder)
        try container.encode(reversiblePaths, forKey: .reversiblePaths)
        try container.encode(guardPaths, forKey: .guardPaths)
        try container.encode(frontierWidth, forKey: .frontierWidth)
        try container.encode(diversityScore, forKey: .diversityScore)
        try container.encode(delayedPaths, forKey: .delayedPaths)
    }
}

public struct BASCounterfactualBundle: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var shortTerm: String
    public var midTerm: String
    public var worstCase: String
    public var uncertainty: Double
    public var affectedDomains: [String]

    public init(
        schemaVersion: String = BASCounterfactualBundle.currentSchemaVersion,
        candidateID: String,
        shortTerm: String,
        midTerm: String,
        worstCase: String,
        uncertainty: Double,
        affectedDomains: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.shortTerm = shortTerm
        self.midTerm = midTerm
        self.worstCase = worstCase
        self.uncertainty = min(max(uncertainty, 0), 1)
        self.affectedDomains = affectedDomains
    }
}

public struct BASCritiqueBundle: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var evidenceGap: Double
    public var manipulationRisk: Double
    public var emotionalBias: Double
    public var boundaryConflict: Double
    public var critiqueStrength: Double

    public init(
        schemaVersion: String = BASCritiqueBundle.currentSchemaVersion,
        candidateID: String,
        evidenceGap: Double,
        manipulationRisk: Double,
        emotionalBias: Double,
        boundaryConflict: Double,
        critiqueStrength: Double
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.evidenceGap = min(max(evidenceGap, 0), 1)
        self.manipulationRisk = min(max(manipulationRisk, 0), 1)
        self.emotionalBias = min(max(emotionalBias, 0), 1)
        self.boundaryConflict = min(max(boundaryConflict, 0), 1)
        self.critiqueStrength = min(max(critiqueStrength, 0), 1)
    }
}

public struct BASUncertaintyLedger: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var ledgerID: String
    public var unresolvedUnknowns: [String]
    public var weakPredictions: [String]
    public var highSensitivityPoints: [String]
    public var confidenceFloor: Double

    public init(
        schemaVersion: String = BASUncertaintyLedger.currentSchemaVersion,
        ledgerID: String,
        unresolvedUnknowns: [String] = [],
        weakPredictions: [String] = [],
        highSensitivityPoints: [String] = [],
        confidenceFloor: Double
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unresolvedUnknowns = unresolvedUnknowns
        self.weakPredictions = weakPredictions
        self.highSensitivityPoints = highSensitivityPoints
        self.confidenceFloor = min(max(confidenceFloor, 0), 1)
    }
}

public struct BASEvidenceDebt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var debtID: String
    public var candidateID: String
    public var missingEvidence: [String]
    public var validationActions: [String]
    public var debtWeight: Double

    public init(
        schemaVersion: String = BASEvidenceDebt.currentSchemaVersion,
        debtID: String,
        candidateID: String,
        missingEvidence: [String] = [],
        validationActions: [String] = [],
        debtWeight: Double
    ) {
        self.schemaVersion = schemaVersion
        self.debtID = debtID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateID = candidateID
        self.missingEvidence = missingEvidence
        self.validationActions = validationActions
        self.debtWeight = min(max(debtWeight, 0), 1)
    }
}

public enum BASConvergenceStoppingMode: String, Codable, CaseIterable, Sendable {
    case converged
    case leaseEnd
    case sovereignCut
    case guardTakeover
}

public struct BASConvergenceCertificate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var certID: String
    public var frontierID: String
    public var stabilityScore: Double
    public var stoppingMode: BASConvergenceStoppingMode
    public var recommendedNextStep: String

    public init(
        schemaVersion: String = BASConvergenceCertificate.currentSchemaVersion,
        certID: String,
        frontierID: String,
        stabilityScore: Double,
        stoppingMode: BASConvergenceStoppingMode,
        recommendedNextStep: String
    ) {
        self.schemaVersion = schemaVersion
        self.certID = certID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.frontierID = frontierID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.stabilityScore = min(max(stabilityScore, 0), 1)
        self.stoppingMode = stoppingMode
        self.recommendedNextStep = recommendedNextStep.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASLoopLeaseReceipt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var receiptID: String
    public var leaseID: String
    public var loopsUsed: Int
    public var candidatesUsed: Int
    public var projectionsUsed: Int
    public var degraded: Bool

    public init(
        schemaVersion: String = BASLoopLeaseReceipt.currentSchemaVersion,
        receiptID: String,
        leaseID: String,
        loopsUsed: Int,
        candidatesUsed: Int,
        projectionsUsed: Int,
        degraded: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.receiptID = receiptID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.leaseID = leaseID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.loopsUsed = max(0, loopsUsed)
        self.candidatesUsed = max(0, candidatesUsed)
        self.projectionsUsed = max(0, projectionsUsed)
        self.degraded = degraded
    }
}

public enum BASSovereignBreakpointSuggestedAction: String, Codable, CaseIterable, Sendable {
    case shrink
    case cut
    case freeze
    case stop
}

public struct BASSovereignBreakpointHint: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var hintID: String
    public var sourceRef: String
    public var reasonCodes: [String]
    public var affectedCandidates: [String]
    public var suggestedAction: BASSovereignBreakpointSuggestedAction

    public init(
        schemaVersion: String = BASSovereignBreakpointHint.currentSchemaVersion,
        hintID: String,
        sourceRef: String,
        reasonCodes: [String] = [],
        affectedCandidates: [String] = [],
        suggestedAction: BASSovereignBreakpointSuggestedAction
    ) {
        self.schemaVersion = schemaVersion
        self.hintID = hintID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRef = sourceRef.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reasonCodes = reasonCodes
        self.affectedCandidates = affectedCandidates
        self.suggestedAction = suggestedAction
    }
}

