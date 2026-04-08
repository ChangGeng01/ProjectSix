import AppIntents
import Foundation

enum ScenarioType: String, CaseIterable, Codable, Identifiable, Sendable {
    case buy
    case eat
    case scroll
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buy: "Buy"
        case .eat: "Eat"
        case .scroll: "Scroll"
        case .other: "Other"
        }
    }

    var subtitle: String {
        switch self {
        case .buy: "Something that feels tempting right now."
        case .eat: "Food, sugar, delivery, or comfort eating."
        case .scroll: "Short videos, doomscrolling, or staying up."
        case .other: "Anything that might feel good now but strange later."
        }
    }

    var symbolName: String {
        switch self {
        case .buy: "bag"
        case .eat: "fork.knife"
        case .scroll: "play.rectangle"
        case .other: "sparkle.magnifyingglass"
        }
    }
}

extension ScenarioType: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Scenario"

    static let caseDisplayRepresentations: [ScenarioType: DisplayRepresentation] = [
        .buy: "Buy",
        .eat: "Eat",
        .scroll: "Scroll",
        .other: "Other"
    ]
}
