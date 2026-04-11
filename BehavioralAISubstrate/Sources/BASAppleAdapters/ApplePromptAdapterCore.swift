import Foundation
import BASMemory
import BASOrchestration
import BASRuntimeCore

public struct BASApplePromptLifecycleInput: Codable, Sendable, Equatable {
    public var rebuiltSession: Bool
    public var generation: Int
    public var anchorFields: [String]
    public var activeFields: [String]
    public var staleFields: [String]
    public var anchorTitles: [String]

    public init(
        rebuiltSession: Bool,
        generation: Int,
        anchorFields: [String],
        activeFields: [String],
        staleFields: [String],
        anchorTitles: [String] = []
    ) {
        self.rebuiltSession = rebuiltSession
        self.generation = generation
        self.anchorFields = anchorFields
        self.activeFields = activeFields
        self.staleFields = staleFields
        self.anchorTitles = anchorTitles
    }
}

public struct BASApplePromptActivationInput: Codable, Sendable, Equatable {
    public var signal: String
    public var displayTitle: String?

    public init(signal: String, displayTitle: String? = nil) {
        self.signal = signal
        self.displayTitle = displayTitle
    }
}

public struct BASApplePromptActionCandidateInput: Codable, Sendable, Equatable {
    public var route: String

    public init(route: String) {
        self.route = route
    }
}

public struct BASApplePromptNeuralInput: Codable, Sendable, Equatable {
    public var dominantActivations: [BASApplePromptActivationInput]
    public var candidateActions: [BASApplePromptActionCandidateInput]
    public var suppressedBehaviors: [String]

    public init(
        dominantActivations: [BASApplePromptActivationInput],
        candidateActions: [BASApplePromptActionCandidateInput],
        suppressedBehaviors: [String]
    ) {
        self.dominantActivations = dominantActivations
        self.candidateActions = candidateActions
        self.suppressedBehaviors = suppressedBehaviors
    }
}

public struct BASAppleAdaptiveStrategyInput: Codable, Sendable, Equatable {
    public var kind: BASAdaptiveTraceKind
    public var entropy: BASTaskEntropyClass
    public var runtimeGear: BASRuntimeGear
    public var contextBudget: Int
    public var outputCharacterBudget: Int
    public var timeBudgetMs: Int
    public var toolCallBudget: Int
    public var retrievalItemBudget: Int
    public var retrievalMode: BASRetrievalMode
    public var thinkingMode: BASThinkingMode
    public var outputMode: BASOutputMode
    public var tone: BASToneProfile
    public var actionSpace: [String]
    public var responseLanguage: BASAdaptiveResponseLanguage
    public var allowsModelInvocation: Bool

    public init(
        kind: BASAdaptiveTraceKind,
        entropy: BASTaskEntropyClass,
        runtimeGear: BASRuntimeGear,
        contextBudget: Int,
        outputCharacterBudget: Int,
        timeBudgetMs: Int,
        toolCallBudget: Int,
        retrievalItemBudget: Int,
        retrievalMode: BASRetrievalMode,
        thinkingMode: BASThinkingMode,
        outputMode: BASOutputMode,
        tone: BASToneProfile,
        actionSpace: [String],
        responseLanguage: BASAdaptiveResponseLanguage,
        allowsModelInvocation: Bool
    ) {
        self.kind = kind
        self.entropy = entropy
        self.runtimeGear = runtimeGear
        self.contextBudget = contextBudget
        self.outputCharacterBudget = outputCharacterBudget
        self.timeBudgetMs = timeBudgetMs
        self.toolCallBudget = toolCallBudget
        self.retrievalItemBudget = retrievalItemBudget
        self.retrievalMode = retrievalMode
        self.thinkingMode = thinkingMode
        self.outputMode = outputMode
        self.tone = tone
        self.actionSpace = actionSpace
        self.responseLanguage = responseLanguage
        self.allowsModelInvocation = allowsModelInvocation
    }
}

