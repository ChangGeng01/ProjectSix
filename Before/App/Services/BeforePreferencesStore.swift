import Foundation

enum OnDeviceIntelligenceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case off
    case assistive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .assistive: "Assistive"
        }
    }

    var subtitle: String {
        switch self {
        case .off:
            "Use the deterministic decision system only."
        case .assistive:
            "Let local intelligence tighten routing, summaries, and reminder recall without owning verdicts."
        }
    }

    var isEnabled: Bool {
        self == .assistive
    }
}

enum DecisionModelProviderPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case gemmaE4B
    case openModel
    case foundationModels
    case template

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gemmaE4B: "Gemma 4 E4B"
        case .openModel: "Open model runtime"
        case .foundationModels: "Apple Foundation Model"
        case .template: "Deterministic local copy"
        }
    }

    var subtitle: String {
        switch self {
        case .gemmaE4B:
            "Use the bundled Gemma model as the primary local intelligence provider."
        case .openModel:
            "Use the currently registered open-model runtime slot as the primary local intelligence provider."
        case .foundationModels:
            "Use Apple Intelligence as the primary on-device language model when it is available."
        case .template:
            "Use the rule-based deterministic layer only, without any model refinement."
        }
    }

    var kind: DecisionModelProviderKind {
        switch self {
        case .gemmaE4B: .gemmaE4B
        case .openModel: .openModel
        case .foundationModels: .foundationModels
        case .template: .template
        }
    }
}

enum HomePromptAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case autoRoute
    case quick
    case balance
    case mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .autoRoute: "Auto route"
        case .quick: "Always quick"
        case .balance: "Always balance"
        case .mirror: "Always mirror"
        }
    }

    var buttonTitle: String {
        switch self {
        case .autoRoute: "Route this for me"
        case .quick: "Open quick judgment"
        case .balance: "Open balance board"
        case .mirror: "Open mirror"
        }
    }

    var preferredMode: DecisionMode? {
        switch self {
        case .autoRoute: nil
        case .quick: .quick
        case .balance: .balance
        case .mirror: .mirror
        }
    }
}

struct BeforePreferences: Codable, Equatable, Sendable {
    var homePromptAction: HomePromptAction
    var quickBufferDuration: QuickBufferDuration
    var restoreInProgressWorkspaces: Bool
    var showReviewInsights: Bool
    var onDeviceIntelligenceMode: OnDeviceIntelligenceMode
    var preferredIntelligenceProvider: DecisionModelProviderPreference
    var allowModelFallbacks: Bool

    static let `default` = BeforePreferences(
        homePromptAction: .autoRoute,
        quickBufferDuration: BeforePolicy.QuickCheck.defaultBufferDuration,
        restoreInProgressWorkspaces: true,
        showReviewInsights: true,
        onDeviceIntelligenceMode: .assistive,
        preferredIntelligenceProvider: .gemmaE4B,
        allowModelFallbacks: true
    )

    private enum CodingKeys: String, CodingKey {
        case homePromptAction
        case quickBufferDuration
        case restoreInProgressWorkspaces
        case showReviewInsights
        case onDeviceIntelligenceMode
        case preferredIntelligenceProvider
        case allowModelFallbacks
    }

    init(
        homePromptAction: HomePromptAction,
        quickBufferDuration: QuickBufferDuration,
        restoreInProgressWorkspaces: Bool,
        showReviewInsights: Bool,
        onDeviceIntelligenceMode: OnDeviceIntelligenceMode,
        preferredIntelligenceProvider: DecisionModelProviderPreference,
        allowModelFallbacks: Bool = true
    ) {
        self.homePromptAction = homePromptAction
        self.quickBufferDuration = quickBufferDuration
        self.restoreInProgressWorkspaces = restoreInProgressWorkspaces
        self.showReviewInsights = showReviewInsights
        self.onDeviceIntelligenceMode = onDeviceIntelligenceMode
        self.preferredIntelligenceProvider = preferredIntelligenceProvider
        self.allowModelFallbacks = allowModelFallbacks
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.homePromptAction = try container.decodeIfPresent(HomePromptAction.self, forKey: .homePromptAction) ?? BeforePreferences.default.homePromptAction
        self.quickBufferDuration = try container.decodeIfPresent(QuickBufferDuration.self, forKey: .quickBufferDuration) ?? BeforePreferences.default.quickBufferDuration
        self.restoreInProgressWorkspaces = try container.decodeIfPresent(Bool.self, forKey: .restoreInProgressWorkspaces) ?? BeforePreferences.default.restoreInProgressWorkspaces
        self.showReviewInsights = try container.decodeIfPresent(Bool.self, forKey: .showReviewInsights) ?? BeforePreferences.default.showReviewInsights
        self.onDeviceIntelligenceMode = try container.decodeIfPresent(OnDeviceIntelligenceMode.self, forKey: .onDeviceIntelligenceMode) ?? BeforePreferences.default.onDeviceIntelligenceMode
        self.preferredIntelligenceProvider = try container.decodeIfPresent(DecisionModelProviderPreference.self, forKey: .preferredIntelligenceProvider) ?? BeforePreferences.default.preferredIntelligenceProvider
        self.allowModelFallbacks = try container.decodeIfPresent(Bool.self, forKey: .allowModelFallbacks) ?? BeforePreferences.default.allowModelFallbacks
    }
}

enum BeforePreferencesStore {
    private static let key = "before.preferences"

    static func load() -> BeforePreferences {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let preferences = try? JSONDecoder().decode(BeforePreferences.self, from: data)
        else {
            return .default
        }

        return preferences
    }

    static func save(_ preferences: BeforePreferences) {
        do {
            let data = try JSONEncoder().encode(preferences)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            _ = PersistenceIssueRecorder.record(error: error, operation: "encoding app preferences")
        }
    }
}
