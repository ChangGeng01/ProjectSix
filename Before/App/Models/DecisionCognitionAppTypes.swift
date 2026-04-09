import Foundation

enum BrainStateUpdateSource: String, Codable, Sendable {
    case launch
    case sceneActive
    case watchHandoff
    case notification
    case widget
    case explicitRefresh
    case sessionPrime
}

struct CurrentBrainState: Equatable, Sendable {
    let source: BrainStateUpdateSource
    let mode: DecisionMode
    let taskGraph: DecisionTaskGraphSnapshot?
    let brainState: DecisionBrainState
    let dominantGoal: String?
    let activeConstraints: [String]
    let activeTemplateIDs: [String]
    let failureGuardIDs: [String]
    let sourceIntentEnvelope: DecisionIntentEnvelope?
    let loadedAt: Date

    var verificationSnapshot: DecisionBrainStateSnapshot {
        brainState.verificationSnapshot
    }

    var dominantReactionWeight: DecisionReactionWeightKey {
        brainState.reactionWeights.dominantKey
    }
}

struct BrainPortraitMemoryItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let source: DecisionMemorySource
    let confidence: Double
    let tier: DecisionMemoryTier
    let isPending: Bool
    let lastConfirmedAt: Date
    let governanceStatus: DecisionGovernedMemoryStatus
}

struct BrainPortraitTemplateItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let body: [String]
    let mode: DecisionMode
    let riskLevel: InterventionRiskLevel
    let isPinned: Bool
    let successCount: Int
}

struct BrainPortraitFailurePatternItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let mode: DecisionMode
    let cadenceTag: String
    let suppressionWeight: Double
    let evidenceCount: Int
}

struct BrainPortraitPanelState: Equatable, Sendable {
    let currentBrainState: CurrentBrainState?
    let memories: [BrainPortraitMemoryItem]
    let templates: [BrainPortraitTemplateItem]
    let failurePatterns: [BrainPortraitFailurePatternItem]
    let generatedAt: Date
}

struct InterventionPredictionCandidate: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let riskLevel: InterventionRiskLevel
    let title: String
    let detail: String
    let suggestedModeRaw: String?
    let reason: String
    let createdAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        riskLevel: InterventionRiskLevel,
        title: String,
        detail: String,
        suggestedMode: DecisionMode? = nil,
        reason: String,
        createdAt: Date = .now,
        expiresAt: Date
    ) {
        self.id = id
        self.riskLevel = riskLevel
        self.title = title
        self.detail = detail
        self.suggestedModeRaw = suggestedMode?.rawValue
        self.reason = reason
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    var suggestedMode: DecisionMode? {
        suggestedModeRaw.flatMap(DecisionMode.init(rawValue:))
    }
}