public struct BASAppleAdaptiveStrategyRawInput: Codable, Sendable, Equatable {
    public var kindRawValue: String
    public var entropyRawValue: String
    public var runtimeGearRawValue: String
    public var contextBudget: Int
    public var outputCharacterBudget: Int
    public var timeBudgetMs: Int
    public var toolCallBudget: Int
    public var retrievalItemBudget: Int
    public var retrievalModeRawValue: String
    public var thinkingModeRawValue: String
    public var outputModeRawValue: String
    public var toneRawValue: String
    public var actionSpace: [String]
    public var responseLanguageRawValue: String
    public var allowsModelInvocation: Bool

    public init(
        kindRawValue: String,
        entropyRawValue: String,
        runtimeGearRawValue: String,
        contextBudget: Int,
        outputCharacterBudget: Int,
        timeBudgetMs: Int,
        toolCallBudget: Int,
        retrievalItemBudget: Int,
        retrievalModeRawValue: String,
        thinkingModeRawValue: String,
        outputModeRawValue: String,
        toneRawValue: String,
        actionSpace: [String],
        responseLanguageRawValue: String,
        allowsModelInvocation: Bool
    ) {
        self.kindRawValue = kindRawValue
        self.entropyRawValue = entropyRawValue
        self.runtimeGearRawValue = runtimeGearRawValue
        self.contextBudget = contextBudget
        self.outputCharacterBudget = outputCharacterBudget
        self.timeBudgetMs = timeBudgetMs
        self.toolCallBudget = toolCallBudget
        self.retrievalItemBudget = retrievalItemBudget
        self.retrievalModeRawValue = retrievalModeRawValue
        self.thinkingModeRawValue = thinkingModeRawValue
        self.outputModeRawValue = outputModeRawValue
        self.toneRawValue = toneRawValue
        self.actionSpace = actionSpace
        self.responseLanguageRawValue = responseLanguageRawValue
        self.allowsModelInvocation = allowsModelInvocation
    }
}

public struct BASAppleQuickRefinementEnvelopeRequest: Codable, Sendable, Equatable {
    public var modeTitle: String
    public var scenarioTitle: String
    public var motivationTitle: String
    public var expectedOutcomeTitle: String
    public var controlLevelTitle: String
    public var note: String
    public var currentPerspective: String
    public var afterPerspective: String
    public var verdictTitle: String
    public var primaryActionTitle: String
    public var secondaryActionTitles: [String]
    public var providerIdentifier: String?
    public var strategy: BASAppleAdaptiveStrategyRawInput?
    public var contextLifecycleInput: BASApplePromptLifecycleInput?
    public var neuralInput: BASApplePromptNeuralInput?
    public var brainState: BASDecisionBrainState?

    public init(
        modeTitle: String,
        scenarioTitle: String,
        motivationTitle: String,
        expectedOutcomeTitle: String,
        controlLevelTitle: String,
        note: String,
        currentPerspective: String,
        afterPerspective: String,
        verdictTitle: String,
        primaryActionTitle: String,
        secondaryActionTitles: [String],
        providerIdentifier: String? = nil,
        strategy: BASAppleAdaptiveStrategyRawInput? = nil,
        contextLifecycleInput: BASApplePromptLifecycleInput? = nil,
        neuralInput: BASApplePromptNeuralInput? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.modeTitle = modeTitle
        self.scenarioTitle = scenarioTitle
        self.motivationTitle = motivationTitle
        self.expectedOutcomeTitle = expectedOutcomeTitle
        self.controlLevelTitle = controlLevelTitle
        self.note = note
        self.currentPerspective = currentPerspective
        self.afterPerspective = afterPerspective
        self.verdictTitle = verdictTitle
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitles = secondaryActionTitles
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleInput = contextLifecycleInput
        self.neuralInput = neuralInput
        self.brainState = brainState
    }
}

public struct BASAppleBalanceRefinementEnvelopeRequest: Codable, Sendable, Equatable {
    public var modeTitle: String
    public var prompt: String
    public var desire: String
    public var concern: String
    public var constraint: String
    public var longTerm: String
    public var headline: String
    public var summary: String
    public var focusTitle: String
    public var focusDescription: String
    public var nextAction: String
    public var providerIdentifier: String?
    public var strategy: BASAppleAdaptiveStrategyRawInput?
    public var contextLifecycleInput: BASApplePromptLifecycleInput?
    public var neuralInput: BASApplePromptNeuralInput?
    public var brainState: BASDecisionBrainState?

