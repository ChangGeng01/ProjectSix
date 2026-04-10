import Foundation
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
