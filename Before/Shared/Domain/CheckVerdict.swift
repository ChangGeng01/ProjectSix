import Foundation

enum CheckVerdict: String, CaseIterable, Codable, Identifiable, Sendable {
    case goAhead
    case pause
    case notRecommended

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goAhead: "Go ahead"
        case .pause: "Pause"
        case .notRecommended: "Not recommended"
        }
    }

    var summary: String {
        switch self {
        case .goAhead: "This looks more like a real choice than a blind impulse."
        case .pause: "This is mixed. Give yourself a little buffer before deciding."
        case .notRecommended: "This looks more like short-term relief than a choice you'll respect."
        }
    }

    var symbolName: String {
        switch self {
        case .goAhead: "checkmark.circle.fill"
        case .pause: "pause.circle.fill"
        case .notRecommended: "hand.raised.circle.fill"
        }
    }
}