    public init(
        modeTitle: String,
        prompt: String,
        desire: String,
        concern: String,
        constraint: String,
        longTerm: String,
        headline: String,
        summary: String,
        focusTitle: String,
        focusDescription: String,
        nextAction: String,
        providerIdentifier: String? = nil,
        strategy: BASAppleAdaptiveStrategyRawInput? = nil,
        contextLifecycleInput: BASApplePromptLifecycleInput? = nil,
        neuralInput: BASApplePromptNeuralInput? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.modeTitle = modeTitle
        self.prompt = prompt
        self.desire = desire
        self.concern = concern
        self.constraint = constraint
        self.longTerm = longTerm
        self.headline = headline
        self.summary = summary
        self.focusTitle = focusTitle
        self.focusDescription = focusDescription
        self.nextAction = nextAction
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleInput = contextLifecycleInput
        self.neuralInput = neuralInput
        self.brainState = brainState
    }
}

public struct BASAppleMirrorRefinementEnvelopeRequest: Codable, Sendable, Equatable {
    public var modeTitle: String
    public var prompt: String
    public var emotion: String
    public var relationship: String
    public var reality: String
    public var longTerm: String
    public var selfLens: String
    public var headline: String
    public var coreTension: String
    public var nextActionTitle: String
    public var nextAction: String
    public var providerIdentifier: String?
    public var strategy: BASAppleAdaptiveStrategyRawInput?
    public var contextLifecycleInput: BASApplePromptLifecycleInput?
    public var neuralInput: BASApplePromptNeuralInput?
    public var brainState: BASDecisionBrainState?

    public init(
        modeTitle: String,
        prompt: String,
        emotion: String,
        relationship: String,
        reality: String,
        longTerm: String,
        selfLens: String,
        headline: String,
        coreTension: String,
        nextActionTitle: String,
        nextAction: String,
        providerIdentifier: String? = nil,
        strategy: BASAppleAdaptiveStrategyRawInput? = nil,
        contextLifecycleInput: BASApplePromptLifecycleInput? = nil,
        neuralInput: BASApplePromptNeuralInput? = nil,
        brainState: BASDecisionBrainState? = nil
    ) {
        self.modeTitle = modeTitle
        self.prompt = prompt
        self.emotion = emotion
        self.relationship = relationship
        self.reality = reality
        self.longTerm = longTerm
        self.selfLens = selfLens
        self.headline = headline
        self.coreTension = coreTension
        self.nextActionTitle = nextActionTitle
        self.nextAction = nextAction
        self.providerIdentifier = providerIdentifier
        self.strategy = strategy
        self.contextLifecycleInput = contextLifecycleInput
        self.neuralInput = neuralInput
        self.brainState = brainState
    }
}

public enum BASApplePromptInputAdapter {
    public static func lifecycleSnapshot(
        from input: BASApplePromptLifecycleInput
    ) -> BASPromptContextLifecycleSnapshot {
        let anchorFields = normalizedStrings(input.anchorFields)
        let activeFields = normalizedStrings(input.activeFields)
        let staleFields = normalizedStrings(input.staleFields)
        let anchorTitles = normalizedStrings(input.anchorTitles)

        return BASPromptContextLifecycleSnapshot(
            rebuiltSession: input.rebuiltSession,
            generation: input.generation,
            anchorFields: anchorFields,
            activeFields: activeFields,
            staleFields: staleFields,
            anchorTitles: anchorTitles.isEmpty ? anchorFields : anchorTitles
        )
    }

