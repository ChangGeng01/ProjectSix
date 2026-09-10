import Foundation

struct TemplateLocalModelAdapter: LocalModelAdapting {
    func route(prompt: String, scenario: ScenarioType?, fallback: RoutedDecision) -> RoutedDecision {
        guard scenario == nil else {
            return RoutedDecision(
                mode: .quick,
                reason: "A named impulse is usually safest in the fast lane first."
            )
        }

        let normalized = DecisionIntelligencePromptLibrary.normalized(prompt)
        guard !normalized.isEmpty else { return fallback }

        if containsAny(
            normalized,
            keywords: ["break up", "stay or leave", "relationship", "quit", "resign", "move out", "forgive", "continue this", "marriage", "divorce"]
        ) {
            return RoutedDecision(
                mode: .mirror,
                reason: "This sounds identity-heavy enough that a mirror will surface what you are really protecting."
            )
        }

        if containsAny(
            normalized,
            keywords: ["which", "between", "option", "plan", "invite", "schedule", "dinner", "trip", "choose"]
        ) || normalized.contains(" or ") {
            return RoutedDecision(
                mode: .balance,
                reason: "This reads like a trade-off with competing priorities, not a snap yes-or-no."
            )
        }

        if containsAny(
            normalized,
            keywords: ["buy", "order", "reply", "text back", "message back", "scroll", "watch", "open", "click", "eat", "late night"]
        ) {
            return RoutedDecision(
                mode: .quick,
                reason: "This sounds immediate and easy to regret, so the stoplight should go first."
            )
        }

        return fallback
    }

    func enhanceQuickResult(_ result: QuickCheckResult, input: QuickCheckInput) -> QuickCheckResult {
        let cue = DecisionIntelligencePromptLibrary.clippedClause(from: input.note)

        return QuickCheckResult(
            currentPerspective: currentPerspective(for: input, cue: cue),
            afterPerspective: afterPerspective(for: input, cue: cue, fallback: result.afterPerspective),
            verdict: result.verdict,
            primaryAction: result.primaryAction,
            secondaryActions: result.secondaryActions
        )
    }

    func enhanceBalanceResult(_ result: BalanceBoardResult, input: BalanceBoardInput) -> BalanceBoardResult {
        let desire = DecisionIntelligencePromptLibrary.clippedClause(from: input.desire)
        let concern = DecisionIntelligencePromptLibrary.clippedClause(from: input.concern)
        let constraint = DecisionIntelligencePromptLibrary.clippedClause(from: input.constraint)
        let longTerm = DecisionIntelligencePromptLibrary.clippedClause(from: input.longTerm)

        let summary = [
            desire.map { "You want \($0.lowercased())" },
            concern.map { "you are protecting \($0.lowercased())" },
            constraint.map { "reality is working inside \($0.lowercased())" },
            longTerm.map { "and future-you will still live with \($0.lowercased())" }
        ]
        .compactMap { $0 }
        .joined(separator: ", ")

        let focusDescription: String
        if let constraint, result.focusTitle == "Let reality lead first" {
            focusDescription = "The cleanest anchor is the hard limit you already named: \(constraint)."
        } else if let concern, result.focusTitle == "Name what you are protecting" {
            focusDescription = "Your hesitation is guarding something real: \(concern). Name that before comparing options."
        } else if let longTerm, result.focusTitle == "Let future-you get a vote" {
            focusDescription = "The longer arc is already visible here: \(longTerm). Bring that forward before convenience wins."
        } else if let desire {
            focusDescription = "Start from the preference you actually want to honor: \(desire)."
        } else {
            focusDescription = result.focusDescription
        }

        return BalanceBoardResult(
            headline: "This needs ranking, not a rushed answer.",
            summary: summary.isEmpty ? result.summary : sentence(summary),
            focusTitle: result.focusTitle,
            focusDescription: focusDescription,
            nextAction: result.nextAction
        )
    }

    func enhanceMirrorResult(_ result: MirrorResult, input: MirrorInput) -> MirrorResult {
        let emotion = DecisionIntelligencePromptLibrary.clippedClause(from: input.emotion)
        let relationship = DecisionIntelligencePromptLibrary.clippedClause(from: input.relationship)
        let longTerm = DecisionIntelligencePromptLibrary.clippedClause(from: input.longTerm)
        let selfLens = DecisionIntelligencePromptLibrary.clippedClause(from: input.selfLens)

        let tension: String
        if let selfLens, let relationship {
            tension = "This may be less about one decision and more about what \(relationship.lowercased()) keeps asking you to ignore about yourself: \(selfLens.lowercased())."
        } else if let longTerm, let emotion {
            tension = "The feeling is real, but so is the life shape this creates if nothing changes: \(emotion.lowercased()), with \(longTerm.lowercased()) still waiting underneath."
        } else {
            tension = result.coreTension
        }

        return MirrorResult(
            headline: "This needs a clearer mirror before it needs an answer.",
            coreTension: tension,
            nextActionTitle: result.nextActionTitle,
            nextAction: result.nextAction
        )
    }

