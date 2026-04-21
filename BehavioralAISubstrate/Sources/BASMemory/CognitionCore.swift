import CryptoKit
import Foundation
import BASRuntimeCore

public enum BASDecisionMode: String, Codable, Sendable, CaseIterable {
    case primary = "primary"
    case comparative = "comparative"
    case reflective = "reflective"

    public static let primaryID = "primary"
    public static let comparativeID = "comparative"
    public static let reflectiveID = "reflective"
    public static let genericPriorityIDs = [
        primaryID,
        comparativeID,
        reflectiveID
    ]

    public var identifier: String {
        switch self {
        case .primary:
            Self.primaryID
        case .comparative:
            Self.comparativeID
        case .reflective:
            Self.reflectiveID
        }
    }

    public init?(identifier: String) {
        switch identifier {
        case Self.primaryID:
            self = .primary
        case Self.comparativeID:
            self = .comparative
        case Self.reflectiveID:
            self = .reflective
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let mode = BASDecisionMode(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported decision mode identifier: \(identifier)"
            )
        }
        self = mode
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var title: String {
        switch self {
        case .primary:
            "Primary"
        case .comparative:
            "Comparative"
        case .reflective:
            "Reflective"
        }
    }
}

public enum BASInteractionSurface: String, Codable, Sendable, CaseIterable {
    case app
    case watch
    case widget
    case shortcut
    case siri
    case notification
    case system

    public var title: String {
        switch self {
        case .app:
            "App"
        case .watch:
            "Watch"
        case .widget:
            "Widget"
        case .shortcut:
            "Shortcut"
        case .siri:
            "Siri"
        case .notification:
            "Notification"
        case .system:
            "System"
        }
    }
}

public enum BASMemorySource: String, Codable, Sendable, CaseIterable {
    case cue
    case pattern
    case reflection
    case archive

    public init?(identifier: String) {
        switch identifier {
        case Self.cue.rawValue:
            self = .cue
        case Self.pattern.rawValue:
            self = .pattern
        case Self.reflection.rawValue:
            self = .reflection
        case Self.archive.rawValue:
            self = .archive
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let source = BASMemorySource(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported memory source identifier: \(identifier)"
            )
        }
        self = source
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var title: String {
        switch self {
        case .cue:
            "Cue"
        case .pattern:
            "Pattern"
        case .reflection:
            "Reflection"
        case .archive:
            "Archive"
        }
    }
}

public enum BASMemoryDecayPolicy: String, Codable, Sendable, CaseIterable {
    case stable
    case slow
    case medium
    case fast
}

public enum BASMemoryLoadStatus: String, Codable, Sendable, CaseIterable {
    case admitted
    case deferred
    case pending
}

public struct BASMemoryTrustProfile: Equatable, Sendable {
    public let score: Double
    public let tier: BASMemorySourceTrustTier
    public let provenanceRisk: Bool
    public let confidenceMultiplier: Double
    public let decayGraceMultiplier: Double
}

public struct BASMemoryTrustBehavior: Codable, Equatable, Sendable {
    public static let generic = BASMemoryTrustBehavior()

    public var baseScoresBySourceID: [String: Double]
    public var governanceAdjustmentsByStatusID: [String: Double]
    public var decayAdjustmentsByPolicyID: [String: Double]
    public var sourceDecayMultipliersBySourceID: [String: Double]
    public var governanceDecayMultipliersByStatusID: [String: Double]
    public var evidenceBoostPerExtraObservation: Double
    public var evidenceBoostCap: Double
    public var evidenceDecayBoostPerExtraObservation: Double
    public var evidenceDecayBoostCap: Double
    public var pendingPenalty: Double
    public var contaminationPenalty: Double
    public var pendingDecayPenalty: Double
    public var provenanceDecayPenalty: Double
    public var contaminationSignals: [String]

