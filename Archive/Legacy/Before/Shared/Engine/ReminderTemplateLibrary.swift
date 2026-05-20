import Foundation

enum ReminderTemplateLibrary {
    static func templates(for scenario: ScenarioType, outcome: ReflectionOutcome?) -> [String] {
        let base: [String]
        switch scenario {
        case .buy:
            base = [
                "I do not want the item. I want relief.",
                "When I feel rushed, my buying judgment gets worse.",
                "Last time this did not change the day."
            ]
        case .eat:
            base = [
                "This feels more emotional than hungry.",
                "If I wait ten minutes, the edge usually softens.",
                "Comfort is real, but delivery is not the only version of it."
            ]
        case .scroll:
            base = [
                "Ten minutes usually turns into much more.",
                "This is escape, not rest.",
                "If I need rest, endless input is the wrong tool."
            ]
        case .other:
            base = [
                "My first urge is not always my clearest choice.",
                "A little space usually changes the answer.",
                "I want relief. I do not necessarily want this."
            ]
        }

        guard let outcome else {
            return base
        }

        switch outcome {
        case .betterThanExpected:
            return [
                "This time it was okay because I chose it, not because I escaped into it.",
                "A real yes feels calmer than a frantic yes.",
                "Not every urge is a mistake."
            ]
        case .okay:
            return [
                "It was okay, but not as urgent as it felt.",
                "If I can name it clearly, I can choose it clearly.",
                "Neutral outcomes still count as information."
            ]
        case .notNeeded:
            return base
        case .regrettedIt:
            return [
                "I knew this would not feel good afterward.",
                "Relief lasted less than I hoped.",
                "Next time I can pause before repeating this pattern."
            ]
        case .feltEmptier:
            return [
                "If it leaves me emptier, it is not what I needed.",
                "Numbing the moment is not the same as caring for it.",
                "The urge was loud. The result was small."
            ]
        }
    }
}
