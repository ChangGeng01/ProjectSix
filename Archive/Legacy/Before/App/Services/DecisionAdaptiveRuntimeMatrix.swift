import Foundation
import BASHostKit

enum DecisionRuntimeGear: String, Equatable, Sendable {
    case low
    case balanced
    case high
}

enum DecisionEnvironmentClass: String, Equatable, Sendable {
    case simulator
    case lowPower
    case memoryConstrained
    case normal
}

enum DecisionDevicePerformanceClass: String, Equatable, Sendable {
    case simulator
    case memoryConstrainedPhone
    case balancedPhone
    case fullPhone
}

enum DecisionLanguageMode: String, Equatable, Sendable {
    case english
    case chinese
    case mixed
    case unknown

    static func detect(preferredLanguages: [String]) -> DecisionLanguageMode {
        DecisionLanguageMode(BASLanguageMode.detect(preferredLanguages: preferredLanguages))
    }

    static func detect(
        preferredLanguages: [String],
        sampleTexts: [String]
    ) -> DecisionLanguageMode {
        DecisionLanguageMode(
            BASLanguageMode.detect(
                preferredLanguages: preferredLanguages,
                sampleTexts: sampleTexts
            )
        )
    }

    static func detect(sampleTexts: [String]) -> DecisionLanguageMode {
        DecisionLanguageMode(BASLanguageMode.detect(sampleTexts: sampleTexts))
    }

    var retrievalTags: [String] {
        basLanguageMode.retrievalTags
    }
}

enum DecisionAdaptiveResponseLanguage: String, Equatable, Sendable {
    case english
    case chinese
    case mixed
}

enum DecisionTaskEntropyClass: String, Equatable, Sendable {
    case low
    case medium
    case high
}

enum DecisionRetrievalMode: String, Equatable, Sendable {
    case off
    case filtered
    case adaptive
}

enum DecisionThinkingMode: String, Equatable, Sendable {
    case off
    case gated
}

enum DecisionOutputMode: String, Equatable, Sendable {
    case deterministicTemplate
    case guidedShort
    case structuredBoard
    case reflectiveStructured
    case jsonShort
}

enum DecisionToneProfile: String, Equatable, Sendable {
    case neutral
    case briefWarm
    case groundedDirect
    case reflectiveClear
}

struct DecisionRuntimeBudget: Equatable, Sendable {
    let substrate: BASAdaptiveRuntimeBudget

    let contextBudget: Int
    let outputCharacterBudget: Int
    let timeBudgetMs: Int
    let toolCallBudget: Int
    let retrievalItemBudget: Int

    init(
        contextBudget: Int,
        outputCharacterBudget: Int,
        timeBudgetMs: Int,
        toolCallBudget: Int,
        retrievalItemBudget: Int
    ) {
        let substrate = BASAdaptiveRuntimeBudget(
            contextBudget: contextBudget,
            outputCharacterBudget: outputCharacterBudget,
            timeBudgetMs: timeBudgetMs,
            toolCallBudget: toolCallBudget,
            retrievalItemBudget: retrievalItemBudget
        )
        self.init(substrate: substrate)
    }

    init(substrate: BASAdaptiveRuntimeBudget) {
        self.substrate = substrate
        self.contextBudget = substrate.contextBudget
        self.outputCharacterBudget = substrate.outputCharacterBudget
        self.timeBudgetMs = substrate.timeBudgetMs
        self.toolCallBudget = substrate.toolCallBudget
        self.retrievalItemBudget = substrate.retrievalItemBudget
    }
}

struct DecisionAdaptiveTaskStrategy: Equatable, Sendable {
    let substrate: BASAdaptiveTaskStrategy
    let preferredProvider: DecisionModelProviderPreference

    var kind: DecisionIntelligenceTraceKind { DecisionIntelligenceTraceKind(substrate.kind) }
    var entropy: DecisionTaskEntropyClass { DecisionTaskEntropyClass(substrate.entropy) }
    var runtimeGear: DecisionRuntimeGear { DecisionRuntimeGear(substrate.runtimeGear) }
    var runtimeBudget: DecisionRuntimeBudget { DecisionRuntimeBudget(substrate: substrate.runtimeBudget) }
    var retrievalMode: DecisionRetrievalMode { DecisionRetrievalMode(substrate.retrievalMode) }
    var thinkingMode: DecisionThinkingMode { DecisionThinkingMode(substrate.thinkingMode) }
    var outputMode: DecisionOutputMode { DecisionOutputMode(substrate.outputMode) }
    var tone: DecisionToneProfile { DecisionToneProfile(substrate.tone) }
    var actionSpace: [String] { substrate.actionSpace }
    var responseLanguage: DecisionAdaptiveResponseLanguage {
        DecisionAdaptiveResponseLanguage(substrate.responseLanguage)
    }
    var allowsModelInvocation: Bool { substrate.allowsModelInvocation }
    var contextBudget: Int { substrate.contextBudget }
    var outputCharacterBudget: Int { substrate.outputCharacterBudget }
    var timeBudgetMs: Int { substrate.timeBudgetMs }
    var toolCallBudget: Int { substrate.toolCallBudget }
    var retrievalItemBudget: Int { substrate.retrievalItemBudget }

