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
        _ = modeName
        return BASReactionWeights(
            briefLanguage: 0.50,
            warmDirectTone: 0.54,
            lowCognitiveLoad: 0.50,
            interruptiveActionBias: 0.44,
            boundaryNamingBias: 0.46,
            tradeoffClarityBias: 0.50
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

public enum BASIdentityRole: String, CaseIterable, Codable, Sendable {
    case boundedGuide = "bounded_guide"
    case pauseCompanion = "pause_companion"
    case tradeoffGuide = "tradeoff_guide"
    case reflectiveWitness = "reflective_witness"
    case predictiveSentinel = "predictive_sentinel"

    public var identifier: String {
        switch self {
        case .boundedGuide:
            "bounded_guide"
        case .pauseCompanion:
            "stability_guide"
        case .tradeoffGuide:
            "comparative_guide"
        case .reflectiveWitness:
            "reflective_witness"
        case .predictiveSentinel:
            "risk_sentinel"
        }
    }

    public init?(identifier: String) {
        switch identifier {
        case Self.boundedGuide.identifier, Self.boundedGuide.rawValue:
            self = .boundedGuide
        case Self.pauseCompanion.identifier, Self.pauseCompanion.rawValue:
            self = .pauseCompanion
        case Self.tradeoffGuide.identifier, Self.tradeoffGuide.rawValue:
            self = .tradeoffGuide
        case Self.reflectiveWitness.identifier, Self.reflectiveWitness.rawValue:
            self = .reflectiveWitness
        case Self.predictiveSentinel.identifier, Self.predictiveSentinel.rawValue:
            self = .predictiveSentinel
        default:
            return nil
        }
    }

    public var title: String {
        switch self {
        case .boundedGuide:
            "Bounded Guide"
        case .pauseCompanion:
            "Stability Guide"
        case .tradeoffGuide:
            "Comparative Guide"
        case .reflectiveWitness:
            "Reflective Witness"
        case .predictiveSentinel:
            "Risk Sentinel"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let role = BASIdentityRole(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported identity role identifier: \(identifier)"
            )
        }
        self = role
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
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
        _ = modeName
        return BASIdentityProfile(
            role: .boundedGuide,
            posture: .reflective,
            initiative: .guided,
            confidenceCeiling: 0.70,
            canAdvise: true,
            canExecuteActions: false,
            canEscalateToCloud: false,
            relationshipBoundary: "Stay bounded, local, and explicit about uncertainty."
        )
    }
}

public struct BASIdentityProfileOverlay: Codable, Equatable, Sendable {
    public var role: BASIdentityRole?
    public var posture: BASIdentityPosture?
    public var initiative: BASIdentityInitiative?
    public var confidenceCeiling: Double?
    public var canAdvise: Bool?
    public var canExecuteActions: Bool?
    public var canEscalateToCloud: Bool?
    public var relationshipBoundary: String?

    public init(
        role: BASIdentityRole? = nil,
        posture: BASIdentityPosture? = nil,
        initiative: BASIdentityInitiative? = nil,
        confidenceCeiling: Double? = nil,
        canAdvise: Bool? = nil,
        canExecuteActions: Bool? = nil,
        canEscalateToCloud: Bool? = nil,
        relationshipBoundary: String? = nil
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

    public func applying(
        to profile: BASIdentityProfile,
        initiativeOverride: BASIdentityInitiative? = nil
    ) -> BASIdentityProfile {
        BASIdentityProfile(
            role: role ?? profile.role,
            posture: posture ?? profile.posture,
            initiative: initiativeOverride ?? initiative ?? profile.initiative,
            confidenceCeiling: confidenceCeiling ?? profile.confidenceCeiling,
            canAdvise: canAdvise ?? profile.canAdvise,
            canExecuteActions: canExecuteActions ?? profile.canExecuteActions,
            canEscalateToCloud: canEscalateToCloud ?? profile.canEscalateToCloud,
            relationshipBoundary: relationshipBoundary ?? profile.relationshipBoundary
        )
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

public struct BASBoundaryEvaluationBehavior: Codable, Equatable, Sendable {
    public var defaultAllowedActionClasses: [String]
    public var defaultBlockedActionClasses: [String]
    public var defaultConstraints: [BASBoundaryConstraint]
    public var allowedActionClassesBySurfaceID: [String: [String]]
    public var blockedActionClassesBySurfaceID: [String: [String]]
    public var constraintsBySurfaceID: [String: [BASBoundaryConstraint]]
    public var highRiskRequiredConfirmations: [String]
    public var highRiskBlockedActionClasses: [String]
    public var reflectiveModeIDs: [String]
    public var advisoryHeadline: String
    public var reflectiveHeadline: String
    public var protectiveHeadline: String

    public init(
        defaultAllowedActionClasses: [String] = ["render_local_guidance", "load_governed_memory"],
        defaultBlockedActionClasses: [String] = ["cloud_escalation", "autonomous_external_action"],
        defaultConstraints: [BASBoundaryConstraint] = [
            .noCloudEscalation,
            .noAutonomousExternalAction,
            .lockSensitiveMemory,
            .roleLimitedAdvice
        ],
        allowedActionClassesBySurfaceID: [String: [String]] = [
            BASInteractionSurface.watch.rawValue: ["lightweight_capture"]
        ],
        blockedActionClassesBySurfaceID: [String: [String]] = [
            BASInteractionSurface.watch.rawValue: ["deep_editor_surface"],
            BASInteractionSurface.notification.rawValue: ["high_frequency_nudge"]
        ],
        constraintsBySurfaceID: [String: [BASBoundaryConstraint]] = [
            BASInteractionSurface.watch.rawValue: [.watchSurfaceLightweight],
            BASInteractionSurface.notification.rawValue: [.notificationRequiresEvidence]
        ],
        highRiskRequiredConfirmations: [String] = ["irreversible_decision"],
        highRiskBlockedActionClasses: [String] = ["fast_commit_action"],
        reflectiveModeIDs: [String] = [BASDecisionMode.reflectiveID],
        advisoryHeadline: String = "Keep output local, bounded, and reversible.",
        reflectiveHeadline: String = "Keep interpretation local and avoid premature closure.",
        protectiveHeadline: String = "Keep execution local, increase confirmation, and slow irreversible change."
    ) {
        self.defaultAllowedActionClasses = defaultAllowedActionClasses
        self.defaultBlockedActionClasses = defaultBlockedActionClasses
        self.defaultConstraints = defaultConstraints
        self.allowedActionClassesBySurfaceID = allowedActionClassesBySurfaceID
        self.blockedActionClassesBySurfaceID = blockedActionClassesBySurfaceID
        self.constraintsBySurfaceID = constraintsBySurfaceID
        self.highRiskRequiredConfirmations = highRiskRequiredConfirmations
        self.highRiskBlockedActionClasses = highRiskBlockedActionClasses
        self.reflectiveModeIDs = reflectiveModeIDs
        self.advisoryHeadline = advisoryHeadline
        self.reflectiveHeadline = reflectiveHeadline
        self.protectiveHeadline = protectiveHeadline
    }
}

public struct BASBrainCompilationBehavior: Codable, Equatable, Sendable {
    public var filteredCandidateLimitByModeID: [String: Int]
    public var retrievalOffCandidateLimitByModeID: [String: Int]
    public var retrievalOffGoalLimitByModeID: [String: Int]
    public var filteredRelevantLimitByModeID: [String: Int]
    public var adaptiveRelevantLimitByModeID: [String: Int]
    public var relevantPriorityBaselinesByModeID: [String: Double]
    public var requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired: Bool
    public var requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired: Bool
    public var ignoredRetrievalTags: [String]
    public var interruptiveModeIDs: [String]
    public var boundaryNamingModeIDs: [String]
    public var tradeoffClarityModeIDs: [String]
    public var typeBoostsByModeID: [String: [String: Double]]
    public var interruptiveActionIDs: [String]
    public var proceedActionIDs: [String]
    public var positiveReflectionOutcomeIDs: [String]
    public var negativeReflectionOutcomeIDs: [String]

    public init(
        filteredCandidateLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 8,
            BASDecisionMode.comparativeID: 8,
            BASDecisionMode.reflectiveID: 8
        ],
        retrievalOffCandidateLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 4,
            BASDecisionMode.comparativeID: 5,
            BASDecisionMode.reflectiveID: 5
        ],
        retrievalOffGoalLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 1,
            BASDecisionMode.comparativeID: 2,
            BASDecisionMode.reflectiveID: 2
        ],
        filteredRelevantLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 3,
            BASDecisionMode.comparativeID: 3,
            BASDecisionMode.reflectiveID: 3
        ],
        adaptiveRelevantLimitByModeID: [String: Int] = [
            BASDecisionMode.primaryID: 3,
            BASDecisionMode.comparativeID: 3,
            BASDecisionMode.reflectiveID: 4
        ],
        relevantPriorityBaselinesByModeID: [String: Double] = [
            BASDecisionMode.primaryID: 0.64,
            BASDecisionMode.comparativeID: 0.64,
            BASDecisionMode.reflectiveID: 0.58
        ],
        requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired: Bool = false,
        requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired: Bool = false,
        ignoredRetrievalTags: [String] = [
            BASDecisionMode.primaryID,
            BASDecisionMode.comparativeID,
            BASDecisionMode.reflectiveID,
            "recent",
            "goal",
            "long_term",
            "pattern",
            "repeat"
        ],
        interruptiveModeIDs: [String] = [BASDecisionMode.primaryID],
        boundaryNamingModeIDs: [String] = [BASDecisionMode.reflectiveID],
        tradeoffClarityModeIDs: [String] = [BASDecisionMode.comparativeID],
        typeBoostsByModeID: [String: [String: Double]] = [
            BASDecisionMode.primaryID: [
                BASMemoryKind.support.rawValue: 3.4,
                BASMemoryKind.semantic.rawValue: 2.8,
                BASMemoryKind.situational.rawValue: 2.4
            ],
            BASDecisionMode.comparativeID: [
                BASMemoryKind.goal.rawValue: 3.0,
                BASMemoryKind.semantic.rawValue: 3.0
            ],
            BASDecisionMode.reflectiveID: [
                BASMemoryKind.situational.rawValue: 3.4,
                BASMemoryKind.semantic.rawValue: 3.4,
                BASMemoryKind.goal.rawValue: 3.4
            ]
        ],
        interruptiveActionIDs: [String] = ["pause", "step_back", "defer"],
        proceedActionIDs: [String] = ["proceed", "continue"],
        positiveReflectionOutcomeIDs: [String] = ["stabilized", "okay", "not_needed"],
        negativeReflectionOutcomeIDs: [String] = ["regretted", "felt_worse"]
    ) {
        self.filteredCandidateLimitByModeID = filteredCandidateLimitByModeID
        self.retrievalOffCandidateLimitByModeID = retrievalOffCandidateLimitByModeID
        self.retrievalOffGoalLimitByModeID = retrievalOffGoalLimitByModeID
        self.filteredRelevantLimitByModeID = filteredRelevantLimitByModeID
        self.adaptiveRelevantLimitByModeID = adaptiveRelevantLimitByModeID
        self.relevantPriorityBaselinesByModeID = relevantPriorityBaselinesByModeID
        self.requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired =
            requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired
        self.requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired =
            requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired
        self.ignoredRetrievalTags = ignoredRetrievalTags
        self.interruptiveModeIDs = interruptiveModeIDs
        self.boundaryNamingModeIDs = boundaryNamingModeIDs
        self.tradeoffClarityModeIDs = tradeoffClarityModeIDs
        self.typeBoostsByModeID = typeBoostsByModeID
        self.interruptiveActionIDs = interruptiveActionIDs
        self.proceedActionIDs = proceedActionIDs
        self.positiveReflectionOutcomeIDs = positiveReflectionOutcomeIDs
        self.negativeReflectionOutcomeIDs = negativeReflectionOutcomeIDs
    }

    public func candidateLimitWhenFiltered(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: filteredCandidateLimitByModeID, for: mode) ?? 8
    }

    public func candidateLimitWhenRetrievalOff(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: retrievalOffCandidateLimitByModeID, for: mode) ?? 5
    }

    public func goalLimitWhenRetrievalOff(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: retrievalOffGoalLimitByModeID, for: mode) ?? 2
    }

    public func relevantLimitWhenFiltered(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: filteredRelevantLimitByModeID, for: mode) ?? 3
    }

    public func relevantLimitWhenAdaptive(for mode: BASDecisionMode) -> Int {
        resolvedInt(from: adaptiveRelevantLimitByModeID, for: mode) ?? 3
    }

    public func relevantPriorityBaseline(for mode: BASDecisionMode) -> Double {
        resolvedDouble(from: relevantPriorityBaselinesByModeID, for: mode) ?? 0.64
    }

    public func ignoredRetrievalTagSet() -> Set<String> {
        Set(ignoredRetrievalTags.map { $0.lowercased() })
    }

    public func typeBoost(for mode: BASDecisionMode, kind: BASMemoryKind) -> Double {
        for key in modeKeys(for: mode) {
            if let mapping = typeBoostsByModeID[key], let boost = mapping[kind.rawValue] {
                return boost
            }
        }
        if kind == .profile {
            return 1.8
        }
        return 1.0
    }

    public func isInterruptiveMode(_ mode: BASDecisionMode) -> Bool {
        matches(mode: mode, configuredIDs: interruptiveModeIDs)
    }

    public func isBoundaryNamingMode(_ mode: BASDecisionMode) -> Bool {
        matches(mode: mode, configuredIDs: boundaryNamingModeIDs)
    }

    public func isTradeoffClarityMode(_ mode: BASDecisionMode) -> Bool {
        matches(mode: mode, configuredIDs: tradeoffClarityModeIDs)
    }

    private func modeKeys(for mode: BASDecisionMode) -> [String] {
        [mode.identifier, mode.rawValue]
    }

    private func resolvedInt(from mapping: [String: Int], for mode: BASDecisionMode) -> Int? {
        for key in modeKeys(for: mode) {
            if let value = mapping[key] {
                return value
            }
        }
        return nil
    }

    private func resolvedDouble(from mapping: [String: Double], for mode: BASDecisionMode) -> Double? {
        for key in modeKeys(for: mode) {
            if let value = mapping[key] {
                return value
            }
        }
        return nil
    }

    private func matches(mode: BASDecisionMode, configuredIDs: [String]) -> Bool {
        let keys = Set(modeKeys(for: mode))
        return configuredIDs.contains { keys.contains($0) }
    }
}

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
                confidenceCeiling: 0.58,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Use brief local nudges without taking over the user's agency."
            ),
            BASInteractionSurface.watch.rawValue: BASIdentityProfileOverlay(
                role: .pauseCompanion,
                initiative: .guided,
                confidenceCeiling: 0.64,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "Keep the wearable surface lightweight, local, and interruptive."
            )
        ],
        highRiskIdentityOverlay: BASIdentityProfileOverlay = BASIdentityProfileOverlay(
            posture: .protective,
            confidenceCeiling: 0.66,
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

public enum BASEvolutionApprovalState: String, CaseIterable, Codable, Sendable {
    case automatic
    case reviewSuggested
}

public struct BASEvolutionFoldedLungSummary: Codable, Equatable, Sendable, BASSchemaVersioned {
    public static let currentSchemaVersion = "1.6.0"

    public struct PrecisionRecord: Codable, Equatable, Sendable {
        public let organID: String
        public let tierID: String

        public init(
            organID: String,
            tierID: String
        ) {
            self.organID = organID.trimmingCharacters(in: .whitespacesAndNewlines)
            self.tierID = tierID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public struct OrganPackageRecord: Codable, Equatable, Sendable {
        public let packageID: String
        public let organID: String
        public let sizeMB: Int
        public let precisionOptionIDs: [String]
        public let loadTimeMs: Int
        public let thermalCost: Int
        public let sovereignClass: String

        public init(
            packageID: String,
            organID: String,
            sizeMB: Int,
            precisionOptionIDs: [String] = [],
            loadTimeMs: Int,
            thermalCost: Int,
            sovereignClass: String
        ) {
            self.packageID = packageID.trimmingCharacters(in: .whitespacesAndNewlines)
            self.organID = organID.trimmingCharacters(in: .whitespacesAndNewlines)
            self.sizeMB = max(0, sizeMB)
            self.precisionOptionIDs = precisionOptionIDs
            self.loadTimeMs = max(0, loadTimeMs)
            self.thermalCost = max(0, thermalCost)
            self.sovereignClass = sovereignClass.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public let schemaVersion: String
    public let morphGraphID: String?
    public let hotColdMapID: String?
    public let precisionProfileID: String?
    public let lungStateRef: String?
    public let breathSchedulerID: String?
    public let thermalExchangeID: String?
    public let integrityWeaveID: String?
    public let organDeltaPlanID: String?
    public let breathMode: String
    public let breathPhase: String
    public let thermalPressure: Int
    public let cachePressure: Int
    public let restoreReadinessPercent: Int
    public let resumeID: String
    public let sourceFoldID: String
    public let resumeDepth: Int
    public let requiredOrganIDs: [String]
    public let consistencyChecks: [String]
    public let fallbackMode: String
    public let rollbackAnchorID: String
    public let safeSnapshotRef: String
    public let foldRefs: [String]
    public let hostVersionRef: String?
    public let cacheStateRef: String?
    public let integrityHash: String
    public let sovereignActuationKinds: [BASSovereignActuationKind]
    public let invalidatedResumeFrameIDs: [String]
    public let invalidatedCacheRefs: [String]
    public let invalidatedFoldRefs: [String]
    public let quarantinedFoldRefs: [String]
    public let resultingBreathMode: String?
    public let preservedReadOnlyRecovery: Bool?
    public let sovereignBridgeSummary: String?
    public let morphActiveOrganIDs: [String]
    public let morphExecutionOrder: [String]
    public let morphPrecisionRecords: [PrecisionRecord]
    public let morphDeviceRouteMap: [String: String]
    public let morphThermalProfile: [String]
    public let morphSovereignConstraints: [String]
    public let hotOrganIDs: [String]
    public let warmOrganIDs: [String]
    public let coldOrganIDs: [String]
    public let organPackageRecords: [OrganPackageRecord]
    public let organDeltaMode: String?
    public let organDeltaActivatePackageIDs: [String]
    public let organDeltaPreloadPackageIDs: [String]
    public let organDeltaEvictPackageIDs: [String]
    public let organDeltaRetainPackageIDs: [String]
    public let organDeltaRollbackSafePackageIDs: [String]
    public let organDeltaTriggeredActuationKinds: [String]
    public let organDeltaReasonCodes: [String]
    public let hotColdPreloadPolicy: String?
    public let hotColdEvictionPolicy: String?
    public let schedulerCadenceTag: String?
    public let schedulerCheckpointCadence: String?
    public let schedulerMicroSleepWindowMs: Int?
    public let schedulerBackgroundMaintenanceWindowMs: Int?
    public let schedulerAllowsBackgroundMaintenance: Bool?
    public let schedulerAllowsMicroSleep: Bool?
    public let schedulerResumeBudgetClass: String?
    public let schedulerReasonCodes: [String]
    public let thermalExchangeMode: String?
    public let thermalPredictedBand: String?
    public let thermalCoolingActions: [String]
    public let thermalSuppressedOrganIDs: [String]
    public let thermalReroutedOrganIDs: [String]
    public let thermalRerouteTargets: [String: String]
    public let thermalPrecisionDowngradeRecords: [PrecisionRecord]
    public let thermalExchangeReasonCodes: [String]
    public let integrityRequiredChecks: [String]
    public let integrityCompletedChecks: [String]
    public let integrityFailedChecks: [String]
    public let integrityPurityState: String?
    public let integrityContaminationRefs: [String]
    public let integrityTrustedSnapshotRef: String?
    public let integrityVerificationHash: String?
    public let precisionOrganPrecisionRecords: [PrecisionRecord]
    public let precisionLockedOrganIDs: [String]
    public let precisionDegradationOrder: [String]
    public let precisionGuardSafeFloorID: String?

    public init(
        schemaVersion: String = BASEvolutionFoldedLungSummary.currentSchemaVersion,
        morphGraphID: String? = nil,
        hotColdMapID: String? = nil,
        precisionProfileID: String? = nil,
        lungStateRef: String? = nil,
        breathSchedulerID: String? = nil,
        thermalExchangeID: String? = nil,
        integrityWeaveID: String? = nil,
        organDeltaPlanID: String? = nil,
        breathMode: String,
        breathPhase: String,
        thermalPressure: Int,
        cachePressure: Int,
        restoreReadinessPercent: Int,
        resumeID: String,
        sourceFoldID: String,
        resumeDepth: Int,
        requiredOrganIDs: [String] = [],
        consistencyChecks: [String] = [],
        fallbackMode: String,
        rollbackAnchorID: String,
        safeSnapshotRef: String,
        foldRefs: [String] = [],
        hostVersionRef: String? = nil,
        cacheStateRef: String? = nil,
        integrityHash: String,
        sovereignActuationKinds: [BASSovereignActuationKind] = [],
        invalidatedResumeFrameIDs: [String] = [],
        invalidatedCacheRefs: [String] = [],
        invalidatedFoldRefs: [String] = [],
        quarantinedFoldRefs: [String] = [],
        resultingBreathMode: String? = nil,
        preservedReadOnlyRecovery: Bool? = nil,
        sovereignBridgeSummary: String? = nil,
        morphActiveOrganIDs: [String] = [],
        morphExecutionOrder: [String] = [],
        morphPrecisionRecords: [PrecisionRecord] = [],
        morphDeviceRouteMap: [String: String] = [:],
        morphThermalProfile: [String] = [],
        morphSovereignConstraints: [String] = [],
        hotOrganIDs: [String] = [],
        warmOrganIDs: [String] = [],
        coldOrganIDs: [String] = [],
        organPackageRecords: [OrganPackageRecord] = [],
        organDeltaMode: String? = nil,
        organDeltaActivatePackageIDs: [String] = [],
        organDeltaPreloadPackageIDs: [String] = [],
        organDeltaEvictPackageIDs: [String] = [],
        organDeltaRetainPackageIDs: [String] = [],
        organDeltaRollbackSafePackageIDs: [String] = [],
        organDeltaTriggeredActuationKinds: [String] = [],
        organDeltaReasonCodes: [String] = [],
        hotColdPreloadPolicy: String? = nil,
        hotColdEvictionPolicy: String? = nil,
        schedulerCadenceTag: String? = nil,
        schedulerCheckpointCadence: String? = nil,
        schedulerMicroSleepWindowMs: Int? = nil,
        schedulerBackgroundMaintenanceWindowMs: Int? = nil,
        schedulerAllowsBackgroundMaintenance: Bool? = nil,
        schedulerAllowsMicroSleep: Bool? = nil,
        schedulerResumeBudgetClass: String? = nil,
        schedulerReasonCodes: [String] = [],
        thermalExchangeMode: String? = nil,
        thermalPredictedBand: String? = nil,
        thermalCoolingActions: [String] = [],
        thermalSuppressedOrganIDs: [String] = [],
        thermalReroutedOrganIDs: [String] = [],
        thermalRerouteTargets: [String: String] = [:],
        thermalPrecisionDowngradeRecords: [PrecisionRecord] = [],
        thermalExchangeReasonCodes: [String] = [],
        integrityRequiredChecks: [String] = [],
        integrityCompletedChecks: [String] = [],
        integrityFailedChecks: [String] = [],
        integrityPurityState: String? = nil,
        integrityContaminationRefs: [String] = [],
        integrityTrustedSnapshotRef: String? = nil,
        integrityVerificationHash: String? = nil,
        precisionOrganPrecisionRecords: [PrecisionRecord] = [],
        precisionLockedOrganIDs: [String] = [],
        precisionDegradationOrder: [String] = [],
        precisionGuardSafeFloorID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.morphGraphID = morphGraphID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hotColdMapID = hotColdMapID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.precisionProfileID = precisionProfileID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lungStateRef = lungStateRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breathSchedulerID = breathSchedulerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thermalExchangeID = thermalExchangeID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityWeaveID = integrityWeaveID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organDeltaPlanID = organDeltaPlanID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breathMode = breathMode
        self.breathPhase = breathPhase
        self.thermalPressure = min(max(thermalPressure, 0), 100)
        self.cachePressure = min(max(cachePressure, 0), 100)
        self.restoreReadinessPercent = min(max(restoreReadinessPercent, 0), 100)
        self.resumeID = resumeID
        self.sourceFoldID = sourceFoldID
        self.resumeDepth = max(0, resumeDepth)
        self.requiredOrganIDs = requiredOrganIDs
        self.consistencyChecks = consistencyChecks
        self.fallbackMode = fallbackMode
        self.rollbackAnchorID = rollbackAnchorID
        self.safeSnapshotRef = safeSnapshotRef
        self.foldRefs = foldRefs
        self.hostVersionRef = hostVersionRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cacheStateRef = cacheStateRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityHash = integrityHash
        self.sovereignActuationKinds = sovereignActuationKinds
        self.invalidatedResumeFrameIDs = invalidatedResumeFrameIDs
        self.invalidatedCacheRefs = invalidatedCacheRefs
        self.invalidatedFoldRefs = invalidatedFoldRefs
        self.quarantinedFoldRefs = quarantinedFoldRefs
        self.resultingBreathMode = resultingBreathMode?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.preservedReadOnlyRecovery = preservedReadOnlyRecovery
        self.sovereignBridgeSummary = sovereignBridgeSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.morphActiveOrganIDs = morphActiveOrganIDs
        self.morphExecutionOrder = morphExecutionOrder
        self.morphPrecisionRecords = morphPrecisionRecords
        self.morphDeviceRouteMap = morphDeviceRouteMap
        self.morphThermalProfile = morphThermalProfile
        self.morphSovereignConstraints = morphSovereignConstraints
        self.hotOrganIDs = hotOrganIDs
        self.warmOrganIDs = warmOrganIDs
        self.coldOrganIDs = coldOrganIDs
        self.organPackageRecords = organPackageRecords
        self.organDeltaMode = organDeltaMode?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organDeltaActivatePackageIDs = organDeltaActivatePackageIDs
        self.organDeltaPreloadPackageIDs = organDeltaPreloadPackageIDs
        self.organDeltaEvictPackageIDs = organDeltaEvictPackageIDs
        self.organDeltaRetainPackageIDs = organDeltaRetainPackageIDs
        self.organDeltaRollbackSafePackageIDs = organDeltaRollbackSafePackageIDs
        self.organDeltaTriggeredActuationKinds = organDeltaTriggeredActuationKinds
        self.organDeltaReasonCodes = organDeltaReasonCodes
        self.hotColdPreloadPolicy = hotColdPreloadPolicy?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hotColdEvictionPolicy = hotColdEvictionPolicy?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerCadenceTag = schedulerCadenceTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerCheckpointCadence = schedulerCheckpointCadence?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerMicroSleepWindowMs = schedulerMicroSleepWindowMs.map { max(0, $0) }
        self.schedulerBackgroundMaintenanceWindowMs = schedulerBackgroundMaintenanceWindowMs.map { max(0, $0) }
        self.schedulerAllowsBackgroundMaintenance = schedulerAllowsBackgroundMaintenance
        self.schedulerAllowsMicroSleep = schedulerAllowsMicroSleep
        self.schedulerResumeBudgetClass = schedulerResumeBudgetClass?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerReasonCodes = schedulerReasonCodes
        self.thermalExchangeMode = thermalExchangeMode?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thermalPredictedBand = thermalPredictedBand?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thermalCoolingActions = thermalCoolingActions
        self.thermalSuppressedOrganIDs = thermalSuppressedOrganIDs
        self.thermalReroutedOrganIDs = thermalReroutedOrganIDs
        self.thermalRerouteTargets = thermalRerouteTargets.reduce(into: [:]) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.isEmpty == false, value.isEmpty == false else { return }
            result[key] = value
        }
        self.thermalPrecisionDowngradeRecords = thermalPrecisionDowngradeRecords
        self.thermalExchangeReasonCodes = thermalExchangeReasonCodes
        self.integrityRequiredChecks = integrityRequiredChecks
        self.integrityCompletedChecks = integrityCompletedChecks
        self.integrityFailedChecks = integrityFailedChecks
        self.integrityPurityState = integrityPurityState?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityContaminationRefs = integrityContaminationRefs
        self.integrityTrustedSnapshotRef = integrityTrustedSnapshotRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityVerificationHash = integrityVerificationHash?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.precisionOrganPrecisionRecords = precisionOrganPrecisionRecords
        self.precisionLockedOrganIDs = precisionLockedOrganIDs
        self.precisionDegradationOrder = precisionDegradationOrder
        self.precisionGuardSafeFloorID = precisionGuardSafeFloorID?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case morphGraphID
        case hotColdMapID
        case precisionProfileID
        case lungStateRef
        case breathSchedulerID
        case thermalExchangeID
        case integrityWeaveID
        case organDeltaPlanID
        case breathMode
        case breathPhase
        case thermalPressure
        case cachePressure
        case restoreReadinessPercent
        case resumeID
        case sourceFoldID
        case resumeDepth
        case requiredOrganIDs
        case consistencyChecks
        case fallbackMode
        case rollbackAnchorID
        case safeSnapshotRef
        case foldRefs
        case hostVersionRef
        case cacheStateRef
        case integrityHash
        case sovereignActuationKinds
        case invalidatedResumeFrameIDs
        case invalidatedCacheRefs
        case invalidatedFoldRefs
        case quarantinedFoldRefs
        case resultingBreathMode
        case preservedReadOnlyRecovery
        case sovereignBridgeSummary
        case morphActiveOrganIDs
        case morphExecutionOrder
        case morphPrecisionRecords
        case morphDeviceRouteMap
        case morphThermalProfile
        case morphSovereignConstraints
        case hotOrganIDs
        case warmOrganIDs
        case coldOrganIDs
        case organPackageRecords
        case organDeltaMode
        case organDeltaActivatePackageIDs
        case organDeltaPreloadPackageIDs
        case organDeltaEvictPackageIDs
        case organDeltaRetainPackageIDs
        case organDeltaRollbackSafePackageIDs
        case organDeltaTriggeredActuationKinds
        case organDeltaReasonCodes
        case hotColdPreloadPolicy
        case hotColdEvictionPolicy
        case schedulerCadenceTag
        case schedulerCheckpointCadence
        case schedulerMicroSleepWindowMs
        case schedulerBackgroundMaintenanceWindowMs
        case schedulerAllowsBackgroundMaintenance
        case schedulerAllowsMicroSleep
        case schedulerResumeBudgetClass
        case schedulerReasonCodes
        case thermalExchangeMode
        case thermalPredictedBand
        case thermalCoolingActions
        case thermalSuppressedOrganIDs
        case thermalReroutedOrganIDs
        case thermalRerouteTargets
        case thermalPrecisionDowngradeRecords
        case thermalExchangeReasonCodes
        case integrityRequiredChecks
        case integrityCompletedChecks
        case integrityFailedChecks
        case integrityPurityState
        case integrityContaminationRefs
        case integrityTrustedSnapshotRef
        case integrityVerificationHash
        case precisionOrganPrecisionRecords
        case precisionLockedOrganIDs
        case precisionDegradationOrder
        case precisionGuardSafeFloorID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASEvolutionFoldedLungSummary.currentSchemaVersion
        let morphGraphID = try container.decodeIfPresent(String.self, forKey: .morphGraphID)
        let hotColdMapID = try container.decodeIfPresent(String.self, forKey: .hotColdMapID)
        let precisionProfileID = try container.decodeIfPresent(String.self, forKey: .precisionProfileID)
        let lungStateRef = try container.decodeIfPresent(String.self, forKey: .lungStateRef)
        let breathSchedulerID = try container.decodeIfPresent(String.self, forKey: .breathSchedulerID)
        let thermalExchangeID = try container.decodeIfPresent(String.self, forKey: .thermalExchangeID)
        let integrityWeaveID = try container.decodeIfPresent(String.self, forKey: .integrityWeaveID)
        let organDeltaPlanID = try container.decodeIfPresent(String.self, forKey: .organDeltaPlanID)
        let breathMode = try container.decode(String.self, forKey: .breathMode)
        let breathPhase = try container.decode(String.self, forKey: .breathPhase)
        let thermalPressure = min(max(try container.decode(Int.self, forKey: .thermalPressure), 0), 100)
        let cachePressure = min(max(try container.decode(Int.self, forKey: .cachePressure), 0), 100)
        let restoreReadinessPercent = min(max(try container.decode(Int.self, forKey: .restoreReadinessPercent), 0), 100)
        let resumeID = try container.decode(String.self, forKey: .resumeID)
        let sourceFoldID = try container.decode(String.self, forKey: .sourceFoldID)
        let resumeDepth = max(0, try container.decode(Int.self, forKey: .resumeDepth))
        let requiredOrganIDs = try container.decodeIfPresent([String].self, forKey: .requiredOrganIDs) ?? []
        let consistencyChecks = try container.decodeIfPresent([String].self, forKey: .consistencyChecks) ?? []
        let fallbackMode = try container.decode(String.self, forKey: .fallbackMode)
        let rollbackAnchorID = try container.decode(String.self, forKey: .rollbackAnchorID)
        let safeSnapshotRef = try container.decode(String.self, forKey: .safeSnapshotRef)
        let foldRefs = try container.decodeIfPresent([String].self, forKey: .foldRefs) ?? []
        let hostVersionRef = try container.decodeIfPresent(String.self, forKey: .hostVersionRef)
        let cacheStateRef = try container.decodeIfPresent(String.self, forKey: .cacheStateRef)
        let integrityHash = try container.decode(String.self, forKey: .integrityHash)
        let sovereignActuationKinds = try container.decodeIfPresent(
            [BASSovereignActuationKind].self,
            forKey: .sovereignActuationKinds
        ) ?? []
        let invalidatedResumeFrameIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .invalidatedResumeFrameIDs
        ) ?? []
        let invalidatedCacheRefs = try container.decodeIfPresent(
            [String].self,
            forKey: .invalidatedCacheRefs
        ) ?? []
        let invalidatedFoldRefs = try container.decodeIfPresent(
            [String].self,
            forKey: .invalidatedFoldRefs
        ) ?? []
        let quarantinedFoldRefs = try container.decodeIfPresent(
            [String].self,
            forKey: .quarantinedFoldRefs
        ) ?? []
        let resultingBreathMode = try container.decodeIfPresent(String.self, forKey: .resultingBreathMode)
        let preservedReadOnlyRecovery = try container.decodeIfPresent(Bool.self, forKey: .preservedReadOnlyRecovery)
        let sovereignBridgeSummary = try container.decodeIfPresent(String.self, forKey: .sovereignBridgeSummary)
        let morphActiveOrganIDs = try container.decodeIfPresent([String].self, forKey: .morphActiveOrganIDs) ?? []
        let morphExecutionOrder = try container.decodeIfPresent([String].self, forKey: .morphExecutionOrder) ?? []
        let morphPrecisionRecords = try container.decodeIfPresent([PrecisionRecord].self, forKey: .morphPrecisionRecords) ?? []
        let morphDeviceRouteMap = try container.decodeIfPresent([String: String].self, forKey: .morphDeviceRouteMap) ?? [:]
        let morphThermalProfile = try container.decodeIfPresent([String].self, forKey: .morphThermalProfile) ?? []
        let morphSovereignConstraints = try container.decodeIfPresent([String].self, forKey: .morphSovereignConstraints) ?? []
        let hotOrganIDs = try container.decodeIfPresent([String].self, forKey: .hotOrganIDs) ?? []
        let warmOrganIDs = try container.decodeIfPresent([String].self, forKey: .warmOrganIDs) ?? []
        let coldOrganIDs = try container.decodeIfPresent([String].self, forKey: .coldOrganIDs) ?? []
        let organPackageRecords = try container.decodeIfPresent(
            [OrganPackageRecord].self,
            forKey: .organPackageRecords
        ) ?? []
        let organDeltaMode = try container.decodeIfPresent(String.self, forKey: .organDeltaMode)
        let organDeltaActivatePackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaActivatePackageIDs
        ) ?? []
        let organDeltaPreloadPackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaPreloadPackageIDs
        ) ?? []
        let organDeltaEvictPackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaEvictPackageIDs
        ) ?? []
        let organDeltaRetainPackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaRetainPackageIDs
        ) ?? []
        let organDeltaRollbackSafePackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaRollbackSafePackageIDs
        ) ?? []
        let organDeltaTriggeredActuationKinds = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaTriggeredActuationKinds
        ) ?? []
        let organDeltaReasonCodes = try container.decodeIfPresent(
            [String].self,
            forKey: .organDeltaReasonCodes
        ) ?? []
        let hotColdPreloadPolicy = try container.decodeIfPresent(String.self, forKey: .hotColdPreloadPolicy)
        let hotColdEvictionPolicy = try container.decodeIfPresent(String.self, forKey: .hotColdEvictionPolicy)
        let schedulerCadenceTag = try container.decodeIfPresent(String.self, forKey: .schedulerCadenceTag)
        let schedulerCheckpointCadence = try container.decodeIfPresent(String.self, forKey: .schedulerCheckpointCadence)
        let schedulerMicroSleepWindowMs = try container.decodeIfPresent(Int.self, forKey: .schedulerMicroSleepWindowMs).map { max(0, $0) }
        let schedulerBackgroundMaintenanceWindowMs = try container.decodeIfPresent(Int.self, forKey: .schedulerBackgroundMaintenanceWindowMs).map { max(0, $0) }
        let schedulerAllowsBackgroundMaintenance = try container.decodeIfPresent(Bool.self, forKey: .schedulerAllowsBackgroundMaintenance)
        let schedulerAllowsMicroSleep = try container.decodeIfPresent(Bool.self, forKey: .schedulerAllowsMicroSleep)
        let schedulerResumeBudgetClass = try container.decodeIfPresent(String.self, forKey: .schedulerResumeBudgetClass)
        let schedulerReasonCodes = try container.decodeIfPresent([String].self, forKey: .schedulerReasonCodes) ?? []
        let thermalExchangeMode = try container.decodeIfPresent(String.self, forKey: .thermalExchangeMode)
        let thermalPredictedBand = try container.decodeIfPresent(String.self, forKey: .thermalPredictedBand)
        let thermalCoolingActions = try container.decodeIfPresent([String].self, forKey: .thermalCoolingActions) ?? []
        let thermalSuppressedOrganIDs = try container.decodeIfPresent([String].self, forKey: .thermalSuppressedOrganIDs) ?? []
        let thermalReroutedOrganIDs = try container.decodeIfPresent([String].self, forKey: .thermalReroutedOrganIDs) ?? []
        let thermalRerouteTargets = try container.decodeIfPresent([String: String].self, forKey: .thermalRerouteTargets) ?? [:]
        let thermalPrecisionDowngradeRecords = try container.decodeIfPresent(
            [PrecisionRecord].self,
            forKey: .thermalPrecisionDowngradeRecords
        ) ?? []
        let thermalExchangeReasonCodes = try container.decodeIfPresent([String].self, forKey: .thermalExchangeReasonCodes) ?? []
        let integrityRequiredChecks = try container.decodeIfPresent([String].self, forKey: .integrityRequiredChecks) ?? []
        let integrityCompletedChecks = try container.decodeIfPresent([String].self, forKey: .integrityCompletedChecks) ?? []
        let integrityFailedChecks = try container.decodeIfPresent([String].self, forKey: .integrityFailedChecks) ?? []
        let integrityPurityState = try container.decodeIfPresent(String.self, forKey: .integrityPurityState)
        let integrityContaminationRefs = try container.decodeIfPresent([String].self, forKey: .integrityContaminationRefs) ?? []
        let integrityTrustedSnapshotRef = try container.decodeIfPresent(String.self, forKey: .integrityTrustedSnapshotRef)
        let integrityVerificationHash = try container.decodeIfPresent(String.self, forKey: .integrityVerificationHash)
        let precisionOrganPrecisionRecords = try container.decodeIfPresent(
            [PrecisionRecord].self,
            forKey: .precisionOrganPrecisionRecords
        ) ?? []
        let precisionLockedOrganIDs = try container.decodeIfPresent([String].self, forKey: .precisionLockedOrganIDs) ?? []
        let precisionDegradationOrder = try container.decodeIfPresent([String].self, forKey: .precisionDegradationOrder) ?? []
        let precisionGuardSafeFloorID = try container.decodeIfPresent(String.self, forKey: .precisionGuardSafeFloorID)

        self.init(
            schemaVersion: schemaVersion,
            morphGraphID: morphGraphID,
            hotColdMapID: hotColdMapID,
            precisionProfileID: precisionProfileID,
            lungStateRef: lungStateRef,
            breathSchedulerID: breathSchedulerID,
            thermalExchangeID: thermalExchangeID,
            integrityWeaveID: integrityWeaveID,
            organDeltaPlanID: organDeltaPlanID,
            breathMode: breathMode,
            breathPhase: breathPhase,
            thermalPressure: thermalPressure,
            cachePressure: cachePressure,
            restoreReadinessPercent: restoreReadinessPercent,
            resumeID: resumeID,
            sourceFoldID: sourceFoldID,
            resumeDepth: resumeDepth,
            requiredOrganIDs: requiredOrganIDs,
            consistencyChecks: consistencyChecks,
            fallbackMode: fallbackMode,
            rollbackAnchorID: rollbackAnchorID,
            safeSnapshotRef: safeSnapshotRef,
            foldRefs: foldRefs,
            hostVersionRef: hostVersionRef,
            cacheStateRef: cacheStateRef,
            integrityHash: integrityHash,
            sovereignActuationKinds: sovereignActuationKinds,
            invalidatedResumeFrameIDs: invalidatedResumeFrameIDs,
            invalidatedCacheRefs: invalidatedCacheRefs,
            invalidatedFoldRefs: invalidatedFoldRefs,
            quarantinedFoldRefs: quarantinedFoldRefs,
            resultingBreathMode: resultingBreathMode,
            preservedReadOnlyRecovery: preservedReadOnlyRecovery,
            sovereignBridgeSummary: sovereignBridgeSummary,
            morphActiveOrganIDs: morphActiveOrganIDs,
            morphExecutionOrder: morphExecutionOrder,
            morphPrecisionRecords: morphPrecisionRecords,
            morphDeviceRouteMap: morphDeviceRouteMap,
            morphThermalProfile: morphThermalProfile,
            morphSovereignConstraints: morphSovereignConstraints,
            hotOrganIDs: hotOrganIDs,
            warmOrganIDs: warmOrganIDs,
            coldOrganIDs: coldOrganIDs,
            organPackageRecords: organPackageRecords,
            organDeltaMode: organDeltaMode,
            organDeltaActivatePackageIDs: organDeltaActivatePackageIDs,
            organDeltaPreloadPackageIDs: organDeltaPreloadPackageIDs,
            organDeltaEvictPackageIDs: organDeltaEvictPackageIDs,
            organDeltaRetainPackageIDs: organDeltaRetainPackageIDs,
            organDeltaRollbackSafePackageIDs: organDeltaRollbackSafePackageIDs,
            organDeltaTriggeredActuationKinds: organDeltaTriggeredActuationKinds,
            organDeltaReasonCodes: organDeltaReasonCodes,
            hotColdPreloadPolicy: hotColdPreloadPolicy,
            hotColdEvictionPolicy: hotColdEvictionPolicy,
            schedulerCadenceTag: schedulerCadenceTag,
            schedulerCheckpointCadence: schedulerCheckpointCadence,
            schedulerMicroSleepWindowMs: schedulerMicroSleepWindowMs,
            schedulerBackgroundMaintenanceWindowMs: schedulerBackgroundMaintenanceWindowMs,
            schedulerAllowsBackgroundMaintenance: schedulerAllowsBackgroundMaintenance,
            schedulerAllowsMicroSleep: schedulerAllowsMicroSleep,
            schedulerResumeBudgetClass: schedulerResumeBudgetClass,
            schedulerReasonCodes: schedulerReasonCodes,
            thermalExchangeMode: thermalExchangeMode,
            thermalPredictedBand: thermalPredictedBand,
            thermalCoolingActions: thermalCoolingActions,
            thermalSuppressedOrganIDs: thermalSuppressedOrganIDs,
            thermalReroutedOrganIDs: thermalReroutedOrganIDs,
            thermalRerouteTargets: thermalRerouteTargets,
            thermalPrecisionDowngradeRecords: thermalPrecisionDowngradeRecords,
            thermalExchangeReasonCodes: thermalExchangeReasonCodes,
            integrityRequiredChecks: integrityRequiredChecks,
            integrityCompletedChecks: integrityCompletedChecks,
            integrityFailedChecks: integrityFailedChecks,
            integrityPurityState: integrityPurityState,
            integrityContaminationRefs: integrityContaminationRefs,
            integrityTrustedSnapshotRef: integrityTrustedSnapshotRef,
            integrityVerificationHash: integrityVerificationHash,
            precisionOrganPrecisionRecords: precisionOrganPrecisionRecords,
            precisionLockedOrganIDs: precisionLockedOrganIDs,
            precisionDegradationOrder: precisionDegradationOrder,
            precisionGuardSafeFloorID: precisionGuardSafeFloorID
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(morphGraphID, forKey: .morphGraphID)
        try container.encodeIfPresent(hotColdMapID, forKey: .hotColdMapID)
        try container.encodeIfPresent(precisionProfileID, forKey: .precisionProfileID)
        try container.encodeIfPresent(lungStateRef, forKey: .lungStateRef)
        try container.encodeIfPresent(breathSchedulerID, forKey: .breathSchedulerID)
        try container.encodeIfPresent(thermalExchangeID, forKey: .thermalExchangeID)
        try container.encodeIfPresent(integrityWeaveID, forKey: .integrityWeaveID)
        try container.encodeIfPresent(organDeltaPlanID, forKey: .organDeltaPlanID)
        try container.encode(breathMode, forKey: .breathMode)
        try container.encode(breathPhase, forKey: .breathPhase)
        try container.encode(thermalPressure, forKey: .thermalPressure)
        try container.encode(cachePressure, forKey: .cachePressure)
        try container.encode(restoreReadinessPercent, forKey: .restoreReadinessPercent)
        try container.encode(resumeID, forKey: .resumeID)
        try container.encode(sourceFoldID, forKey: .sourceFoldID)
        try container.encode(resumeDepth, forKey: .resumeDepth)
        try container.encode(requiredOrganIDs, forKey: .requiredOrganIDs)
        try container.encode(consistencyChecks, forKey: .consistencyChecks)
        try container.encode(fallbackMode, forKey: .fallbackMode)
        try container.encode(rollbackAnchorID, forKey: .rollbackAnchorID)
        try container.encode(safeSnapshotRef, forKey: .safeSnapshotRef)
        try container.encode(foldRefs, forKey: .foldRefs)
        try container.encodeIfPresent(hostVersionRef, forKey: .hostVersionRef)
        try container.encodeIfPresent(cacheStateRef, forKey: .cacheStateRef)
        try container.encode(integrityHash, forKey: .integrityHash)
        try container.encode(sovereignActuationKinds, forKey: .sovereignActuationKinds)
        try container.encode(invalidatedResumeFrameIDs, forKey: .invalidatedResumeFrameIDs)
        try container.encode(invalidatedCacheRefs, forKey: .invalidatedCacheRefs)
        try container.encode(invalidatedFoldRefs, forKey: .invalidatedFoldRefs)
        try container.encode(quarantinedFoldRefs, forKey: .quarantinedFoldRefs)
        try container.encodeIfPresent(resultingBreathMode, forKey: .resultingBreathMode)
        try container.encodeIfPresent(preservedReadOnlyRecovery, forKey: .preservedReadOnlyRecovery)
        try container.encodeIfPresent(sovereignBridgeSummary, forKey: .sovereignBridgeSummary)
        try container.encode(morphActiveOrganIDs, forKey: .morphActiveOrganIDs)
        try container.encode(morphExecutionOrder, forKey: .morphExecutionOrder)
        try container.encode(morphPrecisionRecords, forKey: .morphPrecisionRecords)
        try container.encode(morphDeviceRouteMap, forKey: .morphDeviceRouteMap)
        try container.encode(morphThermalProfile, forKey: .morphThermalProfile)
        try container.encode(morphSovereignConstraints, forKey: .morphSovereignConstraints)
        try container.encode(hotOrganIDs, forKey: .hotOrganIDs)
        try container.encode(warmOrganIDs, forKey: .warmOrganIDs)
        try container.encode(coldOrganIDs, forKey: .coldOrganIDs)
        try container.encode(organPackageRecords, forKey: .organPackageRecords)
        try container.encodeIfPresent(organDeltaMode, forKey: .organDeltaMode)
        try container.encode(organDeltaActivatePackageIDs, forKey: .organDeltaActivatePackageIDs)
        try container.encode(organDeltaPreloadPackageIDs, forKey: .organDeltaPreloadPackageIDs)
        try container.encode(organDeltaEvictPackageIDs, forKey: .organDeltaEvictPackageIDs)
        try container.encode(organDeltaRetainPackageIDs, forKey: .organDeltaRetainPackageIDs)
        try container.encode(organDeltaRollbackSafePackageIDs, forKey: .organDeltaRollbackSafePackageIDs)
        try container.encode(organDeltaTriggeredActuationKinds, forKey: .organDeltaTriggeredActuationKinds)
        try container.encode(organDeltaReasonCodes, forKey: .organDeltaReasonCodes)
        try container.encodeIfPresent(hotColdPreloadPolicy, forKey: .hotColdPreloadPolicy)
        try container.encodeIfPresent(hotColdEvictionPolicy, forKey: .hotColdEvictionPolicy)
        try container.encodeIfPresent(schedulerCadenceTag, forKey: .schedulerCadenceTag)
        try container.encodeIfPresent(schedulerCheckpointCadence, forKey: .schedulerCheckpointCadence)
        try container.encodeIfPresent(schedulerMicroSleepWindowMs, forKey: .schedulerMicroSleepWindowMs)
        try container.encodeIfPresent(schedulerBackgroundMaintenanceWindowMs, forKey: .schedulerBackgroundMaintenanceWindowMs)
        try container.encodeIfPresent(schedulerAllowsBackgroundMaintenance, forKey: .schedulerAllowsBackgroundMaintenance)
        try container.encodeIfPresent(schedulerAllowsMicroSleep, forKey: .schedulerAllowsMicroSleep)
        try container.encodeIfPresent(schedulerResumeBudgetClass, forKey: .schedulerResumeBudgetClass)
        try container.encode(schedulerReasonCodes, forKey: .schedulerReasonCodes)
        try container.encodeIfPresent(thermalExchangeMode, forKey: .thermalExchangeMode)
        try container.encodeIfPresent(thermalPredictedBand, forKey: .thermalPredictedBand)
        try container.encode(thermalCoolingActions, forKey: .thermalCoolingActions)
        try container.encode(thermalSuppressedOrganIDs, forKey: .thermalSuppressedOrganIDs)
        try container.encode(thermalReroutedOrganIDs, forKey: .thermalReroutedOrganIDs)
        try container.encode(thermalRerouteTargets, forKey: .thermalRerouteTargets)
        try container.encode(thermalPrecisionDowngradeRecords, forKey: .thermalPrecisionDowngradeRecords)
        try container.encode(thermalExchangeReasonCodes, forKey: .thermalExchangeReasonCodes)
        try container.encode(integrityRequiredChecks, forKey: .integrityRequiredChecks)
        try container.encode(integrityCompletedChecks, forKey: .integrityCompletedChecks)
        try container.encode(integrityFailedChecks, forKey: .integrityFailedChecks)
        try container.encodeIfPresent(integrityPurityState, forKey: .integrityPurityState)
        try container.encode(integrityContaminationRefs, forKey: .integrityContaminationRefs)
        try container.encodeIfPresent(integrityTrustedSnapshotRef, forKey: .integrityTrustedSnapshotRef)
        try container.encodeIfPresent(integrityVerificationHash, forKey: .integrityVerificationHash)
        try container.encode(precisionOrganPrecisionRecords, forKey: .precisionOrganPrecisionRecords)
        try container.encode(precisionLockedOrganIDs, forKey: .precisionLockedOrganIDs)
        try container.encode(precisionDegradationOrder, forKey: .precisionDegradationOrder)
        try container.encodeIfPresent(precisionGuardSafeFloorID, forKey: .precisionGuardSafeFloorID)
    }
}