    public init(
        baseScoresBySourceID: [String: Double] = [
            BASMemorySource.cue.rawValue: 0.94,
            BASMemorySource.pattern.rawValue: 0.82,
            BASMemorySource.reflection.rawValue: 0.74,
            BASMemorySource.archive.rawValue: 0.66
        ],
        governanceAdjustmentsByStatusID: [String: Double] = [
            BASMemoryLoadStatus.admitted.rawValue: 0.04,
            BASMemoryLoadStatus.deferred.rawValue: -0.08,
            BASMemoryLoadStatus.pending.rawValue: -0.12
        ],
        decayAdjustmentsByPolicyID: [String: Double] = [
            BASMemoryDecayPolicy.stable.rawValue: 0.04,
            BASMemoryDecayPolicy.slow.rawValue: 0.02,
            BASMemoryDecayPolicy.medium.rawValue: 0,
            BASMemoryDecayPolicy.fast.rawValue: -0.06
        ],
        sourceDecayMultipliersBySourceID: [String: Double] = [
            BASMemorySource.cue.rawValue: 1.32,
            BASMemorySource.pattern.rawValue: 1.12,
            BASMemorySource.archive.rawValue: 0.96,
            BASMemorySource.reflection.rawValue: 0.78
        ],
        governanceDecayMultipliersByStatusID: [String: Double] = [
            BASMemoryLoadStatus.admitted.rawValue: 1.08,
            BASMemoryLoadStatus.deferred.rawValue: 0.92,
            BASMemoryLoadStatus.pending.rawValue: 0.82
        ],
        evidenceBoostPerExtraObservation: Double = 0.03,
        evidenceBoostCap: Double = 0.12,
        evidenceDecayBoostPerExtraObservation: Double = 0.04,
        evidenceDecayBoostCap: Double = 0.18,
        pendingPenalty: Double = 0.06,
        contaminationPenalty: Double = 0.24,
        pendingDecayPenalty: Double = 0.82,
        provenanceDecayPenalty: Double = 0.55,
        contaminationSignals: [String] = [
            "<script",
            "</",
            "```",
            "http://",
            "https://",
            "assistant:",
            "tool call",
            "function(",
            "\"role\":",
            "{json"
        ]
    ) {
        self.baseScoresBySourceID = baseScoresBySourceID
        self.governanceAdjustmentsByStatusID = governanceAdjustmentsByStatusID
        self.decayAdjustmentsByPolicyID = decayAdjustmentsByPolicyID
        self.sourceDecayMultipliersBySourceID = sourceDecayMultipliersBySourceID
        self.governanceDecayMultipliersByStatusID = governanceDecayMultipliersByStatusID
        self.evidenceBoostPerExtraObservation = evidenceBoostPerExtraObservation
        self.evidenceBoostCap = evidenceBoostCap
        self.evidenceDecayBoostPerExtraObservation = evidenceDecayBoostPerExtraObservation
        self.evidenceDecayBoostCap = evidenceDecayBoostCap
        self.pendingPenalty = pendingPenalty
        self.contaminationPenalty = contaminationPenalty
        self.pendingDecayPenalty = pendingDecayPenalty
        self.provenanceDecayPenalty = provenanceDecayPenalty
        self.contaminationSignals = contaminationSignals
    }
}

public enum BASMemoryTrustEngine {
    public static func profile(
        source: BASMemorySource,
        evidenceCount: Int,
        decayPolicy: BASMemoryDecayPolicy,
        governanceStatus: BASMemoryLoadStatus,
        isPending: Bool,
        provenanceSummary: String,
        behavior: BASMemoryTrustBehavior = .generic
    ) -> BASMemoryTrustProfile {
        let baseScore = resolvedDouble(
            behavior.baseScoresBySourceID,
            key: source.rawValue,
            fallback: 0.7
        )
        let evidenceBoost = min(
            behavior.evidenceBoostCap,
            Double(max(0, evidenceCount - 1)) * behavior.evidenceBoostPerExtraObservation
        )
        let governanceAdjustment = resolvedDouble(
            behavior.governanceAdjustmentsByStatusID,
            key: governanceStatus.rawValue,
            fallback: 0
        )
        let decayAdjustment = resolvedDouble(
            behavior.decayAdjustmentsByPolicyID,
            key: decayPolicy.rawValue,
            fallback: 0
        )
        let pendingPenalty = isPending ? behavior.pendingPenalty : 0
        let provenanceRisk = isContaminated(provenanceSummary, behavior: behavior)
        let contaminationPenalty = provenanceRisk ? behavior.contaminationPenalty : 0

        let score = clamp(
            baseScore +
                evidenceBoost +
                governanceAdjustment +
                decayAdjustment -
                pendingPenalty -
                contaminationPenalty,
            min: 0.15,
            max: 0.99
        )

        let tier: BASMemorySourceTrustTier
        switch score {
        case ..<0.60:
            tier = .low
        case ..<0.82:
            tier = .medium
        default:
            tier = .high
        }

        let confidenceMultiplier = 0.55 + (score * 0.45)
        let tierDecayMultiplier: Double = switch tier {
        case .high:
            1.18
        case .medium:
            1.0
        case .low:
            0.78
        }
        let sourceDecayMultiplier = resolvedDouble(
            behavior.sourceDecayMultipliersBySourceID,
            key: source.rawValue,
            fallback: 1.0
        )
        let governanceDecayMultiplier = resolvedDouble(
            behavior.governanceDecayMultipliersByStatusID,
            key: governanceStatus.rawValue,
            fallback: 1.0
        )
        let evidenceDecayMultiplier = 1 + min(
            behavior.evidenceDecayBoostCap,
            Double(max(0, evidenceCount - 1)) * behavior.evidenceDecayBoostPerExtraObservation
        )
        let pendingDecayPenalty = isPending ? behavior.pendingDecayPenalty : 1.0
        let provenanceDecayPenalty = provenanceRisk ? behavior.provenanceDecayPenalty : 1.0
        let decayGraceMultiplier = clamp(
            tierDecayMultiplier *
                sourceDecayMultiplier *
                governanceDecayMultiplier *
                evidenceDecayMultiplier *
                pendingDecayPenalty *
                provenanceDecayPenalty,
            min: 0.45,
            max: 1.95
        )

        return BASMemoryTrustProfile(
            score: score,
            tier: tier,
            provenanceRisk: provenanceRisk,
            confidenceMultiplier: confidenceMultiplier,
            decayGraceMultiplier: decayGraceMultiplier
        )
    }

    public static func effectiveConfidence(
        rawConfidence: Double,
        trustProfile: BASMemoryTrustProfile
    ) -> Double {
        clamp(
            rawConfidence * trustProfile.confidenceMultiplier,
            min: 0,
            max: 1
        )
    }

    private static func isContaminated(
        _ provenanceSummary: String,
        behavior: BASMemoryTrustBehavior
    ) -> Bool {
        let normalized = provenanceSummary.lowercased()
        return behavior.contaminationSignals.contains { normalized.contains($0) }
    }

    private static func resolvedDouble(
        _ mapping: [String: Double],
        key: String,
        fallback: Double
    ) -> Double {
        mapping[key] ?? fallback
    }

    private static func clamp(
        _ value: Double,
        min lowerBound: Double,
        max upperBound: Double
    ) -> Double {
        Swift.max(lowerBound, Swift.min(upperBound, value))
    }
}

public struct BASMemoryEligibilityCandidate: Codable, Equatable, Sendable {
    public let id: String
    public let role: BASBrainMemoryRole
    public let kind: BASMemoryKind
    public let headline: String
    public let source: BASMemorySource
    public let scope: BASMemoryScope
    public let sensitivity: BASMemorySensitivity
    public let confidence: Double
    public let priority: Double
    public let retrievalTags: [String]
    public let lastConfirmedAt: Date
    public let decayPolicy: BASMemoryDecayPolicy
    public let lifecycleState: String
    public let governanceStatus: BASMemoryLoadStatus
    public let isPending: Bool
    public let provenanceSummary: String
    public let sourceTrustScore: Double
    public let sourceTrustTier: BASMemorySourceTrustTier
    public let effectiveConfidence: Double
    public let provenanceRisk: Bool