    init(
        kind: DecisionIntelligenceTraceKind,
        entropy: DecisionTaskEntropyClass,
        runtimeGear: DecisionRuntimeGear = .balanced,
        preferredProvider: DecisionModelProviderPreference,
        contextBudget: Int,
        outputCharacterBudget: Int? = nil,
        timeBudgetMs: Int? = nil,
        toolCallBudget: Int? = nil,
        retrievalItemBudget: Int? = nil,
        retrievalMode: DecisionRetrievalMode,
        thinkingMode: DecisionThinkingMode,
        outputMode: DecisionOutputMode,
        tone: DecisionToneProfile,
        actionSpace: [String],
        responseLanguage: DecisionAdaptiveResponseLanguage = .english,
        allowsModelInvocation: Bool
    ) {
        self.substrate = BASAdaptiveTaskStrategy(
            kind: kind.basAdaptiveTraceKind,
            entropy: entropy.basTaskEntropyClass,
            runtimeGear: runtimeGear.basRuntimeGear,
            contextBudget: contextBudget,
            outputCharacterBudget: outputCharacterBudget,
            timeBudgetMs: timeBudgetMs,
            toolCallBudget: toolCallBudget,
            retrievalItemBudget: retrievalItemBudget,
            retrievalMode: retrievalMode.basRetrievalMode,
            thinkingMode: thinkingMode.basThinkingMode,
            outputMode: outputMode.basOutputMode,
            tone: tone.basToneProfile,
            actionSpace: actionSpace,
            responseLanguage: responseLanguage.basAdaptiveResponseLanguage,
            allowsModelInvocation: allowsModelInvocation
        )
        self.preferredProvider = preferredProvider
    }

    init(
        substrate strategy: BASAdaptiveTaskStrategy,
        preferredProvider: DecisionModelProviderPreference
    ) {
        self.substrate = strategy
        self.preferredProvider = preferredProvider
    }
}

extension DecisionAdaptiveTaskStrategy {
    func adapting(
        contextState: DecisionContextPreparedState? = nil,
        neuralState: DecisionNeuralState? = nil,
        brainState: DecisionBrainState? = nil
    ) -> DecisionAdaptiveTaskStrategy {
        DecisionAdaptiveTaskStrategy(
            substrate: BASAppleAdaptiveRuntimeAdapter.adapt(
                strategy: basAdaptiveTaskStrategy,
                with: BASAppleAdaptiveRuntimeInput(
                    briefLanguageWeight: brainState?.reactionWeights.briefLanguage ?? 0,
                    lowCognitiveLoadWeight: brainState?.reactionWeights.lowCognitiveLoad ?? 0,
                    fatigueStrength: neuralState?.strength(for: .fatigue) ?? 0,
                    emotionLoadStrength: neuralState?.strength(for: .emotionLoad) ?? 0,
                    sessionBiases: brainState?.sessionBiases ?? [],
                    interruptiveActionBias: brainState?.reactionWeights.interruptiveActionBias ?? 0,
                    urgencyStrength: neuralState?.strength(for: .urgency) ?? 0,
                    boundaryNamingBias: brainState?.reactionWeights.boundaryNamingBias ?? 0,
                    boundaryRiskStrength: neuralState?.strength(for: .boundaryRisk) ?? 0,
                    tradeoffClarityBias: brainState?.reactionWeights.tradeoffClarityBias ?? 0,
                    rebuiltSession: contextState?.rebuiltSession == true,
                    staleFieldCount: contextState?.staleFieldCount ?? 0,
                    screenedOutMemoryCount: brainState?.memoryGovernance.screenedOutMemoryCount ?? 0,
                    lowTrustLoad: brainState?.verificationSnapshot.riskFlags.contains(.lowTrustLoad) == true,
                    retrievalInstability: brainState?.verificationSnapshot.riskFlags.contains(.retrievalInstability) == true,
                    retrievalTags: brainState?.retrievalTags ?? [],
                    externallyRefreshedCandidateCount: brainState?.memoryGovernance.externallyRefreshedCandidateCount ?? 0,
                    quarantinedObservationCount: brainState?.memoryGovernance.quarantinedObservationCount ?? 0,
                    evidenceCaveatedCandidateCount: brainState?.memoryGovernance.evidenceCaveatedCandidateCount ?? 0,
                    externalRefreshGuardTriggered: brainState?.verificationSnapshot.riskFlags.contains(.externalRefreshGuardTriggered) == true,
                    observationOnlyQuarantine: brainState?.verificationSnapshot.riskFlags.contains(.observationOnlyQuarantine) == true,
                    evidenceCaveatLoad: brainState?.verificationSnapshot.riskFlags.contains(.evidenceCaveatLoad) == true
                )
            ),
            preferredProvider: preferredProvider
        )
    }
}