public struct BASEvolutionLineageSummary: Codable, Equatable, Sendable, BASSchemaVersioned {
    public static let currentSchemaVersion = "1.14.0"

    public struct ContextSummary: Codable, Equatable, Sendable {
        public let emotionalLoadPercent: Int
        public let timePressurePercent: Int
        public let relationPattern: String
        public let ambiguityPercent: Int
        public let consequencePercent: Int
        public let manipulationHintCount: Int
        public let sceneType: String?
        public let roleRelationClass: String?
        public let powerDirection: String?
        public let powerStrengthPercent: Int?
        public let urgencyPercent: Int?
        public let routeMode: String?
        public let guardRequired: Bool?
        public let continuityArc: String?

        public init(
            emotionalLoadPercent: Int,
            timePressurePercent: Int,
            relationPattern: String,
            ambiguityPercent: Int,
            consequencePercent: Int,
            manipulationHintCount: Int,
            sceneType: String? = nil,
            roleRelationClass: String? = nil,
            powerDirection: String? = nil,
            powerStrengthPercent: Int? = nil,
            urgencyPercent: Int? = nil,
            routeMode: String? = nil,
            guardRequired: Bool? = nil,
            continuityArc: String? = nil
        ) {
            self.emotionalLoadPercent = emotionalLoadPercent
            self.timePressurePercent = timePressurePercent
            self.relationPattern = relationPattern
            self.ambiguityPercent = ambiguityPercent
            self.consequencePercent = consequencePercent
            self.manipulationHintCount = manipulationHintCount
            self.sceneType = sceneType
            self.roleRelationClass = roleRelationClass
            self.powerDirection = powerDirection
            self.powerStrengthPercent = powerStrengthPercent
            self.urgencyPercent = urgencyPercent
            self.routeMode = routeMode
            self.guardRequired = guardRequired
            self.continuityArc = continuityArc
        }
    }

