import Foundation
import BASAppleAdapters
import BASRuntimeCore

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
    let contextBudget: Int
    let outputCharacterBudget: Int
    let timeBudgetMs: Int
    let toolCallBudget: Int
    let retrievalItemBudget: Int
}

struct DecisionAdaptiveTaskStrategy: Equatable, Sendable {
    let kind: DecisionIntelligenceTraceKind
    let entropy: DecisionTaskEntropyClass
    let runtimeGear: DecisionRuntimeGear
    let preferredProvider: DecisionModelProviderPreference
    let runtimeBudget: DecisionRuntimeBudget
    let retrievalMode: DecisionRetrievalMode
    let thinkingMode: DecisionThinkingMode
    let outputMode: DecisionOutputMode
    let tone: DecisionToneProfile
    let actionSpace: [String]
    let responseLanguage: DecisionAdaptiveResponseLanguage
    let allowsModelInvocation: Bool

    var contextBudget: Int { runtimeBudget.contextBudget }
    var outputCharacterBudget: Int { runtimeBudget.outputCharacterBudget }
    var timeBudgetMs: Int { runtimeBudget.timeBudgetMs }
    var toolCallBudget: Int { runtimeBudget.toolCallBudget }
    var retrievalItemBudget: Int { runtimeBudget.retrievalItemBudget }

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
        self.kind = kind
        self.entropy = entropy
        self.runtimeGear = runtimeGear
        self.preferredProvider = preferredProvider
        self.runtimeBudget = DecisionRuntimeBudget(
            contextBudget: contextBudget,
            outputCharacterBudget: outputCharacterBudget ??
                Self.defaultOutputCharacterBudget(
                    for: kind,
                    gear: runtimeGear,
                    allowsModelInvocation: allowsModelInvocation,
                    outputMode: outputMode
                ),
            timeBudgetMs: timeBudgetMs ??
                Self.defaultTimeBudgetMs(
                    for: kind,
                    gear: runtimeGear,
                    allowsModelInvocation: allowsModelInvocation,
                    thinkingMode: thinkingMode
                ),
            toolCallBudget: toolCallBudget ??
                Self.defaultToolCallBudget(
                    for: kind,
                    allowsModelInvocation: allowsModelInvocation
                ),
            retrievalItemBudget: retrievalItemBudget ??
                Self.defaultRetrievalItemBudget(
                    for: kind,
                    retrievalMode: retrievalMode
                )
        )
        self.retrievalMode = retrievalMode
        self.thinkingMode = thinkingMode
        self.outputMode = outputMode
        self.tone = tone
        self.actionSpace = actionSpace
        self.responseLanguage = responseLanguage
        self.allowsModelInvocation = allowsModelInvocation
    }

    private static func defaultOutputCharacterBudget(
        for kind: DecisionIntelligenceTraceKind,
        gear: DecisionRuntimeGear,
        allowsModelInvocation: Bool,
        outputMode: DecisionOutputMode
    ) -> Int {
        guard allowsModelInvocation else {
            switch kind {
            case .quick, .reminder:
                return 180
            case .balance:
                return 260
            case .mirror:
                return 320
            }
        }

        let base: Int = switch (gear, kind) {
        case (.low, .quick):
            180
        case (.low, .balance):
            260
        case (.low, .mirror):
            320
        case (.low, .reminder):
            140
        case (.balanced, .quick):
            220
        case (.balanced, .balance):
            340
        case (.balanced, .mirror):
            440
        case (.balanced, .reminder):
            160
        case (.high, .quick):
            260
        case (.high, .balance):
            420
        case (.high, .mirror):
            560
        case (.high, .reminder):
            180
        }

        let schemaPenalty: Int = switch outputMode {
        case .jsonShort, .deterministicTemplate:
            20
        case .guidedShort:
            0
        case .structuredBoard:
            10
        case .reflectiveStructured:
            0
        }

        return max(120, base - schemaPenalty)
    }

    private static func defaultTimeBudgetMs(
        for kind: DecisionIntelligenceTraceKind,
        gear: DecisionRuntimeGear,
        allowsModelInvocation: Bool,
        thinkingMode: DecisionThinkingMode
    ) -> Int {
        guard allowsModelInvocation else {
            switch kind {
            case .quick, .reminder:
                return 350
            case .balance:
                return 500
            case .mirror:
                return 650
            }
        }

        let base: Int = switch (gear, kind) {
        case (.low, .quick):
            500
        case (.low, .balance):
            700
        case (.low, .mirror):
            900
        case (.low, .reminder):
            350
        case (.balanced, .quick):
            700
        case (.balanced, .balance):
            1000
        case (.balanced, .mirror):
            1300
        case (.balanced, .reminder):
            450
        case (.high, .quick):
            900
        case (.high, .balance):
            1400
        case (.high, .mirror):
            1800
        case (.high, .reminder):
            550
        }

        return thinkingMode == .gated ? base + 250 : base
    }

    private static func defaultToolCallBudget(
        for kind: DecisionIntelligenceTraceKind,
        allowsModelInvocation: Bool
    ) -> Int {
        guard allowsModelInvocation else { return 0 }
        return switch kind {
        case .quick:
            1
        case .balance:
            2
        case .mirror:
            2
        case .reminder:
            1
        }
    }

    private static func defaultRetrievalItemBudget(
        for kind: DecisionIntelligenceTraceKind,
        retrievalMode: DecisionRetrievalMode
    ) -> Int {
        switch retrievalMode {
        case .off:
            return 0
        case .filtered:
            return kind == .reminder ? 2 : 3
        case .adaptive:
            return kind == .mirror ? 5 : 4
        }
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
                    retrievalTags: brainState?.retrievalTags ?? []
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
        let runtimeGear = runtimeGear(for: tier)
        let languageMode = DecisionLanguageMode.detect(preferredLanguages: preferredLanguages)
        let deviceProfile = substrateDeviceProfile(for: device)
        let substrateMatrix = BASAdaptiveRuntimeMatrixResolver.resolve(
            request: BASAdaptiveRuntimeMatrixRequest(
                runtimeGear: runtimeGear.basRuntimeGear,
                environmentClass: BASAdaptiveRuntimeMatrixResolver.environmentClass(for: deviceProfile),
                deviceClass: BASAdaptiveRuntimeMatrixResolver.deviceClass(for: deviceProfile),
                languageMode: languageMode.basLanguageMode,
                allowFallbacks: allowFallbacks,
                allowsModelInvocationByKind: Dictionary(
                    uniqueKeysWithValues: DecisionIntelligenceTraceKind.allCases.map { kind in
                        (
                            kind.basAdaptiveTraceKind,
                            providerPreference(
                                for: kind,
                                tier: tier,
                                preference: preference
                            ) != .template
                        )
                    }
                )
            )
        )

        let strategies = Dictionary(
            uniqueKeysWithValues: DecisionIntelligenceTraceKind.allCases.map { kind in
                let preferredProvider = providerPreference(
                    for: kind,
                    tier: tier,
                    preference: preference
                )
                return (
                    kind,
                    DecisionAdaptiveTaskStrategy(
                        substrate: substrateMatrix.strategy(for: kind.basAdaptiveTraceKind),
                        preferredProvider: preferredProvider
                    )
                )
            }
        )

        return DecisionAdaptiveRuntimeMatrix(
            runtimeGear: DecisionRuntimeGear(substrateMatrix.runtimeGear),
            environmentClass: DecisionEnvironmentClass(substrateMatrix.environmentClass),
            deviceClass: DecisionDevicePerformanceClass(substrateMatrix.deviceClass),
            languageMode: DecisionLanguageMode(substrateMatrix.languageMode),
            strategiesByKind: strategies
        )
    }

    private static func substrateDeviceProfile(
        for device: DeviceCapabilitySnapshot
    ) -> BASDeviceProfile {
        BASDeviceProfile(
            modelName: device.isSimulator ? "simulator" : "iphone-\(device.physicalMemoryGB)gb",
            memoryMB: device.physicalMemoryGB * 1024,
            batteryLevel: device.isLowPowerModeEnabled ? 0.18 : 1.0,
            lowPowerMode: device.isLowPowerModeEnabled,
            thermalState: device.isLowPowerModeEnabled ? "low_power" : "nominal"
        )
    }

    private static func runtimeGear(for tier: DecisionIntelligenceExecutionTier) -> DecisionRuntimeGear {
        switch tier {
        case .off, .simulator, .conservativeDeterministic:
            .low
        case .balancedGemma, .systemManaged:
            .balanced
        case .testingOverride, .fullGemma:
            .high
        }
    }

    private static func providerPreference(
        for kind: DecisionIntelligenceTraceKind,
        tier: DecisionIntelligenceExecutionTier,
        preference: DecisionModelProviderPreference
    ) -> DecisionModelProviderPreference {
        switch tier {
        case .off, .simulator, .conservativeDeterministic:
            return .template
        case .balancedGemma:
            return kind == .quick ? .template : preference
        case .testingOverride, .fullGemma, .systemManaged:
            return preference
        }
    }
}

