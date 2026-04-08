import Foundation

struct RoutedDecision: Equatable, Sendable {
    let mode: DecisionMode
    let reason: String
}

enum DecisionModeRouter {
    static func route(prompt: String, scenario: ScenarioType? = nil) -> RoutedDecision {
        guard scenario == nil else {
            return RoutedDecision(
                mode: .quick,
                reason: "A named impulse scenario is usually best handled with a fast call first."
            )
        }

        let normalized = normalize(prompt)
        guard !normalized.isEmpty else {
            return RoutedDecision(
                mode: .balance,
                reason: "When the question is still broad, starting with a balance board is the safest default."
            )
        }

        if matchesAny(in: normalized, keywords: mirrorKeywords) {
            return RoutedDecision(
                mode: .mirror,
                reason: "This sounds like a heavier question with identity, relationship, or long-term weight."
            )
        }

        if matchesAny(in: normalized, keywords: quickKeywords) {
            return RoutedDecision(
                mode: .quick,
                reason: "This sounds fast, emotional, and easy to regret later."
            )
        }

        if normalized.contains(" or ") || matchesAny(in: normalized, keywords: balanceKeywords) {
            return RoutedDecision(
                mode: .balance,
                reason: "This looks more like a trade-off than a pure impulse."
            )
        }

        let wordCount = normalized.split(separator: " ").count
        if wordCount >= 16 {
            return RoutedDecision(
                mode: .mirror,
                reason: "Longer, heavier questions usually need a mirror before they need an answer."
            )
        }

        if wordCount <= 6 {
            return RoutedDecision(
                mode: .quick,
                reason: "Short, urgent questions usually benefit from a clean stoplight first."
            )
        }

        return RoutedDecision(
            mode: .balance,
            reason: "This sits in the middle: not a snap urge, not a life verdict. Balance it first."
        )
    }

    private static let quickKeywords = [
        "buy", "order", "spend", "eat", "scroll", "reply", "text back",
        "watch", "open", "click", "smoke", "drink", "message back", "late night"
    ]

    private static let balanceKeywords = [
        "choose", "which", "option", "plan", "schedule", "meet", "dinner",
        "invite", "travel", "trip", "arrange", "decide between", "best way"
    ]

    private static let mirrorKeywords = [
        "break up", "relationship", "partner", "stay or leave", "leave this",
        "quit", "resign", "job", "career", "move away", "move out", "forgive",
        "marriage", "divorce", "continue this", "should i stay", "should i leave"
    ]

    private static func normalize(_ prompt: String) -> String {
        prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func matchesAny(in text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
