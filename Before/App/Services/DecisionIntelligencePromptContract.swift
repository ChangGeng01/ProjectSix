import Foundation
import BASAppleAdapters
import BASOrchestration
import BASPolicy
import BASRuntimeCore

enum DecisionIntelligencePromptContract {
    enum Limit {
        static let quickCurrentPerspective = BASReferencePromptLimits.quickCurrentPerspective
        static let quickAfterPerspective = BASReferencePromptLimits.quickAfterPerspective
        static let balanceHeadline = BASReferencePromptLimits.balanceHeadline
        static let balanceSummary = BASReferencePromptLimits.balanceSummary
        static let balanceFocusDescription = BASReferencePromptLimits.balanceFocusDescription
        static let balanceNextAction = BASReferencePromptLimits.balanceNextAction
        static let mirrorHeadline = BASReferencePromptLimits.mirrorHeadline
        static let mirrorCoreTension = BASReferencePromptLimits.mirrorCoreTension
        static let mirrorNextAction = BASReferencePromptLimits.mirrorNextAction
        static let reminderCandidates = BASReferencePromptLimits.reminderCandidates
        static let reminderCandidateLength = BASReferencePromptLimits.reminderCandidateLength
        static let stateField = BASReferencePromptLimits.stateField
        static let statePrompt = BASReferencePromptLimits.statePrompt
        static let evidenceSnippet = BASReferencePromptLimits.evidenceSnippet
    }

