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
    var profileCore: [String]
    var activeGoals: [String]
    var relevantMemories: [String]
    var sessionBiases: [String]
    var retrievalTags: [String]
    var reactionWeights: DecisionReactionWeights
    var memoryGovernance: DecisionMemoryGovernanceState = .empty
    var loadedAt: Date

    var isEmpty: Bool {
        profileCore.isEmpty &&
            activeGoals.isEmpty &&
            relevantMemories.isEmpty &&
            sessionBiases.isEmpty &&
            retrievalTags.isEmpty
    }
}
