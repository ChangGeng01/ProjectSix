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
        switch modeName {
        case "quick":
            BASReactionWeights(
                briefLanguage: 0.62,
                warmDirectTone: 0.58,
                lowCognitiveLoad: 0.54,
                interruptiveActionBias: 0.72,
                boundaryNamingBias: 0.34,
                tradeoffClarityBias: 0.38
            )
        case "balance":
            BASReactionWeights(
                briefLanguage: 0.48,
                warmDirectTone: 0.56,
                lowCognitiveLoad: 0.40,
                interruptiveActionBias: 0.36,
                boundaryNamingBias: 0.44,
                tradeoffClarityBias: 0.76
            )
        case "mirror":
            BASReactionWeights(
                briefLanguage: 0.44,
                warmDirectTone: 0.62,
                lowCognitiveLoad: 0.46,
                interruptiveActionBias: 0.28,
                boundaryNamingBias: 0.78,
                tradeoffClarityBias: 0.42
            )
        default:
            BASReactionWeights(
                briefLanguage: 0.50,
                warmDirectTone: 0.56,
                lowCognitiveLoad: 0.48,
                interruptiveActionBias: 0.40,
                boundaryNamingBias: 0.46,
                tradeoffClarityBias: 0.50
            )
        }
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

public enum BASIdentityRole: String, CaseIterable, Codable, Sendable {
    case pauseCompanion = "pause_companion"
    case tradeoffGuide = "tradeoff_guide"
    case mirrorWitness = "mirror_witness"
    case predictiveSentinel = "predictive_sentinel"

    public var title: String {
        switch self {
        case .pauseCompanion:
            "Pause Companion"
        case .tradeoffGuide:
            "Trade-off Guide"
        case .mirrorWitness:
            "Mirror Witness"
        case .predictiveSentinel:
            "Predictive Sentinel"
        }
    }
}

public enum BASIdentityPosture: String, CaseIterable, Codable, Sendable {
    case reflective
    case coaching
    case protective
}

public enum BASIdentityInitiative: String, CaseIterable, Codable, Sendable {
    case passive
    case guided
    case assertive
}

public struct BASIdentityProfile: Codable, Equatable, Sendable {
    public let role: BASIdentityRole
    public let posture: BASIdentityPosture
    public let initiative: BASIdentityInitiative
    public let confidenceCeiling: Double
    public let canAdvise: Bool
    public let canExecuteActions: Bool
    public let canEscalateToCloud: Bool
    public let relationshipBoundary: String

    public init(
        role: BASIdentityRole,
        posture: BASIdentityPosture,
        initiative: BASIdentityInitiative,
        confidenceCeiling: Double,
        canAdvise: Bool,
        canExecuteActions: Bool,
        canEscalateToCloud: Bool,
        relationshipBoundary: String
    ) {
        self.role = role
        self.posture = posture
        self.initiative = initiative
        self.confidenceCeiling = confidenceCeiling
        self.canAdvise = canAdvise
        self.canExecuteActions = canExecuteActions
        self.canEscalateToCloud = canEscalateToCloud
        self.relationshipBoundary = relationshipBoundary
    }

    public static func `default`(modeName: String) -> BASIdentityProfile {
        switch modeName {
        case "quick":
            BASIdentityProfile(
                role: .pauseCompanion,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.72,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Interrupt speed, do not impersonate certainty."
            )
        case "balance":
            BASIdentityProfile(
                role: .tradeoffGuide,
                posture: .reflective,
                initiative: .guided,
                confidenceCeiling: 0.76,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Clarify trade-offs without taking control of the decision."
            )
        case "mirror":
            BASIdentityProfile(
                role: .mirrorWitness,
                posture: .reflective,
                initiative: .passive,
                confidenceCeiling: 0.68,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Reflect the pattern without becoming the protagonist."
            )
        default:
            BASIdentityProfile(
                role: .pauseCompanion,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.70,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Stay bounded, local, and supportive."
            )
        }
    }
}

