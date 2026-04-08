import Foundation

enum DecisionMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case quick
    case balance
    case mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: "Quick Judgment"
        case .balance: "Balance Board"
        case .mirror: "Mirror"
        }
    }

    var shortTitle: String {
        switch self {
        case .quick: "Quick"
        case .balance: "Balance"
        case .mirror: "Mirror"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: "For urges, snap calls, and decisions that can go blurry fast."
        case .balance: "For trade-offs that need structure, not another loop in your head."
        case .mirror: "For heavier questions that need honesty, not a forced verdict."
        }
    }

    var symbolName: String {
        switch self {
        case .quick: "stop.circle"
        case .balance: "slider.horizontal.3"
        case .mirror: "square.split.2x1"
        }
    }

    var callToAction: String {
        switch self {
        case .quick: "Open quick judgment"
        case .balance: "Open balance board"
        case .mirror: "Open mirror"
        }
    }
}