    public static func neuralSnapshot(
        from input: BASApplePromptNeuralInput
    ) -> BASPromptNeuralSnapshot {
        BASPromptNeuralSnapshot(
            dominantActivations: input.dominantActivations.reduce(into: []) { result, activation in
                let signal = normalizedText(activation.signal)
                guard signal.isEmpty == false else { return }
                let displayTitle = normalizedOptionalText(activation.displayTitle)
                guard result.contains(where: { $0.signal == signal && $0.displayTitle == displayTitle }) == false else { return }
                result.append(
                    BASPromptNeuralActivationSnapshot(
                        signal: signal,
                        displayTitle: displayTitle
                    )
                )
            },
            candidateActions: input.candidateActions.reduce(into: []) { result, candidate in
                let route = normalizedText(candidate.route)
                guard route.isEmpty == false else { return }
                guard result.contains(where: { $0.route == route }) == false else { return }
                result.append(BASPromptNeuralActionCandidateSnapshot(route: route))
            },
            suppressedBehaviors: normalizedStrings(input.suppressedBehaviors)
        )
    }

    public static func adaptiveStrategy(
        from input: BASAppleAdaptiveStrategyInput
    ) -> BASAdaptiveTaskStrategy {
        BASAdaptiveTaskStrategy(
            kind: input.kind,
            entropy: input.entropy,
            runtimeGear: input.runtimeGear,
            contextBudget: input.contextBudget,
            outputCharacterBudget: input.outputCharacterBudget,
            timeBudgetMs: input.timeBudgetMs,
            toolCallBudget: input.toolCallBudget,
            retrievalItemBudget: input.retrievalItemBudget,
            retrievalMode: input.retrievalMode,
            thinkingMode: input.thinkingMode,
            outputMode: input.outputMode,
            tone: input.tone,
            actionSpace: normalizedStrings(input.actionSpace),
            responseLanguage: input.responseLanguage,
            allowsModelInvocation: input.allowsModelInvocation
        )
    }

    public static func adaptiveStrategy(
        from input: BASAppleAdaptiveStrategyRawInput
    ) -> BASAdaptiveTaskStrategy {
        adaptiveStrategy(
            from: BASAppleAdaptiveStrategyInput(
                kind: BASAdaptiveTraceKind(rawValue: input.kindRawValue) ?? .quick,
                entropy: BASTaskEntropyClass(rawValue: input.entropyRawValue) ?? .medium,
                runtimeGear: BASRuntimeGear(rawValue: input.runtimeGearRawValue) ?? .balanced,
                contextBudget: input.contextBudget,
                outputCharacterBudget: input.outputCharacterBudget,
                timeBudgetMs: input.timeBudgetMs,
                toolCallBudget: input.toolCallBudget,
                retrievalItemBudget: input.retrievalItemBudget,
                retrievalMode: BASRetrievalMode(rawValue: input.retrievalModeRawValue) ?? .adaptive,
                thinkingMode: BASThinkingMode(rawValue: input.thinkingModeRawValue) ?? .gated,
                outputMode: BASOutputMode(rawValue: input.outputModeRawValue) ?? .guidedShort,
                tone: BASToneProfile(rawValue: input.toneRawValue) ?? .neutral,
                actionSpace: input.actionSpace,
                responseLanguage: BASAdaptiveResponseLanguage(rawValue: input.responseLanguageRawValue) ?? .english,
                allowsModelInvocation: input.allowsModelInvocation
            )
        )
    }

    private static func normalizedStrings(_ values: [String]) -> [String] {
        values.reduce(into: []) { result, value in
            let normalized = normalizedText(value)
            guard normalized.isEmpty == false else { return }
            guard result.contains(normalized) == false else { return }
            result.append(normalized)
        }
    }

