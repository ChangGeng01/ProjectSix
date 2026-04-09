import CryptoKit
import Foundation

enum DecisionReactionWeightKey: String, CaseIterable, Codable, Sendable {
    case briefLanguage = "brief_language"
    case warmDirectTone = "warm_direct_tone"
    case lowCognitiveLoad = "low_cognitive_load"
    case interruptiveActionBias = "interruptive_action_bias"
    case boundaryNamingBias = "boundary_naming_bias"
    case tradeoffClarityBias = "tradeoff_clarity_bias"
}

struct DecisionReactionWeights: Codable, Equatable, Sendable {
    var briefLanguage: Double
    var warmDirectTone: Double
    var lowCognitiveLoad: Double
    var interruptiveActionBias: Double
    var boundaryNamingBias: Double
    var tradeoffClarityBias: Double

    static func defaults(for mode: DecisionMode) -> DecisionReactionWeights {
        switch mode {
        case .quick:
            DecisionReactionWeights(
                briefLanguage: 0.62,
                warmDirectTone: 0.58,
                lowCognitiveLoad: 0.54,
                interruptiveActionBias: 0.72,
                boundaryNamingBias: 0.34,
                tradeoffClarityBias: 0.38
            )
        case .balance:
            DecisionReactionWeights(
                briefLanguage: 0.48,
                warmDirectTone: 0.56,
                lowCognitiveLoad: 0.4,
                interruptiveActionBias: 0.36,
                boundaryNamingBias: 0.44,
                tradeoffClarityBias: 0.76
            )
        case .mirror:
            DecisionReactionWeights(
                briefLanguage: 0.44,
                warmDirectTone: 0.62,
                lowCognitiveLoad: 0.46,
                interruptiveActionBias: 0.28,
                boundaryNamingBias: 0.78,
                tradeoffClarityBias: 0.42
            )
        }
    }

    func value(for key: DecisionReactionWeightKey) -> Double {
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

    var dominantKey: DecisionReactionWeightKey {
        DecisionReactionWeightKey.allCases.max { lhs, rhs in
            value(for: lhs) < value(for: rhs)
        } ?? .briefLanguage
    }
}

enum DecisionBrainMemoryRole: String, Codable, Sendable {
    case profile
    case goal
    case relevant
}

enum DecisionMemorySourceTrustTier: String, Codable, Sendable {
    case low
    case medium
    case high
}

enum DecisionMemoryEligibilityReason: String, CaseIterable, Codable, Sendable {
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

struct DecisionMemoryEligibilityDecision: Codable, Equatable, Sendable {
    let isAllowed: Bool
    let reason: DecisionMemoryEligibilityReason

    static func allowed(_ reason: DecisionMemoryEligibilityReason) -> DecisionMemoryEligibilityDecision {
        DecisionMemoryEligibilityDecision(isAllowed: true, reason: reason)
    }

    static func screenedOut(_ reason: DecisionMemoryEligibilityReason) -> DecisionMemoryEligibilityDecision {
        DecisionMemoryEligibilityDecision(isAllowed: false, reason: reason)
    }
}

enum DecisionGovernedMemoryStatus: String, Codable, Sendable {
    case admitted
    case deferred
    case pending
}

struct DecisionGovernedMemorySlice: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let role: DecisionBrainMemoryRole
    let type: String
    let headline: String
    let source: String
    let confidence: Double
    let priority: Double
    let lifecycleState: String
    let governanceStatus: DecisionGovernedMemoryStatus
    let eligibility: DecisionMemoryEligibilityDecision
    let sourceTrustScore: Double
    let sourceTrustTier: DecisionMemorySourceTrustTier
    let retrievalTags: [String]
    let isPending: Bool
    let provenanceSummary: String
}

enum DecisionBrainStateRiskFlag: String, Codable, Sendable {
    case highPendingInfluence = "high_pending_influence"
    case lowTrustLoad = "low_trust_load"
    case contaminationGuardTriggered = "contamination_guard_triggered"
    case retrievalInstability = "retrieval_instability"
    case tagFloodBlocked = "tag_flood_blocked"
}

struct DecisionBrainStateSnapshot: Codable, Equatable, Sendable {
    let fingerprint: String
    let dominantReactionWeight: DecisionReactionWeightKey
    let loadedMemoryCount: Int
    let pendingMemoryLoadRate: Double
    let lowTrustMemoryLoadRate: Double
    let riskFlags: [DecisionBrainStateRiskFlag]
}

struct DecisionMemoryGovernanceState: Codable, Equatable, Sendable {
    var totalRecordCount: Int
    var totalCandidateCount: Int
    var pendingCandidateCount: Int
    var promotedCandidateCount: Int
    var loadedPromotedMemoryCount: Int
    var loadedPendingMemoryCount: Int
    var deferredCandidateCount: Int = 0
    var admittedCandidateCount: Int = 0
    var screenedOutMemoryCount: Int = 0
    var screenedOutPendingMemoryCount: Int = 0
    var loadedReasonCounts: [DecisionMemoryEligibilityReason: Int] = [:]
    var screenedOutReasonCounts: [DecisionMemoryEligibilityReason: Int] = [:]