    public struct CognitionSummary: Codable, Equatable, Sendable {
        public let factCount: Int
        public let goalCount: Int
        public let claimCount: Int?
        public let unknownCount: Int
        public let contradictionCount: Int
        public let pressureSummary: String?
        public let manipulationSummary: String?
        public let boundarySummary: String?
        public let mirrorModeID: String?
        public let routeHint: String?
        public let memoryAtomCount: Int
        public let candidateCount: Int
        public let forecastCount: Int
        public let critiqueCount: Int
        public let stopReasonID: String?
        public let mirrorCalibrationPointCount: Int?
        public let mirrorOmittedSpeculationCount: Int?
        public let mirrorToneGuard: String?

        public init(
            factCount: Int,
            goalCount: Int,
            claimCount: Int? = nil,
            unknownCount: Int,
            contradictionCount: Int,
            pressureSummary: String? = nil,
            manipulationSummary: String? = nil,
            boundarySummary: String? = nil,
            mirrorModeID: String? = nil,
            routeHint: String? = nil,
            memoryAtomCount: Int,
            candidateCount: Int,
            forecastCount: Int,
            critiqueCount: Int,
            stopReasonID: String? = nil,
            mirrorCalibrationPointCount: Int? = nil,
            mirrorOmittedSpeculationCount: Int? = nil,
            mirrorToneGuard: String? = nil
        ) {
            self.factCount = factCount
            self.goalCount = goalCount
            self.claimCount = claimCount
            self.unknownCount = unknownCount
            self.contradictionCount = contradictionCount
            self.pressureSummary = pressureSummary
            self.manipulationSummary = manipulationSummary
            self.boundarySummary = boundarySummary
            self.mirrorModeID = mirrorModeID
            self.routeHint = routeHint
            self.memoryAtomCount = memoryAtomCount
            self.candidateCount = candidateCount
            self.forecastCount = forecastCount
            self.critiqueCount = critiqueCount
            self.stopReasonID = stopReasonID
            self.mirrorCalibrationPointCount = mirrorCalibrationPointCount
            self.mirrorOmittedSpeculationCount = mirrorOmittedSpeculationCount
            self.mirrorToneGuard = mirrorToneGuard
        }
    }

