import Foundation

enum SupportRequestKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case holdMe10Minutes
    case helpMeJudgeThis
    case iAmGettingBlurry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .holdMe10Minutes: "Hold me for 10 minutes"
        case .helpMeJudgeThis: "Help me judge this"
        case .iAmGettingBlurry: "I am getting blurry"
        }
    }

    var subtitle: String {
        switch self {
        case .holdMe10Minutes:
            "A small pause when the impulse is loud."
        case .helpMeJudgeThis:
            "A second brain for a fast trade-off."
        case .iAmGettingBlurry:
            "A calm reset when the signal gets fuzzy."
        }
    }

    var symbolName: String {
        switch self {
        case .holdMe10Minutes: "timer"
        case .helpMeJudgeThis: "questionmark.circle"
        case .iAmGettingBlurry: "cloud.fog"
        }
    }

    var defaultMessage: String {
        switch self {
        case .holdMe10Minutes:
            "I am close to acting fast and I need a short pause."
        case .helpMeJudgeThis:
            "I want a clearer read before I choose."
        case .iAmGettingBlurry:
            "I am losing the shape of this decision."
        }
    }

    var quickReplies: [String] {
        switch self {
        case .holdMe10Minutes:
            [
                "Stay with me",
                "Keep me from acting too fast",
                "Just help me slow down"
            ]
        case .helpMeJudgeThis:
            [
                "Name the trade-off",
                "Point out the blind spot",
                "Tell me what matters most"
            ]
        case .iAmGettingBlurry:
            [
                "Reduce the noise",
                "Help me reset",
                "Give me one clear next step"
            ]
        }
    }
}
