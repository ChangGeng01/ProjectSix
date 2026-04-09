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
    let retrievalTags: [String]
    let isPending: Bool
    let provenanceSummary: String
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
                retrievalTags: defaultTags,
                isPending: false,
                provenanceSummary: "Legacy relevant-memory projection."
            )
        }

        return profileSlices + goalSlices + relevantSlices
    }
}
