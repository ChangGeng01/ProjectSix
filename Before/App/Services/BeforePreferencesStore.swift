import Foundation

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
}

struct BeforePreferences: Codable, Equatable, Sendable {
    var homePromptAction: HomePromptAction
    var restoreInProgressWorkspaces: Bool
    var showReviewInsights: Bool

    static let `default` = BeforePreferences(
        homePromptAction: .autoRoute,
        restoreInProgressWorkspaces: true,
        showReviewInsights: true
    )
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
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
