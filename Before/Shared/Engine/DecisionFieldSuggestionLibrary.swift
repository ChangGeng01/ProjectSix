import Foundation

enum BalanceField: String, CaseIterable, Sendable {
    case desire
    case concern
    case constraint
    case longTerm
}

enum MirrorField: String, CaseIterable, Sendable {
    case emotion
    case relationship
    case reality
    case longTerm
    case selfLens
}

enum DecisionFieldSuggestionLibrary {
    static func suggestions(for field: BalanceField) -> [String] {
        switch field {
        case .desire:
            [
                "I want the easiest option.",
                "I want this to feel good, not just efficient.",
                "I want the choice with the least friction."
            ]
        case .concern:
            [
                "I do not want to waste money on the wrong call.",
                "I am trying to protect my time and energy.",
                "I do not want to create awkwardness or regret."
            ]
        case .constraint:
            [
                "The schedule is already tight.",
                "Budget is real here, even if I want to ignore it.",
                "Distance or logistics make some options heavier."
            ]
        case .longTerm:
            [
                "Future-me will care more about the cost than the moment.",
                "I will probably respect the calmer choice more tomorrow.",
                "This is small now, but it can set a pattern."
            ]
        }
    }

    static func suggestions(for field: MirrorField) -> [String] {
        switch field {
        case .emotion:
            [
                "I feel hurt more than I want to admit.",
                "I am afraid of losing this, even if I am tired.",
                "Part of me feels relief, and that matters."
            ]
        case .relationship:
            [
                "The same pattern keeps repeating after every repair.",
                "Respect or trust feels thinner than it should.",
                "I keep shrinking to keep this working."
            ]
        case .reality:
            [
                "Money, housing, or work make this harder to move on.",
                "Family or logistics are part of the weight here.",
                "There are real constraints, not just feelings."
            ]
        case .longTerm:
            [
                "If this stays the same, I can already see the drift.",
                "Continuing like this could cost me more than leaving.",
                "Ending it would hurt, but staying may shape a life I do not want."
            ]
        case .selfLens:
            [
                "I feel less like myself inside this.",
                "I am trying not to lose my self-respect here.",
                "I want to choose the version of me I can still stand beside."
            ]
        }
    }
}