    public init(
        id: String,
        role: BASBrainMemoryRole,
        kind: BASMemoryKind,
        headline: String,
        source: BASMemorySource,
        scope: BASMemoryScope,
        sensitivity: BASMemorySensitivity,
        confidence: Double,
        priority: Double,
        retrievalTags: [String],
        lastConfirmedAt: Date,
        decayPolicy: BASMemoryDecayPolicy,
        lifecycleState: String,
        governanceStatus: BASMemoryLoadStatus,
        isPending: Bool,
        provenanceSummary: String,
        sourceTrustScore: Double,
        sourceTrustTier: BASMemorySourceTrustTier,
        effectiveConfidence: Double,
        provenanceRisk: Bool
    ) {
        self.id = id
        self.role = role
        self.kind = kind
        self.headline = headline
        self.source = source
        self.scope = scope
        self.sensitivity = sensitivity
        self.confidence = confidence
        self.priority = priority
        self.retrievalTags = retrievalTags
        self.lastConfirmedAt = lastConfirmedAt
        self.decayPolicy = decayPolicy
        self.lifecycleState = lifecycleState
        self.governanceStatus = governanceStatus
        self.isPending = isPending
        self.provenanceSummary = provenanceSummary
        self.sourceTrustScore = sourceTrustScore
        self.sourceTrustTier = sourceTrustTier
        self.effectiveConfidence = effectiveConfidence
        self.provenanceRisk = provenanceRisk
    }
}

public enum BASMemoryEligibilityJudge {
    public static func decide(
        candidate: BASMemoryEligibilityCandidate,
        mode: BASDecisionMode,
        queryTags: Set<String>,
        now: Date,
        behavior: BASBrainCompilationBehavior = BASBrainCompilationBehavior()
    ) -> BASMemoryEligibilityDecision {
        if candidate.kind == .goal {
            return .allowed(.goalOverride)
        }

        let ignoredTags = behavior.ignoredRetrievalTagSet()
        let meaningfulItemTags = relevantTags(candidate.retrievalTags, ignoredTags: ignoredTags)
        let meaningfulQueryTags = relevantTags(Array(queryTags), ignoredTags: ignoredTags)
        let hasTagOverlap = !meaningfulItemTags.intersection(meaningfulQueryTags).isEmpty
        let ageHours = max(0, now.timeIntervalSince(candidate.lastConfirmedAt) / 3_600)

        if candidate.provenanceRisk {
            return .screenedOut(.provenanceContamination)
        }

        if meaningfulItemTags.count >= 9, !hasTagOverlap {
            return .screenedOut(.tagFloodNoOverlap)
        }

        if candidate.isPending {
            if behavior.requireTagOverlapForPendingCandidatesWhenExternalRefreshRequired, !hasTagOverlap {
                return .screenedOut(.externalRefreshNoOverlap)
            }
            if candidate.sourceTrustTier == .low, !hasTagOverlap, ageHours <= 18 {
                return .screenedOut(.lowTrustPending)
            }
            return hasTagOverlap
                ? .allowed(.pendingTagOverlap)
                : (ageHours <= 18 ? .allowed(.pendingGraceWindow) : .screenedOut(.confidenceNoOverlap))
        }

        if candidate.decayPolicy == .fast {
            if behavior.requireTagOverlapForFastDecayCandidatesWhenExternalRefreshRequired, !hasTagOverlap {
                return .screenedOut(.externalRefreshNoOverlap)
            }
            return hasTagOverlap
                ? .allowed(.fastDecayTagOverlap)
                : (ageHours <= 24 ? .allowed(.fastDecayGraceWindow) : .screenedOut(.confidenceNoOverlap))
        }

        if candidate.effectiveConfidence < 0.62, !hasTagOverlap {
            return .screenedOut(.confidenceNoOverlap)
        }

        if candidate.role == .relevant {
            let baseline = behavior.relevantPriorityBaseline(for: mode)
            if candidate.priority < baseline, !hasTagOverlap {
                return .screenedOut(candidate.kind == .template ? .supportPriorityNoOverlap : .semanticPriorityNoOverlap)
            }
        }

        return .allowed(.defaultAllowed)
    }

    private static func relevantTags(
        _ tags: [String],
        ignoredTags: Set<String>
    ) -> Set<String> {
        return Set(tags.map { $0.lowercased() })
            .subtracting(ignoredTags)
            .filter { tag in
                !tag.hasPrefix("lang:") && !tag.hasPrefix("script:")
            }
    }
}

public struct BASBrainTaskGraphHint: Codable, Equatable, Sendable {
    public var headline: String
    public var activeNodeCount: Int
    public var hasResumeCandidate: Bool
    public var resumeHint: String?

    public init(
        headline: String,
        activeNodeCount: Int,
        hasResumeCandidate: Bool,
        resumeHint: String? = nil
    ) {
        self.headline = headline
        self.activeNodeCount = activeNodeCount
        self.hasResumeCandidate = hasResumeCandidate
        self.resumeHint = resumeHint
    }
}

public struct BASBrainBootstrapRequest: Codable, Equatable, Sendable {
    public var mode: BASDecisionMode
    public var prompt: String
    public var source: BASMemorySource
    public var sourceSurface: BASInteractionSurface
    public var riskLevel: BASRiskLevel
    public var retrievalMode: String
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var goalHints: [String]
    public var constraintHints: [String]
    public var now: Date

    public init(
        mode: BASDecisionMode,
        prompt: String,
        source: BASMemorySource,
        sourceSurface: BASInteractionSurface,
        riskLevel: BASRiskLevel,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        goalHints: [String] = [],
        constraintHints: [String] = [],
        now: Date = .now
    ) {
        self.mode = mode
        self.prompt = prompt
        self.source = source
        self.sourceSurface = sourceSurface
        self.riskLevel = riskLevel
        self.retrievalMode = retrievalMode
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.goalHints = goalHints
        self.constraintHints = constraintHints
        self.now = now
    }
}

public struct BASBrainProjection: Codable, Equatable, Sendable {
    public var records: [BASGovernedMemory]
    public var candidates: [BASMemoryEligibilityCandidate]
    public var recentEvents: [BASEventRecord]
    public var embeddingScoresByID: [String: Double]
    public var governanceSnapshot: BASMemoryGovernanceState?
    public var taskGraphHint: BASBrainTaskGraphHint?
    public var activeTemplateIDs: [String]
    public var failureGuardIDs: [String]

    public init(
        records: [BASGovernedMemory],
        candidates: [BASMemoryEligibilityCandidate],
        recentEvents: [BASEventRecord],
        embeddingScoresByID: [String: Double] = [:],
        governanceSnapshot: BASMemoryGovernanceState? = nil,
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        activeTemplateIDs: [String] = [],
        failureGuardIDs: [String] = []
    ) {
        self.records = records
        self.candidates = candidates
        self.recentEvents = recentEvents
        self.embeddingScoresByID = embeddingScoresByID
        self.governanceSnapshot = governanceSnapshot
        self.taskGraphHint = taskGraphHint
        self.activeTemplateIDs = activeTemplateIDs
        self.failureGuardIDs = failureGuardIDs
    }
}

public struct BASBootstrappedBrainState: Codable, Equatable, Sendable {
    public var brainState: BASDecisionBrainState
    public var dominantGoal: String?
    public var activeConstraints: [String]
    public var activeTemplateIDs: [String]
    public var failureGuardIDs: [String]
    public var taskGraphHint: BASBrainTaskGraphHint?

    public init(
        brainState: BASDecisionBrainState,
        dominantGoal: String?,
        activeConstraints: [String],
        activeTemplateIDs: [String],
        failureGuardIDs: [String],
        taskGraphHint: BASBrainTaskGraphHint? = nil
    ) {
        self.brainState = brainState
        self.dominantGoal = dominantGoal
        self.activeConstraints = activeConstraints
        self.activeTemplateIDs = activeTemplateIDs
        self.failureGuardIDs = failureGuardIDs
        self.taskGraphHint = taskGraphHint
    }
}

public enum BASDecisionBrainCompiler {
    private struct RetrievalPlan {
        let candidateLimit: Int
        let profileLimit: Int
        let goalLimit: Int
        let relevantLimit: Int
        let includesPendingCandidates: Bool
    }

    private struct CompilerItem {
        let id: String
        let role: BASBrainMemoryRole
        let kind: BASMemoryKind
        let headline: String
        let source: BASMemorySource
        let sourceLabel: String
        let scope: BASMemoryScope
        let sensitivity: BASMemorySensitivity
        let confidence: Double
        let priority: Double
        let retrievalTags: [String]
        let lastConfirmedAt: Date
        let decayPolicy: BASMemoryDecayPolicy
        let lifecycleState: String
        let governanceStatus: BASBrainGovernedMemoryStatus
        let loadStatus: BASMemoryLoadStatus
        let isPending: Bool
        let provenanceSummary: String
        let tier: BASMemoryTier
        let sourceTrustScore: Double
        let sourceTrustTier: BASMemorySourceTrustTier
        let effectiveConfidence: Double
        let provenanceRisk: Bool
        let decayGraceMultiplier: Double
        let isCandidate: Bool

