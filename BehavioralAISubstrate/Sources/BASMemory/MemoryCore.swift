import CryptoKit
import Foundation
import BASRuntimeCore

public enum BASMemoryKind: String, Codable, Sendable {
    case episodic
    case semantic
    case profile
    case goal
    case situational
    case support
    case template
    case failurePattern
}

public enum BASMemoryScope: String, Codable, Sendable {
    case user
    case device
    case session
    case task
}

public enum BASMemorySensitivity: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum BASMemoryTier: String, Codable, Sendable {
    case hot
    case warm
    case cold
}

public enum BASMemoryGovernanceStatus: String, Codable, Sendable {
    case candidate
    case governed
    case quarantined
    case rejected
    case archived
}

public enum BASReactionWeightKey: String, CaseIterable, Codable, Sendable {
    case briefLanguage = "brief_language"
    case warmDirectTone = "warm_direct_tone"
    case lowCognitiveLoad = "low_cognitive_load"
    case interruptiveActionBias = "interruptive_action_bias"
    case boundaryNamingBias = "boundary_naming_bias"
    case tradeoffClarityBias = "tradeoff_clarity_bias"
}

public struct BASReactionWeights: Codable, Sendable, Equatable {
    /// **M601 chapter 一百七十二 — anti-magic-number** (chapter 一百六十六
    /// §166.5 backlog 5 of 6): default reaction-weight seed values.
    /// Pre-fix these 6 values were inline at line ~90-95 in
    /// `defaults(for: modeName)`.
    ///
    /// **Doctrine**: seed defaults are 0.50-centered (neutral
    /// baseline) with axis-specific deviations:
    /// - briefLanguage 0.50: neutral preference for brevity
    /// - warmDirectTone 0.54: slight bias toward warm directness
    /// - lowCognitiveLoad 0.50: neutral preference for low load
    /// - interruptiveActionBias 0.44: SLIGHT BIAS AGAINST
    ///   interrupting (below 0.50 — substrate defaults to
    ///   non-interruptive)
    /// - boundaryNamingBias 0.46: slight bias against verbose
    ///   boundary-naming (most boundaries should be implicit)
    /// - tradeoffClarityBias 0.50: neutral
    ///
    /// These are seed defaults, not active gating thresholds —
    /// they're starting values for runtime fitting. Lower
    /// extraction priority than active thresholds (chapters 167-171).
    /// Extracted for cross-reference + drift-prevention.
    public static let defaultBriefLanguageSeed: Double = 0.50
    public static let defaultWarmDirectToneSeed: Double = 0.54
    public static let defaultLowCognitiveLoadSeed: Double = 0.50
    public static let defaultInterruptiveActionBiasSeed: Double =
        0.44
    public static let defaultBoundaryNamingBiasSeed: Double = 0.46
    public static let defaultTradeoffClarityBiasSeed: Double = 0.50

    public var briefLanguage: Double
    public var warmDirectTone: Double
    public var lowCognitiveLoad: Double
    public var interruptiveActionBias: Double
    public var boundaryNamingBias: Double
    public var tradeoffClarityBias: Double

    public init(
        briefLanguage: Double,
        warmDirectTone: Double,
        lowCognitiveLoad: Double,
        interruptiveActionBias: Double,
        boundaryNamingBias: Double,
        tradeoffClarityBias: Double
    ) {
        self.briefLanguage = briefLanguage
        self.warmDirectTone = warmDirectTone
        self.lowCognitiveLoad = lowCognitiveLoad
        self.interruptiveActionBias = interruptiveActionBias
        self.boundaryNamingBias = boundaryNamingBias
        self.tradeoffClarityBias = tradeoffClarityBias
    }

    public init(warmth: Double, directness: Double, brevity: Double, actionBias: Double) {
        self.init(
            briefLanguage: brevity,
            warmDirectTone: warmth,
            lowCognitiveLoad: max(0, min(1, (warmth + brevity) / 2)),
            interruptiveActionBias: actionBias,
            boundaryNamingBias: max(0, min(1, (warmth + directness) / 2)),
            tradeoffClarityBias: directness
        )
    }