public enum BASBoundaryPolicyMode: String, CaseIterable, Codable, Sendable {
    case localOnlyReflective = "local_only_reflective"
    case localOnlyAdvisory = "local_only_advisory"
    case localOnlyProtective = "local_only_protective"

    public var isPureLocal: Bool { true }
}

public enum BASBoundaryConstraint: String, CaseIterable, Codable, Sendable {
    case noCloudEscalation = "no_cloud_escalation"
    case noAutonomousExternalAction = "no_autonomous_external_action"
    case confirmIrreversibleAction = "confirm_irreversible_action"
    case lockSensitiveMemory = "lock_sensitive_memory"
    case watchSurfaceLightweight = "watch_surface_lightweight"
    case notificationRequiresEvidence = "notification_requires_evidence"
    case roleLimitedAdvice = "role_limited_advice"

    public var title: String {
        rawValue.replacingOccurrences(of: "_", with: " ")
    }
}

public struct BASBoundaryPolicyState: Codable, Equatable, Sendable {
    public let mode: BASBoundaryPolicyMode
    public let riskLevel: BASRiskLevel
    public let allowedActionClasses: [String]
    public let blockedActionClasses: [String]
    public let requiredConfirmations: [String]
    public let activeConstraints: [BASBoundaryConstraint]
    public let auditHeadline: String

    public init(
        mode: BASBoundaryPolicyMode,
        riskLevel: BASRiskLevel,
        allowedActionClasses: [String],
        blockedActionClasses: [String],
        requiredConfirmations: [String],
        activeConstraints: [BASBoundaryConstraint],
        auditHeadline: String
    ) {
        self.mode = mode
        self.riskLevel = riskLevel
        self.allowedActionClasses = allowedActionClasses
        self.blockedActionClasses = blockedActionClasses
        self.requiredConfirmations = requiredConfirmations
        self.activeConstraints = activeConstraints
        self.auditHeadline = auditHeadline
    }

