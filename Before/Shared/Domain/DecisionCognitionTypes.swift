import Foundation

enum DecisionIntentKind: String, Codable, Sendable {
    case quickCapture
    case openMode
    case routedInput
    case openEvolutionControl
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
    case volatile
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

    var sanitizedPromptSeed: String {
        Self.cleanedSeed(promptSeed) ?? ""
    }

    private static func cleanedSeed(_ text: String?) -> String? {
        let cleanedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedText?.isEmpty == true ? nil : cleanedText
    }

    static func quickCapture(
        entrySource: EntrySource,
        scenario: ScenarioType? = nil,
        promptSeed: String? = nil,
        riskLevel: InterventionRiskLevel = .low,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> DecisionIntentEnvelope {
        return DecisionIntentEnvelope(
            kind: .quickCapture,
            sourceSurface: entrySource.intentSourceSurface,
            entrySource: entrySource,
            preferredMode: .quick,
            scenario: scenario,
            promptSeed: cleanedSeed(promptSeed),
            riskLevel: riskLevel,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func openMode(
        entrySource: EntrySource,
        mode: DecisionMode,
        promptSeed: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> DecisionIntentEnvelope {
        return DecisionIntentEnvelope(
            kind: .openMode,
            sourceSurface: entrySource.intentSourceSurface,
            entrySource: entrySource,
            preferredMode: mode,
            promptSeed: cleanedSeed(promptSeed),
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func routedInput(
        entrySource: EntrySource,
        promptSeed: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> DecisionIntentEnvelope {
        DecisionIntentEnvelope(
            kind: .routedInput,
            sourceSurface: entrySource.intentSourceSurface,
            entrySource: entrySource,
            promptSeed: cleanedSeed(promptSeed),
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func openEvolutionControl(
        entrySource: EntrySource,
        promptSeed: String? = nil,
        triggerReason: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> DecisionIntentEnvelope {
        let cleanedTriggerReason = cleanedSeed(triggerReason)
        return DecisionIntentEnvelope(
            kind: .openEvolutionControl,
            sourceSurface: entrySource.intentSourceSurface,
            entrySource: entrySource,
            preferredMode: .mirror,
            promptSeed: cleanedSeed(promptSeed),
            riskLevel: .medium,
            triggerReason: cleanedTriggerReason?.isEmpty == false
                ? cleanedTriggerReason
                : entrySource.defaultEvolutionControlTriggerReason,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func reopenTomorrowItem(
        sourceSurface: DecisionIntentSourceSurface? = nil,
        entrySource: EntrySource,
        title: String,
        riskLevel: InterventionRiskLevel,
        preferredMode: DecisionMode,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> DecisionIntentEnvelope {
        return DecisionIntentEnvelope(
            kind: .reopenTomorrowItem,
            sourceSurface: sourceSurface ?? entrySource.intentSourceSurface,
            entrySource: entrySource,
            preferredMode: preferredMode,
            promptSeed: cleanedSeed(title),
            riskLevel: riskLevel,
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func predictiveIntervention(
        sourceSurface: DecisionIntentSourceSurface = .notification,
        entrySource: EntrySource = .app,
        preferredMode: DecisionMode,
        promptSeed: String? = nil,
        riskLevel: InterventionRiskLevel,
        triggerReason: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> DecisionIntentEnvelope {
        DecisionIntentEnvelope(
            kind: .predictiveIntervention,
            sourceSurface: sourceSurface,
            entrySource: entrySource,
            preferredMode: preferredMode,
            promptSeed: cleanedSeed(promptSeed),
            riskLevel: riskLevel,
            triggerReason: cleanedSeed(triggerReason),
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }

    static func resumeCurrentDecision(
        sourceSurface: DecisionIntentSourceSurface,
        entrySource: EntrySource,
        preferredMode: DecisionMode,
        promptSeed: String? = nil,
        riskLevel: InterventionRiskLevel? = nil,
        triggerReason: String? = nil,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) -> DecisionIntentEnvelope {
        DecisionIntentEnvelope(
            kind: .resumeCurrentDecision,
            sourceSurface: sourceSurface,
            entrySource: entrySource,
            preferredMode: preferredMode,
            promptSeed: cleanedSeed(promptSeed),
            riskLevel: riskLevel,
            triggerReason: cleanedSeed(triggerReason),
            requestedAt: requestedAt,
            expiresAt: expiresAt
        )
    }
}

extension DecisionIntentEnvelope {
    var launchRequestResolution: LaunchRequestResolution {
        if let scenario {
            return .quick(scenario: scenario, prompt: sanitizedPromptSeed)
        }

        if let preferredMode {
            return .mode(preferredMode, prompt: sanitizedPromptSeed)
        }

        if !sanitizedPromptSeed.isEmpty {
            return .routedPrompt(sanitizedPromptSeed)
        }

        return .quick(scenario: nil, prompt: "")
    }
}

extension EntrySource {
    var intentSourceSurface: DecisionIntentSourceSurface {
        switch self {
        case .watch:
            .watch
        case .homeWidgetSmall, .homeWidgetMedium, .lockScreenWidget:
            .widget
        case .siri:
            .siri
        case .shortcut, .spotlight, .app:
            .shortcut
        }
    }

    var defaultEvolutionControlTriggerReason: String {
        switch self {
        case .watch:
            "A watch glance asked the iPhone brain to open Evolution Control."
        default:
            "Open Evolution Control from \(label)."
        }
    }
}