        init(memory: BASGovernedMemory, trustBehavior: BASMemoryTrustBehavior = .generic) {
            let resolvedSource = BASDecisionBrainCompiler.source(for: memory.sourceType)
            let resolvedDecay = BASDecisionBrainCompiler.decay(for: memory)
            let trustProfile = BASMemoryTrustEngine.profile(
                source: resolvedSource,
                evidenceCount: 1,
                decayPolicy: resolvedDecay,
                governanceStatus: .admitted,
                isPending: false,
                provenanceSummary: memory.provenanceSummary,
                behavior: trustBehavior
            )

            id = memory.id.uuidString
            role = BASDecisionBrainCompiler.role(for: memory)
            kind = memory.kind
            headline = memory.content
            source = resolvedSource
            sourceLabel = memory.sourceType
            scope = memory.scope
            sensitivity = memory.sensitivity
            confidence = memory.confidence
            priority = BASDecisionBrainCompiler.priority(for: memory)
            retrievalTags = BASDecisionBrainCompiler.metadataTags(for: memory)
            lastConfirmedAt = memory.lastConfirmedAt ?? .distantPast
            decayPolicy = resolvedDecay
            lifecycleState = memory.governanceStatus.rawValue
            governanceStatus = .admitted
            loadStatus = .admitted
            isPending = false
            provenanceSummary = memory.provenanceSummary
            tier = memory.tier
            sourceTrustScore = trustProfile.score
            sourceTrustTier = trustProfile.tier
            effectiveConfidence = BASMemoryTrustEngine.effectiveConfidence(
                rawConfidence: memory.confidence,
                trustProfile: trustProfile
            )
            provenanceRisk = trustProfile.provenanceRisk
            decayGraceMultiplier = trustProfile.decayGraceMultiplier
            isCandidate = false
        }

        init(candidate: BASMemoryEligibilityCandidate, trustBehavior: BASMemoryTrustBehavior = .generic) {
            id = candidate.id
            role = candidate.role
            kind = candidate.kind
            headline = candidate.headline
            source = candidate.source
            sourceLabel = candidate.source.rawValue
            scope = candidate.scope
            sensitivity = candidate.sensitivity
            confidence = candidate.confidence
            priority = candidate.priority
            retrievalTags = candidate.retrievalTags
            lastConfirmedAt = candidate.lastConfirmedAt
            decayPolicy = candidate.decayPolicy
            lifecycleState = candidate.lifecycleState
            governanceStatus = BASDecisionBrainCompiler.governedStatus(from: candidate.governanceStatus)
            loadStatus = candidate.governanceStatus
            isPending = candidate.isPending
            provenanceSummary = candidate.provenanceSummary
            tier = candidate.scope == .session ? .hot : .warm
            sourceTrustScore = candidate.sourceTrustScore
            sourceTrustTier = candidate.sourceTrustTier
            effectiveConfidence = candidate.effectiveConfidence
            provenanceRisk = candidate.provenanceRisk
            let trustProfile = BASMemoryTrustEngine.profile(
                source: candidate.source,
                evidenceCount: 1,
                decayPolicy: candidate.decayPolicy,
                governanceStatus: candidate.governanceStatus,
                isPending: candidate.isPending,
                provenanceSummary: candidate.provenanceSummary,
                behavior: trustBehavior
            )
            decayGraceMultiplier = trustProfile.decayGraceMultiplier
            isCandidate = true
        }

        var eligibilityCandidate: BASMemoryEligibilityCandidate {
            BASMemoryEligibilityCandidate(
                id: id,
                role: role,
                kind: kind,
                headline: headline,
                source: source,
                scope: scope,
                sensitivity: sensitivity,
                confidence: confidence,
                priority: priority,
                retrievalTags: retrievalTags,
                lastConfirmedAt: lastConfirmedAt,
                decayPolicy: decayPolicy,
                lifecycleState: lifecycleState,
                governanceStatus: loadStatus,
                isPending: isPending,
                provenanceSummary: provenanceSummary,
                sourceTrustScore: sourceTrustScore,
                sourceTrustTier: sourceTrustTier,
                effectiveConfidence: effectiveConfidence,
                provenanceRisk: provenanceRisk
            )
        }

        func makeSlice(eligibility: BASMemoryEligibilityDecision) -> BASGovernedMemorySlice {
            BASGovernedMemorySlice(
                id: id,
                role: role,
                type: kind.rawValue,
                headline: headline,
                source: sourceLabel,
                confidence: confidence,
                priority: priority,
                lifecycleState: lifecycleState,
                governanceStatus: governanceStatus,
                eligibility: eligibility,
                sourceTrustScore: sourceTrustScore,
                sourceTrustTier: sourceTrustTier,
                retrievalTags: retrievalTags,
                isPending: isPending,
                provenanceSummary: provenanceSummary
            )
        }
    }

    private struct EvaluatedItem {
        let item: CompilerItem
        let eligibility: BASMemoryEligibilityDecision
    }

