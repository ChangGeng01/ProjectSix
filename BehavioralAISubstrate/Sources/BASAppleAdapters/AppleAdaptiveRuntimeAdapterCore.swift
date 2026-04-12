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

public struct BASAppleAdaptiveMatrixRequest: Codable, Equatable, Sendable {
    public var executionTierID: String
    public var preferredProviderID: String
    public var allowFallbacks: Bool
    public var isSimulator: Bool
    public var physicalMemoryGB: Int
    public var isLowPowerModeEnabled: Bool
    public var preferredLanguages: [String]

    public init(
        executionTierID: String,
        preferredProviderID: String,
        allowFallbacks: Bool,
        isSimulator: Bool,
        physicalMemoryGB: Int,
        isLowPowerModeEnabled: Bool,
        preferredLanguages: [String]
    ) {
        self.executionTierID = executionTierID
        self.preferredProviderID = preferredProviderID
        self.allowFallbacks = allowFallbacks
        self.isSimulator = isSimulator
        self.physicalMemoryGB = physicalMemoryGB
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.preferredLanguages = preferredLanguages
    }
}

public struct BASAppleAdaptiveMatrixCompilation: Codable, Equatable, Sendable {
    public var matrix: BASAdaptiveRuntimeMatrix
    public var preferredProviderIDByKind: [String: String]

    public init(
        matrix: BASAdaptiveRuntimeMatrix,
        preferredProviderIDByKind: [String: String]
    ) {
        self.matrix = matrix
        self.preferredProviderIDByKind = preferredProviderIDByKind
    }
}

public enum BASAppleAdaptiveRuntimeAdapter {
    public static func compileMatrix(
        request: BASAppleAdaptiveMatrixRequest
    ) -> BASAppleAdaptiveMatrixCompilation {
        let runtimeGear = runtimeGear(for: request.executionTierID)
        let languageMode = BASLanguageMode.detect(preferredLanguages: request.preferredLanguages)
        let deviceProfile = substrateDeviceProfile(for: request)
        let matrix = BASAdaptiveRuntimeMatrixResolver.resolve(
            request: BASAdaptiveRuntimeMatrixRequest(
                runtimeGear: runtimeGear,
                environmentClass: BASAdaptiveRuntimeMatrixResolver.environmentClass(for: deviceProfile),
                deviceClass: BASAdaptiveRuntimeMatrixResolver.deviceClass(for: deviceProfile),
                languageMode: languageMode,
                allowFallbacks: request.allowFallbacks,
                allowsModelInvocationByKind: Dictionary(
                    uniqueKeysWithValues: BASAdaptiveTraceKind.allCases.map { kind in
                        (
                            kind,
                            providerPreferenceID(
                                for: kind.rawValue,
                                executionTierID: request.executionTierID,
                                preferredProviderID: request.preferredProviderID
                            ) != BASReferenceProviderRuntime.templateProviderID
                        )
                    }
                )
            )
        )

        return BASAppleAdaptiveMatrixCompilation(
            matrix: matrix,
            preferredProviderIDByKind: Dictionary(
                uniqueKeysWithValues: BASAdaptiveTraceKind.allCases.map { kind in
                    (
                        kind.rawValue,
                        providerPreferenceID(
                            for: kind.rawValue,
                            executionTierID: request.executionTierID,
                            preferredProviderID: request.preferredProviderID
                        )
                    )
                }
            )
        )
    }

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

    private static func substrateDeviceProfile(
        for request: BASAppleAdaptiveMatrixRequest
    ) -> BASDeviceProfile {
        BASDeviceProfile(
            modelName: request.isSimulator ? "simulator" : "iphone-\(request.physicalMemoryGB)gb",
            memoryMB: request.physicalMemoryGB * 1024,
            batteryLevel: request.isLowPowerModeEnabled ? 0.18 : 1.0,
            lowPowerMode: request.isLowPowerModeEnabled,
            thermalState: request.isLowPowerModeEnabled ? "low_power" : "nominal"
        )
    }

    private static func runtimeGear(for executionTierID: String) -> BASRuntimeGear {
        switch executionTierID {
        case "testingOverride", "fullGemma":
            .high
        case "balancedGemma", "systemManaged":
            .balanced
        case "off", "simulator", "conservativeDeterministic":
            .low
        default:
            .low
        }
    }

    private static func providerPreferenceID(
        for kindID: String,
        executionTierID: String,
        preferredProviderID: String
    ) -> String {
        switch executionTierID {
        case "off", "simulator", "conservativeDeterministic":
            BASReferenceProviderRuntime.templateProviderID
        case "balancedGemma":
            BASAdaptiveTraceKind(identifier: kindID) == .primary
                ? BASReferenceProviderRuntime.templateProviderID
                : preferredProviderID
        case "testingOverride", "fullGemma", "systemManaged":
            preferredProviderID
        default:
            preferredProviderID
        }
    }
}
