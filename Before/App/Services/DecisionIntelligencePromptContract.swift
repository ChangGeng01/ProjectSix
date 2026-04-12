import Foundation
import BASHostKit

enum DecisionIntelligencePromptContract {
    enum Limit {
        static let quickCurrentPerspective = BASReferencePromptLimits.primaryCurrentPerspective
        static let quickAfterPerspective = BASReferencePromptLimits.primaryAfterPerspective
        static let balanceHeadline = BASReferencePromptLimits.comparativeHeadline
        static let balanceSummary = BASReferencePromptLimits.comparativeDetailSummary
        static let balanceFocusDescription = BASReferencePromptLimits.comparativeFocusDescription
        static let balanceNextAction = BASReferencePromptLimits.comparativeNextAction
        static let mirrorHeadline = BASReferencePromptLimits.reflectiveHeadline
        static let mirrorCoreTension = BASReferencePromptLimits.reflectiveCoreTension
        static let mirrorNextAction = BASReferencePromptLimits.reflectiveNextAction
        static let reminderCandidates = BASReferencePromptLimits.selectionCandidates
        static let reminderCandidateLength = BASReferencePromptLimits.selectionCandidateLength
        static let stateField = BASReferencePromptLimits.stateField
        static let statePrompt = BASReferencePromptLimits.statePrompt
        static let evidenceSnippet = BASReferencePromptLimits.evidenceSnippet
    }

