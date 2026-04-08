import Foundation

struct WidgetSafeMessage: Codable, Equatable, Sendable {
    let body: String

    static let generic = WidgetSafeMessage(
        body: "Open a fast two-perspective check before you act."
    )
}

enum WidgetSafeCopy {
    static func message(for scenario: ScenarioType?, verdict: CheckVerdict?) -> WidgetSafeMessage {
        switch (scenario, verdict) {
        case (.buy, .pause):
            return WidgetSafeMessage(body: "A little distance can change a buying answer.")
        case (.buy, .notRecommended):
            return WidgetSafeMessage(body: "If it still matters tomorrow, it will still be there.")
        case (.eat, .pause):
            return WidgetSafeMessage(body: "Pause long enough to tell hunger from comfort.")
        case (.eat, .notRecommended):
            return WidgetSafeMessage(body: "A quick soothe can pass before you place the order.")
        case (.scroll, .pause):
            return WidgetSafeMessage(body: "A short break now can change the next hour.")
        case (.scroll, .notRecommended):
            return WidgetSafeMessage(body: "Rest and endless input are rarely the same thing.")
        case (_, .goAhead):
            return WidgetSafeMessage(body: "If it still feels clean after a breath, choose it on purpose.")
        case (.other, .pause):
            return WidgetSafeMessage(body: "Give this one beat before you decide from momentum.")
        case (.other, .notRecommended):
            return WidgetSafeMessage(body: "Step back first. Clarity tends to come with a little space.")
        default:
            return .generic
        }
    }
}