    static let empty = DecisionMemoryGovernanceState(
        totalRecordCount: 0,
        totalCandidateCount: 0,
        pendingCandidateCount: 0,
        promotedCandidateCount: 0,
        loadedPromotedMemoryCount: 0,
        loadedPendingMemoryCount: 0
    )
}

struct DecisionBrainState: Codable, Equatable, Sendable {
    var memorySlices: [DecisionGovernedMemorySlice]
    var sessionBiases: [String]
    var retrievalTags: [String]
    var reactionWeights: DecisionReactionWeights
    var memoryGovernance: DecisionMemoryGovernanceState = .empty
    var loadedAt: Date

    init(
        memorySlices: [DecisionGovernedMemorySlice],
        sessionBiases: [String],
        retrievalTags: [String],
        reactionWeights: DecisionReactionWeights,
        memoryGovernance: DecisionMemoryGovernanceState = .empty,
        loadedAt: Date
    ) {
        self.memorySlices = memorySlices
        self.sessionBiases = sessionBiases
        self.retrievalTags = retrievalTags
        self.reactionWeights = reactionWeights
        self.memoryGovernance = memoryGovernance
        self.loadedAt = loadedAt
    }

    init(
        profileCore: [String],
        activeGoals: [String],
        relevantMemories: [String],
        sessionBiases: [String],
        retrievalTags: [String],
        reactionWeights: DecisionReactionWeights,
        memoryGovernance: DecisionMemoryGovernanceState = .empty,
        loadedAt: Date = .now
    ) {
        self.init(
            memorySlices: Self.legacyMemorySlices(
                profileCore: profileCore,
                activeGoals: activeGoals,
                relevantMemories: relevantMemories
            ),
            sessionBiases: sessionBiases,
            retrievalTags: retrievalTags,
            reactionWeights: reactionWeights,
            memoryGovernance: memoryGovernance,
            loadedAt: loadedAt
        )
    }

    var profileCoreSlices: [DecisionGovernedMemorySlice] {
        memorySlices.filter { $0.role == .profile }
    }

    var activeGoalSlices: [DecisionGovernedMemorySlice] {
        memorySlices.filter { $0.role == .goal }
    }

    var relevantMemorySlices: [DecisionGovernedMemorySlice] {
        memorySlices.filter { $0.role == .relevant }
    }

    var profileCore: [String] {
        profileCoreSlices.map(\.headline)
    }

    var activeGoals: [String] {
        activeGoalSlices.map(\.headline)
    }

    var relevantMemories: [String] {
        relevantMemorySlices.map(\.headline)
    }

    var isEmpty: Bool {
        memorySlices.isEmpty &&
            sessionBiases.isEmpty &&
            retrievalTags.isEmpty
    }

    var verificationSnapshot: DecisionBrainStateSnapshot {
        let governanceLoadedMemoryCount = memoryGovernance.loadedPromotedMemoryCount +
            memoryGovernance.loadedPendingMemoryCount
        let loadedMemoryCount = max(memorySlices.count, governanceLoadedMemoryCount)
        let pendingMemoryCount = max(
            memorySlices.filter(\.isPending).count,
            memoryGovernance.loadedPendingMemoryCount
        )
        let lowTrustMemoryCount = memorySlices.filter { $0.sourceTrustTier == .low }.count

        let pendingMemoryLoadRate = loadedMemoryCount > 0
            ? Double(pendingMemoryCount) / Double(loadedMemoryCount)
            : 0
        let lowTrustMemoryLoadRate = loadedMemoryCount > 0
            ? Double(lowTrustMemoryCount) / Double(loadedMemoryCount)
            : 0

        var riskFlags: [DecisionBrainStateRiskFlag] = []
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

        let material = [
            profileCore.sorted().joined(separator: "|"),
            activeGoals.sorted().joined(separator: "|"),
            relevantMemories.sorted().joined(separator: "|"),
            sessionBiases.sorted().joined(separator: "|"),
            retrievalTags.sorted().joined(separator: "|"),
            reactionWeights.dominantKey.rawValue,
            memorySlices
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
                .joined(separator: "||"),
            riskFlags.map(\.rawValue).sorted().joined(separator: "|")
        ]
        .joined(separator: "###")

        let fingerprint = SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(20)

        return DecisionBrainStateSnapshot(
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
    ) -> [DecisionGovernedMemorySlice] {
        let defaultEligibility = DecisionMemoryEligibilityDecision.allowed(.defaultAllowed)
        let defaultTags: [String] = []

        let profileSlices = profileCore.enumerated().map { index, headline in
            DecisionGovernedMemorySlice(
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
            DecisionGovernedMemorySlice(
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
            DecisionGovernedMemorySlice(
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