    private static func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = normalizedText(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

public enum BASAppleReferencePromptBuilder {
    public static func quickEnvelope(
        _ request: BASAppleQuickRefinementEnvelopeRequest,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<BASReferencePromptKind, BASFrontstageState> {
        BASReferencePromptBuilder.quickEnvelope(
            BASQuickRefinementPromptRequest(
                kind: .quick,
                modeTitle: request.modeTitle,
                scenarioTitle: request.scenarioTitle,
                motivationTitle: request.motivationTitle,
                expectedOutcomeTitle: request.expectedOutcomeTitle,
                controlLevelTitle: request.controlLevelTitle,
                note: request.note,
                currentPerspective: request.currentPerspective,
                afterPerspective: request.afterPerspective,
                verdictTitle: request.verdictTitle,
                primaryActionTitle: request.primaryActionTitle,
                secondaryActionTitles: request.secondaryActionTitles,
                providerIdentifier: request.providerIdentifier,
                strategy: request.strategy.map(BASApplePromptInputAdapter.adaptiveStrategy),
                contextLifecycleSnapshot: request.contextLifecycleInput.map(BASApplePromptInputAdapter.lifecycleSnapshot),
                neuralSnapshot: request.neuralInput.map(BASApplePromptInputAdapter.neuralSnapshot),
                brainState: request.brainState
            ),
            behavior: behavior
        )
    }

    public static func balanceEnvelope(
        _ request: BASAppleBalanceRefinementEnvelopeRequest,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<BASReferencePromptKind, BASFrontstageState> {
        BASReferencePromptBuilder.balanceEnvelope(
            BASBalanceRefinementPromptRequest(
                kind: .balance,
                modeTitle: request.modeTitle,
                prompt: request.prompt,
                desire: request.desire,
                concern: request.concern,
                constraint: request.constraint,
                longTerm: request.longTerm,
                headline: request.headline,
                summary: request.summary,
                focusTitle: request.focusTitle,
                focusDescription: request.focusDescription,
                nextAction: request.nextAction,
                providerIdentifier: request.providerIdentifier,
                strategy: request.strategy.map(BASApplePromptInputAdapter.adaptiveStrategy),
                contextLifecycleSnapshot: request.contextLifecycleInput.map(BASApplePromptInputAdapter.lifecycleSnapshot),
                neuralSnapshot: request.neuralInput.map(BASApplePromptInputAdapter.neuralSnapshot),
                brainState: request.brainState
            ),
            behavior: behavior
        )
    }

    public static func mirrorEnvelope(
        _ request: BASAppleMirrorRefinementEnvelopeRequest,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASPromptEnvelope<BASReferencePromptKind, BASFrontstageState> {
        BASReferencePromptBuilder.mirrorEnvelope(
            BASMirrorRefinementPromptRequest(
                kind: .mirror,
                modeTitle: request.modeTitle,
                prompt: request.prompt,
                emotion: request.emotion,
                relationship: request.relationship,
                reality: request.reality,
                longTerm: request.longTerm,
                selfLens: request.selfLens,
                headline: request.headline,
                coreTension: request.coreTension,
                nextActionTitle: request.nextActionTitle,
                nextAction: request.nextAction,
                providerIdentifier: request.providerIdentifier,
                strategy: request.strategy.map(BASApplePromptInputAdapter.adaptiveStrategy),
                contextLifecycleSnapshot: request.contextLifecycleInput.map(BASApplePromptInputAdapter.lifecycleSnapshot),
                neuralSnapshot: request.neuralInput.map(BASApplePromptInputAdapter.neuralSnapshot),
                brainState: request.brainState
            ),
            behavior: behavior
        )
    }

    public static func reminderEnvelope<Candidate: Equatable & Sendable>(
        candidates: [Candidate],
        candidateText: (Candidate) -> String,
        modeTitle: String,
        scenarioTitle: String,
        prompt: String,
        reminderSurfaceModeRawValue: String?,
        providerIdentifier: String? = nil,
        strategy: BASAppleAdaptiveStrategyRawInput? = nil,
        behavior: BASReferencePromptBehavior = .generic
    ) -> BASReferenceReminderSelectionEnvelope<Candidate> {
        let clippedCandidates = Array(candidates.prefix(BASReferencePromptLimits.reminderCandidates))
        let envelope = BASReferencePromptBuilder.reminderEnvelope(
            BASReminderSelectionPromptRequest<BASReferencePromptKind>(
                kind: .reminder,
                modeTitle: modeTitle,
                scenarioTitle: scenarioTitle,
                prompt: prompt,
                candidateTexts: clippedCandidates.map(candidateText),
                reminderSurfaceMode: reminderSurfaceModeRawValue.flatMap(BASDecisionMode.init(identifier:)),
                providerIdentifier: providerIdentifier,
                strategy: strategy.map(BASApplePromptInputAdapter.adaptiveStrategy)
            ),
            behavior: behavior
        )

        return BASReferenceReminderSelectionEnvelope(
            prompt: envelope,
            candidates: clippedCandidates
        )
    }
}
