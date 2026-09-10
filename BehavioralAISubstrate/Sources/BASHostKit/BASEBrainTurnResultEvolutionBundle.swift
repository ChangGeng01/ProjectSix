// MARK: - BASEBrainTurnResultEvolutionBundle
// chapter 五百二十四 / M1473 — typed evolution cluster
//                              packaging surface
//
// Aggregates the 10 evolution-cluster fields of
// `BASEBrainTurnResult` into one typed input surface。
// Mirrors the chapter 511-522 projection-block pattern,
// applied to a NEW target:the public BASEBrainTurnResult
// return type instead of the audit projections。
//
// ## Why this exists
//
// `BASEBrainTurnResult.init(...)` takes ~52 named args。
// 10 of them form a tight cluster of L13 evolution-
// governance outputs (experienceCandidates,
// workflowCandidates,guardTemplateCandidates,
// biasRecords,riskPatternCandidates,
// learningExportBundles,shadowTrialRecords,
// versionDeltas,retractionOrders,evolutionSeals)。
//
// V1 monolith builds these from `BASEvolution
// GovernanceArtifacts` (file-private to coordinator)
// and then unpacks them into 10 separate named args at
// the return-statement call site (line 2287+)。
//
// This typed bundle:
//   - Packs the 10 fields into ONE typed surface
//   - Adds a convenience init on BASEBrainTurnResult
//     (M1474) that accepts the bundle
//   - V1 splice (M1475) collapses 10 named args → 1
//     evolutionBundle arg at the call site
//
// PUBLIC API preserved:the existing 52-arg
// `BASEBrainTurnResult.init(...)` remains unchanged。
// The new convenience init is purely additive。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only — old init kept
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 10
//     evolution fields via ONE typed surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 69 → 70
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1472 → M1473

import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// Typed-surface bundle packaging the 10 evolution-
/// cluster fields of `BASEBrainTurnResult`。 Pure value-
/// type carrier — no derive calls,no IO。
public struct BASEBrainTurnResultEvolutionBundle:
    Codable, Equatable, Sendable
{

    // MARK: - 10 evolution-cluster fields

    /// L13 experience candidates emitted this turn。
    public let experienceCandidates:
        [BASExperienceCandidate]

    /// L13 workflow candidates emitted this turn。
    public let workflowCandidates: [BASWorkflowCandidate]

    /// L13 guard-template candidates emitted this turn。
    public let guardTemplateCandidates:
        [BASGuardTemplateCandidate]

    /// L13 bias records emitted this turn。
    public let biasRecords: [BASBiasRecord]

    /// L13 risk pattern candidates emitted this turn。
    public let riskPatternCandidates:
        [BASRiskPatternCandidate]

    /// L13 learning export bundles emitted this turn。
    public let learningExportBundles:
        [BASLearningExportBundle]

    /// L13 shadow trial records emitted this turn。
    public let shadowTrialRecords:
        [BASShadowTrialRecord]

    /// L13 version deltas emitted this turn。
    public let versionDeltas: [BASVersionDelta]

    /// L13 retraction orders emitted this turn。
    public let retractionOrders: [BASRetractionOrder]

    /// L13 evolution seals emitted this turn。
    public let evolutionSeals: [BASEvolutionSeal]

    // MARK: - Construction

    public init(
        experienceCandidates:
            [BASExperienceCandidate] = [],
        workflowCandidates:
            [BASWorkflowCandidate] = [],
        guardTemplateCandidates:
            [BASGuardTemplateCandidate] = [],
        biasRecords: [BASBiasRecord] = [],
        riskPatternCandidates:
            [BASRiskPatternCandidate] = [],
        learningExportBundles:
            [BASLearningExportBundle] = [],
        shadowTrialRecords:
            [BASShadowTrialRecord] = [],
        versionDeltas: [BASVersionDelta] = [],
        retractionOrders: [BASRetractionOrder] = [],
        evolutionSeals: [BASEvolutionSeal] = []
    ) {
        self.experienceCandidates =
            experienceCandidates
        self.workflowCandidates = workflowCandidates
        self.guardTemplateCandidates =
            guardTemplateCandidates
        self.biasRecords = biasRecords
        self.riskPatternCandidates =
            riskPatternCandidates
        self.learningExportBundles =
            learningExportBundles
        self.shadowTrialRecords = shadowTrialRecords
        self.versionDeltas = versionDeltas
        self.retractionOrders = retractionOrders
        self.evolutionSeals = evolutionSeals
    }

    // MARK: - Coverage queries

    /// Count of non-empty arrays (0-10)。 Useful for
    /// "how many evolution governance signals fired
    /// this turn?" audits。
    public var populatedFieldCount: Int {
        var n = 0
        if !experienceCandidates.isEmpty { n += 1 }
        if !workflowCandidates.isEmpty { n += 1 }
        if !guardTemplateCandidates.isEmpty { n += 1 }
        if !biasRecords.isEmpty { n += 1 }
        if !riskPatternCandidates.isEmpty { n += 1 }
        if !learningExportBundles.isEmpty { n += 1 }
        if !shadowTrialRecords.isEmpty { n += 1 }
        if !versionDeltas.isEmpty { n += 1 }
        if !retractionOrders.isEmpty { n += 1 }
        if !evolutionSeals.isEmpty { n += 1 }
        return n
    }

    /// `true` when all 10 arrays are empty (cold turn
    /// from evolution-governance perspective)。
    public var isCold: Bool {
        populatedFieldCount == 0
    }

    /// All-empty singleton。 Hosts running minimal turns
    /// or initializing test fixtures use this。
    public static let empty =
        BASEBrainTurnResultEvolutionBundle()

    /// Field count invariant — 10 evolution fields。
    public static let evolutionFieldCount: Int = 10
}
