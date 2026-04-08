import Foundation

enum CheckRuleEngine {
    static func evaluate(_ input: QuickCheckInput) -> QuickCheckResult {
        let score = scoreForMotivation(input.motivation)
            + scoreForOutcome(input.expectedOutcome)
            + scoreForControl(input.controlLevel)

        let verdict: CheckVerdict
        if score >= 2 {
            verdict = .goAhead
        } else if score <= -2 {
            verdict = .notRecommended
        } else {
            verdict = .pause
        }

        let primaryAction: CheckAction
        let secondaryActions: [CheckAction]
        switch verdict {
        case .goAhead:
            primaryAction = .continueMindfully
            secondaryActions = [.wait90s, .decideTomorrow]
        case .pause:
            primaryAction = .wait90s
            secondaryActions = [.leaveStimulus, .decideTomorrow, .goAheadAnyway]
        case .notRecommended:
            primaryAction = .leaveStimulus
            secondaryActions = [.wait90s, .decideTomorrow, .goAheadAnyway]
        }

        return QuickCheckResult(
            currentPerspective: currentPerspective(for: input),
            afterPerspective: afterPerspective(for: input),
            verdict: verdict,
            primaryAction: primaryAction,
            secondaryActions: secondaryActions
        )
    }

    private static func scoreForMotivation(_ value: MotivationChoice) -> Int {
        switch value {
        case .genuineNeed: 1
        case .reward: 0
        case .stressed: -1
        case .avoiding: -1
        }
    }

    private static func scoreForOutcome(_ value: OutcomeChoice) -> Int {
        switch value {
        case .satisfied: 1
        case .temporaryRelief: -1
        case .regret: -2
        case .unsure: 0
        }
    }

    private static func scoreForControl(_ value: ControlChoice) -> Int {
        switch value {
        case .yes: 1
        case .maybe: 0
        case .no: -1
        }
    }

    private static func currentPerspective(for input: QuickCheckInput) -> String {
        switch input.motivation {
        case .genuineNeed:
            return "Part of you sees this \(input.scenario.title.lowercased()) decision as genuinely useful right now."
        case .reward:
            return "This feels like a quick reward after holding a lot today."
        case .stressed:
            return "You are looking for relief more than analysis right now."
        case .avoiding:
            return "This looks like a way to get out of the current feeling fast."
        }
    }

    private static func afterPerspective(for input: QuickCheckInput) -> String {
        switch input.expectedOutcome {
        case .satisfied:
            return "If it still feels clean after you imagine the next hour, this may be a real yes."
        case .temporaryRelief:
            return "The relief may be real, but brief, which usually means the urge is doing most of the talking."
        case .regret:
            return "You already expect regret, which is often your clearest signal."
        case .unsure:
            return "If you cannot tell whether future-you will respect this, a small buffer is probably worth it."
        }
    }
}
