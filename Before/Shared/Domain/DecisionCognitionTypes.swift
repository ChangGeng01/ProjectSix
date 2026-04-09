import Foundation

enum DecisionIntentKind: String, Codable, Sendable {
    case quickCapture
    case openMode
    case reopenTomorrowItem
    case predictiveIntervention
    case resumeCurrentDecision
}

enum DecisionIntentSourceSurface: String, Codable, Sendable {
    case app
    case watch
    case widget
    case shortcut
    case siri
    case notification
}

enum InterventionRiskLevel: String, CaseIterable, Codable, Identifiable, Sendable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var subtitle: String {
        switch self {
        case .low:
            "A light nudge or Tomorrow Box is usually enough."
        case .medium:
            "A little distance and one cleaner question can help."
        case .high:
            "Slow the move down and reopen it with more structure."
        }
    }
}

enum DecisionMemoryTier: String, CaseIterable, Codable, Sendable {
    case hot
    case warm
    case cold
}

struct DecisionIntentEnvelope: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: DecisionIntentKind
    let sourceSurfaceRaw: String
    let entrySourceRaw: String
    let preferredModeRaw: String?
    let scenarioRaw: String?
    let promptSeed: String?
    let riskLevelRaw: String?
    let triggerReason: String?
    let brainFingerprint: String?
    let requestedAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        kind: DecisionIntentKind,
        sourceSurface: DecisionIntentSourceSurface,
        entrySource: EntrySource,
        preferredMode: DecisionMode? = nil,
        scenario: ScenarioType? = nil,
        promptSeed: String? = nil,
        riskLevel: InterventionRiskLevel? = nil,
        triggerReason: String? = nil,
        brainFingerprint: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.sourceSurfaceRaw = sourceSurface.rawValue
        self.entrySourceRaw = entrySource.rawValue
        self.preferredModeRaw = preferredMode?.rawValue
        self.scenarioRaw = scenario?.rawValue
        self.promptSeed = promptSeed
        self.riskLevelRaw = riskLevel?.rawValue
        self.triggerReason = triggerReason
        self.brainFingerprint = brainFingerprint
        self.requestedAt = requestedAt
        self.expiresAt = expiresAt ?? requestedAt.addingTimeInterval(BeforePolicy.LaunchRequests.expirationInterval)
    }

    var sourceSurface: DecisionIntentSourceSurface {
        DecisionIntentSourceSurface(rawValue: sourceSurfaceRaw) ?? .app
    }

    var entrySource: EntrySource {
        EntrySource(rawValue: entrySourceRaw) ?? .app
    }

    var preferredMode: DecisionMode? {
        preferredModeRaw.flatMap(DecisionMode.init(rawValue:))
    }

    var scenario: ScenarioType? {
        scenarioRaw.flatMap(ScenarioType.init(rawValue:))
    }

    var riskLevel: InterventionRiskLevel? {
        riskLevelRaw.flatMap(InterventionRiskLevel.init(rawValue:))
    }
}