    public struct AdjudicationSummary: Codable, Equatable, Sendable {
        public let triScoreCount: Int
        public let vetoCount: Int
        public let gsiPercent: Int
        public let alternativeActionCount: Int
        public let emergencyBrakeLevelID: String?

        public init(
            triScoreCount: Int,
            vetoCount: Int,
            gsiPercent: Int,
            alternativeActionCount: Int,
            emergencyBrakeLevelID: String? = nil
        ) {
            self.triScoreCount = triScoreCount
            self.vetoCount = vetoCount
            self.gsiPercent = gsiPercent
            self.alternativeActionCount = alternativeActionCount
            self.emergencyBrakeLevelID = emergencyBrakeLevelID
        }
    }

    public struct GovernanceSummary: Codable, Equatable, Sendable {
        public let experienceCandidateCount: Int
        public let experienceCandidateTypeCounts: [String: Int]
        public let workflowCandidateCount: Int
        public let guardTemplateCandidateCount: Int
        public let biasRecordCount: Int
        public let riskPatternCandidateCount: Int
        public let learningExportBundleCount: Int
        public let pendingNurseryCandidateCount: Int
        public let passedShadowTrialCount: Int
        public let failedShadowTrialCount: Int
        public let shadowTrialCount: Int
        public let pendingShadowTrialCount: Int
        public let sealCount: Int
        public let deniedSealCount: Int
        public let pendingSealCount: Int
        public let versionDeltaCount: Int
        public let versionDeltaHighlights: [String]
        public let retractionOrderCount: Int
        public let retractionOrderHighlights: [String]
        public let pendingRetractionCount: Int
        public let blockedPromotionReasonCodes: [String]
        public let dreamLoopStoppingMode: String?
        public let dreamLoopSignalRefs: [String]
        public let dreamLoopRemandTargets: [String]
        public let dreamLoopReservationMode: String?
        public let dreamLoopMaxEvidenceDebtPercent: Int?