    public static func defaults(for modeName: String) -> BASReactionWeights {
        _ = modeName
        // M601 chapter 一百七十二 — anti-magic-number: seed values
        // sourced from named static constants with doctrine
        // doc-comment.
        return BASReactionWeights(
            briefLanguage: defaultBriefLanguageSeed,
            warmDirectTone: defaultWarmDirectToneSeed,
            lowCognitiveLoad: defaultLowCognitiveLoadSeed,
            interruptiveActionBias:
                defaultInterruptiveActionBiasSeed,
            boundaryNamingBias: defaultBoundaryNamingBiasSeed,
            tradeoffClarityBias: defaultTradeoffClarityBiasSeed
        )
    }

    public static func defaults(forModeName modeName: String) -> BASReactionWeights {
        defaults(for: modeName)
    }

    public func value(for key: BASReactionWeightKey) -> Double {
        switch key {
        case .briefLanguage:
            briefLanguage
        case .warmDirectTone:
            warmDirectTone
        case .lowCognitiveLoad:
            lowCognitiveLoad
        case .interruptiveActionBias:
            interruptiveActionBias
        case .boundaryNamingBias:
            boundaryNamingBias
        case .tradeoffClarityBias:
            tradeoffClarityBias
        }
    }

    public var dominantKey: BASReactionWeightKey {
        BASReactionWeightKey.allCases.max { lhs, rhs in
            value(for: lhs) < value(for: rhs)
        } ?? .briefLanguage
    }

    public var warmth: Double {
        get { warmDirectTone }
        set { warmDirectTone = newValue }
    }

    public var directness: Double {
        get { tradeoffClarityBias }
        set { tradeoffClarityBias = newValue }
    }

    public var brevity: Double {
        get { briefLanguage }
        set { briefLanguage = newValue }
    }

    public var actionBias: Double {
        get { interruptiveActionBias }
        set { interruptiveActionBias = newValue }
    }
}

public enum BASBrainMemoryRole: String, Codable, Sendable {
    case profile
    case goal
    case relevant
}

public enum BASMemorySourceTrustTier: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum BASMemoryEligibilityReason: String, CaseIterable, Codable, Sendable {
    case identityOverride = "identity_override"
    case goalOverride = "goal_override"
    case pendingTagOverlap = "pending_tag_overlap"
    case pendingGraceWindow = "pending_grace_window"
    case externalRefreshNoOverlap = "external_refresh_no_overlap"
    case fastDecayTagOverlap = "fast_decay_tag_overlap"
    case fastDecayGraceWindow = "fast_decay_grace_window"
    case confidenceNoOverlap = "confidence_no_overlap"
    case supportPriorityNoOverlap = "support_priority_no_overlap"
    case semanticPriorityNoOverlap = "semantic_priority_no_overlap"
    case provenanceContamination = "provenance_contamination"
    case lowTrustPending = "low_trust_pending"
    case tagFloodNoOverlap = "tag_flood_no_overlap"
    case defaultAllowed = "default_allowed"
}

public struct BASMemoryEligibilityDecision: Codable, Equatable, Sendable {
    public let isAllowed: Bool
    public let reason: BASMemoryEligibilityReason

    public init(isAllowed: Bool, reason: BASMemoryEligibilityReason) {
        self.isAllowed = isAllowed
        self.reason = reason
    }

    public static func allowed(_ reason: BASMemoryEligibilityReason) -> BASMemoryEligibilityDecision {
        BASMemoryEligibilityDecision(isAllowed: true, reason: reason)
    }

    public static func screenedOut(_ reason: BASMemoryEligibilityReason) -> BASMemoryEligibilityDecision {
        BASMemoryEligibilityDecision(isAllowed: false, reason: reason)
    }
}

public enum BASBrainGovernedMemoryStatus: String, Codable, Sendable {
    case admitted
    case deferred
    case pending
}

