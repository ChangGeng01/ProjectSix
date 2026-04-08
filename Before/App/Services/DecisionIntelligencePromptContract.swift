import Foundation

enum DecisionIntelligencePromptContract {
    enum Limit {
        static let quickCurrentPerspective = 140
        static let quickAfterPerspective = 160
        static let balanceHeadline = 110
        static let balanceSummary = 180
        static let balanceFocusDescription = 170
        static let balanceNextAction = 170
        static let mirrorHeadline = 120
        static let mirrorCoreTension = 220
        static let mirrorNextAction = 180
        static let reminderCandidates = 6
        static let reminderCandidateLength = 140
    }

    static func sanitized(_ value: String, fallback: String, limit: Int) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        guard !trimmed.isEmpty else { return fallback }
        let collapsed = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return fallback }
        if collapsed.count <= limit {
            return collapsed
        }

        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    static func quickRefinementPrompt(base: QuickCheckResult, input: QuickCheckInput) -> String {
        [
            "Scenario: \(input.scenario.title)",
            "Motivation: \(input.motivation.title)",
            "Expected outcome: \(input.expectedOutcome.title)",
            "Control level: \(input.controlLevel.title)",
            bullet("Optional note", input.note),
            bullet("Current perspective", base.currentPerspective),
            bullet("After perspective", base.afterPerspective),
            "Rewrite those two lines so they feel more precise and human, but keep the same meaning."
        ]
        .joined(separator: "\n")
    }

    static func balanceRefinementPrompt(base: BalanceBoardResult, input: BalanceBoardInput) -> String {
        [
            bullet("Prompt", input.prompt),
            bullet("Want", input.desire),
            bullet("Concern", input.concern),
            bullet("Reality", input.constraint),
            bullet("Long-term", input.longTerm),
            bullet("Current headline", base.headline),
            bullet("Current summary", base.summary),
            bullet("Focus title", base.focusTitle),
            bullet("Focus description", base.focusDescription),
            bullet("Next action", base.nextAction),
            "Tighten the wording without changing the underlying focus."
        ]
        .joined(separator: "\n")
    }

    static func mirrorRefinementPrompt(base: MirrorResult, input: MirrorInput) -> String {
        [
            bullet("Prompt", input.prompt),
            bullet("Emotion", input.emotion),
            bullet("Relationship", input.relationship),
            bullet("Reality", input.reality),
            bullet("Long-term", input.longTerm),
            bullet("Self lens", input.selfLens),
            bullet("Current headline", base.headline),
            bullet("Core tension", base.coreTension),
            bullet("Next action title", base.nextActionTitle),
            bullet("Next action", base.nextAction),
            "Clarify the mirror without becoming dramatic or giving a yes-no answer."
        ]
        .joined(separator: "\n")
    }

    static func reminderSelectionPrompt(
        candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) -> String {
        let clippedCandidates = Array(candidates.prefix(Limit.reminderCandidates))
        let modeLine = mode.map { "Mode: \($0.shortTitle)" } ?? "Mode: Not specified"
        let currentPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateLines = clippedCandidates.enumerated().map { index, candidate in
            let safeContent = sanitized(
                candidate.content,
                fallback: candidate.content,
                limit: Limit.reminderCandidateLength
            )
            return "\(index): \(safeContent)"
        }

        return (
            [
                "Scenario: \(scenario.title)",
                modeLine,
                bullet("Current prompt", currentPrompt),
                "Choose the one reminder that best matches the user's current state.",
                "Return only the zero-based index of the best candidate."
            ]
            + candidateLines
        )
        .joined(separator: "\n")
    }

    private static func bullet(_ label: String, _ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(label): \(trimmed.isEmpty ? "Not provided." : trimmed)"
    }
}