        public init(
            experienceCandidateCount: Int,
            experienceCandidateTypeCounts: [String: Int] = [:],
            workflowCandidateCount: Int = 0,
            guardTemplateCandidateCount: Int = 0,
            biasRecordCount: Int = 0,
            riskPatternCandidateCount: Int = 0,
            learningExportBundleCount: Int = 0,
            pendingNurseryCandidateCount: Int = 0,
            passedShadowTrialCount: Int = 0,
            failedShadowTrialCount: Int = 0,
            shadowTrialCount: Int,
            pendingShadowTrialCount: Int,
            sealCount: Int,
            deniedSealCount: Int = 0,
            pendingSealCount: Int,
            versionDeltaCount: Int,
            versionDeltaHighlights: [String] = [],
            retractionOrderCount: Int,
            retractionOrderHighlights: [String] = [],
            pendingRetractionCount: Int,
            blockedPromotionReasonCodes: [String] = [],
            dreamLoopStoppingMode: String? = nil,
            dreamLoopSignalRefs: [String] = [],
            dreamLoopRemandTargets: [String] = [],
            dreamLoopReservationMode: String? = nil,
            dreamLoopMaxEvidenceDebtPercent: Int? = nil
        ) {
            self.experienceCandidateCount = max(0, experienceCandidateCount)
            self.experienceCandidateTypeCounts = experienceCandidateTypeCounts
            self.workflowCandidateCount = max(0, workflowCandidateCount)
            self.guardTemplateCandidateCount = max(0, guardTemplateCandidateCount)
            self.biasRecordCount = max(0, biasRecordCount)
            self.riskPatternCandidateCount = max(0, riskPatternCandidateCount)
            self.learningExportBundleCount = max(0, learningExportBundleCount)
            self.pendingNurseryCandidateCount = max(0, pendingNurseryCandidateCount)
            self.passedShadowTrialCount = max(0, passedShadowTrialCount)
            self.failedShadowTrialCount = max(0, failedShadowTrialCount)
            self.shadowTrialCount = max(0, shadowTrialCount)
            self.pendingShadowTrialCount = max(0, pendingShadowTrialCount)
            self.sealCount = max(0, sealCount)
            self.deniedSealCount = max(0, deniedSealCount)
            self.pendingSealCount = max(0, pendingSealCount)
            self.versionDeltaCount = max(0, versionDeltaCount)
            self.versionDeltaHighlights = versionDeltaHighlights
            self.retractionOrderCount = max(0, retractionOrderCount)
            self.retractionOrderHighlights = retractionOrderHighlights
            self.pendingRetractionCount = max(0, pendingRetractionCount)
            self.blockedPromotionReasonCodes = blockedPromotionReasonCodes
            self.dreamLoopStoppingMode = dreamLoopStoppingMode?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.dreamLoopSignalRefs = dreamLoopSignalRefs
            self.dreamLoopRemandTargets = dreamLoopRemandTargets
            self.dreamLoopReservationMode = dreamLoopReservationMode?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.dreamLoopMaxEvidenceDebtPercent = dreamLoopMaxEvidenceDebtPercent.map { max(0, min(100, $0)) }
        }