public struct BASGovernedMemorySlice: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let role: BASBrainMemoryRole
    public let type: String
    public let headline: String
    public let source: String
    public let confidence: Double
    public let priority: Double
    public let lifecycleState: String
    public let governanceStatus: BASBrainGovernedMemoryStatus
    public let eligibility: BASMemoryEligibilityDecision
    public let sourceTrustScore: Double
    public let sourceTrustTier: BASMemorySourceTrustTier
    public let retrievalTags: [String]
    public let isPending: Bool
    public let provenanceSummary: String

    public init(
        id: String,
        role: BASBrainMemoryRole,
        type: String,
        headline: String,
        source: String,
        confidence: Double,
        priority: Double,
        lifecycleState: String,
        governanceStatus: BASBrainGovernedMemoryStatus,
        eligibility: BASMemoryEligibilityDecision,
        sourceTrustScore: Double,
        sourceTrustTier: BASMemorySourceTrustTier,
        retrievalTags: [String],
        isPending: Bool,
        provenanceSummary: String
    ) {
        self.id = id
        self.role = role
        self.type = type
        self.headline = headline
        self.source = source
        self.confidence = confidence
        self.priority = priority
        self.lifecycleState = lifecycleState
        self.governanceStatus = governanceStatus
        self.eligibility = eligibility
        self.sourceTrustScore = sourceTrustScore
        self.sourceTrustTier = sourceTrustTier
        self.retrievalTags = retrievalTags
        self.isPending = isPending
        self.provenanceSummary = provenanceSummary
    }
}

public enum BASBrainStateRiskFlag: String, Codable, Sendable {
    case highPendingInfluence = "high_pending_influence"
    case lowTrustLoad = "low_trust_load"
    case contaminationGuardTriggered = "contamination_guard_triggered"
    case externalRefreshGuardTriggered = "external_refresh_guard_triggered"
    case observationOnlyQuarantine = "observation_only_quarantine"
    case evidenceCaveatLoad = "evidence_caveat_load"
    case retrievalInstability = "retrieval_instability"
    case tagFloodBlocked = "tag_flood_blocked"
}

public struct BASBrainStateSnapshot: Codable, Equatable, Sendable {
    public let fingerprint: String
    public let dominantReactionWeight: BASReactionWeightKey
    public let loadedMemoryCount: Int
    public let pendingMemoryLoadRate: Double
    public let lowTrustMemoryLoadRate: Double
    public let riskFlags: [BASBrainStateRiskFlag]

    public init(
        fingerprint: String,
        dominantReactionWeight: BASReactionWeightKey,
        loadedMemoryCount: Int,
        pendingMemoryLoadRate: Double,
        lowTrustMemoryLoadRate: Double,
        riskFlags: [BASBrainStateRiskFlag]
    ) {
        self.fingerprint = fingerprint
        self.dominantReactionWeight = dominantReactionWeight
        self.loadedMemoryCount = loadedMemoryCount
        self.pendingMemoryLoadRate = pendingMemoryLoadRate
        self.lowTrustMemoryLoadRate = lowTrustMemoryLoadRate
        self.riskFlags = riskFlags
    }
}


// chapter 二百八十四 / M771 — Identity + Boundary + Brain
// compilation cluster (BASIdentityRole / BASIdentityPosture /
// BASIdentityInitiative / BASIdentityProfile /
// BASIdentityProfileOverlay / BASBoundaryPolicyMode /
// BASBoundaryConstraint / BASBoundaryPolicyState /
// BASBoundaryEvaluationBehavior / BASBrainCompilationBehavior)
// extracted to `MemoryIdentityBoundaryCore.swift`. Phase Alpha
// 10th cut. 0 behavior change.


public struct BASCognitionBehavior: Codable, Equatable, Sendable {
    public var surfaceIdentityOverlaysBySurfaceID: [String: BASIdentityProfileOverlay]
    public var highRiskIdentityOverlay: BASIdentityProfileOverlay
    public var highRiskInitiativeByRoleID: [String: BASIdentityInitiative]
    public var boundary: BASBoundaryEvaluationBehavior
    public var sessionBias: BASSessionBiasBehavior
    public var brainCompilation: BASBrainCompilationBehavior
    public var memoryTrust: BASMemoryTrustBehavior

