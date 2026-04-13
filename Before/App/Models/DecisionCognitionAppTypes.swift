import Foundation

enum BrainStateUpdateSource: String, Codable, Sendable {
    case launch
    case sceneActive
    case watchHandoff
    case notification
    case widget
    case explicitRefresh
    case sessionBootstrap = "session_bootstrap"

    init?(identifier: String) {
        switch BeforeLegacyMigration.normalizedBrainStateUpdateSourceIdentifier(identifier) {
        case Self.launch.rawValue:
            self = .launch
        case Self.sceneActive.rawValue:
            self = .sceneActive
        case Self.watchHandoff.rawValue:
            self = .watchHandoff
        case Self.notification.rawValue:
            self = .notification
        case Self.widget.rawValue:
            self = .widget
        case Self.explicitRefresh.rawValue:
            self = .explicitRefresh
        case Self.sessionBootstrap.rawValue:
            self = .sessionBootstrap
        default:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let source = BrainStateUpdateSource(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported brain state update source identifier: \(identifier)"
            )
        }
        self = source
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CurrentBrainState: Equatable, Sendable {
    let source: BrainStateUpdateSource
    let sourceSurface: DecisionIntentSourceSurface
    let mode: DecisionMode
    let riskLevel: InterventionRiskLevel
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

    var identityProfile: DecisionIdentityProfile {
        brainState.identityProfile
    }

    var boundaryPolicy: DecisionBoundaryPolicyState {
        brainState.boundaryPolicy
    }

    var calibrationState: DecisionCalibrationState {
        brainState.calibrationState
    }

    var evolutionState: DecisionEvolutionState {
        brainState.evolutionState
    }

    func replacingEvolutionState(_ evolutionState: DecisionEvolutionState) -> CurrentBrainState {
        var updatedBrainState = brainState
        updatedBrainState.evolutionState = evolutionState

        return CurrentBrainState(
            source: source,
            sourceSurface: sourceSurface,
            mode: mode,
            riskLevel: riskLevel,
            taskGraph: taskGraph,
            brainState: updatedBrainState,
            dominantGoal: dominantGoal,
            activeConstraints: activeConstraints,
            activeTemplateIDs: activeTemplateIDs,
            failureGuardIDs: failureGuardIDs,
            sourceIntentEnvelope: sourceIntentEnvelope,
            loadedAt: loadedAt
        )
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
    let evidenceSignalCount: Int
    let suggestedModeRaw: String?
    let reason: String
    let createdAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        riskLevel: InterventionRiskLevel,
        title: String,
        detail: String,
        evidenceSignalCount: Int = 1,
        suggestedMode: DecisionMode? = nil,
        reason: String,
        createdAt: Date = .now,
        expiresAt: Date
    ) {
        self.id = id
        self.riskLevel = riskLevel
        self.title = title
        self.detail = detail
        self.evidenceSignalCount = max(0, evidenceSignalCount)
        self.suggestedModeRaw = suggestedMode?.rawValue
        self.reason = reason
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    var suggestedMode: DecisionMode? {
        suggestedModeRaw.flatMap(DecisionMode.init(rawValue:))
    }
}