        private enum CodingKeys: String, CodingKey {
            case experienceCandidateCount
            case experienceCandidateTypeCounts
            case workflowCandidateCount
            case guardTemplateCandidateCount
            case biasRecordCount
            case riskPatternCandidateCount
            case learningExportBundleCount
            case pendingNurseryCandidateCount
            case passedShadowTrialCount
            case failedShadowTrialCount
            case shadowTrialCount
            case pendingShadowTrialCount
            case sealCount
            case deniedSealCount
            case pendingSealCount
            case versionDeltaCount
            case versionDeltaHighlights
            case retractionOrderCount
            case retractionOrderHighlights
            case pendingRetractionCount
            case blockedPromotionReasonCodes
            case dreamLoopStoppingMode
            case dreamLoopSignalRefs
            case dreamLoopRemandTargets
            case dreamLoopReservationMode
            case dreamLoopMaxEvidenceDebtPercent
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                experienceCandidateCount: try container.decodeIfPresent(Int.self, forKey: .experienceCandidateCount) ?? 0,
                experienceCandidateTypeCounts: try container.decodeIfPresent([String: Int].self, forKey: .experienceCandidateTypeCounts) ?? [:],
                workflowCandidateCount: try container.decodeIfPresent(Int.self, forKey: .workflowCandidateCount) ?? 0,
                guardTemplateCandidateCount: try container.decodeIfPresent(Int.self, forKey: .guardTemplateCandidateCount) ?? 0,
                biasRecordCount: try container.decodeIfPresent(Int.self, forKey: .biasRecordCount) ?? 0,
                riskPatternCandidateCount: try container.decodeIfPresent(Int.self, forKey: .riskPatternCandidateCount) ?? 0,
                learningExportBundleCount: try container.decodeIfPresent(Int.self, forKey: .learningExportBundleCount) ?? 0,
                pendingNurseryCandidateCount: try container.decodeIfPresent(Int.self, forKey: .pendingNurseryCandidateCount) ?? 0,
                passedShadowTrialCount: try container.decodeIfPresent(Int.self, forKey: .passedShadowTrialCount) ?? 0,
                failedShadowTrialCount: try container.decodeIfPresent(Int.self, forKey: .failedShadowTrialCount) ?? 0,
                shadowTrialCount: try container.decodeIfPresent(Int.self, forKey: .shadowTrialCount) ?? 0,
                pendingShadowTrialCount: try container.decodeIfPresent(Int.self, forKey: .pendingShadowTrialCount) ?? 0,
                sealCount: try container.decodeIfPresent(Int.self, forKey: .sealCount) ?? 0,
                deniedSealCount: try container.decodeIfPresent(Int.self, forKey: .deniedSealCount) ?? 0,
                pendingSealCount: try container.decodeIfPresent(Int.self, forKey: .pendingSealCount) ?? 0,
                versionDeltaCount: try container.decodeIfPresent(Int.self, forKey: .versionDeltaCount) ?? 0,
                versionDeltaHighlights: try container.decodeIfPresent([String].self, forKey: .versionDeltaHighlights) ?? [],
                retractionOrderCount: try container.decodeIfPresent(Int.self, forKey: .retractionOrderCount) ?? 0,
                retractionOrderHighlights: try container.decodeIfPresent([String].self, forKey: .retractionOrderHighlights) ?? [],
                pendingRetractionCount: try container.decodeIfPresent(Int.self, forKey: .pendingRetractionCount) ?? 0,
                blockedPromotionReasonCodes: try container.decodeIfPresent([String].self, forKey: .blockedPromotionReasonCodes) ?? [],
                dreamLoopStoppingMode: try container.decodeIfPresent(String.self, forKey: .dreamLoopStoppingMode),
                dreamLoopSignalRefs: try container.decodeIfPresent([String].self, forKey: .dreamLoopSignalRefs) ?? [],
                dreamLoopRemandTargets: try container.decodeIfPresent([String].self, forKey: .dreamLoopRemandTargets) ?? [],
                dreamLoopReservationMode: try container.decodeIfPresent(String.self, forKey: .dreamLoopReservationMode),
                dreamLoopMaxEvidenceDebtPercent: try container.decodeIfPresent(Int.self, forKey: .dreamLoopMaxEvidenceDebtPercent)
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(experienceCandidateCount, forKey: .experienceCandidateCount)
            try container.encode(experienceCandidateTypeCounts, forKey: .experienceCandidateTypeCounts)
            try container.encode(workflowCandidateCount, forKey: .workflowCandidateCount)
            try container.encode(guardTemplateCandidateCount, forKey: .guardTemplateCandidateCount)
            try container.encode(biasRecordCount, forKey: .biasRecordCount)
            try container.encode(riskPatternCandidateCount, forKey: .riskPatternCandidateCount)
            try container.encode(learningExportBundleCount, forKey: .learningExportBundleCount)
            try container.encode(pendingNurseryCandidateCount, forKey: .pendingNurseryCandidateCount)
            try container.encode(passedShadowTrialCount, forKey: .passedShadowTrialCount)
            try container.encode(failedShadowTrialCount, forKey: .failedShadowTrialCount)
            try container.encode(shadowTrialCount, forKey: .shadowTrialCount)
            try container.encode(pendingShadowTrialCount, forKey: .pendingShadowTrialCount)
            try container.encode(sealCount, forKey: .sealCount)
            try container.encode(deniedSealCount, forKey: .deniedSealCount)
            try container.encode(pendingSealCount, forKey: .pendingSealCount)
            try container.encode(versionDeltaCount, forKey: .versionDeltaCount)
            try container.encode(versionDeltaHighlights, forKey: .versionDeltaHighlights)
            try container.encode(retractionOrderCount, forKey: .retractionOrderCount)
            try container.encode(retractionOrderHighlights, forKey: .retractionOrderHighlights)
            try container.encode(pendingRetractionCount, forKey: .pendingRetractionCount)
            try container.encode(blockedPromotionReasonCodes, forKey: .blockedPromotionReasonCodes)
            try container.encodeIfPresent(dreamLoopStoppingMode, forKey: .dreamLoopStoppingMode)
            try container.encode(dreamLoopSignalRefs, forKey: .dreamLoopSignalRefs)
            try container.encode(dreamLoopRemandTargets, forKey: .dreamLoopRemandTargets)
            try container.encodeIfPresent(dreamLoopReservationMode, forKey: .dreamLoopReservationMode)
            try container.encodeIfPresent(dreamLoopMaxEvidenceDebtPercent, forKey: .dreamLoopMaxEvidenceDebtPercent)
        }
    }

    public let schemaVersion: String
    public let recordedAt: Date
    public let sessionID: String
    public let runMode: BASEBrainRunMode?
    public let taskType: String
    public let riskLevel: String
    public let permitMode: String
    public let hostGatePercent: Int
    public let thoughtFoldChecksum: String
    public let updateTicketSummaries: [String]
    public let reviewDirectiveLine: String?
    public let hostChangeCandidateIDs: [String]
    public let hostChangeTypes: [String]
    public let activeKillSwitches: [String]
    public let guardrailFindings: [String]
    public let recommendedKillSwitches: [String]
    public let stackedModes: [String]
    public let assertionCeiling: String?
    public let allowedDomains: [String]
    public let blockedDomains: [String]
    public let delayType: String?
    public let substituteType: String?
    public let sovereignHintLevel: String?
    public let wakeIntent: BASWakeIntent?
    public let vitalState: BASVitalState?
    public let runLease: BASRunLease?
    public let emergencyBrake: BASEmergencyBrake?
    public let sovereignVerdict: BASSovereignVerdict?
    public let sovereignCommitTokens: [BASSovereignCommitToken]
    public let sovereignWarrants: [BASSovereignWarrant]
    public let sovereignLock: BASSovereignLock?
    public let quarantineRecords: [BASQuarantineRecord]
    public let sovereignAuditEntry: BASSovereignAuditEntry?
    public let sovereignActuationCommands: [BASSovereignActuationCommand]
    public let sovereignExecutionReceipts: [BASSovereignExecutionReceipt]
    public let policyLineage: BASRuntimePolicyLineage?
    public let recoveryDisposition: BASRecoveryDisposition?
    public let neuralMorphID: String?
    public let activeOrganIDs: [String]
    public let headGuarantees: [String]
    public let frontierWidth: Int?
    public let bindingCount: Int
    public let projectionLeadCandidateID: String?
    public let projectionCandidateCount: Int
    public let projectionForecastCount: Int
    public let projectionCritiqueCount: Int
    public let degradedReasonCodes: [String]
    public let contextSummary: ContextSummary?
    public let cognitionSummary: CognitionSummary?
    public let adjudicationSummary: AdjudicationSummary?
    public let foldedLungSummary: BASEvolutionFoldedLungSummary?
    public let governanceSummary: GovernanceSummary?

