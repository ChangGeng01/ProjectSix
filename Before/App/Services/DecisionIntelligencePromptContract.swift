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
                "mode": .string(DecisionMode.quick.shortTitle),
                "scenario": .string(input.scenario.title),
                "motivation": .string(input.motivation.title),
                "expected_outcome": .string(input.expectedOutcome.title),
                "control_level": .string(input.controlLevel.title),
                "note": .string(stateValue(input.note, fallback: "Not provided.", limit: Limit.stateField))
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
                "mode": .string(DecisionMode.balance.shortTitle),
                "prompt": .string(stateValue(input.prompt, fallback: "Not provided.", limit: Limit.statePrompt)),
                "want": .string(stateValue(input.desire, fallback: "Not provided.", limit: Limit.stateField)),
                "concern": .string(stateValue(input.concern, fallback: "Not provided.", limit: Limit.stateField)),
                "reality": .string(stateValue(input.constraint, fallback: "Not provided.", limit: Limit.stateField)),
                "long_term": .string(stateValue(input.longTerm, fallback: "Not provided.", limit: Limit.stateField))
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
                "mode": .string(DecisionMode.mirror.shortTitle),
                "prompt": .string(stateValue(input.prompt, fallback: "Not provided.", limit: Limit.statePrompt)),
                "emotion": .string(stateValue(input.emotion, fallback: "Not provided.", limit: Limit.stateField)),
                "relationship": .string(stateValue(input.relationship, fallback: "Not provided.", limit: Limit.stateField)),
                "reality": .string(stateValue(input.reality, fallback: "Not provided.", limit: Limit.stateField)),
                "long_term": .string(stateValue(input.longTerm, fallback: "Not provided.", limit: Limit.stateField)),
                "self_lens": .string(stateValue(input.selfLens, fallback: "Not provided.", limit: Limit.stateField))
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
                "mode": .string(modeTitle),
                "scenario": .string(scenario.title),
                "current_prompt": .string(stateValue(prompt, fallback: "Not provided.", limit: Limit.statePrompt)),
                "candidate_count": .integer(clippedCandidates.count)
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
        state: [String: BASPromptStateValue?],
        evidence: [String],
        outputGuard: [String],
        openTextSignalCount: Int = 0,
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil,
        structuredTruthOverride: BASStructuredTruthState? = nil,
        includeStructuredTruthBlock: Bool = true
    ) -> PromptEnvelope {
        let substrateStrategy = strategy.map { substrateAdaptiveStrategy($0) }
        return BASPromptPreparationCompiler.compile(
            BASPromptPreparationRequest(
                kind: kind,
                semanticKind: semanticTaskKind(for: kind),
                adaptiveKind: adaptiveTraceKind(for: kind),
                taskState: state,
                evidenceSnippets: evidence,
                outputGuard: outputGuard,
                openTextSignalCount: openTextSignalCount,
                defaultTargetCharacters: kind.targetCharacters,
                strategy: substrateStrategy,
                contextLifecycleSnapshot: contextState.map(promptContextLifecycleSnapshot),
                neuralSnapshot: neuralState.map(promptNeuralSnapshot),
                brainState: brainState,
                structuredTruthOverride: structuredTruthOverride,
                includeStructuredTruthBlock: includeStructuredTruthBlock,
                providerIdentifier: strategy.map(\.preferredProvider.rawValue),
            )
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

    private static func promptContextLifecycleSnapshot(
        _ contextState: DecisionContextPreparedState
    ) -> BASPromptContextLifecycleSnapshot {
        BASPromptContextLifecycleSnapshot(
            rebuiltSession: contextState.rebuiltSession,
            generation: contextState.generation,
            anchorFields: contextState.anchorFields.map(\.rawValue),
            activeFields: contextState.activeFields.map(\.rawValue),
            staleFields: contextState.staleFields.map(\.rawValue),
            anchorTitles: contextState.anchorFields.map(\.title)
        )
    }

    private static func promptNeuralSnapshot(
        _ neuralState: DecisionNeuralState
    ) -> BASPromptNeuralSnapshot {
        BASPromptNeuralSnapshot(
            dominantActivations: neuralState.dominantActivations.map {
                BASPromptNeuralActivationSnapshot(
                    signal: $0.signal.rawValue,
                    displayTitle: $0.signal.title
                )
            },
            candidateActions: neuralState.candidateActions.map {
                BASPromptNeuralActionCandidateSnapshot(route: $0.route.rawValue)
            },
            suppressedBehaviors: neuralState.suppressedBehaviors
        )
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