    public init(
        surfaceIdentityOverlaysBySurfaceID: [String: BASIdentityProfileOverlay] = [
            BASInteractionSurface.notification.rawValue: BASIdentityProfileOverlay(
                role: .predictiveSentinel,
                posture: .coaching,
                initiative: .guided,
                // M598 chapter 一百六十九 — anti-magic-number
                confidenceCeiling: BASIdentityProfile
                    .notificationSurfaceConfidenceCeiling,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Use brief local nudges without taking over the user's agency."
            ),
            BASInteractionSurface.watch.rawValue: BASIdentityProfileOverlay(
                role: .pauseCompanion,
                initiative: .guided,
                confidenceCeiling: BASIdentityProfile
                    .watchSurfaceConfidenceCeiling,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Keep the wearable surface lightweight, local, and interruptive."
            )
        ],
        highRiskIdentityOverlay: BASIdentityProfileOverlay = BASIdentityProfileOverlay(
            posture: .protective,
            confidenceCeiling: BASIdentityProfile
                .highRiskOverlayConfidenceCeiling,
            canAdvise: true,
            canExecuteActions: false,
            canEscalateToCloud: false,
            relationshipBoundary: "Slow execution down and preserve reversibility before offering stronger interpretation."
        ),
        highRiskInitiativeByRoleID: [String: BASIdentityInitiative] = [
            BASIdentityRole.reflectiveWitness.identifier: .guided
        ],
        boundary: BASBoundaryEvaluationBehavior = BASBoundaryEvaluationBehavior(),
        sessionBias: BASSessionBiasBehavior = BASSessionBiasBehavior(),
        brainCompilation: BASBrainCompilationBehavior = BASBrainCompilationBehavior(),
        memoryTrust: BASMemoryTrustBehavior = .generic
    ) {
        self.surfaceIdentityOverlaysBySurfaceID = surfaceIdentityOverlaysBySurfaceID
        self.highRiskIdentityOverlay = highRiskIdentityOverlay
        self.highRiskInitiativeByRoleID = highRiskInitiativeByRoleID
        self.boundary = boundary
        self.sessionBias = sessionBias
        self.brainCompilation = brainCompilation
        self.memoryTrust = memoryTrust
    }

    public static let generic = BASCognitionBehavior()
}

public struct BASSessionBiasBehavior: Codable, Equatable, Sendable {
    public var defaultBiasesByModeID: [String: [String]]
    public var briefLanguageSignals: [String]
    public var nightBias: String
    public var nightLowLoadBias: String
    public var lowCognitiveLoadSignals: [String]
    public var interruptiveActionSignals: [String]
    public var interruptiveActionBias: String
    public var boundaryNamingSignals: [String]
    public var boundaryNamingBias: String
    public var tradeoffClaritySignals: [String]
    public var tradeoffClarityBias: String

    public init(
        defaultBiasesByModeID: [String: [String]] = [
            BASDecisionMode.primaryID: ["Preserve state stability before expanding scope."],
            BASDecisionMode.comparativeID: ["Keep competing factors visible without collapsing them."],
            BASDecisionMode.reflectiveID: ["Describe the underlying signal before steering it."]
        ],
        briefLanguageSignals: [String] = ["short", "direct", "concise"],
        nightBias: String = "Lower-fidelity conditions call for more pacing.",
        nightLowLoadBias: String = "Prefer a lighter cognitive load when signal quality drops.",
        lowCognitiveLoadSignals: [String] = ["lighter guidance", "lighter", "shorter guidance", "low load", "fatigued", "overloaded"],
        interruptiveActionSignals: [String] = ["hold", "pause", "interrupt", "step away", "slow down"],
        interruptiveActionBias: String = "Prefer a reversible next step before adding more complexity.",
        boundaryNamingSignals: [String] = ["boundary", "pattern", "relationship", "limit", "edge"],
        boundaryNamingBias: String = "State the active limit before reframing.",
        tradeoffClaritySignals: [String] = ["trade-off", "tradeoff", "constraint", "benefit", "cost"],
        tradeoffClarityBias: String = "Keep the active trade-off visible before polishing language."
    ) {
        self.defaultBiasesByModeID = defaultBiasesByModeID
        self.briefLanguageSignals = briefLanguageSignals
        self.nightBias = nightBias
        self.nightLowLoadBias = nightLowLoadBias
        self.lowCognitiveLoadSignals = lowCognitiveLoadSignals
        self.interruptiveActionSignals = interruptiveActionSignals
        self.interruptiveActionBias = interruptiveActionBias
        self.boundaryNamingSignals = boundaryNamingSignals
        self.boundaryNamingBias = boundaryNamingBias
        self.tradeoffClaritySignals = tradeoffClaritySignals
        self.tradeoffClarityBias = tradeoffClarityBias
    }