    public init(
        schemaVersion: String = BASEvolutionLineageSummary.currentSchemaVersion,
        recordedAt: Date,
        sessionID: String,
        runMode: BASEBrainRunMode? = nil,
        taskType: String,
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int,
        thoughtFoldChecksum: String,
        updateTicketSummaries: [String],
        reviewDirectiveLine: String? = nil,
        hostChangeCandidateIDs: [String] = [],
        hostChangeTypes: [String] = [],
        activeKillSwitches: [String] = [],
        guardrailFindings: [String],
        recommendedKillSwitches: [String],
        stackedModes: [String] = [],
        assertionCeiling: String? = nil,
        allowedDomains: [String] = [],
        blockedDomains: [String] = [],
        delayType: String? = nil,
        substituteType: String? = nil,
        sovereignHintLevel: String? = nil,
        wakeIntent: BASWakeIntent? = nil,
        vitalState: BASVitalState? = nil,
        runLease: BASRunLease? = nil,
        emergencyBrake: BASEmergencyBrake? = nil,
        sovereignVerdict: BASSovereignVerdict? = nil,
        sovereignCommitTokens: [BASSovereignCommitToken] = [],
        sovereignWarrants: [BASSovereignWarrant] = [],
        sovereignLock: BASSovereignLock? = nil,
        quarantineRecords: [BASQuarantineRecord] = [],
        sovereignAuditEntry: BASSovereignAuditEntry? = nil,
        sovereignActuationCommands: [BASSovereignActuationCommand] = [],
        sovereignExecutionReceipts: [BASSovereignExecutionReceipt] = [],
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        neuralMorphID: String? = nil,
        activeOrganIDs: [String] = [],
        headGuarantees: [String] = [],
        frontierWidth: Int? = nil,
        bindingCount: Int = 0,
        projectionLeadCandidateID: String? = nil,
        projectionCandidateCount: Int = 0,
        projectionForecastCount: Int = 0,
        projectionCritiqueCount: Int = 0,
        degradedReasonCodes: [String] = [],
        contextSummary: ContextSummary? = nil,
        cognitionSummary: CognitionSummary? = nil,
        adjudicationSummary: AdjudicationSummary? = nil,
        foldedLungSummary: BASEvolutionFoldedLungSummary? = nil,
        governanceSummary: GovernanceSummary? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.recordedAt = recordedAt
        self.sessionID = sessionID
        self.runMode = runMode
        self.taskType = taskType
        self.riskLevel = riskLevel
        self.permitMode = permitMode
        self.hostGatePercent = hostGatePercent
        self.thoughtFoldChecksum = thoughtFoldChecksum
        self.updateTicketSummaries = updateTicketSummaries
        self.reviewDirectiveLine = reviewDirectiveLine
        self.hostChangeCandidateIDs = hostChangeCandidateIDs
        self.hostChangeTypes = hostChangeTypes
        self.activeKillSwitches = activeKillSwitches
        self.guardrailFindings = guardrailFindings
        self.recommendedKillSwitches = recommendedKillSwitches
        self.stackedModes = stackedModes
        self.assertionCeiling = assertionCeiling
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.delayType = delayType
        self.substituteType = substituteType
        self.sovereignHintLevel = sovereignHintLevel
        self.wakeIntent = wakeIntent
        self.vitalState = vitalState
        self.runLease = runLease
        self.emergencyBrake = emergencyBrake
        self.sovereignVerdict = sovereignVerdict
        self.sovereignCommitTokens = sovereignCommitTokens
        self.sovereignWarrants = sovereignWarrants
        self.sovereignLock = sovereignLock
        self.quarantineRecords = quarantineRecords
        self.sovereignAuditEntry = sovereignAuditEntry
        self.sovereignActuationCommands = sovereignActuationCommands
        self.sovereignExecutionReceipts = sovereignExecutionReceipts
        self.policyLineage = policyLineage
        self.recoveryDisposition = recoveryDisposition
        self.neuralMorphID = neuralMorphID
        self.activeOrganIDs = activeOrganIDs
        self.headGuarantees = headGuarantees
        self.frontierWidth = frontierWidth
        self.bindingCount = bindingCount
        self.projectionLeadCandidateID = projectionLeadCandidateID
        self.projectionCandidateCount = projectionCandidateCount
        self.projectionForecastCount = projectionForecastCount
        self.projectionCritiqueCount = projectionCritiqueCount
        self.degradedReasonCodes = degradedReasonCodes
        self.contextSummary = contextSummary
        self.cognitionSummary = cognitionSummary
        self.adjudicationSummary = adjudicationSummary
        self.foldedLungSummary = foldedLungSummary
        self.governanceSummary = governanceSummary
    }

