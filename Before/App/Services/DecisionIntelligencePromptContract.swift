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
        static let reminderCandidates = 3
        static let reminderCandidateLength = 140
        static let stateField = 140
        static let statePrompt = 170
        static let evidenceSnippet = 180
    }

    enum TaskKind: Equatable, Sendable {
        case quick
        case balance
        case mirror
        case reminder

        var targetCharacters: Int {
            switch self {
            case .quick: 1_350
            case .balance: 1_550
            case .mirror: 1_700
            case .reminder: 1_100
            }
        }
    }

    struct ContextBudget: Equatable, Sendable {
        let targetCharacters: Int
        let prefixCharacters: Int
        let suffixCharacters: Int

        var totalCharacters: Int {
            prefixCharacters + suffixCharacters
        }

        var isWithinTarget: Bool {
            totalCharacters <= targetCharacters
        }
    }

    struct PromptEnvelope: Equatable, Sendable {
        let kind: TaskKind
        let instructions: String
        let payload: String
        let debugPrompt: String
        let budget: ContextBudget

        var runtimePrompt: String {
            instructions + "\n\n" + payload
        }
    }

    struct ReminderSelectionEnvelope: Equatable, Sendable {
        let prompt: PromptEnvelope
        let candidates: [ReminderSelectionCandidate]
    }

    enum PrefixCache {
        static let sharedPrelude = """
        You are the language rendering layer for a local decision app.
        The app owns state, routing, safety, verdicts, and actions.
        You only tighten wording or select from provided options.
        Keep the tone calm, short, and non-shaming.
        """

        static let quick = """
        Rewrite only the two perspective lines.
        Keep the same meaning and do not change verdicts or actions.
        """

        static let balance = """
        Tighten the board without inventing new facts or turning it into a verdict.
        Preserve the same focus and next-step intent.
        """

        static let mirror = """
        Clarify the mirror without becoming dramatic, therapeutic, or yes-no.
        Preserve the same tension and reflective next move.
        """

        static let reminder = """
        Pick one existing reminder that best matches the current state.
        Do not rewrite or invent reminder text.
        """

        static func instructions(for kind: TaskKind) -> String {
            let modeInstructions: String = switch kind {
            case .quick:
                quick
            case .balance:
                balance
            case .mirror:
                mirror
            case .reminder:
                reminder
            }

            return sharedPrelude + "\n" + modeInstructions
        }
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

    static func quickRefinementEnvelope(
        base: QuickCheckResult,
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> PromptEnvelope {
        makeEnvelope(
            kind: .quick,
            state: [
                "mode": DecisionMode.quick.shortTitle,
                "scenario": input.scenario.title,
                "motivation": input.motivation.title,
                "expected_outcome": input.expectedOutcome.title,
                "control_level": input.controlLevel.title,
                "note": stateValue(input.note, fallback: "Not provided.", limit: Limit.stateField)
            ],
            evidence: [
                "Current perspective: \(evidenceValue(base.currentPerspective, limit: Limit.evidenceSnippet))",
                "After perspective: \(evidenceValue(base.afterPerspective, limit: Limit.evidenceSnippet))",
                "Verdict: \(base.verdict.title)",
                "Primary action: \(base.primaryAction.title)",
                secondaryActionEvidence(base.secondaryActions)
            ],
            outputGuard: [
                "Rewrite only the current and after perspective lines.",
                "Keep the same meaning and emotional direction.",
                "Do not change the verdict, actions, or scenario."
            ],
            contextState: contextState
        )
    }

    static func quickRefinementPrompt(
        base: QuickCheckResult,
        input: QuickCheckInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> String {
        quickRefinementEnvelope(base: base, input: input, contextState: contextState).debugPrompt
    }

    static func balanceRefinementEnvelope(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> PromptEnvelope {
        makeEnvelope(
            kind: .balance,
            state: [
                "mode": DecisionMode.balance.shortTitle,
                "prompt": stateValue(input.prompt, fallback: "Not provided.", limit: Limit.statePrompt),
                "want": stateValue(input.desire, fallback: "Not provided.", limit: Limit.stateField),
                "concern": stateValue(input.concern, fallback: "Not provided.", limit: Limit.stateField),
                "reality": stateValue(input.constraint, fallback: "Not provided.", limit: Limit.stateField),
                "long_term": stateValue(input.longTerm, fallback: "Not provided.", limit: Limit.stateField)
            ],
            evidence: [
                "Current headline: \(evidenceValue(base.headline, limit: Limit.evidenceSnippet))",
                "Current summary: \(evidenceValue(base.summary, limit: Limit.evidenceSnippet))",
                "Focus title: \(evidenceValue(base.focusTitle, limit: Limit.evidenceSnippet))",
                "Focus description: \(evidenceValue(base.focusDescription, limit: Limit.evidenceSnippet))",
                "Next action: \(evidenceValue(base.nextAction, limit: Limit.evidenceSnippet))"
            ],
            outputGuard: [
                "Keep the same focus and next-step intent.",
                "Do not invent facts or turn the board into a verdict.",
                "Return tighter language only."
            ],
            contextState: contextState
        )
    }

    static func balanceRefinementPrompt(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> String {
        balanceRefinementEnvelope(base: base, input: input, contextState: contextState).debugPrompt
    }

    static func mirrorRefinementEnvelope(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> PromptEnvelope {
        makeEnvelope(
            kind: .mirror,
            state: [
                "mode": DecisionMode.mirror.shortTitle,
                "prompt": stateValue(input.prompt, fallback: "Not provided.", limit: Limit.statePrompt),
                "emotion": stateValue(input.emotion, fallback: "Not provided.", limit: Limit.stateField),
                "relationship": stateValue(input.relationship, fallback: "Not provided.", limit: Limit.stateField),
                "reality": stateValue(input.reality, fallback: "Not provided.", limit: Limit.stateField),
                "long_term": stateValue(input.longTerm, fallback: "Not provided.", limit: Limit.stateField),
                "self_lens": stateValue(input.selfLens, fallback: "Not provided.", limit: Limit.stateField)
            ],
            evidence: [
                "Current headline: \(evidenceValue(base.headline, limit: Limit.evidenceSnippet))",
                "Core tension: \(evidenceValue(base.coreTension, limit: Limit.evidenceSnippet))",
                "Next action title: \(evidenceValue(base.nextActionTitle, limit: Limit.evidenceSnippet))",
                "Next action: \(evidenceValue(base.nextAction, limit: Limit.evidenceSnippet))"
            ],
            outputGuard: [
                "Clarify the mirror without giving a yes-no answer.",
                "Keep the tone restrained, reflective, and non-therapeutic.",
                "Preserve the same core tension and next reflective move."
            ],
            contextState: contextState
        )
    }

    static func mirrorRefinementPrompt(
        base: MirrorResult,
        input: MirrorInput,
        contextState: DecisionContextPreparedState? = nil
    ) -> String {
        mirrorRefinementEnvelope(base: base, input: input, contextState: contextState).debugPrompt
    }

    static func reminderSelectionEnvelope(
        candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) -> ReminderSelectionEnvelope {
        let clippedCandidates = Array(candidates.prefix(Limit.reminderCandidates))
        let modeTitle = mode?.shortTitle ?? "Not specified"

        let envelope = makeEnvelope(
            kind: .reminder,
            state: [
                "mode": modeTitle,
                "scenario": scenario.title,
                "current_prompt": stateValue(prompt, fallback: "Not provided.", limit: Limit.statePrompt),
                "candidate_count": clippedCandidates.count
            ],
            evidence: clippedCandidates.enumerated().map { index, candidate in
                let safeContent = sanitized(
                    candidate.content,
                    fallback: candidate.content,
                    limit: Limit.reminderCandidateLength
                )
                return "\(index): \(safeContent)"
            },
            outputGuard: [
                "Choose exactly one candidate index from the provided evidence.",
                "Do not rewrite, combine, or invent reminder text.",
                "Prefer the reminder that most directly matches the current state."
            ]
        )

        return ReminderSelectionEnvelope(prompt: envelope, candidates: clippedCandidates)
    }

    static func reminderSelectionPrompt(
        candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?
    ) -> String {
        reminderSelectionEnvelope(
            candidates: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode
        )
        .prompt
        .debugPrompt
    }

    private static func makeEnvelope(
        kind: TaskKind,
        state: [String: Any?],
        evidence: [String],
        outputGuard: [String],
        contextState: DecisionContextPreparedState? = nil
    ) -> PromptEnvelope {
        let instructions = PrefixCache.instructions(for: kind)
        var sections = [
            "TASK_STATE_JSON:",
            stateJSONString(state),
        ]

        if let contextState {
            sections += [
                "CONTEXT_LIFECYCLE_JSON:",
                contextStateJSONString(contextState)
            ]
        }

        sections += [
            "EVIDENCE_SNIPPETS:",
            evidenceBlock(evidence),
            "OUTPUT_GUARD:",
            bulletList(outputGuard)
        ]

        let payload = sections.joined(separator: "\n")

        let debugPrompt = [
            "[PREFIX CACHE]",
            instructions,
            "",
            "[SUFFIX CONTEXT]",
            payload
        ]
        .joined(separator: "\n")

        return PromptEnvelope(
            kind: kind,
            instructions: instructions,
            payload: payload,
            debugPrompt: debugPrompt,
            budget: ContextBudget(
                targetCharacters: kind.targetCharacters,
                prefixCharacters: instructions.count,
                suffixCharacters: payload.count
            )
        )
    }

    private static func stateJSONString(_ state: [String: Any?]) -> String {
        let compactState = state.reduce(into: [String: Any]()) { result, pair in
            guard let value = pair.value else { return }
            result[pair.key] = value
        }

        guard JSONSerialization.isValidJSONObject(compactState),
              let data = try? JSONSerialization.data(withJSONObject: compactState, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func contextStateJSONString(_ contextState: DecisionContextPreparedState) -> String {
        let payload: [String: Any] = [
            "rebuilt_session": contextState.rebuiltSession,
            "generation": contextState.generation,
            "active_fields": contextState.activeFields.map(\.rawValue),
            "stale_fields": contextState.staleFields.map(\.rawValue),
            "active_field_count": contextState.activeFieldCount,
            "stale_field_count": contextState.staleFieldCount
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func evidenceBlock(_ evidence: [String]) -> String {
        let compactEvidence = evidence
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !compactEvidence.isEmpty else { return "- None." }
        return bulletList(compactEvidence)
    }

    private static func bulletList(_ lines: [String]) -> String {
        lines.map { "- \($0)" }.joined(separator: "\n")
    }

    private static func stateValue(_ value: String, fallback: String, limit: Int) -> String {
        sanitized(value, fallback: fallback, limit: limit)
    }

    private static func evidenceValue(_ value: String, limit: Int) -> String {
        sanitized(value, fallback: "Not provided.", limit: limit)
    }

    private static func secondaryActionEvidence(_ actions: [CheckAction]) -> String {
        guard !actions.isEmpty else { return "Secondary actions: None." }
        let titles = actions.map(\.title).joined(separator: ", ")
        return "Secondary actions: \(titles)"
    }
}
