import AppIntents
import Foundation

enum EntrySource: String, CaseIterable, Codable, Identifiable, Sendable {
    case app
    case homeWidgetSmall
    case homeWidgetMedium
    case lockScreenWidget
    case siri
    case shortcut
    case spotlight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .app: "App"
        case .homeWidgetSmall: "Small Widget"
        case .homeWidgetMedium: "Medium Widget"
        case .lockScreenWidget: "Lock Screen Widget"
        case .siri: "Siri"
        case .shortcut: "Shortcut"
        case .spotlight: "Spotlight"
        }
    }
}

extension EntrySource: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Entry Source"

    static let caseDisplayRepresentations: [EntrySource: DisplayRepresentation] = [
        .app: "App",
        .homeWidgetSmall: "Small Widget",
        .homeWidgetMedium: "Medium Widget",
        .lockScreenWidget: "Lock Screen Widget",
        .siri: "Siri",
        .shortcut: "Shortcut",
        .spotlight: "Spotlight"
    ]
}