    public static func bootstrap(
        request: BASBrainBootstrapRequest,
        projection: BASBrainProjection
    ) -> BASBootstrappedBrainState {
        let queryTags = buildQueryTags(for: request, projection: projection)
        let brainCompilation = request.cognitionBehavior.brainCompilation
        let memoryTrust = request.cognitionBehavior.memoryTrust
        let retrievalPlan = retrievalPlan(
            for: request.mode,
            retrievalMode: request.retrievalMode,
            behavior: brainCompilation
        )
        let compilerItems = BASMemoryTierFilter.frontstageEligibleMemories(projection.records)
            .map { CompilerItem(memory: $0, trustBehavior: memoryTrust) }
            .sorted(by: memorySort)
        let compilerCandidates = projection.candidates
            .map { CompilerItem(candidate: $0, trustBehavior: memoryTrust) }
            .sorted(by: memorySort)
        let orderedItems = (compilerItems + compilerCandidates)
            .sorted { lhs, rhs in
                score(
                    lhs,
                    mode: request.mode,
                    queryTags: queryTags,
                    embeddingScores: projection.embeddingScoresByID,
                    now: request.now,
                    behavior: brainCompilation
                ) > score(
                    rhs,
                    mode: request.mode,
                    queryTags: queryTags,
                    embeddingScores: projection.embeddingScoresByID,
                    now: request.now,
                    behavior: brainCompilation
                )
            }
        let retrievalPool = orderedItems.filter {
            retrievalPlan.includesPendingCandidates || !$0.isPending
        }
        let judged = judgeRetrievalCandidates(
            from: retrievalPool,
            mode: request.mode,
            queryTags: queryTags,
            now: request.now,
            behavior: brainCompilation
        )
        let retrievalQualified = Array(judged.allowedItems.prefix(retrievalPlan.candidateLimit))
        let profileItems = selectItems(
            from: retrievalQualified,
            limit: retrievalPlan.profileLimit,
            matching: { $0.role == .profile }
        )
        let goalItems = selectItems(
            from: retrievalQualified,
            limit: retrievalPlan.goalLimit,
            excludingIDs: Set(profileItems.map(\.item.id)),
            matching: { $0.role == .goal }
        )
        let relevantItems = selectItems(
            from: retrievalQualified,
            limit: retrievalPlan.relevantLimit,
            excludingIDs: Set(profileItems.map(\.item.id) + goalItems.map(\.item.id)),
            matching: { $0.role == .relevant }
        )
        let memorySlices = buildMemorySlices(
            profileItems: profileItems,
            goalItems: goalItems,
            relevantItems: relevantItems
        )

        let profileGoals = memorySlices
            .filter { $0.role == .profile || $0.role == .goal }
            .map(\.headline)
            .filter { !$0.isEmpty }
        let dominantGoals = uniqueOrdered(request.goalHints + profileGoals + requestGoals(from: projection.recentEvents))
        let activeConstraints = uniqueOrdered(
            request.constraintHints +
                constraintHints(from: compilerItems) +
                requestBoundaryConstraints(for: request)
        )
        let retrievalTags = uniqueOrdered(
            Array(queryTags).sorted() +
                memorySlices.flatMap(\.retrievalTags) +
                requestTags(for: request) +
                eventTags(from: projection.recentEvents)
        )
        let reactionWeights = reactionWeights(
            for: request.mode,
            seed: request.reactionWeightSeed ?? BASReactionWeights.defaults(forModeName: request.mode.identifier),
            queryTags: queryTags,
            memorySlices: memorySlices,
            recentEvents: projection.recentEvents,
            cognitionBehavior: request.cognitionBehavior
        )
        let sessionBiases = sessionBiases(
            for: request,
            queryTags: queryTags,
            memorySlices: memorySlices,
            recentEvents: projection.recentEvents,
            reactionWeights: reactionWeights
        )
        let identityProfile = request.identityProfileOverride ?? BASIdentityProfile.default(modeName: request.mode.identifier)
        let boundaryPolicy = BASBoundaryPolicyState.default(riskLevel: request.riskLevel)
        let memoryGovernance = mergeGovernanceState(
            seed: projection.governanceSnapshot,
            computed: governanceState(
                records: projection.records,
                selectedItems: profileItems + goalItems + relevantItems,
                screenedOutItems: judged.screenedOutItems
            )
        )
        let activeTemplateIDs = uniqueOrdered(projection.activeTemplateIDs + templateIDs(from: memorySlices))
        let failureGuardIDs = uniqueOrdered(projection.failureGuardIDs + failurePatternIDs(from: memorySlices))

        let brainState = BASDecisionBrainState(
            memorySlices: memorySlices,
            sessionBiases: sessionBiases,
            retrievalTags: retrievalTags,
            reactionWeights: reactionWeights,
            identityProfile: identityProfile,
            boundaryPolicy: boundaryPolicy,
            calibrationState: BASCalibrationState.stable(at: request.now),
            evolutionState: BASEvolutionState.empty,
            activeInterventionTemplateIDs: activeTemplateIDs,
            failureGuardIDs: failureGuardIDs,
            memoryGovernance: memoryGovernance,
            loadedAt: request.now
        )

        return BASBootstrappedBrainState(
            brainState: brainState,
            dominantGoal: dominantGoals.first,
            activeConstraints: activeConstraints,
            activeTemplateIDs: brainState.activeInterventionTemplateIDs,
            failureGuardIDs: brainState.failureGuardIDs,
            taskGraphHint: projection.taskGraphHint
        )
    }

    private static func governanceState(
        records: [BASGovernedMemory],
        selectedItems: [EvaluatedItem],
        screenedOutItems: [EvaluatedItem]
    ) -> BASMemoryGovernanceState {
        var loadedReasonCounts: [BASMemoryEligibilityReason: Int] = [:]
        var screenedOutReasonCounts: [BASMemoryEligibilityReason: Int] = [:]

        for item in selectedItems {
            loadedReasonCounts[item.eligibility.reason, default: 0] += 1
        }

        for item in screenedOutItems {
            screenedOutReasonCounts[item.eligibility.reason, default: 0] += 1
        }

        let allItems = selectedItems + screenedOutItems
        let candidateItems = allItems.filter { $0.item.isCandidate }
        let pendingCount = candidateItems.filter { $0.item.isPending }.count
        let deferredCount = candidateItems.filter { $0.item.loadStatus == .deferred }.count
        let admittedCandidateCount = candidateItems.filter { $0.item.loadStatus == .admitted }.count
        let screenedOutCount = screenedOutItems.count
        let screenedOutPendingCount = screenedOutItems.filter { $0.item.isPending }.count
        let loadedPendingCount = selectedItems.filter { $0.item.isPending }.count

        return BASMemoryGovernanceState(
            totalRecordCount: records.count,
            totalCandidateCount: candidateItems.count,
            pendingCandidateCount: pendingCount,
            promotedCandidateCount: selectedItems.count - loadedPendingCount,
            loadedPromotedMemoryCount: selectedItems.count - loadedPendingCount,
            loadedPendingMemoryCount: loadedPendingCount,
            deferredCandidateCount: deferredCount,
            admittedCandidateCount: admittedCandidateCount,
            screenedOutMemoryCount: screenedOutCount,
            screenedOutPendingMemoryCount: screenedOutPendingCount,
            loadedReasonCounts: loadedReasonCounts,
            screenedOutReasonCounts: screenedOutReasonCounts
        )
    }

    private static func mergeGovernanceState(
        seed: BASMemoryGovernanceState?,
        computed: BASMemoryGovernanceState
    ) -> BASMemoryGovernanceState {
        guard let seed else { return computed }

        var merged = seed
        merged.totalRecordCount = max(seed.totalRecordCount, computed.totalRecordCount)
        merged.totalCandidateCount = max(seed.totalCandidateCount, computed.totalCandidateCount)
        merged.pendingCandidateCount = max(seed.pendingCandidateCount, computed.pendingCandidateCount)
        merged.promotedCandidateCount = max(seed.promotedCandidateCount, computed.promotedCandidateCount)
        merged.loadedPromotedMemoryCount = max(seed.loadedPromotedMemoryCount, computed.loadedPromotedMemoryCount)
        merged.loadedPendingMemoryCount = max(seed.loadedPendingMemoryCount, computed.loadedPendingMemoryCount)
        merged.deferredCandidateCount = max(seed.deferredCandidateCount, computed.deferredCandidateCount)
        merged.admittedCandidateCount = max(seed.admittedCandidateCount, computed.admittedCandidateCount)
        merged.externallyRefreshedCandidateCount = max(
            seed.externallyRefreshedCandidateCount,
            computed.externallyRefreshedCandidateCount
        )
        merged.quarantinedObservationCount = max(
            seed.quarantinedObservationCount,
            computed.quarantinedObservationCount
        )
        merged.evidenceCaveatedCandidateCount = max(
            seed.evidenceCaveatedCandidateCount,
            computed.evidenceCaveatedCandidateCount
        )
        merged.screenedOutMemoryCount = max(seed.screenedOutMemoryCount, computed.screenedOutMemoryCount)
        merged.screenedOutPendingMemoryCount = max(seed.screenedOutPendingMemoryCount, computed.screenedOutPendingMemoryCount)
        merged.loadedReasonCounts = mergeReasonCounts(seed.loadedReasonCounts, computed.loadedReasonCounts)
        merged.screenedOutReasonCounts = mergeReasonCounts(seed.screenedOutReasonCounts, computed.screenedOutReasonCounts)
        return merged
    }

