import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

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
            case .quick: 1_500
            case .balance: 2_050
            case .mirror: 1_700
            case .reminder: 1_250
            }
        }
    }

    typealias ContextBudget = BASPromptBudget
    typealias PromptLayers = BASPromptLayers
    typealias PromptBlockKind = BASSemanticPromptBlockKind
    typealias PromptBlockRetention = BASSemanticPromptBlockRetention
    typealias PromptBlock = BASSemanticPromptBlock
    typealias PromptAssembly = BASSemanticContextAssembly
    typealias PromptEnvelope = BASPromptEnvelope<TaskKind, DecisionFrontstageState>

    struct ReminderSelectionEnvelope: Equatable, Sendable {
        let prompt: PromptEnvelope
        let candidates: [ReminderSelectionCandidate]
    }

    enum PrefixCache {
        static func instructions(for kind: TaskKind) -> String {
            BASPromptPrefixCatalog.instructions(for: semanticTaskKind(for: kind))
        }

        static func immutablePrefix(for kind: TaskKind) -> String {
            BASPromptPrefixCatalog.immutablePrefix(for: semanticTaskKind(for: kind))
        }

        static func adaptivePrefix(for kind: TaskKind) -> String {
            BASPromptPrefixCatalog.adaptivePrefix(for: semanticTaskKind(for: kind))
        }
    }

    static func sanitized(_ value: String, fallback: String, limit: Int) -> String {
        BASPromptTextSanitizer.sanitized(value, fallback: fallback, limit: limit)
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
                "Keep the same focus and next step.",
                "Do not invent facts or force a verdict.",
                "Tighten language only."
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
            openTextSignalCount: nonEmptySignalCount([prompt]),
            structuredTruthOverride: BASStructuredTruthCompiler.truthState(
                for: BASStructuredTruthRequest(
                    kind: .reminder,
                    brainState: nil,
                    reminderSurfaceMode: mode.map(substrateMode(from:))
                )
            ),
            includeStructuredTruthBlock: false
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
        BASPromptFingerprinting.cacheFingerprint(
            providerIdentifier: provider.rawValue,
            envelope: envelope
        )
    }

    static func cacheFingerprint(
        provider: DecisionModelProviderKind,
        semanticPrompt: String
    ) -> String {
        BASPromptFingerprinting.cacheFingerprint(
            providerIdentifier: provider.rawValue,
            semanticPrompt: semanticPrompt
        )
    }

    static func semanticFingerprint(for envelope: PromptEnvelope) -> String {
        BASPromptFingerprinting.semanticFingerprint(for: envelope)
    }

    static func stablePrefixFingerprint(for envelope: PromptEnvelope) -> String {
        BASPromptFingerprinting.stablePrefixFingerprint(for: envelope)
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
        brainState: DecisionBrainState? = nil,
        structuredTruthOverride: BASStructuredTruthState? = nil,
        includeStructuredTruthBlock: Bool = true
    ) -> PromptEnvelope {
        let immutablePrefix = PrefixCache.immutablePrefix(for: kind)
        let adaptivePrefix = PrefixCache.adaptivePrefix(for: kind)
        let structuredTruth = structuredTruthOverride ?? BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: adaptiveTraceKind(for: kind),
                brainState: brainState
            )
        )
        let renderedStructuredTruth = includeStructuredTruthBlock ? structuredTruth : nil
        let substrateStrategy = strategy.map { substrateAdaptiveStrategy($0) }
        let scopedContextJSON = BASScopedContextCompiler.compile(
            kind: adaptiveTraceKind(for: kind),
            strategy: substrateStrategy,
            brainState: brainState
        )
        .map(BASScopedContextCompiler.jsonString(for:))
        let frontstageInput = BASPromptContractFrontstageInput(
            kind: adaptiveTraceKind(for: kind),
            activeStateSignalCount: activeStateSignalCount(in: state),
            openTextSignalCount: openTextSignalCount,
            contextWasRebuilt: contextState?.rebuiltSession == true,
            staleFieldCount: contextState?.staleFieldCount ?? 0,
            anchorTitles: (contextState?.anchorFields ?? []).map(\.title),
            dominantSignalTitles: (neuralState?.dominantActivations ?? []).map(\.signal.title),
            suppressedBehaviors: neuralState?.suppressedBehaviors ?? [],
            memoryHeadlines: brainState?.relevantMemories ?? [],
            sessionBiases: brainState?.sessionBiases ?? []
        )
        let targetCharacters = strategy?.contextBudget ?? kind.targetCharacters
        let suffixFloor: Int
        if strategy?.runtimeGear == .low {
            switch kind {
            case .quick, .reminder:
                suffixFloor = 120
            case .balance, .mirror:
                suffixFloor = 150
            }
        } else {
            suffixFloor = 180
        }

        return BASPromptContractCompiler.compile(
            BASPromptContractRequest(
                kind: kind,
                semanticKind: semanticTaskKind(for: kind),
                adaptiveKind: adaptiveTraceKind(for: kind),
                immutablePrefix: immutablePrefix,
                adaptivePrefix: adaptivePrefix,
                taskStateJSON: stateJSONString(state),
                evidenceSnippets: evidence,
                evidenceRetentionBudget: evidenceRetentionBudget(for: kind, strategy: strategy),
                outputGuard: outputGuard,
                frontstageInput: frontstageInput,
                targetCharacters: targetCharacters,
                suffixFloorCharacters: suffixFloor,
                strategy: substrateStrategy,
                structuredTruth: structuredTruth,
                includeStructuredTruthBlock: renderedStructuredTruth != nil,
                scopedContextJSON: scopedContextJSON,
                providerIdentifier: strategy.map(\.preferredProvider.rawValue),
                contextLifecycleJSON: contextState.map(contextStateJSONString),
                neuralStateJSON: neuralState.map(neuralStateJSONString),
                brainStateJSON: brainState.flatMap { $0.isEmpty ? nil : brainStateJSONString($0) }
            )
        )
    }

    static func consistencyTruthState(
        for kind: DecisionIntelligenceTraceKind,
        brainState: DecisionBrainState?,
        reminderMode: DecisionMode? = nil
    ) -> BASStructuredTruthState? {
        BASStructuredTruthCompiler.truthState(
            for: BASStructuredTruthRequest(
                kind: adaptiveTraceKind(for: kind),
                brainState: brainState,
                reminderSurfaceMode: reminderMode.map(substrateMode(from:))
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

    private static func brainStateJSONString(_ brainState: DecisionBrainState) -> String {
        let payload: [String: Any] = [
            "profile_core": brainState.profileCore,
            "active_goals": brainState.activeGoals,
            "relevant_memories": brainState.relevantMemories,
            "session_biases": brainState.sessionBiases,
            "reaction_weights": reactionWeightsJSONObject(brainState.reactionWeights),
            "identity": [
                "role": brainState.identityProfile.role.rawValue,
                "posture": brainState.identityProfile.posture.rawValue,
                "initiative": brainState.identityProfile.initiative.rawValue,
                "confidence_ceiling": brainState.identityProfile.confidenceCeiling
            ],
            "boundary_policy": [
                "mode": brainState.boundaryPolicy.mode.rawValue,
                "constraints": brainState.boundaryPolicy.activeConstraints.map(\.rawValue),
                "required_confirmations": brainState.boundaryPolicy.requiredConfirmations
            ],
            "calibration": [
                "status": brainState.calibrationState.status.rawValue,
                "alerts": brainState.calibrationState.alerts.map(\.rawValue)
            ]
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

    private static func evidenceRetentionBudget(
        for kind: TaskKind,
        strategy: DecisionAdaptiveTaskStrategy?
    ) -> Int {
        BASPromptRetentionAdvisor.evidenceRetentionBudget(
            for: semanticTaskKind(for: kind),
            strategy: strategy.map(substrateAdaptiveStrategy)
        )
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

    private static func semanticTaskKind(
        for kind: TaskKind
    ) -> BASSemanticTaskKind {
        switch kind {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case .reminder:
            .reminder
        }
    }

    private static func adaptiveTraceKind(
        for kind: TaskKind
    ) -> BASAdaptiveTraceKind {
        switch kind {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case .reminder:
            .reminder
        }
    }

    private static func adaptiveTraceKind(
        for kind: DecisionIntelligenceTraceKind
    ) -> BASAdaptiveTraceKind {
        switch kind {
        case .quick:
            .quick
        case .balance:
            .balance
        case .mirror:
            .mirror
        case .reminder:
            .reminder
        }
    }

    private static func substrateAdaptiveStrategy(
        _ strategy: DecisionAdaptiveTaskStrategy
    ) -> BASAdaptiveTaskStrategy {
        let kind: BASAdaptiveTraceKind
        switch strategy.kind {
        case .quick:
            kind = .quick
        case .balance:
            kind = .balance
        case .mirror:
            kind = .mirror
        case .reminder:
            kind = .reminder
        }

        let entropy: BASTaskEntropyClass
        switch strategy.entropy {
        case .low:
            entropy = .low
        case .medium:
            entropy = .medium
        case .high:
            entropy = .high
        }

        let runtimeGear: BASRuntimeGear
        switch strategy.runtimeGear {
        case .low:
            runtimeGear = .low
        case .balanced:
            runtimeGear = .balanced
        case .high:
            runtimeGear = .high
        }

        let retrievalMode: BASRetrievalMode
        switch strategy.retrievalMode {
        case .off:
            retrievalMode = .off
        case .filtered:
            retrievalMode = .filtered
        case .adaptive:
            retrievalMode = .adaptive
        }

        let thinkingMode: BASThinkingMode
        switch strategy.thinkingMode {
        case .off:
            thinkingMode = .off
        case .gated:
            thinkingMode = .gated
        }

        let outputMode: BASOutputMode
        switch strategy.outputMode {
        case .deterministicTemplate:
            outputMode = .deterministicTemplate
        case .guidedShort:
            outputMode = .guidedShort
        case .structuredBoard:
            outputMode = .structuredBoard
        case .reflectiveStructured:
            outputMode = .reflectiveStructured
        case .jsonShort:
            outputMode = .jsonShort
        }

        let tone: BASToneProfile
        switch strategy.tone {
        case .neutral:
            tone = .neutral
        case .briefWarm:
            tone = .briefWarm
        case .groundedDirect:
            tone = .groundedDirect
        case .reflectiveClear:
            tone = .reflectiveClear
        }

        let responseLanguage: BASAdaptiveResponseLanguage
        switch strategy.responseLanguage {
        case .english:
            responseLanguage = .english
        case .chinese:
            responseLanguage = .chinese
        case .mixed:
            responseLanguage = .mixed
        }

        return BASAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy,
            runtimeGear: runtimeGear,
            contextBudget: strategy.contextBudget,
            outputCharacterBudget: strategy.outputCharacterBudget,
            timeBudgetMs: strategy.timeBudgetMs,
            toolCallBudget: strategy.toolCallBudget,
            retrievalItemBudget: strategy.retrievalItemBudget,
            retrievalMode: retrievalMode,
            thinkingMode: thinkingMode,
            outputMode: outputMode,
            tone: tone,
            actionSpace: strategy.actionSpace,
            responseLanguage: responseLanguage,
            allowsModelInvocation: strategy.allowsModelInvocation
        )
    }
}
