import Foundation

enum ReminderSelectionNeed: String, CaseIterable, Codable, Sendable {
    case control
    case knowledge
}

struct ReminderSelectionAssessment: Equatable, Sendable {
    let need: ReminderSelectionNeed
    let reason: String
    let promptTokenCount: Int
    let topCandidateScore: Int
    let secondCandidateScore: Int
    let distinctCandidateCount: Int
}

enum ReminderSelectionPolicy {
    static func bestReminder(in reminders: [SelfReminder], for scenario: ScenarioType) -> SelfReminder? {
        ranked(reminders: reminders.filter { $0.scenario == scenario }).first
    }

    static func remindersToTrim(from reminders: [SelfReminder]) -> [SelfReminder] {
        Array(ranked(reminders: reminders).dropFirst(BeforePolicy.Reflection.maxStoredReminders))
    }

    static func ranked(reminders: [SelfReminder]) -> [SelfReminder] {
        reminders.sorted(by: isHigherPriority)
    }

    static func assessSelectionNeed(
        candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) -> ReminderSelectionAssessment {
        guard candidates.count > 1 else {
            return ReminderSelectionAssessment(
                need: .control,
                reason: "Reminder retrieval stayed deterministic because there is only one viable candidate.",
                promptTokenCount: 0,
                topCandidateScore: 0,
                secondCandidateScore: 0,
                distinctCandidateCount: candidates.count
            )
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectionPrompt = [trimmedPrompt, scenario.title, mode?.shortTitle]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: " ")
        let promptTokenCount = DecisionIntelligencePromptLibrary.tokenSet(for: trimmedPrompt).count
        let distinctCandidateCount = Set(candidates.map { DecisionIntelligencePromptLibrary.normalized($0.content) }).count

        guard distinctCandidateCount > 1 else {
            return ReminderSelectionAssessment(
                need: .control,
                reason: "Reminder retrieval stayed deterministic because the candidate set collapsed into one repeated message after normalization.",
                promptTokenCount: promptTokenCount,
                topCandidateScore: 0,
                secondCandidateScore: 0,
                distinctCandidateCount: distinctCandidateCount
            )
        }

        guard promptTokenCount > 0 else {
            return ReminderSelectionAssessment(
                need: .control,
                reason: "Reminder retrieval stayed deterministic because there is no meaningful open-text signal to disambiguate the ranked reminders.",
                promptTokenCount: 0,
                topCandidateScore: 0,
                secondCandidateScore: 0,
                distinctCandidateCount: distinctCandidateCount
            )
        }

        let scored = candidates.map { candidate in
            (
                candidate: candidate,
                score: lexicalScore(
                    candidate: candidate,
                    scenario: scenario,
                    prompt: selectionPrompt,
                    mode: mode
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.candidate.rank < rhs.candidate.rank
            }
            return lhs.score > rhs.score
        }

        let topCandidateScore = scored.first?.score ?? 0
        let secondCandidateScore = scored.dropFirst().first?.score ?? 0
        let lead = topCandidateScore - secondCandidateScore

        if promptTokenCount < 2 {
            return ReminderSelectionAssessment(
                need: .control,
                reason: "Reminder retrieval stayed deterministic because the current prompt only contributes a thin control signal, not enough knowledge pressure to justify a model pass.",
                promptTokenCount: promptTokenCount,
                topCandidateScore: topCandidateScore,
                secondCandidateScore: secondCandidateScore,
                distinctCandidateCount: distinctCandidateCount
            )
        }

        if topCandidateScore <= 0 {
            return ReminderSelectionAssessment(
                need: .control,
                reason: "Reminder retrieval stayed deterministic because none of the candidates carries enough lexical overlap with the current state to justify model selection.",
                promptTokenCount: promptTokenCount,
                topCandidateScore: topCandidateScore,
                secondCandidateScore: secondCandidateScore,
                distinctCandidateCount: distinctCandidateCount
            )
        }

        if lead >= 2 {
            return ReminderSelectionAssessment(
                need: .control,
                reason: "Reminder retrieval stayed deterministic because the highest-ranked candidate already has a clear lead over the next option.",
                promptTokenCount: promptTokenCount,
                topCandidateScore: topCandidateScore,
                secondCandidateScore: secondCandidateScore,
                distinctCandidateCount: distinctCandidateCount
            )
        }

        return ReminderSelectionAssessment(
            need: .knowledge,
            reason: "Reminder retrieval was allowed because the current prompt creates a real conflict between multiple reminder candidates.",
            promptTokenCount: promptTokenCount,
            topCandidateScore: topCandidateScore,
            secondCandidateScore: secondCandidateScore,
            distinctCandidateCount: distinctCandidateCount
        )
    }

    static func sourcePriority(_ source: ReminderSourceType) -> Int {
        switch source {
        case .userWritten: 0
        case .compressed: 1
        case .template: 2
        }
    }

    private static func isHigherPriority(_ lhs: SelfReminder, _ rhs: SelfReminder) -> Bool {
        let lhsPriority = sourcePriority(lhs.source)
        let rhsPriority = sourcePriority(rhs.source)

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        if lhs.useCount != rhs.useCount {
            return lhs.useCount > rhs.useCount
        }

        if lhs.lastUsedAt != rhs.lastUsedAt {
            return lhs.lastUsedAt > rhs.lastUsedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func lexicalScore(
        candidate: ReminderSelectionCandidate,
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) -> Int {
        let overlap = DecisionIntelligencePromptLibrary.overlapScore(
            candidate: candidate.content,
            prompt: prompt
        )
        let scenarioBonus = DecisionIntelligencePromptLibrary.overlapScore(
            candidate: candidate.content,
            prompt: scenario.title
        )

        return overlap
            + scenarioBonus
            + modeBonus(for: candidate.content, mode: mode)
            + sourceBonus(for: candidate)
            + useCountBonus(for: candidate)
    }

    private static func modeBonus(
        for candidate: String,
        mode: DecisionMode?
    ) -> Int {
        guard let mode else { return 0 }
        let normalized = DecisionIntelligencePromptLibrary.normalized(candidate)

        switch mode {
        case .quick:
            return containsAny(normalized, keywords: ["urge", "buy", "scroll", "late", "need", "want"]) ? 1 : 0
        case .balance:
            return containsAny(normalized, keywords: ["priority", "budget", "time", "trade", "option"]) ? 1 : 0
        case .mirror:
            return containsAny(normalized, keywords: ["boundary", "self", "pattern", "leave", "stay", "fit"]) ? 1 : 0
        }
    }

    private static func sourceBonus(for candidate: ReminderSelectionCandidate) -> Int {
        switch candidate.source {
        case .userWritten: 1
        case .compressed, .template: 0
        }
    }

    private static func useCountBonus(for candidate: ReminderSelectionCandidate) -> Int {
        candidate.useCount > 0 ? 1 : 0
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains(where: text.contains)
    }
}