    private static func mergeReasonCounts(
        _ lhs: [BASMemoryEligibilityReason: Int],
        _ rhs: [BASMemoryEligibilityReason: Int]
    ) -> [BASMemoryEligibilityReason: Int] {
        let keys = Set(lhs.keys).union(rhs.keys)
        var merged: [BASMemoryEligibilityReason: Int] = [:]
        for key in keys {
            merged[key] = max(lhs[key, default: 0], rhs[key, default: 0])
        }
        return merged
    }

    private static func retrievalPlan(
        for mode: BASDecisionMode,
        retrievalMode: String,
        behavior: BASBrainCompilationBehavior
    ) -> RetrievalPlan {
        switch retrievalMode {
        case "off":
            return RetrievalPlan(
                candidateLimit: behavior.candidateLimitWhenRetrievalOff(for: mode),
                profileLimit: 1,
                goalLimit: behavior.goalLimitWhenRetrievalOff(for: mode),
                relevantLimit: 1,
                includesPendingCandidates: false
            )
        case "adaptive":
            return RetrievalPlan(
                candidateLimit: 12,
                profileLimit: 2,
                goalLimit: 2,
                relevantLimit: behavior.relevantLimitWhenAdaptive(for: mode),
                includesPendingCandidates: true
            )
        default:
            return RetrievalPlan(
                candidateLimit: behavior.candidateLimitWhenFiltered(for: mode),
                profileLimit: 2,
                goalLimit: 2,
                relevantLimit: behavior.relevantLimitWhenFiltered(for: mode),
                includesPendingCandidates: true
            )
        }
    }

    private static func buildQueryTags(
        for request: BASBrainBootstrapRequest,
        projection: BASBrainProjection
    ) -> Set<String> {
        let languageMode = BASLanguageMode.detect(sampleTexts: [request.prompt])
        return Set(tags(from: request.prompt))
            .union(languageMode.retrievalTags)
            .union([request.mode.rawValue])
            .union(requestTags(for: request))
    }

    private static func requestTags(for request: BASBrainBootstrapRequest) -> [String] {
        [
            "mode:\(request.mode.rawValue)",
            "surface:\(request.sourceSurface.rawValue)",
            "risk:\(request.riskLevel.rawValue)",
            "retrieval:\(request.retrievalMode)"
        ]
    }

    private static func requestGoals(from events: [BASEventRecord]) -> [String] {
        events
            .filter { $0.kind == .profile || $0.kind == .semantic }
            .map(\.content)
            .filter { !$0.isEmpty }
    }

    private static func constraintHints(from memories: [CompilerItem]) -> [String] {
        memories
            .filter { $0.sensitivity == .high }
            .map { "sensitive:\($0.scope.rawValue)" }
    }

    private static func eventTags(from events: [BASEventRecord]) -> [String] {
        events.flatMap { event in
            var tags = event.tags.map { "event:\($0.lowercased())" }
            tags.append("event_kind:\(event.kind.rawValue)")
            return tags
        }
    }

    private static func templateIDs(from memories: [BASGovernedMemorySlice]) -> [String] {
        memories.filter { $0.type == BASMemoryKind.template.rawValue }.map(\.id)
    }

    private static func failurePatternIDs(from memories: [BASGovernedMemorySlice]) -> [String] {
        memories.filter { $0.type == BASMemoryKind.failurePattern.rawValue }.map(\.id)
    }

    private static func requestBoundaryConstraints(for request: BASBrainBootstrapRequest) -> [String] {
        var constraints: [String] = []

        if request.riskLevel == .high {
            constraints.append("require_confirmation")
        }

        if request.sourceSurface == .notification {
            constraints.append("notification_requires_evidence")
        }

        if request.sourceSurface == .watch {
            constraints.append("watch_surface_lightweight")
        }

        return constraints
    }

    private static func sessionBiases(
        for request: BASBrainBootstrapRequest,
        queryTags: Set<String>,
        memorySlices: [BASGovernedMemorySlice],
        recentEvents: [BASEventRecord],
        reactionWeights: BASReactionWeights
    ) -> [String] {
        let memoryText = normalizedMemoryText(from: memorySlices)
        let hasNightSignal = hasNightSignal(queryTags: queryTags, memoryText: memoryText, recentEvents: recentEvents, now: request.now)
        let behavior = request.cognitionBehavior.sessionBias
        let brainCompilation = request.cognitionBehavior.brainCompilation
        var biases = behavior.defaultBiases(for: request.mode)

        if reactionWeights.briefLanguage >= 0.7 ||
            containsSignal(in: memoryText, signals: behavior.briefLanguageSignals) {
            biases.append("Keep the language short and concrete.")
        }

        if hasNightSignal {
            biases.append(behavior.nightBias)
        }

        if hasNightSignal &&
            (containsSignal(in: memoryText, signals: behavior.lowCognitiveLoadSignals) ||
             reactionWeights.lowCognitiveLoad >= 0.72) {
            biases.append(behavior.nightLowLoadBias)
        }

        if brainCompilation.isInterruptiveMode(request.mode),
           (reactionWeights.interruptiveActionBias >= 0.74 ||
            containsSignal(in: memoryText, signals: behavior.interruptiveActionSignals)) {
            biases.append(behavior.interruptiveActionBias)
        }

        if brainCompilation.isBoundaryNamingMode(request.mode),
           reactionWeights.boundaryNamingBias >= 0.8 {
            biases.append(behavior.boundaryNamingBias)
        }

        if brainCompilation.isTradeoffClarityMode(request.mode),
           reactionWeights.tradeoffClarityBias >= 0.8 {
            biases.append(behavior.tradeoffClarityBias)
        }

        let contextMarkers = [
            "mode:\(request.mode.rawValue)",
            "source:\(request.source.rawValue)",
            "surface:\(request.sourceSurface.rawValue)",
            "retrieval:\(request.retrievalMode)"
        ] + recentEvents.flatMap { event in
            event.tags.prefix(2).map { "recent:\($0.lowercased())" }
        }

        return uniqueOrdered(biases + contextMarkers)
    }