    func pickReminder(
        from orderedCandidates: [String],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) -> String? {
        guard !orderedCandidates.isEmpty else { return nil }
        let normalizedPrompt = DecisionIntelligencePromptLibrary.normalized(prompt)
        guard !normalizedPrompt.isEmpty else { return orderedCandidates.first }

        let scenarioPrompt = prompt + " " + scenario.title
        let scored = orderedCandidates.map { candidate in
            (
                candidate,
                DecisionIntelligencePromptLibrary.overlapScore(candidate: candidate, prompt: scenarioPrompt)
                    + modeBonus(for: candidate, mode: mode)
                    + contextBonus(for: candidate, prompt: normalizedPrompt)
            )
        }

        return scored.max { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.count > rhs.0.count
            }
            return lhs.1 < rhs.1
        }?.0 ?? orderedCandidates.first
    }

    private func currentPerspective(for input: QuickCheckInput, cue: String?) -> String {
        switch input.motivation {
        case .genuineNeed:
            if let cue {
                return "Part of you reads this as a real need, not just a mood spike around \(cue.lowercased())."
            }
            return "Part of you reads this as a real need, not just a mood spike."
        case .reward:
            if let cue {
                return "This feels like relief or reward after \(cue.lowercased()), not just a neutral choice."
            }
            return "This feels like relief or reward more than a fully neutral choice."
        case .stressed:
            if let cue {
                return "You may be reaching for this because \(cue.lowercased()) still feels raw."
            }
            return "You may be reaching for relief faster than you are reaching for clarity."
        case .avoiding:
            if let cue {
                return "This may be less about wanting it and more about getting away from \(cue.lowercased())."
            }
            return "This may be less about wanting it and more about getting away from the feeling quickly."
        }
    }

    private func afterPerspective(
        for input: QuickCheckInput,
        cue: String?,
        fallback: String
    ) -> String {
        switch input.expectedOutcome {
        case .satisfied:
            return "If this still looks clean after the next hour, it probably fits the real need behind the urge."
        case .temporaryRelief:
            if let cue {
                return "If the main payoff is relief from \(cue.lowercased()), the urge is probably louder than the need."
            }
            return "If the main payoff is quick relief, the urge is probably louder than the need."
        case .regret:
            return "You already expect a bad aftertaste. That forecast usually matters more than the urge."
        case .unsure:
            return fallback.replacingOccurrences(of: "If you cannot tell whether future-you will respect this, a small buffer is probably worth it.", with: "If future-you still feels blurry, a short buffer will buy better signal.")
        }
    }

    private func modeBonus(for candidate: String, mode: DecisionMode?) -> Int {
        guard let mode else { return 0 }
        let normalized = DecisionIntelligencePromptLibrary.normalized(candidate)
        switch mode {
        case .quick:
            return containsAny(normalized, keywords: ["urge", "buy", "late", "scroll", "need", "want"]) ? 1 : 0
        case .balance:
            return containsAny(normalized, keywords: ["priority", "budget", "time", "trade", "option"]) ? 1 : 0
        case .mirror:
            return containsAny(normalized, keywords: ["fit", "boundary", "self", "stay", "leave", "pattern"]) ? 1 : 0
        }
    }

    private func contextBonus(for candidate: String, prompt: String) -> Int {
        let normalizedCandidate = DecisionIntelligencePromptLibrary.normalized(candidate)

        if containsAny(prompt, keywords: ["rough", "stress", "stressed", "hard day", "upset", "tired", "exhausted", "drained"]) &&
            containsAny(normalizedCandidate, keywords: ["stress", "shopping", "relief", "comfort", "again", "reward"]) {
            return 2
        }

        if containsAny(prompt, keywords: ["need", "replace", "broken", "charger", "practical"]) &&
            containsAny(normalizedCandidate, keywords: ["need", "replace", "practical", "actually needed"]) {
            return 2
        }

        return 0
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        return trimmed.hasSuffix(".") ? trimmed : trimmed + "."
    }
}