    public static func `default`(riskLevel: BASRiskLevel) -> BASBoundaryPolicyState {
        BASBoundaryPolicyState(
            mode: riskLevel == .high ? .localOnlyProtective : .localOnlyAdvisory,
            riskLevel: riskLevel,
            allowedActionClasses: ["render_local_guidance", "load_governed_memory"],
            blockedActionClasses: ["cloud_escalation", "autonomous_external_action"],
            requiredConfirmations: riskLevel == .high ? ["irreversible_decision"] : [],
            activeConstraints: [.noCloudEscalation, .noAutonomousExternalAction, .lockSensitiveMemory],
            auditHeadline: "Stay local, stay bounded, and avoid irreversible momentum."
        )
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

public enum BASEvolutionApprovalState: String, CaseIterable, Codable, Sendable {
    case automatic
    case reviewSuggested
}

public struct BASEvolutionCheckpointSummary: Codable, Equatable, Sendable {
    public let id: String
    public let previousCheckpointID: String?
    public let createdAt: Date
    public let diffSummary: [String]
    public let rollbackReady: Bool
    public let approvalState: BASEvolutionApprovalState

    public init(
        id: String,
        previousCheckpointID: String?,
        createdAt: Date,
        diffSummary: [String],
        rollbackReady: Bool,
        approvalState: BASEvolutionApprovalState
    ) {
        self.id = id
        self.previousCheckpointID = previousCheckpointID
        self.createdAt = createdAt
        self.diffSummary = diffSummary
        self.rollbackReady = rollbackReady
        self.approvalState = approvalState
    }
}

public struct BASEvolutionState: Codable, Equatable, Sendable {
    public let latestCheckpoint: BASEvolutionCheckpointSummary?
    public let checkpointCount: Int
    public let rollbackReady: Bool
    public let pendingReviewCount: Int
    public let recentDiffSummary: [String]

    public init(
        latestCheckpoint: BASEvolutionCheckpointSummary?,
        checkpointCount: Int,
        rollbackReady: Bool,
        pendingReviewCount: Int,
        recentDiffSummary: [String]
    ) {
        self.latestCheckpoint = latestCheckpoint
        self.checkpointCount = checkpointCount
        self.rollbackReady = rollbackReady
        self.pendingReviewCount = pendingReviewCount
        self.recentDiffSummary = recentDiffSummary
    }

    public static let empty = BASEvolutionState(
        latestCheckpoint: nil,
        checkpointCount: 0,
        rollbackReady: false,
        pendingReviewCount: 0,
        recentDiffSummary: []
    )
}

public struct BASMemoryGovernanceState: Codable, Equatable, Sendable {
    public var totalRecordCount: Int
    public var totalCandidateCount: Int
    public var pendingCandidateCount: Int
    public var promotedCandidateCount: Int
    public var loadedPromotedMemoryCount: Int
    public var loadedPendingMemoryCount: Int
    public var deferredCandidateCount: Int = 0
    public var admittedCandidateCount: Int = 0
    public var screenedOutMemoryCount: Int = 0
    public var screenedOutPendingMemoryCount: Int = 0
    public var loadedReasonCounts: [BASMemoryEligibilityReason: Int] = [:]
    public var screenedOutReasonCounts: [BASMemoryEligibilityReason: Int] = [:]

    public init(
        totalRecordCount: Int,
        totalCandidateCount: Int,
        pendingCandidateCount: Int,
        promotedCandidateCount: Int,
        loadedPromotedMemoryCount: Int,
        loadedPendingMemoryCount: Int,
        deferredCandidateCount: Int = 0,
        admittedCandidateCount: Int = 0,
        screenedOutMemoryCount: Int = 0,
        screenedOutPendingMemoryCount: Int = 0,
        loadedReasonCounts: [BASMemoryEligibilityReason: Int] = [:],
        screenedOutReasonCounts: [BASMemoryEligibilityReason: Int] = [:]
    ) {
        self.totalRecordCount = totalRecordCount
        self.totalCandidateCount = totalCandidateCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedCandidateCount = promotedCandidateCount
        self.loadedPromotedMemoryCount = loadedPromotedMemoryCount
        self.loadedPendingMemoryCount = loadedPendingMemoryCount
        self.deferredCandidateCount = deferredCandidateCount
        self.admittedCandidateCount = admittedCandidateCount
        self.screenedOutMemoryCount = screenedOutMemoryCount
        self.screenedOutPendingMemoryCount = screenedOutPendingMemoryCount
        self.loadedReasonCounts = loadedReasonCounts
        self.screenedOutReasonCounts = screenedOutReasonCounts
    }

    public static let empty = BASMemoryGovernanceState(
        totalRecordCount: 0,
        totalCandidateCount: 0,
        pendingCandidateCount: 0,
        promotedCandidateCount: 0,
        loadedPromotedMemoryCount: 0,
        loadedPendingMemoryCount: 0
    )
}

public struct BASEventRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: BASMemoryKind
    public var content: String
    public var timestamp: Date
    public var tags: [String]
    public var scenarioID: String?
    public var actionID: String?
    public var reflectionOutcomeID: String?
    public var entrySourceID: String?

    public init(
        id: UUID = UUID(),
        kind: BASMemoryKind,
        content: String,
        timestamp: Date = .now,
        tags: [String] = [],
        scenarioID: String? = nil,
        actionID: String? = nil,
        reflectionOutcomeID: String? = nil,
        entrySourceID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.timestamp = timestamp
        self.tags = tags
        self.scenarioID = scenarioID
        self.actionID = actionID
        self.reflectionOutcomeID = reflectionOutcomeID
        self.entrySourceID = entrySourceID
    }
}

public struct BASMemoryCandidate: Codable, Sendable, Equatable {
    public var id: UUID
    public var event: BASEventRecord
    public var scope: BASMemoryScope
    public var sensitivity: BASMemorySensitivity
    public var confidence: Double
    public var sourceType: String
    public var preferredTier: BASMemoryTier