    private static func reactionWeights(
        for mode: BASDecisionMode,
        seed: BASReactionWeights,
        queryTags: Set<String>,
        memorySlices: [BASGovernedMemorySlice],
        recentEvents: [BASEventRecord],
        cognitionBehavior: BASCognitionBehavior
    ) -> BASReactionWeights {
        var weights = seed
        let memoryText = normalizedMemoryText(from: memorySlices)
        let hasNightSignal = hasNightSignal(queryTags: queryTags, memoryText: memoryText, recentEvents: recentEvents, now: nil)
        let behavior = cognitionBehavior.sessionBias
        let brainCompilation = cognitionBehavior.brainCompilation

        if containsSignal(in: memoryText, signals: behavior.briefLanguageSignals) {
            weights.briefLanguage += 0.24
            weights.warmDirectTone += 0.08
        }

        if hasNightSignal {
            weights.lowCognitiveLoad += 0.3
            weights.briefLanguage += 0.12
            weights.warmDirectTone += 0.06
        }

        if brainCompilation.isInterruptiveMode(mode) &&
            containsSignal(in: memoryText, signals: behavior.interruptiveActionSignals) {
            weights.interruptiveActionBias += 0.24
        }

        let positiveInterruptiveReflections = recentEvents.filter { event in
            guard let actionID = event.actionID, let reflectionOutcomeID = event.reflectionOutcomeID else {
                return false
            }
            return brainCompilation.interruptiveActionIDs.contains(actionID) &&
                brainCompilation.positiveReflectionOutcomeIDs.contains(reflectionOutcomeID)
        }.count

        let negativeProceedReflections = recentEvents.filter { event in
            guard let actionID = event.actionID, let reflectionOutcomeID = event.reflectionOutcomeID else {
                return false
            }
            return brainCompilation.proceedActionIDs.contains(actionID) &&
                brainCompilation.negativeReflectionOutcomeIDs.contains(reflectionOutcomeID)
        }.count

        let positiveProceedReflections = recentEvents.filter { event in
            guard let actionID = event.actionID, let reflectionOutcomeID = event.reflectionOutcomeID else {
                return false
            }
            return brainCompilation.proceedActionIDs.contains(actionID) &&
                brainCompilation.positiveReflectionOutcomeIDs.contains(reflectionOutcomeID)
        }.count

        if positiveInterruptiveReflections > 0 || negativeProceedReflections > 0 {
            let interruptiveBoost = Double(positiveInterruptiveReflections + negativeProceedReflections) * 0.08
            weights.interruptiveActionBias += min(0.28, interruptiveBoost)
            weights.lowCognitiveLoad += min(0.16, Double(positiveInterruptiveReflections) * 0.05)
        }

        if positiveProceedReflections > 0 {
            let proceedStability = min(0.18, Double(positiveProceedReflections) * 0.05)
            weights.interruptiveActionBias -= proceedStability
            weights.warmDirectTone += min(0.1, Double(positiveProceedReflections) * 0.03)
        }

        if brainCompilation.isBoundaryNamingMode(mode) ||
            containsSignal(in: memoryText, signals: behavior.boundaryNamingSignals) {
            weights.boundaryNamingBias += 0.18
            weights.warmDirectTone += 0.06
        }

        if brainCompilation.isTradeoffClarityMode(mode) ||
            containsSignal(in: memoryText, signals: behavior.tradeoffClaritySignals) ||
            containsSignal(in: queryTags, signals: behavior.tradeoffClaritySignals) {
            weights.tradeoffClarityBias += 0.22
        }

        return rounded(clamped(weights))
    }

    private static func containsSignal(
        in text: String,
        signals: [String]
    ) -> Bool {
        let normalizedText = text.lowercased()
        return signals.contains { signal in
            normalizedText.contains(signal.lowercased())
        }
    }

    private static func containsSignal(
        in tags: Set<String>,
        signals: [String]
    ) -> Bool {
        let normalizedTags = Set(tags.map { $0.lowercased() })
        return signals.contains { signal in
            normalizedTags.contains(signal.lowercased())
        }
    }

    private static func role(for memory: BASGovernedMemory) -> BASBrainMemoryRole {
        switch memory.kind {
        case .profile:
            return .profile
        case .goal:
            return .goal
        case .template:
            return .goal
        case .failurePattern:
            return .relevant
        case .episodic, .semantic, .situational, .support:
            return .relevant
        }
    }

    private static func governedStatus(from loadStatus: BASMemoryLoadStatus) -> BASBrainGovernedMemoryStatus {
        switch loadStatus {
        case .admitted:
            .admitted
        case .deferred:
            .deferred
        case .pending:
            .pending
        }
    }

    private static func source(for sourceType: String) -> BASMemorySource {
        let normalized = sourceType.lowercased()
        if normalized.contains("cue") {
            return .cue
        }
        if normalized.contains("archive") {
            return .archive
        }
        if normalized.contains("pattern") {
            return .pattern
        }
        if normalized.contains("reflection") {
            return .reflection
        }
        return .pattern
    }

    private static func decay(for memory: BASGovernedMemory) -> BASMemoryDecayPolicy {
        switch memory.kind {
        case .profile:
            return .stable
        case .goal:
            return .slow
        case .template:
            return .slow
        case .failurePattern:
            return .medium
        case .semantic, .support:
            return .medium
        case .situational, .episodic:
            return .fast
        }
    }

    private static func priority(for memory: BASGovernedMemory) -> Double {
        let tierBias: Double = switch memory.tier {
        case .hot:
            0.35
        case .warm:
            0.2
        case .cold:
            0.05
        }
        return min(max(memory.confidence + tierBias - memory.decayScore, 0), 1)
    }

    private static func metadataTags(for memory: BASGovernedMemory) -> [String] {
        [
            "tier:\(memory.tier.rawValue)",
            "scope:\(memory.scope.rawValue)",
            "kind:\(memory.kind.rawValue)",
            "source:\(memory.sourceType)"
        ]
    }

    private static func tags(from text: String) -> [String] {
        let stopwords: Set<String> = [
            "the", "and", "for", "that", "with", "this", "from", "into",
            "have", "just", "been", "than", "then", "they", "them",
            "want", "need", "feel", "will", "your", "about", "after",
            "before", "would", "should", "could", "again", "really",
            "maybe", "because", "when", "what", "where", "while", "into"
        ]

        let normalizedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let latinTokens = normalizedText
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !stopwords.contains($0) }

        let languageTags = BASLanguageMode.detect(sampleTexts: [text]).retrievalTags
        let tags = languageTags + Array(latinTokens.prefix(6)) + hanTokens(from: text)
        return uniqueOrdered(Array(tags.prefix(10)))
    }

    private static func normalizedMemoryText(from memorySlices: [BASGovernedMemorySlice]) -> String {
        memorySlices
            .map(\.headline)
            .joined(separator: " ")
            .lowercased()
    }