private extension DecisionAdaptiveTaskStrategy {
    var basAdaptiveTaskStrategy: BASAdaptiveTaskStrategy {
        BASAdaptiveTaskStrategy(
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
    }

    init(
        substrate strategy: BASAdaptiveTaskStrategy,
        preferredProvider: DecisionModelProviderPreference
    ) {
        self.init(
            kind: DecisionIntelligenceTraceKind(strategy.kind),
            entropy: DecisionTaskEntropyClass(strategy.entropy),
            runtimeGear: DecisionRuntimeGear(strategy.runtimeGear),
            preferredProvider: preferredProvider,
            contextBudget: strategy.contextBudget,
            outputCharacterBudget: strategy.outputCharacterBudget,
            timeBudgetMs: strategy.timeBudgetMs,
            toolCallBudget: strategy.toolCallBudget,
            retrievalItemBudget: strategy.retrievalItemBudget,
            retrievalMode: DecisionRetrievalMode(strategy.retrievalMode),
            thinkingMode: DecisionThinkingMode(strategy.thinkingMode),
            outputMode: DecisionOutputMode(strategy.outputMode),
            tone: DecisionToneProfile(strategy.tone),
            actionSpace: strategy.actionSpace,
            responseLanguage: DecisionAdaptiveResponseLanguage(strategy.responseLanguage),
            allowsModelInvocation: strategy.allowsModelInvocation
        )
    }
}

private extension DecisionIntelligenceTraceKind {
    var basAdaptiveTraceKind: BASAdaptiveTraceKind {
        switch self {
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

    init(_ kind: BASAdaptiveTraceKind) {
        switch kind {
        case .quick:
            self = .quick
        case .balance:
            self = .balance
        case .mirror:
            self = .mirror
        case .reminder:
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
