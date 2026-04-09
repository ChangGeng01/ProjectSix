import Foundation

enum WidgetMessageSurface: String, Codable, Equatable, Sendable {
    case publicSafe
}

struct WidgetSafeMessage: Codable, Equatable, Sendable {
    let surface: WidgetMessageSurface
    let headline: String
    let body: String

    static let generic = WidgetSafeMessage(
        surface: .publicSafe,
        headline: "Pause first",
        body: "Open a fast two-perspective check before you act."
    )

    private enum CodingKeys: String, CodingKey {
        case surface
        case headline
        case body
    }

    init(surface: WidgetMessageSurface, headline: String, body: String) {
        self.surface = surface
        self.headline = headline
        self.body = body
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        surface = try container.decodeIfPresent(WidgetMessageSurface.self, forKey: .surface) ?? .publicSafe
        headline = try container.decodeIfPresent(String.self, forKey: .headline) ?? WidgetSafeMessage.generic.headline
        body = try container.decode(String.self, forKey: .body)
    }
}

enum WidgetSafeCopy {
    static func message(for scenario: ScenarioType?, verdict: CheckVerdict?) -> WidgetSafeMessage {
        switch (scenario, verdict) {
        case (.buy, .pause):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Give it room",
                body: "A little distance can change a buying answer."
            )
        case (.buy, .notRecommended):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Let it cool",
                body: "If it still matters tomorrow, it will still be there."
            )
        case (.eat, .pause):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Check the need",
                body: "Pause long enough to tell hunger from comfort."
            )
        case (.eat, .notRecommended):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Wait a beat",
                body: "A quick soothe can pass before you place the order."
            )
        case (.scroll, .pause):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Break the loop",
                body: "A short break now can change the next hour."
            )
        case (.scroll, .notRecommended):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Step out first",
                body: "Rest and endless input are rarely the same thing."
            )
        case (_, .goAhead):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Choose it cleanly",
                body: "If it still feels clean after a breath, choose it on purpose."
            )
        case (.other, .pause):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Pause the momentum",
                body: "Give this one beat before you decide from momentum."
            )
        case (.other, .notRecommended):
            return WidgetSafeMessage(
                surface: .publicSafe,
                headline: "Step back first",
                body: "Clarity tends to come with a little space."
            )
        default:
            return .generic
        }
    }
}