    private static func hasNightSignal(
        queryTags: Set<String>,
        memoryText: String,
        recentEvents: [BASEventRecord],
        now: Date?
    ) -> Bool {
        if queryTags.contains("night") || queryTags.contains("late") {
            return true
        }

        if memoryText.contains("late") ||
            memoryText.contains("night") ||
            memoryText.contains("lighter, shorter guidance") {
            return true
        }

        if recentEvents.contains(where: isLateEvent) {
            return true
        }

        guard let now else { return false }
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= 22 || hour < 6
    }

    private static func isLateEvent(_ event: BASEventRecord) -> Bool {
        let hour = Calendar.current.component(.hour, from: event.timestamp)
        return hour >= 21 || hour < 6
    }

    private static func clamped(_ weights: BASReactionWeights) -> BASReactionWeights {
        BASReactionWeights(
            briefLanguage: max(0, min(1, weights.briefLanguage)),
            warmDirectTone: max(0, min(1, weights.warmDirectTone)),
            lowCognitiveLoad: max(0, min(1, weights.lowCognitiveLoad)),
            interruptiveActionBias: max(0, min(1, weights.interruptiveActionBias)),
            boundaryNamingBias: max(0, min(1, weights.boundaryNamingBias)),
            tradeoffClarityBias: max(0, min(1, weights.tradeoffClarityBias))
        )
    }

    private static func rounded(_ weights: BASReactionWeights) -> BASReactionWeights {
        BASReactionWeights(
            briefLanguage: roundedWeight(weights.briefLanguage),
            warmDirectTone: roundedWeight(weights.warmDirectTone),
            lowCognitiveLoad: roundedWeight(weights.lowCognitiveLoad),
            interruptiveActionBias: roundedWeight(weights.interruptiveActionBias),
            boundaryNamingBias: roundedWeight(weights.boundaryNamingBias),
            tradeoffClarityBias: roundedWeight(weights.tradeoffClarityBias)
        )
    }

    private static func roundedWeight(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private static func hanTokens(from text: String) -> [String] {
        let characters = Array(
            text.filter { character in
                character.unicodeScalars.contains(where: { $0.properties.isIdeographic })
            }
        )

        guard !characters.isEmpty else { return [] }

        var tokens: [String] = []
        let joined = String(characters)
        if joined.count <= 8 {
            tokens.append(joined)
        }

        if characters.count >= 2 {
            for index in 0..<(characters.count - 1) {
                tokens.append(String(characters[index...index + 1]))
            }
        }

        if characters.count >= 3 {
            for index in 0..<(characters.count - 2) {
                tokens.append(String(characters[index...index + 2]))
            }
        }

        return Array(uniqueOrdered(tokens).prefix(6))
    }

    private static func relevantRetrievalTags(_ tags: [String]) -> [String] {
        tags.filter { tag in
            let lowered = tag.lowercased()
            return !lowered.hasPrefix("lang:") && !lowered.hasPrefix("script:")
        }
    }

    private static func score(
        _ item: CompilerItem,
        mode: BASDecisionMode,
        queryTags: Set<String>,
        embeddingScores: [String: Double],
        now: Date,
        behavior: BASBrainCompilationBehavior
    ) -> Double {
        let overlap = Double(
            Set(relevantRetrievalTags(item.retrievalTags))
                .intersection(relevantRetrievalTags(Array(queryTags)))
                .count
        )
        let typeBoost = behavior.typeBoost(for: mode, kind: item.kind)

        let ageInDays = max(0, now.timeIntervalSince(item.lastConfirmedAt) / 86_400)
        let fastWindow = 45 * item.decayGraceMultiplier
        let mediumWindow = 120 * item.decayGraceMultiplier
        let slowWindow = 240 * item.decayGraceMultiplier
        let decayMultiplier: Double = switch item.decayPolicy {
        case .stable:
            1.0
        case .slow:
            max(0.82, 1.0 - (ageInDays / slowWindow))
        case .medium:
            max(0.65, 1.0 - (ageInDays / mediumWindow))
        case .fast:
            max(0.45, 1.0 - (ageInDays / fastWindow))
        }

        let pendingPenalty = item.isPending ? 0.88 : 1.0
        let tierBoost: Double = switch item.tier {
        case .hot: 1.2
        case .warm: 0.6
        case .cold: -0.4
        }
        let embeddingBoost = (embeddingScores[item.id] ?? 0) * 3.2
        return ((item.priority * 5) + (item.effectiveConfidence * 3) + overlap + typeBoost + tierBoost + embeddingBoost) *
            decayMultiplier *
            pendingPenalty
    }

    private static func memorySort(_ lhs: CompilerItem, _ rhs: CompilerItem) -> Bool {
        if lhs.priority == rhs.priority {
            if lhs.isPending != rhs.isPending {
                return !lhs.isPending
            }
            return lhs.lastConfirmedAt > rhs.lastConfirmedAt
        }
        return lhs.priority > rhs.priority
    }

    private static func judgeRetrievalCandidates(
        from orderedItems: [CompilerItem],
        mode: BASDecisionMode,
        queryTags: Set<String>,
        now: Date,
        behavior: BASBrainCompilationBehavior
    ) -> (allowedItems: [EvaluatedItem], screenedOutItems: [EvaluatedItem]) {
        var allowed: [EvaluatedItem] = []
        var screenedOut: [EvaluatedItem] = []

        for item in orderedItems {
            let eligibility = BASMemoryEligibilityJudge.decide(
                candidate: item.eligibilityCandidate,
                mode: mode,
                queryTags: queryTags,
                now: now,
                behavior: behavior
            )
            let evaluated = EvaluatedItem(item: item, eligibility: eligibility)
            if eligibility.isAllowed {
                allowed.append(evaluated)
            } else {
                screenedOut.append(evaluated)
            }
        }

        return (allowed, screenedOut)
    }

    private static func selectItems(
        from orderedItems: [EvaluatedItem],
        limit: Int,
        excludingIDs: Set<String> = [],
        matching predicate: (CompilerItem) -> Bool
    ) -> [EvaluatedItem] {
        var selected: [EvaluatedItem] = []
        var seenHeadlines = Set<String>()

        for evaluated in orderedItems where predicate(evaluated.item) {
            guard !excludingIDs.contains(evaluated.item.id) else { continue }
            guard seenHeadlines.insert(evaluated.item.headline).inserted else { continue }
            selected.append(evaluated)
            if selected.count == limit {
                break
            }
        }

        return selected
    }

    private static func buildMemorySlices(
        profileItems: [EvaluatedItem],
        goalItems: [EvaluatedItem],
        relevantItems: [EvaluatedItem]
    ) -> [BASGovernedMemorySlice] {
        profileItems.map { $0.item.makeSlice(eligibility: $0.eligibility) } +
            goalItems.map { $0.item.makeSlice(eligibility: $0.eligibility) } +
            relevantItems.map { $0.item.makeSlice(eligibility: $0.eligibility) }
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

public enum BASBrainCompiler {
    public static func bootstrap(
        request: BASBrainBootstrapRequest,
        projection: BASBrainProjection
    ) -> BASBootstrappedBrainState {
        BASDecisionBrainCompiler.bootstrap(request: request, projection: projection)
    }
}
