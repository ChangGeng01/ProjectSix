import Foundation

struct BalanceBoardInput: Equatable, Sendable {
    let prompt: String
    let desire: String
    let concern: String
    let constraint: String
    let longTerm: String
}

struct BalanceBoardResult: Codable, Equatable, Sendable {
    let headline: String
    let summary: String
    let focusTitle: String
    let focusDescription: String
    let nextAction: String
}

enum BalanceBoardEngine {
    static func evaluate(_ input: BalanceBoardInput) -> BalanceBoardResult {
        let trimmedDesire = trimmed(input.desire)
        let trimmedConcern = trimmed(input.concern)
        let trimmedConstraint = trimmed(input.constraint)
        let trimmedLongTerm = trimmed(input.longTerm)

        let focus = determineFocus(
            concern: trimmedConcern,
            constraint: trimmedConstraint,
            longTerm: trimmedLongTerm
        )

        return BalanceBoardResult(
            headline: "This looks like a trade-off, not a right-or-wrong call.",
            summary: buildSummary(
                desire: trimmedDesire,
                concern: trimmedConcern,
                constraint: trimmedConstraint,
                longTerm: trimmedLongTerm
            ),
            focusTitle: focus.title,
            focusDescription: focus.description,
            nextAction: focus.nextAction
        )
    }

    private static func determineFocus(
        concern: String,
        constraint: String,
        longTerm: String
    ) -> (title: String, description: String, nextAction: String) {
        let constraintText = constraint.lowercased()
        let longTermText = longTerm.lowercased()

        if containsAny(constraintText, keywords: ["budget", "money", "time", "energy", "schedule", "work", "distance"]) {
            return (
                "Let reality lead first",
                "You already named a concrete limit. Decide what is actually non-negotiable before debating preferences.",
                "Write the one hard limit first, then compare options only inside that boundary."
            )
        }

        if !longTerm.isEmpty || containsAny(longTermText, keywords: ["regret", "later", "future", "month", "year", "drain"]) {
            return (
                "Let future-you get a vote",
                "The long-term cost is already in the room. Bring it forward before short-term convenience takes over.",
                "Name which outcome you would respect more a week from now, then let that lead the choice."
            )
        }

        if !concern.isEmpty {
            return (
                "Name what you are protecting",
                "Your hesitation is probably guarding something real. Clarify that first so the choice stops feeling vague.",
                "Finish this sentence honestly: 'What I do not want to lose here is ...'"
            )
        }

        return (
            "Lead with what you want",
            "Nothing here sounds dangerous yet. The fog may simply come from never naming the real preference out loud.",
            "State the outcome you want most in one sentence before you compare anything else."
        )
    }

    private static func buildSummary(
        desire: String,
        concern: String,
        constraint: String,
        longTerm: String
    ) -> String {
        let dimensions = [
            desire.isEmpty ? nil : "what you want",
            concern.isEmpty ? nil : "what you are protecting",
            constraint.isEmpty ? nil : "what reality allows",
            longTerm.isEmpty ? nil : "what future-you will live with"
        ]
        .compactMap { $0 }

        if dimensions.isEmpty {
            return "Before you pick an option, name at least two sides of the trade-off."
        }

        if dimensions.count == 1 {
            return "Right now this mostly sounds like a question about \(dimensions[0])."
        }

        let joined = dimensions.dropLast().joined(separator: ", ") + " and " + (dimensions.last ?? "")
        return "Right now this decision is carrying \(joined) at the same time."
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