private extension DecisionNeuralState {
    func strength(for signal: DecisionNeuralSignal) -> Double {
        dominantActivations.first(where: { $0.signal == signal })?.strength ?? 0
    }
}

struct DecisionAdaptiveRuntimeMatrix: Equatable, Sendable {
    let runtimeGear: DecisionRuntimeGear
    let environmentClass: DecisionEnvironmentClass
    let deviceClass: DecisionDevicePerformanceClass
    let languageMode: DecisionLanguageMode
    let strategiesByKind: [DecisionIntelligenceTraceKind: DecisionAdaptiveTaskStrategy]

    func strategy(for kind: DecisionIntelligenceTraceKind) -> DecisionAdaptiveTaskStrategy {
        strategiesByKind[kind] ?? DecisionAdaptiveTaskStrategy(
            kind: kind,
            entropy: .medium,
            runtimeGear: .low,
            preferredProvider: .template,
            contextBudget: 0,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: .deterministicTemplate,
            tone: .neutral,
            actionSpace: [],
            responseLanguage: .english,
            allowsModelInvocation: false
        )
    }
}

enum DecisionAdaptiveRuntimeMatrixResolver {
    static func resolve(
        tier: DecisionIntelligenceExecutionTier,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        device: DeviceCapabilitySnapshot,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> DecisionAdaptiveRuntimeMatrix {
        let compilation = BASAppleAdaptiveRuntimeAdapter.compileMatrix(
            request: BASAppleAdaptiveMatrixRequest(
                executionTierID: tier.rawValue,
                preferredProviderID: preference.rawValue,
                allowFallbacks: allowFallbacks,
                isSimulator: device.isSimulator,
                physicalMemoryGB: device.physicalMemoryGB,
                isLowPowerModeEnabled: device.isLowPowerModeEnabled,
                preferredLanguages: preferredLanguages
            )
        )

        let strategies = Dictionary(
            uniqueKeysWithValues: DecisionIntelligenceTraceKind.allCases.map { kind in
                let preferredProvider = resolvedPreferredProviderID(
                    for: kind,
                    in: compilation.preferredProviderIDByKind
                )
                    .flatMap(DecisionModelProviderPreference.init(rawValue:))
                    ?? .template
                return (
                    kind,
                    DecisionAdaptiveTaskStrategy(
                        substrate: compilation.matrix.strategy(for: kind.basAdaptiveTraceKind),
                        preferredProvider: preferredProvider
                    )
                )
            }
        )

        return DecisionAdaptiveRuntimeMatrix(
            runtimeGear: DecisionRuntimeGear(compilation.matrix.runtimeGear),
            environmentClass: DecisionEnvironmentClass(compilation.matrix.environmentClass),
            deviceClass: DecisionDevicePerformanceClass(compilation.matrix.deviceClass),
            languageMode: DecisionLanguageMode(compilation.matrix.languageMode),
            strategiesByKind: strategies
        )
    }

    private static func resolvedPreferredProviderID(
        for kind: DecisionIntelligenceTraceKind,
        in mapping: [String: String]
    ) -> String? {
        let substrateKind = kind.basAdaptiveTraceKind
        let lookupKeys = [
            substrateKind.identifier,
            kind.rawValue
        ]

        for key in lookupKeys where mapping[key] != nil {
            return mapping[key]
        }
        return nil
    }
}

private extension DecisionAdaptiveTaskStrategy {
    var basAdaptiveTaskStrategy: BASAdaptiveTaskStrategy {
        substrate
    }
}

private extension DecisionIntelligenceTraceKind {
    var basAdaptiveTraceKind: BASAdaptiveTraceKind {
        switch self {
        case .quick:
            .primary
        case .balance:
            .comparative
        case .mirror:
            .reflective
        case .reminder:
            .selection
        }
    }

