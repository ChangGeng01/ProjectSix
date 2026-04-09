import CryptoKit
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
        static let frontstageSignal = 48
        static let frontstageEvidence = 96
        static let frontstageSignalCount = 3
        static let brainHeadline = 110
        static let sessionBias = 72
    }

    enum TaskKind: Equatable, Sendable {
        case quick
        case balance
        case mirror
        case reminder

        var targetCharacters: Int {
            switch self {
            case .quick: 1_500
            case .balance: 2_050
            case .mirror: 1_700
            case .reminder: 1_250
            }
        }
    }

    struct ContextBudget: Equatable, Sendable {
        let targetCharacters: Int
        let prefixCharacters: Int
        let suffixCharacters: Int
        let immutablePrefixCharacters: Int
        let adaptivePrefixCharacters: Int

        var totalCharacters: Int {
            prefixCharacters + suffixCharacters
        }

        var isWithinTarget: Bool {
            totalCharacters <= targetCharacters
        }

        var utilizationRatio: Double {
            guard targetCharacters > 0 else { return 0 }
            return Double(totalCharacters) / Double(targetCharacters)
        }

        var stablePrefixShare: Double {
            guard totalCharacters > 0 else { return 0 }
            return Double(prefixCharacters) / Double(totalCharacters)
        }

        var volatileSuffixShare: Double {
            guard totalCharacters > 0 else { return 0 }
            return Double(suffixCharacters) / Double(totalCharacters)
        }

        init(
            targetCharacters: Int,
            prefixCharacters: Int,
            suffixCharacters: Int,
            immutablePrefixCharacters: Int? = nil,
            adaptivePrefixCharacters: Int? = nil
        ) {
            self.targetCharacters = targetCharacters
            self.prefixCharacters = prefixCharacters
            self.suffixCharacters = suffixCharacters

            let resolvedImmutable = immutablePrefixCharacters ?? prefixCharacters
            let resolvedAdaptive = adaptivePrefixCharacters ?? max(0, prefixCharacters - resolvedImmutable)
            self.immutablePrefixCharacters = resolvedImmutable
            self.adaptivePrefixCharacters = resolvedAdaptive
        }
    }

    struct PromptLayers: Equatable, Sendable {
        let immutablePrefix: String
        let adaptivePrefix: String
        let volatileSuffix: String

        var stablePrefix: String {
            [immutablePrefix, adaptivePrefix]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        }

        var runtimePrompt: String {
            [stablePrefix, volatileSuffix]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        }
    }

    struct PromptEnvelope: Equatable, Sendable {
        let kind: TaskKind
        let instructions: String
        let payload: String
        let debugPrompt: String
        let budget: ContextBudget
        let layers: PromptLayers
        let frontstageState: DecisionFrontstageState
        let openTextSignalCount: Int

        var runtimePrompt: String {
            layers.runtimePrompt
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

        static func immutablePrefix(for kind: TaskKind) -> String {
            sharedPrelude
        }

        static func adaptivePrefix(for kind: TaskKind) -> String {
            switch kind {
            case .quick:
                quick
            case .balance:
                balance
            case .mirror:
                mirror
            case .reminder:
                reminder
            }
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
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) -> PromptEnvelope {
        makeEnvelope(
            kind: .quick,
            strategy: strategy,
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
            openTextSignalCount: nonEmptySignalCount([input.note]),
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    static func quickRefinementPrompt(
        base: QuickCheckResult,
        input: QuickCheckInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) -> String {
        quickRefinementEnvelope(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        ).debugPrompt
    }

    static func balanceRefinementEnvelope(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) -> PromptEnvelope {
        makeEnvelope(
            kind: .balance,
            strategy: strategy,
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
            openTextSignalCount: nonEmptySignalCount([
                input.prompt,
                input.desire,
                input.concern,
                input.constraint,
                input.longTerm
            ]),
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    static func balanceRefinementPrompt(
        base: BalanceBoardResult,
        input: BalanceBoardInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) -> String {
        balanceRefinementEnvelope(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        ).debugPrompt
    }

    static func mirrorRefinementEnvelope(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) -> PromptEnvelope {
        makeEnvelope(
            kind: .mirror,
            strategy: strategy,
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
            openTextSignalCount: nonEmptySignalCount([
                input.prompt,
                input.emotion,
                input.relationship,
                input.reality,
                input.longTerm,
                input.selfLens
            ]),
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
    }

    static func mirrorRefinementPrompt(
        base: MirrorResult,
        input: MirrorInput,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) -> String {
        mirrorRefinementEnvelope(
            base: base,
            input: input,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        ).debugPrompt
    }

    static func reminderSelectionEnvelope(
        candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy? = nil
    ) -> ReminderSelectionEnvelope {
        let clippedCandidates = Array(candidates.prefix(Limit.reminderCandidates))
        let modeTitle = mode?.shortTitle ?? "Not specified"

        let envelope = makeEnvelope(
            kind: .reminder,
            strategy: strategy,
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
            ],
            openTextSignalCount: nonEmptySignalCount([prompt])
        )

        return ReminderSelectionEnvelope(prompt: envelope, candidates: clippedCandidates)
    }

    static func reminderSelectionPrompt(
        candidates: [ReminderSelectionCandidate],
        scenario: ScenarioType,
        prompt: String,
        mode: DecisionMode?,
        strategy: DecisionAdaptiveTaskStrategy? = nil
    ) -> String {
        reminderSelectionEnvelope(
            candidates: candidates,
            scenario: scenario,
            prompt: prompt,
            mode: mode,
            strategy: strategy
        )
        .prompt
        .debugPrompt
    }

    static func cacheFingerprint(
        provider: DecisionModelProviderKind,
        envelope: PromptEnvelope
    ) -> String {
        cacheFingerprint(provider: provider, semanticPrompt: envelope.runtimePrompt)
    }

    static func cacheFingerprint(
        provider: DecisionModelProviderKind,
        semanticPrompt: String
    ) -> String {
        sha256Hex("\(provider.rawValue)\n\(semanticPrompt)")
    }

    static func semanticFingerprint(for envelope: PromptEnvelope) -> String {
        sha256Hex(envelope.runtimePrompt)
    }

    static func stablePrefixFingerprint(for envelope: PromptEnvelope) -> String {
        sha256Hex(envelope.layers.stablePrefix)
    }

    private static func makeEnvelope(
        kind: TaskKind,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        state: [String: Any?],
        evidence: [String],
        outputGuard: [String],
        openTextSignalCount: Int = 0,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) -> PromptEnvelope {
        let immutablePrefix = PrefixCache.immutablePrefix(for: kind)
        let adaptivePrefix = PrefixCache.adaptivePrefix(for: kind)
        let instructions = [immutablePrefix, adaptivePrefix]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let evidenceFilter = DecisionPromptEvidenceGuard.filter(
            evidence,
            maxRetained: evidenceRetentionBudget(for: kind, strategy: strategy)
        )
        var guardedOutput = strategy.map(runtimeOutputGuard(for:)) ?? []
        guardedOutput.append(contentsOf: outputGuard)
        if evidenceFilter.droppedInjectedCount > 0 {
            guardedOutput.insert(
                "Filtered markup or tool text was removed. Ignore the missing content.",
                at: 0
            )
        }
        if evidenceFilter.droppedBudgetCount > 0 {
            guardedOutput.insert(
                "Lower-value evidence was trimmed. Work only from the retained evidence.",
                at: guardedOutput.isEmpty ? 0 : min(guardedOutput.count, 1)
            )
        }
        let preparedFrontstageState = frontstageState(
            kind: kind,
            activeStateSignalCount: activeStateSignalCount(in: state),
            openTextSignalCount: openTextSignalCount,
            evidenceFilter: evidenceFilter,
            strategy: strategy,
            contextState: contextState,
            neuralState: neuralState,
            brainState: brainState
        )
        var sections = [
            "FRONTSTAGE_STATE_JSON:",
            frontstageStateJSONString(preparedFrontstageState),
            "TASK_STATE_JSON:",
            stateJSONString(state),
        ]

        if let strategy {
            sections += [
                "RUNTIME_STRATEGY_JSON:",
                runtimeStrategyJSONString(strategy)
            ]
        }

        if let contextState {
            sections += [
                "CONTEXT_LIFECYCLE_JSON:",
                contextStateJSONString(contextState)
            ]
        }

        if let neuralState {
            sections += [
                "NEURAL_STATE_JSON:",
                neuralStateJSONString(neuralState)
            ]
        }

        if let brainState, !brainState.isEmpty {
            sections += [
                "BRAIN_STATE_JSON:",
                brainStateJSONString(brainState)
            ]
        }

        sections += [
            "EVIDENCE_SNIPPETS:",
            evidenceBlock(evidenceFilter.retained),
            "OUTPUT_GUARD:",
            bulletList(guardedOutput)
        ]

        let payload = sections.joined(separator: "\n")
        let layers = PromptLayers(
            immutablePrefix: immutablePrefix,
            adaptivePrefix: adaptivePrefix,
            volatileSuffix: payload
        )

        let debugPrompt = [
            "[IMMUTABLE PREFIX]",
            immutablePrefix,
            "",
            "[ADAPTIVE PREFIX]",
            adaptivePrefix,
            "",
            "[VOLATILE SUFFIX]",
            payload
        ]
        .joined(separator: "\n")

        return PromptEnvelope(
            kind: kind,
            instructions: instructions,
            payload: payload,
            debugPrompt: debugPrompt,
            budget: ContextBudget(
                targetCharacters: strategy?.contextBudget ?? kind.targetCharacters,
                prefixCharacters: instructions.count,
                suffixCharacters: payload.count,
                immutablePrefixCharacters: immutablePrefix.count,
                adaptivePrefixCharacters: adaptivePrefix.count
            ),
            layers: layers,
            frontstageState: preparedFrontstageState,
            openTextSignalCount: openTextSignalCount
        )
    }

    private static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
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
            "anchor_fields": contextState.anchorFields.map(\.rawValue),
            "active_fields": contextState.activeFields.map(\.rawValue),
            "stale_fields": contextState.staleFields.map(\.rawValue)
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func neuralStateJSONString(_ neuralState: DecisionNeuralState) -> String {
        let payload: [String: Any] = [
            "dominant_signals": neuralState.dominantActivations.map { activation in
                [
                    "signal": activation.signal.rawValue
                ]
            },
            "candidate_actions": neuralState.candidateActions.map { candidate in
                [
                    "route": candidate.route.rawValue
                ]
            },
            "suppressed_behaviors": neuralState.suppressedBehaviors
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func frontstageState(
        kind: TaskKind,
        activeStateSignalCount: Int,
        openTextSignalCount: Int,
        evidenceFilter: DecisionPromptEvidenceFilterResult,
        strategy: DecisionAdaptiveTaskStrategy? = nil,
        contextState: DecisionContextPreparedState?,
        neuralState: DecisionNeuralState?,
        brainState: DecisionBrainState?
    ) -> DecisionFrontstageState {
        let focusGoal: String = switch kind {
        case .quick:
            "Interrupt the automatic reaction before it locks in."
        case .balance:
            "Surface the real trade-off before choosing a side."
        case .mirror:
            "Name the core tension without forcing a yes-no answer."
        case .reminder:
            "Pick the one reminder that best fits the current state."
        }

        var dangerSignals = neuralState?
            .dominantActivations
            .prefix(Limit.frontstageSignalCount)
            .map { activation in
                sanitized(
                    activation.signal.title,
                    fallback: activation.signal.title,
                    limit: Limit.frontstageSignal
                )
            } ?? []

        if contextState?.rebuiltSession == true {
            dangerSignals.append("Session rebuild")
        }
        if let staleFieldCount = contextState?.staleFieldCount, staleFieldCount > 0 {
            dangerSignals.append("Stale fields dropped")
        }
        if evidenceFilter.droppedInjectedCount > 0 {
            dangerSignals.append("Evidence filtered")
        }
        if evidenceFilter.droppedBudgetCount > 0 {
            dangerSignals.append("Frontstage trimmed")
        }
        dangerSignals = Array(dangerSignals.prefix(Limit.frontstageSignalCount))

        let evidenceHeadlines = evidenceFilter.retained
            .prefix(frontstageEvidenceCount(for: kind, strategy: strategy))
            .map { snippet in
                sanitized(
                    snippet,
                    fallback: snippet,
                    limit: Limit.frontstageEvidence
                )
            }

        let anchorHeadlines = Array(
            (contextState?.anchorFields ?? [])
                .map(\.title)
                .map { sanitized($0, fallback: $0, limit: Limit.frontstageEvidence) }
                .prefix(Limit.frontstageSignalCount)
        )

        let memoryHeadlines = Array(
            (brainState?.relevantMemories ?? [])
                .map { sanitized($0, fallback: $0, limit: Limit.brainHeadline) }
                .prefix(Limit.frontstageSignalCount)
        )

        let suppressionHints = Array(
            (neuralState?.suppressedBehaviors ?? [])
                .map { sanitized($0, fallback: $0, limit: Limit.frontstageSignal) }
                .prefix(Limit.frontstageSignalCount)
        )

        let sessionBiases = Array(
            (brainState?.sessionBiases ?? [])
                .map { sanitized($0, fallback: $0, limit: Limit.sessionBias) }
                .prefix(Limit.frontstageSignalCount)
        )

        return DecisionFrontstageState(
            focusGoal: focusGoal,
            activeStateSignalCount: activeStateSignalCount,
            openTextSignalCount: openTextSignalCount,
            dangerSignals: dangerSignals,
            evidenceHeadlines: evidenceHeadlines,
            anchorHeadlines: anchorHeadlines,
            memoryHeadlines: memoryHeadlines,
            retainedEvidenceCount: evidenceFilter.retainedCount,
            droppedEvidenceCount: evidenceFilter.droppedCount,
            droppedInjectedEvidenceCount: evidenceFilter.droppedInjectedCount,
            droppedDuplicateEvidenceCount: evidenceFilter.droppedDuplicateCount,
            droppedBudgetEvidenceCount: evidenceFilter.droppedBudgetCount,
            suppressionHints: suppressionHints,
            sessionBiases: sessionBiases
        )
    }

    private static func frontstageStateJSONString(_ frontstageState: DecisionFrontstageState) -> String {
        let payload: [String: Any] = [
            "focus_goal": frontstageState.focusGoal,
            "danger_signals": frontstageState.dangerSignals,
            "evidence_headlines": frontstageState.evidenceHeadlines,
            "anchor_headlines": frontstageState.anchorHeadlines,
            "dropped_budget_evidence_count": frontstageState.droppedBudgetEvidenceCount,
            "suppression_hints": frontstageState.suppressionHints
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func runtimeStrategyJSONString(_ strategy: DecisionAdaptiveTaskStrategy) -> String {
        let payload: [String: Any] = [
            "kind": strategy.kind.rawValue,
            "entropy": strategy.entropy.rawValue,
            "runtime_gear": strategy.runtimeGear.rawValue,
            "provider": strategy.preferredProvider.rawValue,
            "context_budget": strategy.contextBudget,
            "retrieval_mode": strategy.retrievalMode.rawValue,
            "thinking_mode": strategy.thinkingMode.rawValue,
            "output_mode": strategy.outputMode.rawValue,
            "tone": strategy.tone.rawValue,
            "action_space": strategy.actionSpace,
            "response_language": strategy.responseLanguage.rawValue,
            "allows_model_invocation": strategy.allowsModelInvocation
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func brainStateJSONString(_ brainState: DecisionBrainState) -> String {
        let payload: [String: Any] = [
            "profile_core": brainState.profileCore,
            "active_goals": brainState.activeGoals,
            "relevant_memories": brainState.relevantMemories,
            "session_biases": brainState.sessionBiases,
            "reaction_weights": reactionWeightsJSONObject(brainState.reactionWeights)
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func reactionWeightsJSONObject(_ weights: DecisionReactionWeights) -> [String: Double] {
        let allWeights: [(String, Double)] = [
            ("brief", weights.briefLanguage),
            ("warm_direct", weights.warmDirectTone),
            ("low_load", weights.lowCognitiveLoad),
            ("interruptive", weights.interruptiveActionBias),
            ("boundary", weights.boundaryNamingBias),
            ("tradeoff", weights.tradeoffClarityBias)
        ]

        let prioritized = allWeights
            .filter { $0.1 >= 0.6 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 > rhs.1
            }

        let retained = Array((prioritized.isEmpty ? allWeights.sorted { $0.1 > $1.1 } : prioritized).prefix(3))
        return Dictionary(uniqueKeysWithValues: retained)
    }

    private static func frontstageEvidenceCount(
        for kind: TaskKind,
        strategy: DecisionAdaptiveTaskStrategy?
    ) -> Int {
        let base: Int = switch kind {
        case .quick:
            2
        case .balance, .mirror:
            1
        case .reminder:
            0
        }

        guard let strategy else { return base }
        switch strategy.retrievalMode {
        case .off:
            return max(0, base - 1)
        case .filtered:
            return base
        case .adaptive:
            return base + 1
        }
    }

    private static func evidenceRetentionBudget(
        for kind: TaskKind,
        strategy: DecisionAdaptiveTaskStrategy?
    ) -> Int {
        let base: Int = switch kind {
        case .quick:
            5
        case .balance:
            4
        case .mirror:
            4
        case .reminder:
            3
        }

        guard let strategy else { return base }
        switch strategy.retrievalMode {
        case .off:
            return max(2, base - 1)
        case .filtered:
            return base
        case .adaptive:
            return base + 1
        }
    }

    private static func runtimeOutputGuard(for strategy: DecisionAdaptiveTaskStrategy) -> [String] {
        var lines: [String] = []

        switch strategy.runtimeGear {
        case .low:
            lines.append("Stay in the low-gear lane: fast, brief, and low-cost.")
        case .balanced:
            lines.append("Stay in the balanced lane: concise, but allow enough depth to ground the answer.")
        case .high:
            lines.append("Use the high-gear lane only where deeper reflection materially improves clarity.")
        }

        switch strategy.outputMode {
        case .deterministicTemplate:
            lines.append("Stay close to the deterministic structure already provided.")
        case .guidedShort:
            lines.append("Keep the rewrite short and guided, not expansive.")
        case .structuredBoard:
            lines.append("Preserve a structured board shape with concise fields.")
        case .reflectiveStructured:
            lines.append("Keep the response reflective and structured rather than open-ended.")
        case .jsonShort:
            lines.append("Keep the selection output compact and structured.")
        }

        switch strategy.tone {
        case .neutral:
            lines.append("Keep the tone neutral and restrained.")
        case .briefWarm:
            lines.append("Keep the tone brief, calm, and warm.")
        case .groundedDirect:
            lines.append("Keep the tone grounded and direct.")
        case .reflectiveClear:
            lines.append("Keep the tone reflective and clear.")
        }

        switch strategy.thinkingMode {
        case .off:
            lines.append("Do not expose reasoning, self-talk, or chain-of-thought.")
        case .gated:
            lines.append("Use reasoning only to improve the answer internally; keep the output tight.")
        }

        switch strategy.retrievalMode {
        case .off:
            lines.append("Work only from the retained state and evidence already in front of you.")
        case .filtered:
            lines.append("Prioritize the retained evidence over generic completion.")
        case .adaptive:
            lines.append("Use the retained evidence as the anchor for any adaptive interpretation.")
        }

        switch strategy.responseLanguage {
        case .english:
            lines.append("Keep the user-facing output in English unless the structured format says otherwise.")
        case .chinese:
            lines.append("Keep the user-facing output in Chinese unless the structured format says otherwise.")
        case .mixed:
            lines.append("Match the user's latest language and avoid mixed-language output unless the input is mixed.")
        }

        return lines
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

    private static func nonEmptySignalCount(_ values: [String]) -> Int {
        values.reduce(0) { partialResult, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? partialResult : partialResult + 1
        }
    }

    private static func activeStateSignalCount(in state: [String: Any?]) -> Int {
        state.reduce(0) { partialResult, pair in
            guard let value = pair.value else { return partialResult }

            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed == "Not provided." || trimmed == "Not specified" {
                    return partialResult
                }
                return partialResult + 1
            }

            if let number = value as? Int {
                return number > 0 ? partialResult + 1 : partialResult
            }

            return partialResult + 1
        }
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