    public func defaultBiases(for mode: BASDecisionMode) -> [String] {
        if let configured = defaultBiasesByModeID[mode.identifier], !configured.isEmpty {
            return configured
        }
        if let configured = defaultBiasesByModeID[mode.rawValue], !configured.isEmpty {
            return configured
        }

        switch mode {
        case .primary:
            return ["Keep the immediate state bounded before expanding."]
        case .comparative:
            return ["Keep the active considerations visible without forcing resolution."]
        case .reflective:
            return ["Describe the underlying pattern before steering it."]
        }
    }
}

public enum BASCalibrationStatus: String, CaseIterable, Codable, Sendable {
    case stable
    case watch
    case drifting
}

public enum BASCalibrationAlert: String, CaseIterable, Codable, Sendable {
    case highPendingInfluence = "high_pending_influence"
    case lowTrustLoad = "low_trust_load"
    case aggressiveInitiative = "aggressive_initiative"
    case underConstrainedHighRisk = "under_constrained_high_risk"
    case templateCoverageGap = "template_coverage_gap"
}

public struct BASCalibrationState: Codable, Equatable, Sendable {
    public let status: BASCalibrationStatus
    public let alerts: [BASCalibrationAlert]
    public let suggestedAdjustments: [String]
    public let driftScore: Double
    public let generatedAt: Date

    public init(
        status: BASCalibrationStatus,
        alerts: [BASCalibrationAlert],
        suggestedAdjustments: [String],
        driftScore: Double,
        generatedAt: Date
    ) {
        self.status = status
        self.alerts = alerts
        self.suggestedAdjustments = suggestedAdjustments
        self.driftScore = driftScore
        self.generatedAt = generatedAt
    }

    public static func stable(at date: Date = .now) -> BASCalibrationState {
        BASCalibrationState(
            status: .stable,
            alerts: [],
            suggestedAdjustments: [],
            driftScore: 0,
            generatedAt: date
        )
    }
}


// chapter 二百八十一 / M768 — BASEvolutionApprovalState +
// BASEvolutionFoldedLungSummary cluster extracted to
// `MemoryEvolutionFoldedLungCore.swift`. Phase Alpha 7th cut.
// 0 behavior change.


// chapter 二百八十二 / M769 — BASEvolutionLineageSummary +
// BASEvolutionCheckpointSummary + BASEvolutionState +
// BASMemoryGovernanceState cluster extracted to
// `MemoryEvolutionLineageCore.swift`. Phase Alpha 8th cut.
// 0 behavior change.


// chapter 二百八十三 / M770 — Atom records + governance +
// bootstrap cluster (BASEventRecord / BASMemoryCandidate /
// BASGovernedMemory / BASRetrievedEvidence / BASDecisionBrainState /
// BASCurrentBrainState / BASInterventionTemplate / BASFailurePattern /
// BASMemoryTierFilter / BASMemoryGovernance + extensions /
// BASCurrentBrainBootstrap) extracted to
// `MemoryAtomBootstrapCore.swift`. Phase Alpha 9th cut.
// 0 behavior change.