    public init(
        id: UUID = UUID(),
        event: BASEventRecord,
        scope: BASMemoryScope,
        sensitivity: BASMemorySensitivity,
        confidence: Double,
        sourceType: String,
        preferredTier: BASMemoryTier
    ) {
        self.id = id
        self.event = event
        self.scope = scope
        self.sensitivity = sensitivity
        self.confidence = confidence
        self.sourceType = sourceType
        self.preferredTier = preferredTier
    }
}

public struct BASGovernedMemory: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: BASMemoryKind
    public var content: String
    public var scope: BASMemoryScope
    public var sensitivity: BASMemorySensitivity
    public var tier: BASMemoryTier
    public var confidence: Double
    public var sourceType: String
    public var lastConfirmedAt: Date?
    public var decayScore: Double
    public var governanceStatus: BASMemoryGovernanceStatus
    public var provenanceSummary: String

    public init(
        id: UUID = UUID(),
        kind: BASMemoryKind,
        content: String,
        scope: BASMemoryScope,
        sensitivity: BASMemorySensitivity,
        tier: BASMemoryTier,
        confidence: Double,
        sourceType: String,
        lastConfirmedAt: Date? = nil,
        decayScore: Double = 0.0,
        governanceStatus: BASMemoryGovernanceStatus,
        provenanceSummary: String
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.scope = scope
        self.sensitivity = sensitivity
        self.tier = tier
        self.confidence = confidence
        self.sourceType = sourceType
        self.lastConfirmedAt = lastConfirmedAt
        self.decayScore = decayScore
        self.governanceStatus = governanceStatus
        self.provenanceSummary = provenanceSummary
    }
}

public struct BASRetrievedEvidence: Codable, Sendable, Equatable {
    public var memoryID: UUID
    public var summary: String
    public var sourceLabel: String
    public var confidence: Double
    public var tier: BASMemoryTier
    public var scope: BASMemoryScope

    public init(memoryID: UUID, summary: String, sourceLabel: String, confidence: Double, tier: BASMemoryTier, scope: BASMemoryScope) {
        self.memoryID = memoryID
        self.summary = summary
        self.sourceLabel = sourceLabel
        self.confidence = confidence
        self.tier = tier
        self.scope = scope
    }
}

public struct BASDecisionBrainState: Codable, Equatable, Sendable {
    public var memorySlices: [BASGovernedMemorySlice]
    public var sessionBiases: [String]
    public var retrievalTags: [String]
    public var reactionWeights: BASReactionWeights
    public var identityProfile: BASIdentityProfile
    public var boundaryPolicy: BASBoundaryPolicyState
    public var calibrationState: BASCalibrationState
    public var evolutionState: BASEvolutionState
    public var activeInterventionTemplateIDs: [String]
    public var failureGuardIDs: [String]
    public var memoryGovernance: BASMemoryGovernanceState = .empty
    public var loadedAt: Date

    public init(
        memorySlices: [BASGovernedMemorySlice],
        sessionBiases: [String],
        retrievalTags: [String],
        reactionWeights: BASReactionWeights,
        identityProfile: BASIdentityProfile,
        boundaryPolicy: BASBoundaryPolicyState,
        calibrationState: BASCalibrationState = .stable(),
        evolutionState: BASEvolutionState = .empty,
        activeInterventionTemplateIDs: [String] = [],
        failureGuardIDs: [String] = [],
        memoryGovernance: BASMemoryGovernanceState = .empty,
        loadedAt: Date
    ) {
        self.memorySlices = memorySlices
        self.sessionBiases = sessionBiases
        self.retrievalTags = retrievalTags
        self.reactionWeights = reactionWeights
        self.identityProfile = identityProfile
        self.boundaryPolicy = boundaryPolicy
        self.calibrationState = calibrationState
        self.evolutionState = evolutionState
        self.activeInterventionTemplateIDs = activeInterventionTemplateIDs
        self.failureGuardIDs = failureGuardIDs
        self.memoryGovernance = memoryGovernance
        self.loadedAt = loadedAt
    }