    enum TaskKind: Equatable, Sendable {
        case quick
        case balance
        case mirror
        case reminder
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
        BASReferencePromptBuilder.quickEnvelope(
            BASQuickRefinementPromptRequest(
                kind: TaskKind.quick,
                modeTitle: DecisionMode.quick.shortTitle,
                scenarioTitle: input.scenario.title,
                motivationTitle: input.motivation.title,
                expectedOutcomeTitle: input.expectedOutcome.title,
                controlLevelTitle: input.controlLevel.title,
                note: input.note,
                currentPerspective: base.currentPerspective,
                afterPerspective: base.afterPerspective,
                verdictTitle: base.verdict.title,
                primaryActionTitle: base.primaryAction.title,
                secondaryActionTitles: base.secondaryActions.map(\.title),
                providerIdentifier: strategy?.preferredProvider.rawValue,
                strategy: strategy.map(substrateAdaptiveStrategy),
                contextLifecycleSnapshot: contextState.map(promptContextLifecycleSnapshot),
                neuralSnapshot: neuralState.map(promptNeuralSnapshot),
                brainState: brainState
            )
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
        BASReferencePromptBuilder.balanceEnvelope(
            BASBalanceRefinementPromptRequest(
                kind: TaskKind.balance,
                modeTitle: DecisionMode.balance.shortTitle,
                prompt: input.prompt,
                desire: input.desire,
                concern: input.concern,
                constraint: input.constraint,
                longTerm: input.longTerm,
                headline: base.headline,
                summary: base.summary,
                focusTitle: base.focusTitle,
                focusDescription: base.focusDescription,
                nextAction: base.nextAction,
                providerIdentifier: strategy?.preferredProvider.rawValue,
                strategy: strategy.map(substrateAdaptiveStrategy),
                contextLifecycleSnapshot: contextState.map(promptContextLifecycleSnapshot),
                neuralSnapshot: neuralState.map(promptNeuralSnapshot),
                brainState: brainState
            )
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
        BASReferencePromptBuilder.mirrorEnvelope(
            BASMirrorRefinementPromptRequest(
                kind: TaskKind.mirror,
                modeTitle: DecisionMode.mirror.shortTitle,
                prompt: input.prompt,
                emotion: input.emotion,
                relationship: input.relationship,
                reality: input.reality,
                longTerm: input.longTerm,
                selfLens: input.selfLens,
                headline: base.headline,
                coreTension: base.coreTension,
                nextActionTitle: base.nextActionTitle,
                nextAction: base.nextAction,
                providerIdentifier: strategy?.preferredProvider.rawValue,
                strategy: strategy.map(substrateAdaptiveStrategy),
                contextLifecycleSnapshot: contextState.map(promptContextLifecycleSnapshot),
                neuralSnapshot: neuralState.map(promptNeuralSnapshot),
                brainState: brainState
            )
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
        let clippedCandidates = Array(candidates.prefix(BASReferencePromptLimits.reminderCandidates))
        let modeTitle = mode?.shortTitle ?? "Not specified"

        let envelope = BASReferencePromptBuilder.reminderEnvelope(
            BASReminderSelectionPromptRequest(
                kind: TaskKind.reminder,
                modeTitle: modeTitle,
                scenarioTitle: scenario.title,
                prompt: prompt,
                candidateTexts: clippedCandidates.map(\.content),
                reminderSurfaceMode: mode.map(substrateMode(from:)),
                providerIdentifier: strategy?.preferredProvider.rawValue,
                strategy: strategy.map(substrateAdaptiveStrategy)
            )
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

    private static func promptContextLifecycleSnapshot(
        _ contextState: DecisionContextPreparedState
    ) -> BASPromptContextLifecycleSnapshot {
        BASApplePromptInputAdapter.lifecycleSnapshot(
            from: BASApplePromptLifecycleInput(
                rebuiltSession: contextState.rebuiltSession,
                generation: contextState.generation,
                anchorFields: contextState.anchorFields.map(\.rawValue),
                activeFields: contextState.activeFields.map(\.rawValue),
                staleFields: contextState.staleFields.map(\.rawValue),
                anchorTitles: contextState.anchorFields.map(\.title)
            )
        )
    }

    private static func promptNeuralSnapshot(
        _ neuralState: DecisionNeuralState
    ) -> BASPromptNeuralSnapshot {
        BASApplePromptInputAdapter.neuralSnapshot(
            from: BASApplePromptNeuralInput(
                dominantActivations: neuralState.dominantActivations.map {
                    BASApplePromptActivationInput(
                        signal: $0.signal.rawValue,
                        displayTitle: $0.signal.title
                    )
                },
                candidateActions: neuralState.candidateActions.map {
                    BASApplePromptActionCandidateInput(route: $0.route.rawValue)
                },
                suppressedBehaviors: neuralState.suppressedBehaviors
            )
        )
    }

    private static func substrateAdaptiveStrategy(
        _ strategy: DecisionAdaptiveTaskStrategy
    ) -> BASAdaptiveTaskStrategy {
        BASApplePromptInputAdapter.adaptiveStrategy(
            from: BASAppleAdaptiveStrategyInput(
                kind: BASAdaptiveTraceKind(rawValue: strategy.kind.rawValue) ?? .quick,
                entropy: BASTaskEntropyClass(rawValue: strategy.entropy.rawValue) ?? .medium,
                runtimeGear: BASRuntimeGear(rawValue: strategy.runtimeGear.rawValue) ?? .balanced,
                contextBudget: strategy.contextBudget,
                outputCharacterBudget: strategy.outputCharacterBudget,
                timeBudgetMs: strategy.timeBudgetMs,
                toolCallBudget: strategy.toolCallBudget,
                retrievalItemBudget: strategy.retrievalItemBudget,
                retrievalMode: BASRetrievalMode(rawValue: strategy.retrievalMode.rawValue) ?? .adaptive,
                thinkingMode: BASThinkingMode(rawValue: strategy.thinkingMode.rawValue) ?? .gated,
                outputMode: BASOutputMode(rawValue: strategy.outputMode.rawValue) ?? .guidedShort,
                tone: BASToneProfile(rawValue: strategy.tone.rawValue) ?? .neutral,
                actionSpace: strategy.actionSpace,
                responseLanguage: BASAdaptiveResponseLanguage(rawValue: strategy.responseLanguage.rawValue) ?? .english,
                allowsModelInvocation: strategy.allowsModelInvocation
            )
        )
    }
}
