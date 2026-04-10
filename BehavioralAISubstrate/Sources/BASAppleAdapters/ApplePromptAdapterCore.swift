import Foundation
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
