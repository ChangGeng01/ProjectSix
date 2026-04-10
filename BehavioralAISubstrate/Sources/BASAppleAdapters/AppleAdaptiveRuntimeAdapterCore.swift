import Foundation
import BASRuntimeCore

public struct BASAppleAdaptiveRuntimeInput: Codable, Equatable, Sendable {
    public var briefLanguageWeight: Double
    public var lowCognitiveLoadWeight: Double
    public var fatigueStrength: Double
    public var emotionLoadStrength: Double
    public var sessionBiases: [String]
    public var interruptiveActionBias: Double
    public var urgencyStrength: Double
    public var boundaryNamingBias: Double
    public var boundaryRiskStrength: Double
    public var tradeoffClarityBias: Double
    public var rebuiltSession: Bool
    public var staleFieldCount: Int
    public var screenedOutMemoryCount: Int
    public var lowTrustLoad: Bool
    public var retrievalInstability: Bool
    public var retrievalTags: [String]

    public init(
        briefLanguageWeight: Double,
        lowCognitiveLoadWeight: Double,
        fatigueStrength: Double,
        emotionLoadStrength: Double,
        sessionBiases: [String],
        interruptiveActionBias: Double,
        urgencyStrength: Double,
        boundaryNamingBias: Double,
        boundaryRiskStrength: Double,
        tradeoffClarityBias: Double,
        rebuiltSession: Bool,
        staleFieldCount: Int,
        screenedOutMemoryCount: Int,
        lowTrustLoad: Bool,
        retrievalInstability: Bool,
        retrievalTags: [String]
    ) {
        self.briefLanguageWeight = briefLanguageWeight
        self.lowCognitiveLoadWeight = lowCognitiveLoadWeight
        self.fatigueStrength = fatigueStrength
        self.emotionLoadStrength = emotionLoadStrength
        self.sessionBiases = sessionBiases
        self.interruptiveActionBias = interruptiveActionBias
        self.urgencyStrength = urgencyStrength
        self.boundaryNamingBias = boundaryNamingBias
        self.boundaryRiskStrength = boundaryRiskStrength
        self.tradeoffClarityBias = tradeoffClarityBias
        self.rebuiltSession = rebuiltSession
        self.staleFieldCount = staleFieldCount
        self.screenedOutMemoryCount = screenedOutMemoryCount
        self.lowTrustLoad = lowTrustLoad
        self.retrievalInstability = retrievalInstability
        self.retrievalTags = retrievalTags
    }
}

public enum BASAppleAdaptiveRuntimeAdapter {
    public static func compileSignals(
        from input: BASAppleAdaptiveRuntimeInput
    ) -> BASAdaptiveRuntimeSignals {
        BASAdaptiveRuntimeSignals(
            briefBias: max(
                input.briefLanguageWeight,
                input.lowCognitiveLoadWeight
            ),
            fatigueSignal: max(
                input.fatigueStrength,
                input.emotionLoadStrength
            ),
            hasBriefSessionBias: hasBriefSessionBias(input.sessionBiases),
            interruptiveBias: max(
                input.interruptiveActionBias,
                input.urgencyStrength,
                input.fatigueStrength
            ),
            boundaryBias: max(
                input.boundaryNamingBias,
                input.boundaryRiskStrength
            ),
            tradeoffBias: input.tradeoffClarityBias,
            rebuiltSession: input.rebuiltSession,
            staleFieldCount: input.staleFieldCount,
            screenedOutMemoryCount: input.screenedOutMemoryCount,
            lowTrustLoad: input.lowTrustLoad,
            retrievalInstability: input.retrievalInstability,
            retrievalTags: input.retrievalTags
        )
    }

    public static func adapt(
        strategy: BASAdaptiveTaskStrategy,
        with input: BASAppleAdaptiveRuntimeInput
    ) -> BASAdaptiveTaskStrategy {
        strategy.adapting(signals: compileSignals(from: input))
    }

    private static func hasBriefSessionBias(_ biases: [String]) -> Bool {
        biases.contains { bias in
            let normalized = bias.lowercased()
            return normalized.contains("short") ||
                normalized.contains("brief") ||
                normalized.contains("concrete") ||
                normalized.contains("avoid heavy analysis")
        }
    }
}