    public init(
        profileCore: [String],
        activeGoals: [String],
        relevantMemories: [String],
        sessionBiases: [String],
        retrievalTags: [String],
        reactionWeights: BASReactionWeights,
        identityProfile: BASIdentityProfile? = nil,
        boundaryPolicy: BASBoundaryPolicyState? = nil,
        calibrationState: BASCalibrationState = .stable(),
        evolutionState: BASEvolutionState = .empty,
        activeInterventionTemplateIDs: [String] = [],
        failureGuardIDs: [String] = [],
        memoryGovernance: BASMemoryGovernanceState = .empty,
        loadedAt: Date = .now
    ) {
        let resolvedIdentity = identityProfile ?? BASIdentityProfile.default(modeName: "quick")
        let resolvedBoundary = boundaryPolicy ?? BASBoundaryPolicyState.default(riskLevel: .low)
        self.init(
            memorySlices: Self.legacyMemorySlices(
                profileCore: profileCore,
                activeGoals: activeGoals,
                relevantMemories: relevantMemories
            ),
            sessionBiases: sessionBiases,
            retrievalTags: retrievalTags,
            reactionWeights: reactionWeights,
            identityProfile: resolvedIdentity,
            boundaryPolicy: resolvedBoundary,
            calibrationState: calibrationState,
            evolutionState: evolutionState,
            activeInterventionTemplateIDs: activeInterventionTemplateIDs,
            failureGuardIDs: failureGuardIDs,
            memoryGovernance: memoryGovernance,
            loadedAt: loadedAt
        )
    }

    public var profileCoreSlices: [BASGovernedMemorySlice] {
        memorySlices.filter { $0.role == .profile }
    }

    public var activeGoalSlices: [BASGovernedMemorySlice] {
        memorySlices.filter { $0.role == .goal }
    }

    public var relevantMemorySlices: [BASGovernedMemorySlice] {
        memorySlices.filter { $0.role == .relevant }
    }

    public var profileCore: [String] {
        profileCoreSlices.map(\.headline)
    }

    public var activeGoals: [String] {
        activeGoalSlices.map(\.headline)
    }

    public var relevantMemories: [String] {
        relevantMemorySlices.map(\.headline)
    }

    public var isEmpty: Bool {
        memorySlices.isEmpty &&
            sessionBiases.isEmpty &&
            retrievalTags.isEmpty &&
            activeInterventionTemplateIDs.isEmpty &&
            failureGuardIDs.isEmpty &&
            calibrationState.alerts.isEmpty &&
            evolutionState.checkpointCount == 0
    }