    public init(
        recordedAt: Date,
        sessionID: String,
        runMode: BASEBrainRunMode? = nil,
        taskType: String,
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int,
        thoughtFoldChecksum: String,
        updateTicketSummaries: [String],
        reviewDirectiveLine: String? = nil,
        hostChangeCandidateIDs: [String] = [],
        hostChangeTypes: [String] = [],
        guardrailFindings: [String],
        recommendedKillSwitches: [String]
    ) {
        self.init(
            recordedAt: recordedAt,
            sessionID: sessionID,
            runMode: runMode,
            taskType: taskType,
            riskLevel: riskLevel,
            permitMode: permitMode,
            hostGatePercent: hostGatePercent,
            thoughtFoldChecksum: thoughtFoldChecksum,
            updateTicketSummaries: updateTicketSummaries,
            reviewDirectiveLine: reviewDirectiveLine,
            hostChangeCandidateIDs: hostChangeCandidateIDs,
            hostChangeTypes: hostChangeTypes,
            activeKillSwitches: [],
            guardrailFindings: guardrailFindings,
            recommendedKillSwitches: recommendedKillSwitches
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case recordedAt
        case sessionID
        case runMode
        case taskType
        case riskLevel
        case permitMode
        case hostGatePercent
        case thoughtFoldChecksum
        case updateTicketSummaries
        case reviewDirectiveLine
        case hostChangeCandidateIDs
        case hostChangeTypes
        case activeKillSwitches
        case guardrailFindings
        case recommendedKillSwitches
        case stackedModes
        case assertionCeiling
        case allowedDomains
        case blockedDomains
        case delayType
        case substituteType
        case sovereignHintLevel
        case wakeIntent
        case vitalState
        case runLease
        case emergencyBrake
        case sovereignVerdict
        case sovereignCommitTokens
        case sovereignWarrants
        case sovereignLock
        case quarantineRecords
        case sovereignAuditEntry
        case sovereignActuationCommands
        case sovereignExecutionReceipts
        case policyLineage
        case recoveryDisposition
        case neuralMorphID
        case activeOrganIDs
        case headGuarantees
        case frontierWidth
        case bindingCount
        case projectionLeadCandidateID
        case projectionCandidateCount
        case projectionForecastCount
        case projectionCritiqueCount
        case degradedReasonCodes
        case contextSummary
        case cognitionSummary
        case adjudicationSummary
        case foldedLungSummary
        case governanceSummary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASEvolutionLineageSummary.currentSchemaVersion
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        runMode = try container.decodeIfPresent(BASEBrainRunMode.self, forKey: .runMode)
        taskType = try container.decode(String.self, forKey: .taskType)
        riskLevel = try container.decode(String.self, forKey: .riskLevel)
        permitMode = try container.decode(String.self, forKey: .permitMode)
        hostGatePercent = try container.decode(Int.self, forKey: .hostGatePercent)
        thoughtFoldChecksum = try container.decode(String.self, forKey: .thoughtFoldChecksum)
        updateTicketSummaries = try container.decode([String].self, forKey: .updateTicketSummaries)
        reviewDirectiveLine = try container.decodeIfPresent(String.self, forKey: .reviewDirectiveLine)
        hostChangeCandidateIDs = try container.decodeIfPresent([String].self, forKey: .hostChangeCandidateIDs) ?? []
        hostChangeTypes = try container.decodeIfPresent([String].self, forKey: .hostChangeTypes) ?? []
        activeKillSwitches = try container.decodeIfPresent([String].self, forKey: .activeKillSwitches) ?? []
        guardrailFindings = try container.decode([String].self, forKey: .guardrailFindings)
        recommendedKillSwitches = try container.decode([String].self, forKey: .recommendedKillSwitches)
        stackedModes = try container.decodeIfPresent([String].self, forKey: .stackedModes) ?? []
        assertionCeiling = try container.decodeIfPresent(String.self, forKey: .assertionCeiling)
        allowedDomains = try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? []
        blockedDomains = try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? []
        delayType = try container.decodeIfPresent(String.self, forKey: .delayType)
        substituteType = try container.decodeIfPresent(String.self, forKey: .substituteType)
        sovereignHintLevel = try container.decodeIfPresent(String.self, forKey: .sovereignHintLevel)
        wakeIntent = try container.decodeIfPresent(BASWakeIntent.self, forKey: .wakeIntent)
        vitalState = try container.decodeIfPresent(BASVitalState.self, forKey: .vitalState)
        runLease = try container.decodeIfPresent(BASRunLease.self, forKey: .runLease)
        emergencyBrake = try container.decodeIfPresent(BASEmergencyBrake.self, forKey: .emergencyBrake)
        sovereignVerdict = try container.decodeIfPresent(BASSovereignVerdict.self, forKey: .sovereignVerdict)
        sovereignCommitTokens = try container.decodeIfPresent(
            [BASSovereignCommitToken].self,
            forKey: .sovereignCommitTokens
        ) ?? []
        sovereignWarrants = try container.decodeIfPresent(
            [BASSovereignWarrant].self,
            forKey: .sovereignWarrants
        ) ?? []
        sovereignLock = try container.decodeIfPresent(BASSovereignLock.self, forKey: .sovereignLock)
        quarantineRecords = try container.decodeIfPresent(
            [BASQuarantineRecord].self,
            forKey: .quarantineRecords
        ) ?? []
        sovereignAuditEntry = try container.decodeIfPresent(
            BASSovereignAuditEntry.self,
            forKey: .sovereignAuditEntry
        )
        sovereignActuationCommands = try container.decodeIfPresent(
            [BASSovereignActuationCommand].self,
            forKey: .sovereignActuationCommands
        ) ?? []
        sovereignExecutionReceipts = try container.decodeIfPresent(
            [BASSovereignExecutionReceipt].self,
            forKey: .sovereignExecutionReceipts
        ) ?? []
        policyLineage = try container.decodeIfPresent(BASRuntimePolicyLineage.self, forKey: .policyLineage)
        recoveryDisposition = try container.decodeIfPresent(BASRecoveryDisposition.self, forKey: .recoveryDisposition)
        neuralMorphID = try container.decodeIfPresent(String.self, forKey: .neuralMorphID)
        activeOrganIDs = try container.decodeIfPresent([String].self, forKey: .activeOrganIDs) ?? []
        headGuarantees = try container.decodeIfPresent([String].self, forKey: .headGuarantees) ?? []
        frontierWidth = try container.decodeIfPresent(Int.self, forKey: .frontierWidth)
        bindingCount = try container.decodeIfPresent(Int.self, forKey: .bindingCount) ?? 0
        projectionLeadCandidateID = try container.decodeIfPresent(String.self, forKey: .projectionLeadCandidateID)
        projectionCandidateCount = try container.decodeIfPresent(Int.self, forKey: .projectionCandidateCount) ?? 0
        projectionForecastCount = try container.decodeIfPresent(Int.self, forKey: .projectionForecastCount) ?? 0
        projectionCritiqueCount = try container.decodeIfPresent(Int.self, forKey: .projectionCritiqueCount) ?? 0
        degradedReasonCodes = try container.decodeIfPresent([String].self, forKey: .degradedReasonCodes) ?? []
        contextSummary = try container.decodeIfPresent(ContextSummary.self, forKey: .contextSummary)
        cognitionSummary = try container.decodeIfPresent(CognitionSummary.self, forKey: .cognitionSummary)
        adjudicationSummary = try container.decodeIfPresent(AdjudicationSummary.self, forKey: .adjudicationSummary)
        foldedLungSummary = try container.decodeIfPresent(
            BASEvolutionFoldedLungSummary.self,
            forKey: .foldedLungSummary
        )
        governanceSummary = try container.decodeIfPresent(
            GovernanceSummary.self,
            forKey: .governanceSummary
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(recordedAt, forKey: .recordedAt)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(runMode, forKey: .runMode)
        try container.encode(taskType, forKey: .taskType)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encode(permitMode, forKey: .permitMode)
        try container.encode(hostGatePercent, forKey: .hostGatePercent)
        try container.encode(thoughtFoldChecksum, forKey: .thoughtFoldChecksum)
        try container.encode(updateTicketSummaries, forKey: .updateTicketSummaries)
        try container.encodeIfPresent(reviewDirectiveLine, forKey: .reviewDirectiveLine)
        try container.encode(hostChangeCandidateIDs, forKey: .hostChangeCandidateIDs)
        try container.encode(hostChangeTypes, forKey: .hostChangeTypes)
        try container.encode(activeKillSwitches, forKey: .activeKillSwitches)
        try container.encode(guardrailFindings, forKey: .guardrailFindings)
        try container.encode(recommendedKillSwitches, forKey: .recommendedKillSwitches)
        try container.encode(stackedModes, forKey: .stackedModes)
        try container.encodeIfPresent(assertionCeiling, forKey: .assertionCeiling)
        try container.encode(allowedDomains, forKey: .allowedDomains)
        try container.encode(blockedDomains, forKey: .blockedDomains)
        try container.encodeIfPresent(delayType, forKey: .delayType)
        try container.encodeIfPresent(substituteType, forKey: .substituteType)
        try container.encodeIfPresent(sovereignHintLevel, forKey: .sovereignHintLevel)
        try container.encodeIfPresent(wakeIntent, forKey: .wakeIntent)
        try container.encodeIfPresent(vitalState, forKey: .vitalState)
        try container.encodeIfPresent(runLease, forKey: .runLease)
        try container.encodeIfPresent(emergencyBrake, forKey: .emergencyBrake)
        try container.encodeIfPresent(sovereignVerdict, forKey: .sovereignVerdict)
        try container.encode(sovereignCommitTokens, forKey: .sovereignCommitTokens)
        try container.encode(sovereignWarrants, forKey: .sovereignWarrants)
        try container.encodeIfPresent(sovereignLock, forKey: .sovereignLock)
        try container.encode(quarantineRecords, forKey: .quarantineRecords)
        try container.encodeIfPresent(sovereignAuditEntry, forKey: .sovereignAuditEntry)
        try container.encode(sovereignActuationCommands, forKey: .sovereignActuationCommands)
        try container.encode(sovereignExecutionReceipts, forKey: .sovereignExecutionReceipts)
        try container.encodeIfPresent(policyLineage, forKey: .policyLineage)
        try container.encodeIfPresent(recoveryDisposition, forKey: .recoveryDisposition)
        try container.encodeIfPresent(neuralMorphID, forKey: .neuralMorphID)
        try container.encode(activeOrganIDs, forKey: .activeOrganIDs)
        try container.encode(headGuarantees, forKey: .headGuarantees)
        try container.encodeIfPresent(frontierWidth, forKey: .frontierWidth)
        try container.encode(bindingCount, forKey: .bindingCount)
        try container.encodeIfPresent(projectionLeadCandidateID, forKey: .projectionLeadCandidateID)
        try container.encode(projectionCandidateCount, forKey: .projectionCandidateCount)
        try container.encode(projectionForecastCount, forKey: .projectionForecastCount)
        try container.encode(projectionCritiqueCount, forKey: .projectionCritiqueCount)
        try container.encode(degradedReasonCodes, forKey: .degradedReasonCodes)
        try container.encodeIfPresent(contextSummary, forKey: .contextSummary)
        try container.encodeIfPresent(cognitionSummary, forKey: .cognitionSummary)
        try container.encodeIfPresent(adjudicationSummary, forKey: .adjudicationSummary)
        try container.encodeIfPresent(foldedLungSummary, forKey: .foldedLungSummary)
        try container.encodeIfPresent(governanceSummary, forKey: .governanceSummary)
    }
}

public struct BASEvolutionCheckpointSummary: Codable, Equatable, Sendable {
    public let id: String
    public let previousCheckpointID: String?
    public let createdAt: Date
    public let diffSummary: [String]
    public let rollbackReady: Bool
    public let approvalState: BASEvolutionApprovalState
    public let lineageSummary: BASEvolutionLineageSummary?

    public init(
        id: String,
        previousCheckpointID: String?,
        createdAt: Date,
        diffSummary: [String],
        rollbackReady: Bool,
        approvalState: BASEvolutionApprovalState,
        lineageSummary: BASEvolutionLineageSummary? = nil
    ) {
        self.id = id
        self.previousCheckpointID = previousCheckpointID
        self.createdAt = createdAt
        self.diffSummary = diffSummary
        self.rollbackReady = rollbackReady
        self.approvalState = approvalState
        self.lineageSummary = lineageSummary
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
    public var externallyRefreshedCandidateCount: Int = 0
    public var quarantinedObservationCount: Int = 0
    public var evidenceCaveatedCandidateCount: Int = 0
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
        externallyRefreshedCandidateCount: Int = 0,
        quarantinedObservationCount: Int = 0,
        evidenceCaveatedCandidateCount: Int = 0,
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
        self.externallyRefreshedCandidateCount = externallyRefreshedCandidateCount
        self.quarantinedObservationCount = quarantinedObservationCount
        self.evidenceCaveatedCandidateCount = evidenceCaveatedCandidateCount
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
        let resolvedIdentity = identityProfile ?? BASIdentityProfile.default(modeName: "generic")
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
        let loadedRetrievalTags = Set(memorySlices.flatMap(\.retrievalTags))

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
        if (memoryGovernance.screenedOutReasonCounts[.externalRefreshNoOverlap] ?? 0) > 0 {
            riskFlags.append(.externalRefreshGuardTriggered)
        }
        if loadedRetrievalTags.contains("quarantined") ||
            loadedRetrievalTags.contains("tool_observation") ||
            memoryGovernance.quarantinedObservationCount > 0 {
            riskFlags.append(.observationOnlyQuarantine)
        }
        if loadedRetrievalTags.contains("evidence_caveat") ||
            memoryGovernance.evidenceCaveatedCandidateCount > 0 {
            riskFlags.append(.evidenceCaveatLoad)
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
                source: "archive",
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
                source: "archive",
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

    public static func shouldAdmit(
        candidate: BASMemoryCandidate,
        under constitution: BASHostConstitution,
        minimumConfidence: Double = 0.6
    ) -> Bool {
        guard shouldAdmit(candidate: candidate, minimumConfidence: minimumConfidence) else {
            return false
        }

        let writeScope = constitution.consentLattice.memoryWriteScope
        if writeScope == "disabled" || writeScope == "none" {
            return false
        }

        return true
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

    public static func promote(
        candidate: BASMemoryCandidate,
        under constitution: BASHostConstitution,
        lastConfirmedAt: Date? = nil,
        decayScore: Double = 0.0,
        provenanceSummary: String? = nil,
        governanceStatus: BASMemoryGovernanceStatus = .governed
    ) -> BASGovernedMemory {
        let restrictedDomains = Set(constitution.boundaryVeil.restrictedMemoryDomains)
        let sensitiveDomains = Set(constitution.protectionRing.sensitiveDomains)
        let candidateTags = Set(candidate.event.tags)
        let touchesRestrictedDomain = !restrictedDomains.isDisjoint(with: candidateTags)
        let touchesSensitiveDomain = !sensitiveDomains.isDisjoint(with: candidateTags)
        let requiresReview = constitution.consentLattice.memoryPromotionScope == "review_required"
            || touchesRestrictedDomain
            || touchesSensitiveDomain

        let projectedTier: BASMemoryTier
        switch constitution.consentLattice.memoryWriteScope {
        case "warm_only":
            projectedTier = .warm
        case "cold_only":
            projectedTier = .cold
        default:
            projectedTier = candidate.preferredTier
        }

        let projectedStatus = requiresReview ? BASMemoryGovernanceStatus.candidate : governanceStatus
        let phase = constitution.narrativeLoom.currentPhase
        let projectedProvenance = provenanceSummary ?? Self.constitutionProvenanceSummary(
            candidate: candidate,
            constitutionVersion: constitution.activeVersion,
            phase: phase,
            promotionScope: constitution.consentLattice.memoryPromotionScope,
            restrictedDomainTriggered: touchesRestrictedDomain,
            sensitiveDomainTriggered: touchesSensitiveDomain
        )

        return BASGovernedMemory(
            kind: candidate.event.kind,
            content: candidate.event.content,
            scope: candidate.scope,
            sensitivity: candidate.sensitivity,
            tier: projectedTier,
            confidence: candidate.confidence,
            sourceType: candidate.sourceType,
            lastConfirmedAt: lastConfirmedAt,
            decayScore: decayScore,
            governanceStatus: projectedStatus,
            provenanceSummary: projectedProvenance
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
        constitution: BASHostConstitution? = nil,
        goalHints: [String] = [],
        constraintHints: [String] = [],
        mode: String = BASDecisionMode.primaryID,
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

        let constitutionGoals = constitution?.goalSpine.goals ?? []
        let dominantGoals = Self.uniqueOrdered(goalHints + constitutionGoals + profileGoals)

        let highSensitivityConstraints = frontstage
            .filter { $0.sensitivity == .high }
            .map { "sensitive:\($0.scope.rawValue)" }

        let constitutionConstraints = (constitution?.boundaryVeil.hardNoGo ?? [])
            + (constitution?.boundaryVeil.softCaution ?? [])
        let activeConstraints = Self.uniqueOrdered(
            constraintHints + constitutionConstraints + highSensitivityConstraints
        )

        let activeTemplateIDs = frontstage
            .filter { $0.kind == .template }
            .map(\.id)

        let recentFailurePatternIDs = frontstage
            .filter { $0.kind == .failurePattern }
            .map(\.id)

        var retrievalTags = Self.uniqueOrdered(frontstage.flatMap { memory in
            [
                "tier:\(memory.tier.rawValue)",
                "scope:\(memory.scope.rawValue)",
                "kind:\(memory.kind.rawValue)",
                "source:\(memory.sourceType)"
            ]
        })

        if let constitution {
            retrievalTags = Self.uniqueOrdered(
                retrievalTags + [
                    "constitution:\(constitution.activeVersion)",
                    "constitution_phase:\(constitution.narrativeLoom.currentPhase)",
                    "constitution_value_axes:\(constitution.valueAxes.axes.count)"
                ]
            )
        }

        let projectedVerificationSnapshot: String
        if let constitution {
            projectedVerificationSnapshot = Self.uniqueOrdered([
                verificationSnapshot,
                "constitution:\(constitution.activeVersion)",
                "phase:\(constitution.narrativeLoom.currentPhase)"
            ]).joined(separator: "|")
        } else {
            projectedVerificationSnapshot = verificationSnapshot
        }

        return BASCurrentBrainState(
            mode: mode,
            dominantGoals: dominantGoals,
            activeConstraints: activeConstraints,
            reactionWeights: BASReactionWeights(warmth: 0.5, directness: 0.5, brevity: 0.5, actionBias: 0.5),
            activeTemplateIDs: activeTemplateIDs,
            recentFailurePatternIDs: recentFailurePatternIDs,
            retrievalTags: retrievalTags,
            verificationSnapshot: projectedVerificationSnapshot
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

extension BASMemoryGovernance {
    private static func constitutionProvenanceSummary(
        candidate: BASMemoryCandidate,
        constitutionVersion: String,
        phase: String,
        promotionScope: String,
        restrictedDomainTriggered: Bool,
        sensitiveDomainTriggered: Bool
    ) -> String {
        var markers = [
            "promoted from candidate:\(candidate.sourceType)",
            "constitution:\(constitutionVersion)",
            "phase:\(phase)",
            "promotion_scope:\(promotionScope)"
        ]

        if restrictedDomainTriggered {
            markers.append("restricted_domain")
        }
        if sensitiveDomainTriggered {
            markers.append("sensitive_domain")
        }

        return markers.joined(separator: "|")
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