    init(_ kind: BASAdaptiveTraceKind) {
        switch kind {
        case .primary:
            self = .quick
        case .comparative:
            self = .balance
        case .reflective:
            self = .mirror
        case .selection:
            self = .reminder
        }
    }
}

private extension DecisionRuntimeGear {
    var basRuntimeGear: BASRuntimeGear {
        switch self {
        case .low:
            .low
        case .balanced:
            .balanced
        case .high:
            .high
        }
    }

    init(_ gear: BASRuntimeGear) {
        switch gear {
        case .low:
            self = .low
        case .balanced:
            self = .balanced
        case .high:
            self = .high
        }
    }
}

private extension DecisionEnvironmentClass {
    init(_ environmentClass: BASEnvironmentClass) {
        switch environmentClass {
        case .simulator:
            self = .simulator
        case .lowPower:
            self = .lowPower
        case .memoryConstrained:
            self = .memoryConstrained
        case .normal:
            self = .normal
        }
    }
}

private extension DecisionDevicePerformanceClass {
    init(_ deviceClass: BASDevicePerformanceClass) {
        switch deviceClass {
        case .simulator:
            self = .simulator
        case .memoryConstrainedPhone:
            self = .memoryConstrainedPhone
        case .balancedPhone:
            self = .balancedPhone
        case .fullPhone:
            self = .fullPhone
        }
    }
}

private extension DecisionLanguageMode {
    var basLanguageMode: BASLanguageMode {
        switch self {
        case .english:
            .english
        case .chinese:
            .chinese
        case .mixed:
            .mixed
        case .unknown:
            .unknown
        }
    }

    init(_ languageMode: BASLanguageMode) {
        switch languageMode {
        case .english:
            self = .english
        case .chinese:
            self = .chinese
        case .mixed:
            self = .mixed
        case .unknown:
            self = .unknown
        }
    }
}

private extension DecisionAdaptiveResponseLanguage {
    var basAdaptiveResponseLanguage: BASAdaptiveResponseLanguage {
        switch self {
        case .english:
            .english
        case .chinese:
            .chinese
        case .mixed:
            .mixed
        }
    }

    init(_ responseLanguage: BASAdaptiveResponseLanguage) {
        switch responseLanguage {
        case .english:
            self = .english
        case .chinese:
            self = .chinese
        case .mixed:
            self = .mixed
        }
    }
}

private extension DecisionTaskEntropyClass {
    var basTaskEntropyClass: BASTaskEntropyClass {
        switch self {
        case .low:
            .low
        case .medium:
            .medium
        case .high:
            .high
        }
    }

    init(_ entropy: BASTaskEntropyClass) {
        switch entropy {
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .high:
            self = .high
        }
    }
}

private extension DecisionRetrievalMode {
    var basRetrievalMode: BASRetrievalMode {
        switch self {
        case .off:
            .off
        case .filtered:
            .filtered
        case .adaptive:
            .adaptive
        }
    }

    init(_ retrievalMode: BASRetrievalMode) {
        switch retrievalMode {
        case .off:
            self = .off
        case .filtered:
            self = .filtered
        case .adaptive:
            self = .adaptive
        }
    }
}

private extension DecisionThinkingMode {
    var basThinkingMode: BASThinkingMode {
        switch self {
        case .off:
            .off
        case .gated:
            .gated
        }
    }

    init(_ thinkingMode: BASThinkingMode) {
        switch thinkingMode {
        case .off:
            self = .off
        case .gated:
            self = .gated
        }
    }
}

private extension DecisionOutputMode {
    var basOutputMode: BASOutputMode {
        switch self {
        case .deterministicTemplate:
            .deterministicTemplate
        case .guidedShort:
            .guidedShort
        case .structuredBoard:
            .structuredBoard
        case .reflectiveStructured:
            .reflectiveStructured
        case .jsonShort:
            .jsonShort
        }
    }

    init(_ outputMode: BASOutputMode) {
        switch outputMode {
        case .deterministicTemplate:
            self = .deterministicTemplate
        case .guidedShort:
            self = .guidedShort
        case .structuredBoard:
            self = .structuredBoard
        case .reflectiveStructured:
            self = .reflectiveStructured
        case .jsonShort:
            self = .jsonShort
        }
    }
}

private extension DecisionToneProfile {
    var basToneProfile: BASToneProfile {
        switch self {
        case .neutral:
            .neutral
        case .briefWarm:
            .briefWarm
        case .groundedDirect:
            .groundedDirect
        case .reflectiveClear:
            .reflectiveClear
        }
    }

    init(_ tone: BASToneProfile) {
        switch tone {
        case .neutral:
            self = .neutral
        case .briefWarm:
            self = .briefWarm
        case .groundedDirect:
            self = .groundedDirect
        case .reflectiveClear:
            self = .reflectiveClear
        }
    }
}