    public var verificationSnapshot: BASBrainStateSnapshot {
        // Snapshot risk should reflect the current frontstage brain, not a historical
        // governance seed that can dilute present low-trust density.
        let loadedMemoryCount = memorySlices.count
        let pendingMemoryCount = max(
            memorySlices.filter(\.isPending).count,
            memoryGovernance.loadedPendingMemoryCount
        )
        let lowTrustMemoryCount = memorySlices.filter { $0.sourceTrustTier == .low }.count

        let pendingMemoryLoadRate = loadedMemoryCount > 0
            ? min(1, Double(pendingMemoryCount) / Double(loadedMemoryCount))
            : 0
        let lowTrustMemoryLoadRate = loadedMemoryCount > 0
            ? min(1, Double(lowTrustMemoryCount) / Double(loadedMemoryCount))
            : 0

        var riskFlags: [BASBrainStateRiskFlag] = []
        if pendingMemoryLoadRate >= 0.34 {
            riskFlags.append(.highPendingInfluence)
        }
        if lowTrustMemoryLoadRate >= 0.25 {
            riskFlags.append(.lowTrustLoad)
        }
        if (memoryGovernance.screenedOutReasonCounts[.provenanceContamination] ?? 0) > 0 {
            riskFlags.append(.contaminationGuardTriggered)
        }
        if memoryGovernance.screenedOutMemoryCount >= max(4, loadedMemoryCount) {
            riskFlags.append(.retrievalInstability)
        }
        if (memoryGovernance.screenedOutReasonCounts[.tagFloodNoOverlap] ?? 0) > 0 {
            riskFlags.append(.tagFloodBlocked)
        }

        let boundaryConstraintMaterial = boundaryPolicy.activeConstraints
            .map(\.rawValue)
            .sorted()
            .joined(separator: "|")
        let calibrationAlertMaterial = calibrationState.alerts
            .map(\.rawValue)
            .sorted()
            .joined(separator: "|")
        let memorySliceMaterial = memorySlices
            .sorted { $0.id < $1.id }
            .map { slice in
                [
                    slice.id,
                    slice.role.rawValue,
                    slice.headline,
                    slice.source,
                    String(format: "%.3f", slice.sourceTrustScore),
                    slice.sourceTrustTier.rawValue,
                    slice.governanceStatus.rawValue,
                    slice.isPending ? "pending" : "stable"
                ]
                .joined(separator: "::")
            }
            .joined(separator: "||")
        let riskFlagMaterial = riskFlags.map(\.rawValue).sorted().joined(separator: "|")

        let materialParts = [
            profileCore.sorted().joined(separator: "|"),
            activeGoals.sorted().joined(separator: "|"),
            relevantMemories.sorted().joined(separator: "|"),
            sessionBiases.sorted().joined(separator: "|"),
            retrievalTags.sorted().joined(separator: "|"),
            reactionWeights.dominantKey.rawValue,
            identityProfile.role.rawValue,
            identityProfile.posture.rawValue,
            identityProfile.initiative.rawValue,
            boundaryPolicy.mode.rawValue,
            boundaryConstraintMaterial,
            calibrationState.status.rawValue,
            calibrationAlertMaterial,
            memorySliceMaterial,
            riskFlagMaterial
        ]
        let material = materialParts.joined(separator: "###")

        let fingerprint = SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(20)

        return BASBrainStateSnapshot(
            fingerprint: String(fingerprint),
            dominantReactionWeight: reactionWeights.dominantKey,
            loadedMemoryCount: loadedMemoryCount,
            pendingMemoryLoadRate: pendingMemoryLoadRate,
            lowTrustMemoryLoadRate: lowTrustMemoryLoadRate,
            riskFlags: riskFlags
        )
    }

    private static func legacyMemorySlices(
        profileCore: [String],
        activeGoals: [String],
        relevantMemories: [String]
    ) -> [BASGovernedMemorySlice] {
        let defaultEligibility = BASMemoryEligibilityDecision.allowed(.defaultAllowed)
        let defaultTags: [String] = []

        let profileSlices = profileCore.enumerated().map { index, headline in
            BASGovernedMemorySlice(
                id: "legacy.profile.\(index)",
                role: .profile,
                type: "preference",
                headline: headline,
                source: "pattern",
                confidence: 1,
                priority: 1,
                lifecycleState: "active",
                governanceStatus: .admitted,
                eligibility: defaultEligibility,
                sourceTrustScore: 1,
                sourceTrustTier: .high,
                retrievalTags: defaultTags,
                isPending: false,
                provenanceSummary: "Legacy profile core projection."
            )
        }

        let goalSlices = activeGoals.enumerated().map { index, headline in
            BASGovernedMemorySlice(
                id: "legacy.goal.\(index)",
                role: .goal,
                type: "goal",
                headline: headline,
                source: "history",
                confidence: 1,
                priority: 1,
                lifecycleState: "active",
                governanceStatus: .admitted,
                eligibility: defaultEligibility,
                sourceTrustScore: 1,
                sourceTrustTier: .high,
                retrievalTags: defaultTags,
                isPending: false,
                provenanceSummary: "Legacy active-goal projection."
            )
        }

        let relevantSlices = relevantMemories.enumerated().map { index, headline in
            BASGovernedMemorySlice(
                id: "legacy.relevant.\(index)",
                role: .relevant,
                type: "semantic",
                headline: headline,
                source: "history",
                confidence: 1,
                priority: 1,
                lifecycleState: "active",
                governanceStatus: .admitted,
                eligibility: defaultEligibility,
                sourceTrustScore: 1,
                sourceTrustTier: .high,
                retrievalTags: defaultTags,
                isPending: false,
                provenanceSummary: "Legacy relevant-memory projection."
            )
        }

        return profileSlices + goalSlices + relevantSlices
    }
}