    typealias ContextBudget = BASPromptBudget
    typealias PromptLayers = BASPromptLayers
    typealias PromptBlockKind = BASSemanticPromptBlockKind
    typealias PromptBlockRetention = BASSemanticPromptBlockRetention
    typealias PromptBlock = BASSemanticPromptBlock
    typealias PromptAssembly = BASSemanticContextAssembly
    typealias PromptEnvelope = BASPromptEnvelope<BASReferencePromptKind, DecisionFrontstageState>

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
        BASAppleReferencePromptBuilder.primaryEnvelope(
            BASApplePrimaryRefinementEnvelopeRequest(
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
                strategy: strategy.map {
                    BASAppleAdaptiveStrategyRawInput(
                        kindRawValue: $0.kind.rawValue,
                        entropyRawValue: $0.entropy.rawValue,
                        runtimeGearRawValue: $0.runtimeGear.rawValue,
                        contextBudget: $0.contextBudget,
                        outputCharacterBudget: $0.outputCharacterBudget,
                        timeBudgetMs: $0.timeBudgetMs,
                        toolCallBudget: $0.toolCallBudget,
                        retrievalItemBudget: $0.retrievalItemBudget,
                        retrievalModeRawValue: $0.retrievalMode.rawValue,
                        thinkingModeRawValue: $0.thinkingMode.rawValue,
                        outputModeRawValue: $0.outputMode.rawValue,
                        toneRawValue: $0.tone.rawValue,
                        actionSpace: $0.actionSpace,
                        responseLanguageRawValue: $0.responseLanguage.rawValue,
                        allowsModelInvocation: $0.allowsModelInvocation
                    )
                },
                contextLifecycleInput: contextState.map {
                    BASApplePromptLifecycleInput(
                        rebuiltSession: $0.rebuiltSession,
                        generation: $0.generation,
                        anchorFields: $0.anchorFields.map(\.rawValue),
                        activeFields: $0.activeFields.map(\.rawValue),
                        staleFields: $0.staleFields.map(\.rawValue),
                        anchorTitles: $0.anchorFields.map(\.title)
                    )
                },
                neuralInput: neuralState.map {
                    BASApplePromptNeuralInput(
                        dominantActivations: $0.dominantActivations.map {
                            BASApplePromptActivationInput(
                                signal: $0.signal.rawValue,
                                displayTitle: $0.signal.title
                            )
                        },
                        candidateActions: $0.candidateActions.map {
                            BASApplePromptActionCandidateInput(route: $0.route.rawValue)
                        },
                        suppressedBehaviors: $0.suppressedBehaviors
                    )
                },
                brainState: brainState
            ),
            behavior: BeforeProductCompatibility.referencePromptBehavior
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
        BASAppleReferencePromptBuilder.comparativeEnvelope(
            BASAppleComparativeRefinementEnvelopeRequest(
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
                strategy: strategy.map {
                    BASAppleAdaptiveStrategyRawInput(
                        kindRawValue: $0.kind.rawValue,
                        entropyRawValue: $0.entropy.rawValue,
                        runtimeGearRawValue: $0.runtimeGear.rawValue,
                        contextBudget: $0.contextBudget,
                        outputCharacterBudget: $0.outputCharacterBudget,
                        timeBudgetMs: $0.timeBudgetMs,
                        toolCallBudget: $0.toolCallBudget,
                        retrievalItemBudget: $0.retrievalItemBudget,
                        retrievalModeRawValue: $0.retrievalMode.rawValue,
                        thinkingModeRawValue: $0.thinkingMode.rawValue,
                        outputModeRawValue: $0.outputMode.rawValue,
                        toneRawValue: $0.tone.rawValue,
                        actionSpace: $0.actionSpace,
                        responseLanguageRawValue: $0.responseLanguage.rawValue,
                        allowsModelInvocation: $0.allowsModelInvocation
                    )
                },
                contextLifecycleInput: contextState.map {
                    BASApplePromptLifecycleInput(
                        rebuiltSession: $0.rebuiltSession,
                        generation: $0.generation,
                        anchorFields: $0.anchorFields.map(\.rawValue),
                        activeFields: $0.activeFields.map(\.rawValue),
                        staleFields: $0.staleFields.map(\.rawValue),
                        anchorTitles: $0.anchorFields.map(\.title)
                    )
                },
                neuralInput: neuralState.map {
                    BASApplePromptNeuralInput(
                        dominantActivations: $0.dominantActivations.map {
                            BASApplePromptActivationInput(
                                signal: $0.signal.rawValue,
                                displayTitle: $0.signal.title
                            )
                        },
                        candidateActions: $0.candidateActions.map {
                            BASApplePromptActionCandidateInput(route: $0.route.rawValue)
                        },
                        suppressedBehaviors: $0.suppressedBehaviors
                    )
                },
                brainState: brainState
            ),
            behavior: BeforeProductCompatibility.referencePromptBehavior
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
        BASAppleReferencePromptBuilder.reflectiveEnvelope(
            BASAppleReflectiveRefinementEnvelopeRequest(
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
                strategy: strategy.map {
                    BASAppleAdaptiveStrategyRawInput(
                        kindRawValue: $0.kind.rawValue,
                        entropyRawValue: $0.entropy.rawValue,
                        runtimeGearRawValue: $0.runtimeGear.rawValue,
                        contextBudget: $0.contextBudget,
                        outputCharacterBudget: $0.outputCharacterBudget,
                        timeBudgetMs: $0.timeBudgetMs,
                        toolCallBudget: $0.toolCallBudget,
                        retrievalItemBudget: $0.retrievalItemBudget,
                        retrievalModeRawValue: $0.retrievalMode.rawValue,
                        thinkingModeRawValue: $0.thinkingMode.rawValue,
                        outputModeRawValue: $0.outputMode.rawValue,
                        toneRawValue: $0.tone.rawValue,
                        actionSpace: $0.actionSpace,
                        responseLanguageRawValue: $0.responseLanguage.rawValue,
                        allowsModelInvocation: $0.allowsModelInvocation
                    )
                },
                contextLifecycleInput: contextState.map {
                    BASApplePromptLifecycleInput(
                        rebuiltSession: $0.rebuiltSession,
                        generation: $0.generation,
                        anchorFields: $0.anchorFields.map(\.rawValue),
                        activeFields: $0.activeFields.map(\.rawValue),
                        staleFields: $0.staleFields.map(\.rawValue),
                        anchorTitles: $0.anchorFields.map(\.title)
                    )
                },
                neuralInput: neuralState.map {
                    BASApplePromptNeuralInput(
                        dominantActivations: $0.dominantActivations.map {
                            BASApplePromptActivationInput(
                                signal: $0.signal.rawValue,
                                displayTitle: $0.signal.title
                            )
                        },
                        candidateActions: $0.candidateActions.map {
                            BASApplePromptActionCandidateInput(route: $0.route.rawValue)
                        },
                        suppressedBehaviors: $0.suppressedBehaviors
                    )
                },
                brainState: brainState
            ),
            behavior: BeforeProductCompatibility.referencePromptBehavior
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
    ) -> BASReferenceSelectionEnvelope<ReminderSelectionCandidate> {
        BASAppleReferencePromptBuilder.selectionEnvelope(
            candidates: candidates,
            candidateText: \.content,
            modeTitle: mode?.shortTitle ?? "Not specified",
            scenarioTitle: scenario.title,
            prompt: prompt,
            surfaceModeRawValue: mode?.substrateModeID,
            providerIdentifier: strategy?.preferredProvider.rawValue,
            strategy: strategy.map {
                BASAppleAdaptiveStrategyRawInput(
                    kindRawValue: $0.kind.rawValue,
                    entropyRawValue: $0.entropy.rawValue,
                    runtimeGearRawValue: $0.runtimeGear.rawValue,
                    contextBudget: $0.contextBudget,
                    outputCharacterBudget: $0.outputCharacterBudget,
                    timeBudgetMs: $0.timeBudgetMs,
                    toolCallBudget: $0.toolCallBudget,
                    retrievalItemBudget: $0.retrievalItemBudget,
                    retrievalModeRawValue: $0.retrievalMode.rawValue,
                    thinkingModeRawValue: $0.thinkingMode.rawValue,
                    outputModeRawValue: $0.outputMode.rawValue,
                    toneRawValue: $0.tone.rawValue,
                    actionSpace: $0.actionSpace,
                    responseLanguageRawValue: $0.responseLanguage.rawValue,
                    allowsModelInvocation: $0.allowsModelInvocation
                )
            },
            behavior: BeforeProductCompatibility.referencePromptBehavior
        )
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
}