public struct BASCurrentBrainState: Codable, Sendable, Equatable {
    public var mode: String
    public var dominantGoals: [String]
    public var activeConstraints: [String]
    public var reactionWeights: BASReactionWeights
    public var activeTemplateIDs: [UUID]
    public var recentFailurePatternIDs: [UUID]
    public var retrievalTags: [String]
    public var verificationSnapshot: String

    public init(
        mode: String,
        dominantGoals: [String],
        activeConstraints: [String],
        reactionWeights: BASReactionWeights,
        activeTemplateIDs: [UUID],
        recentFailurePatternIDs: [UUID],
        retrievalTags: [String],
        verificationSnapshot: String
    ) {
        self.mode = mode
        self.dominantGoals = dominantGoals
        self.activeConstraints = activeConstraints
        self.reactionWeights = reactionWeights
        self.activeTemplateIDs = activeTemplateIDs
        self.recentFailurePatternIDs = recentFailurePatternIDs
        self.retrievalTags = retrievalTags
        self.verificationSnapshot = verificationSnapshot
    }
}

public struct BASInterventionTemplate: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var triggerTags: [String]
    public var recommendedTone: String
    public var steps: [String]

    public init(id: UUID = UUID(), name: String, triggerTags: [String], recommendedTone: String, steps: [String]) {
        self.id = id
        self.name = name
        self.triggerTags = triggerTags
        self.recommendedTone = recommendedTone
        self.steps = steps
    }
}

public struct BASFailurePattern: Codable, Sendable, Equatable {
    public var id: UUID
    public var description: String
    public var suppressedTone: String
    public var suppressedCadence: String
    public var confidence: Double
    public var lastSeenAt: Date?

    public init(
        id: UUID = UUID(),
        description: String,
        suppressedTone: String,
        suppressedCadence: String,
        confidence: Double,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.description = description
        self.suppressedTone = suppressedTone
        self.suppressedCadence = suppressedCadence
        self.confidence = confidence
        self.lastSeenAt = lastSeenAt
    }
}

public struct BASMemoryTierFilter: Sendable {
    public static func isFrontstageEligible(_ tier: BASMemoryTier) -> Bool {
        tier != .cold
    }

    public static func prioritizedTiers(for scope: BASMemoryScope, sensitivity: BASMemorySensitivity) -> [BASMemoryTier] {
        switch (scope, sensitivity) {
        case (.session, .high), (.task, .high):
            return [.hot, .warm]
        case (.user, .high):
            return [.hot, .warm, .cold]
        case (.device, _), (_, .low):
            return [.hot, .warm, .cold]
        default:
            return [.hot, .warm]
        }
    }

    public static func frontstageEligibleMemories(_ memories: [BASGovernedMemory]) -> [BASGovernedMemory] {
        memories.filter { isFrontstageEligible($0.tier) && $0.governanceStatus == .governed }
    }

    public static func filter(
        _ memories: [BASGovernedMemory],
        allowedTiers: [BASMemoryTier],
        scope: BASMemoryScope? = nil,
        sensitivity: BASMemorySensitivity? = nil
    ) -> [BASGovernedMemory] {
        memories.filter { memory in
            guard allowedTiers.contains(memory.tier) else { return false }
            if let scope, memory.scope != scope { return false }
            if let sensitivity, memory.sensitivity != sensitivity { return false }
            return memory.governanceStatus == .governed
        }
        .sorted {
            if $0.tier != $1.tier {
                return $0.tier.priority > $1.tier.priority
            }
            if $0.confidence != $1.confidence {
                return $0.confidence > $1.confidence
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

public struct BASMemoryGovernance: Sendable {
    public static func shouldAdmit(candidate: BASMemoryCandidate, minimumConfidence: Double = 0.6) -> Bool {
        candidate.confidence >= minimumConfidence
    }

    public static func promote(
        candidate: BASMemoryCandidate,
        lastConfirmedAt: Date? = nil,
        decayScore: Double = 0.0,
        provenanceSummary: String? = nil,
        governanceStatus: BASMemoryGovernanceStatus = .governed
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            kind: candidate.event.kind,
            content: candidate.event.content,
            scope: candidate.scope,
            sensitivity: candidate.sensitivity,
            tier: candidate.preferredTier,
            confidence: candidate.confidence,
            sourceType: candidate.sourceType,
            lastConfirmedAt: lastConfirmedAt,
            decayScore: decayScore,
            governanceStatus: governanceStatus,
            provenanceSummary: provenanceSummary ?? "promoted from candidate:\(candidate.sourceType)"
        )
    }

    public static func resolveConflict(primary: BASGovernedMemory, challenger: BASGovernedMemory) -> BASGovernedMemory {
        guard primary.kind == challenger.kind, primary.scope == challenger.scope else {
            return primary
        }

        if challenger.confidence > primary.confidence {
            return challenger
        }

        if challenger.confidence == primary.confidence, challenger.decayScore < primary.decayScore {
            return challenger
        }

        return primary
    }
}

public struct BASCurrentBrainBootstrap: Sendable {
    public static func bootstrap(
        from memories: [BASGovernedMemory],
        goalHints: [String] = [],
        constraintHints: [String] = [],
        mode: String = "balanced",
        verificationSnapshot: String = "bootstrap"
    ) -> BASCurrentBrainState {
        let frontstage = BASMemoryTierFilter.frontstageEligibleMemories(memories)
            .sorted {
                if $0.tier != $1.tier {
                    return $0.tier.priority > $1.tier.priority
                }
                if $0.confidence != $1.confidence {
                    return $0.confidence > $1.confidence
                }
                return $0.id.uuidString < $1.id.uuidString
            }

        let profileGoals = frontstage
            .filter { $0.kind == .profile }
            .map(\.content)
            .filter { !$0.isEmpty }

        let dominantGoals = Self.uniqueOrdered(goalHints + profileGoals)

        let highSensitivityConstraints = frontstage
            .filter { $0.sensitivity == .high }
            .map { "sensitive:\($0.scope.rawValue)" }

        let activeConstraints = Self.uniqueOrdered(constraintHints + highSensitivityConstraints)

        let activeTemplateIDs = frontstage
            .filter { $0.kind == .template }
            .map(\.id)

        let recentFailurePatternIDs = frontstage
            .filter { $0.kind == .failurePattern }
            .map(\.id)

        let retrievalTags = Self.uniqueOrdered(frontstage.flatMap { memory in
            [
                "tier:\(memory.tier.rawValue)",
                "scope:\(memory.scope.rawValue)",
                "kind:\(memory.kind.rawValue)",
                "source:\(memory.sourceType)"
            ]
        })

        return BASCurrentBrainState(
            mode: mode,
            dominantGoals: dominantGoals,
            activeConstraints: activeConstraints,
            reactionWeights: BASReactionWeights(warmth: 0.5, directness: 0.5, brevity: 0.5, actionBias: 0.5),
            activeTemplateIDs: activeTemplateIDs,
            recentFailurePatternIDs: recentFailurePatternIDs,
            retrievalTags: retrievalTags,
            verificationSnapshot: verificationSnapshot
        )
    }

    private static func uniqueOrdered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

extension BASMemoryTier {
    var priority: Int {
        switch self {
        case .hot: return 3
        case .warm: return 2
        case .cold: return 1
        }
    }
}
