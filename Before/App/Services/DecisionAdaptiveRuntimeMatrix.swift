import Foundation

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
        detect(preferredLanguages: preferredLanguages, sampleTexts: [])
    }

    static func detect(
        preferredLanguages: [String],
        sampleTexts: [String]
    ) -> DecisionLanguageMode {
        let sampled = detect(sampleTexts: sampleTexts)
        guard sampled == .unknown else { return sampled }

        let codes = preferredLanguages
            .prefix(3)
            .compactMap { Locale(identifier: $0).language.languageCode?.identifier }

        guard let first = codes.first else { return .unknown }
        let normalized = Set(codes.map { code in
            if code.hasPrefix("zh") { return "zh" }
            if code.hasPrefix("en") { return "en" }
            return code
        })

        if normalized.count > 1 {
            return .mixed
        }

        switch first {
        case let code where code.hasPrefix("zh"):
            return .chinese
        case let code where code.hasPrefix("en"):
            return .english
        default:
            return .unknown
        }
    }

    static func detect(sampleTexts: [String]) -> DecisionLanguageMode {
        var sawHan = false
        var sawLatin = false
        var sawOtherLetter = false

        for scalar in sampleTexts.joined(separator: " ").unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { continue }
            if scalar.properties.isIdeographic {
                sawHan = true
            } else if scalar.value >= 0x41 && scalar.value <= 0x5A ||
                scalar.value >= 0x61 && scalar.value <= 0x7A {
                sawLatin = true
            } else {
                sawOtherLetter = true
            }
        }

        switch (sawHan, sawLatin, sawOtherLetter) {
        case (true, true, _), (true, false, true), (false, true, true):
            return .mixed
        case (true, false, false):
            return .chinese
        case (false, true, false):
            return .english
        default:
            return .unknown
        }
    }

    var retrievalTags: [String] {
        switch self {
        case .english:
            ["lang:english", "script:latin"]
        case .chinese:
            ["lang:chinese", "script:han"]
        case .mixed:
            ["lang:mixed", "script:mixed"]
        case .unknown:
            []
        }
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
        var runtimeGear = runtimeGear
        var contextBudget = contextBudget
        var outputCharacterBudget = outputCharacterBudget
        var timeBudgetMs = timeBudgetMs
        var toolCallBudget = toolCallBudget
        var retrievalItemBudget = retrievalItemBudget
        var retrievalMode = retrievalMode
        var thinkingMode = thinkingMode
        var tone = tone
        var actionSpace = actionSpace
        var responseLanguage = responseLanguage

        let minimumBudget: Int = switch kind {
        case .quick:
            160
        case .balance:
            220
        case .mirror:
            260
        case .reminder:
            140
        }

        let briefBias = max(
            brainState?.reactionWeights.briefLanguage ?? 0,
            brainState?.reactionWeights.lowCognitiveLoad ?? 0
        )
        let fatigueSignal = max(
            neuralState?.strength(for: .fatigue) ?? 0,
            neuralState?.strength(for: .emotionLoad) ?? 0
        )
        let hasBriefSessionBias = brainState?.sessionBiases.contains(where: { bias in
            let normalized = bias.lowercased()
            return normalized.contains("short") ||
                normalized.contains("brief") ||
                normalized.contains("concrete") ||
                normalized.contains("avoid heavy analysis")
        }) == true

        if briefBias >= 0.78 || fatigueSignal >= 0.68 || hasBriefSessionBias {
            runtimeGear = .low
            let reduction: Int = switch kind {
            case .quick:
                40
            case .balance:
                60
            case .mirror:
                80
            case .reminder:
                20
            }
            contextBudget = max(minimumBudget, contextBudget - reduction)
            outputCharacterBudget = max(120, outputCharacterBudget - max(40, reduction))
            timeBudgetMs = max(300, timeBudgetMs - max(120, reduction * 4))
            toolCallBudget = max(0, toolCallBudget - 1)
            retrievalItemBudget = max(0, retrievalItemBudget - 1)
            tone = .briefWarm
            thinkingMode = .off
            if !actionSpace.contains("stay_brief") {
                actionSpace.append("stay_brief")
            }
        }

        let interruptiveBias = max(
            brainState?.reactionWeights.interruptiveActionBias ?? 0,
            neuralState?.strength(for: .urgency) ?? 0,
            neuralState?.strength(for: .fatigue) ?? 0
        )
        if kind == .quick, interruptiveBias >= 0.82 {
            runtimeGear = .low
            contextBudget = max(minimumBudget, contextBudget - 20)
            outputCharacterBudget = max(120, outputCharacterBudget - 40)
            timeBudgetMs = max(300, timeBudgetMs - 120)
            thinkingMode = .off
            tone = .briefWarm
            if !actionSpace.contains("save_state") {
                actionSpace.append("save_state")
            }
        }

        let boundaryBias = max(
            brainState?.reactionWeights.boundaryNamingBias ?? 0,
            neuralState?.strength(for: .boundaryRisk) ?? 0
        )
        if kind == .mirror, boundaryBias >= 0.78, !actionSpace.contains("name_boundary") {
            actionSpace.append("name_boundary")
        }
        if kind == .mirror,
           runtimeGear != .low,
           boundaryBias >= 0.88,
           fatigueSignal < 0.55,
           briefBias < 0.72 {
            runtimeGear = .high
            contextBudget += 40
            outputCharacterBudget += 60
            timeBudgetMs += 220
            retrievalItemBudget += 1
            if thinkingMode == .off {
                thinkingMode = .gated
            }
        }

        let tradeoffBias = brainState?.reactionWeights.tradeoffClarityBias ?? 0
        if kind == .balance, tradeoffBias >= 0.78, !actionSpace.contains("surface_priority") {
            actionSpace.append("surface_priority")
        }
        if kind == .balance,
           runtimeGear == .balanced,
           tradeoffBias >= 0.86,
           fatigueSignal < 0.55,
           briefBias < 0.72 {
            runtimeGear = .high
            contextBudget += 30
            outputCharacterBudget += 50
            timeBudgetMs += 180
            retrievalItemBudget += 1
            if thinkingMode == .off {
                thinkingMode = .gated
            }
        }

        let shouldGuardRetrieval =
            (contextState?.rebuiltSession == true) ||
            ((contextState?.staleFieldCount ?? 0) > 0) ||
            ((brainState?.memoryGovernance.screenedOutMemoryCount ?? 0) >= 3) ||
            (brainState?.verificationSnapshot.riskFlags.contains(.lowTrustLoad) == true) ||
            (brainState?.verificationSnapshot.riskFlags.contains(.retrievalInstability) == true)

        if shouldGuardRetrieval {
            switch retrievalMode {
            case .adaptive:
                retrievalMode = .filtered
                retrievalItemBudget = min(retrievalItemBudget, kind == .mirror ? 3 : 2)
            case .filtered where kind == .reminder:
                retrievalMode = .off
                retrievalItemBudget = 0
            case .off, .filtered:
                break
            }
        }

        if let inferredResponseLanguage = inferredResponseLanguage(
            from: brainState?.retrievalTags ?? [],
            fallback: responseLanguage
        ) {
            responseLanguage = inferredResponseLanguage
        }

        return DecisionAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy,
            runtimeGear: runtimeGear,
            preferredProvider: preferredProvider,
            contextBudget: contextBudget,
            outputCharacterBudget: outputCharacterBudget,
            timeBudgetMs: timeBudgetMs,
            toolCallBudget: toolCallBudget,
            retrievalItemBudget: retrievalItemBudget,
            retrievalMode: retrievalMode,
            thinkingMode: thinkingMode,
            outputMode: outputMode,
            tone: tone,
            actionSpace: actionSpace,
            responseLanguage: responseLanguage,
            allowsModelInvocation: allowsModelInvocation
        )
    }

    private func inferredResponseLanguage(
        from retrievalTags: [String],
        fallback: DecisionAdaptiveResponseLanguage
    ) -> DecisionAdaptiveResponseLanguage? {
        if retrievalTags.contains("lang:chinese") {
            return .chinese
        }
        if retrievalTags.contains("lang:mixed") || retrievalTags.contains("script:mixed") {
            return .mixed
        }
        if retrievalTags.contains("lang:english") {
            return .english
        }
        return fallback
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
        let environmentClass = environmentClass(for: device)
        let deviceClass = deviceClass(for: device)
        let languageMode = DecisionLanguageMode.detect(preferredLanguages: preferredLanguages)

        let strategies = Dictionary(
            uniqueKeysWithValues: DecisionIntelligenceTraceKind.allCases.map { kind in
                (
                    kind,
                    strategy(
                        for: kind,
                        tier: tier,
                        preference: preference,
                        allowFallbacks: allowFallbacks,
                        runtimeGear: runtimeGear,
                        environmentClass: environmentClass,
                        deviceClass: deviceClass,
                        languageMode: languageMode
                    )
                )
            }
        )

        return DecisionAdaptiveRuntimeMatrix(
            runtimeGear: runtimeGear,
            environmentClass: environmentClass,
            deviceClass: deviceClass,
            languageMode: languageMode,
            strategiesByKind: strategies
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

    private static func environmentClass(for device: DeviceCapabilitySnapshot) -> DecisionEnvironmentClass {
        if device.isSimulator {
            return .simulator
        }
        if device.isLowPowerModeEnabled {
            return .lowPower
        }
        if device.physicalMemoryGB < 7 {
            return .memoryConstrained
        }
        return .normal
    }

    private static func deviceClass(for device: DeviceCapabilitySnapshot) -> DecisionDevicePerformanceClass {
        if device.isSimulator {
            return .simulator
        }
        if device.physicalMemoryGB < 7 {
            return .memoryConstrainedPhone
        }
        if device.physicalMemoryGB < 8 {
            return .balancedPhone
        }
        return .fullPhone
    }

    private static func strategy(
        for kind: DecisionIntelligenceTraceKind,
        tier: DecisionIntelligenceExecutionTier,
        preference: DecisionModelProviderPreference,
        allowFallbacks: Bool,
        runtimeGear: DecisionRuntimeGear,
        environmentClass: DecisionEnvironmentClass,
        deviceClass: DecisionDevicePerformanceClass,
        languageMode: DecisionLanguageMode
    ) -> DecisionAdaptiveTaskStrategy {
        let preferredProvider = providerPreference(
            for: kind,
            tier: tier,
            preference: preference
        )
        let allowsModelInvocation = preferredProvider != .template
        let taskGear = taskGear(
            for: kind,
            runtimeGear: runtimeGear,
            allowsModelInvocation: allowsModelInvocation,
            environmentClass: environmentClass,
            deviceClass: deviceClass
        )

        return DecisionAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy(for: kind),
            runtimeGear: taskGear,
            preferredProvider: preferredProvider,
            contextBudget: contextBudget(
                for: kind,
                gear: taskGear,
                allowsModelInvocation: allowsModelInvocation,
                environmentClass: environmentClass,
                deviceClass: deviceClass,
                languageMode: languageMode
            ),
            outputCharacterBudget: outputCharacterBudget(
                for: kind,
                gear: taskGear,
                allowsModelInvocation: allowsModelInvocation,
                environmentClass: environmentClass,
                deviceClass: deviceClass
            ),
            timeBudgetMs: timeBudgetMs(
                for: kind,
                gear: taskGear,
                allowsModelInvocation: allowsModelInvocation,
                environmentClass: environmentClass,
                deviceClass: deviceClass
            ),
            toolCallBudget: toolCallBudget(
                for: kind,
                allowsModelInvocation: allowsModelInvocation,
                environmentClass: environmentClass
            ),
            retrievalItemBudget: retrievalItemBudget(
                for: kind,
                allowsModelInvocation: allowsModelInvocation,
                environmentClass: environmentClass
            ),
            retrievalMode: retrievalMode(
                for: kind,
                gear: taskGear,
                allowsModelInvocation: allowsModelInvocation,
                environmentClass: environmentClass,
                deviceClass: deviceClass,
                languageMode: languageMode
            ),
            thinkingMode: thinkingMode(
                for: kind,
                gear: taskGear,
                allowsModelInvocation: allowsModelInvocation,
                environmentClass: environmentClass,
                deviceClass: deviceClass,
                languageMode: languageMode
            ),
            outputMode: outputMode(
                for: kind,
                allowsModelInvocation: allowsModelInvocation
            ),
            tone: tone(
                for: kind,
                allowsModelInvocation: allowsModelInvocation,
                environmentClass: environmentClass,
                languageMode: languageMode
            ),
            actionSpace: actionSpace(
                for: kind,
                allowFallbacks: allowFallbacks,
                environmentClass: environmentClass,
                deviceClass: deviceClass
            ),
            responseLanguage: responseLanguage(for: languageMode),
            allowsModelInvocation: allowsModelInvocation
        )
    }

    private static func taskGear(
        for kind: DecisionIntelligenceTraceKind,
        runtimeGear: DecisionRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass,
        deviceClass: DecisionDevicePerformanceClass
    ) -> DecisionRuntimeGear {
        guard allowsModelInvocation else { return .low }

        let baseGear: DecisionRuntimeGear = switch kind {
        case .quick, .reminder:
            .low
        case .balance:
            runtimeGear == .low ? .low : .balanced
        case .mirror:
            switch runtimeGear {
            case .low:
                .low
            case .balanced:
                .balanced
            case .high:
                .high
            }
        }

        if environmentClass == .simulator || environmentClass == .lowPower {
            return .low
        }

        if deviceClass == .memoryConstrainedPhone {
            return baseGear == .high ? .balanced : baseGear
        }

        if deviceClass == .balancedPhone && baseGear == .high {
            return .balanced
        }

        return baseGear
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

    private static func entropy(for kind: DecisionIntelligenceTraceKind) -> DecisionTaskEntropyClass {
        switch kind {
        case .quick, .reminder:
            .low
        case .balance:
            .medium
        case .mirror:
            .high
        }
    }

    private static func contextBudget(
        for kind: DecisionIntelligenceTraceKind,
        gear: DecisionRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass,
        deviceClass: DecisionDevicePerformanceClass,
        languageMode: DecisionLanguageMode
    ) -> Int {
        let base: Int
        if !allowsModelInvocation {
            switch kind {
            case .quick, .reminder: base = 160
            case .balance: base = 220
            case .mirror: base = 240
            }
        } else {
            switch (gear, kind) {
            case (.low, .quick): base = 220
            case (.low, .balance): base = 280
            case (.low, .mirror): base = 320
            case (.low, .reminder): base = 160
            case (.balanced, .quick): base = 320
            case (.balanced, .balance): base = 440
            case (.balanced, .mirror): base = 520
            case (.balanced, .reminder): base = 200
            case (.high, .quick): base = 360
            case (.high, .balance): base = 520
            case (.high, .mirror): base = 620
            case (.high, .reminder): base = 240
            }
        }

        let environmentPenalty: Int = switch environmentClass {
        case .simulator: 90
        case .lowPower: 80
        case .memoryConstrained: 50
        case .normal: 0
        }
        let devicePenalty: Int = switch deviceClass {
        case .simulator: 30
        case .memoryConstrainedPhone: 40
        case .balancedPhone: 20
        case .fullPhone: 0
        }
        let languagePenalty: Int = switch languageMode {
        case .mixed: 20
        case .unknown: 10
        case .english, .chinese: 0
        }
        let minimumBudget: Int = switch kind {
        case .quick: 160
        case .balance: 220
        case .mirror: 260
        case .reminder: 140
        }

        return max(minimumBudget, base - environmentPenalty - devicePenalty - languagePenalty)
    }

    private static func outputCharacterBudget(
        for kind: DecisionIntelligenceTraceKind,
        gear: DecisionRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass,
        deviceClass: DecisionDevicePerformanceClass
    ) -> Int {
        let base = DecisionAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy(for: kind),
            runtimeGear: gear,
            preferredProvider: allowsModelInvocation ? .gemmaE4B : .template,
            contextBudget: 0,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: outputMode(for: kind, allowsModelInvocation: allowsModelInvocation),
            tone: .neutral,
            actionSpace: [],
            allowsModelInvocation: allowsModelInvocation
        ).outputCharacterBudget

        let environmentPenalty: Int = switch environmentClass {
        case .simulator: 30
        case .lowPower: 50
        case .memoryConstrained: 30
        case .normal: 0
        }
        let devicePenalty: Int = switch deviceClass {
        case .simulator: 10
        case .memoryConstrainedPhone: 30
        case .balancedPhone: 10
        case .fullPhone: 0
        }

        return max(120, base - environmentPenalty - devicePenalty)
    }

    private static func timeBudgetMs(
        for kind: DecisionIntelligenceTraceKind,
        gear: DecisionRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass,
        deviceClass: DecisionDevicePerformanceClass
    ) -> Int {
        let base = DecisionAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy(for: kind),
            runtimeGear: gear,
            preferredProvider: allowsModelInvocation ? .gemmaE4B : .template,
            contextBudget: 0,
            retrievalMode: .off,
            thinkingMode: .off,
            outputMode: outputMode(for: kind, allowsModelInvocation: allowsModelInvocation),
            tone: .neutral,
            actionSpace: [],
            allowsModelInvocation: allowsModelInvocation
        ).timeBudgetMs

        let environmentPenalty: Int = switch environmentClass {
        case .simulator: 120
        case .lowPower: 180
        case .memoryConstrained: 100
        case .normal: 0
        }
        let devicePenalty: Int = switch deviceClass {
        case .simulator: 60
        case .memoryConstrainedPhone: 120
        case .balancedPhone: 60
        case .fullPhone: 0
        }

        return max(300, base - environmentPenalty - devicePenalty)
    }

    private static func toolCallBudget(
        for kind: DecisionIntelligenceTraceKind,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass
    ) -> Int {
        guard allowsModelInvocation else { return 0 }
        let base: Int = switch kind {
        case .quick, .reminder:
            1
        case .balance, .mirror:
            2
        }
        return environmentClass == .normal ? base : max(0, base - 1)
    }

    private static func retrievalItemBudget(
        for kind: DecisionIntelligenceTraceKind,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass
    ) -> Int {
        guard allowsModelInvocation else { return 0 }
        let base: Int = switch kind {
        case .quick:
            0
        case .reminder:
            2
        case .balance:
            3
        case .mirror:
            5
        }

        return environmentClass == .normal ? base : max(0, base - 1)
    }

    private static func retrievalMode(
        for kind: DecisionIntelligenceTraceKind,
        gear: DecisionRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass,
        deviceClass: DecisionDevicePerformanceClass,
        languageMode: DecisionLanguageMode
    ) -> DecisionRetrievalMode {
        guard allowsModelInvocation else { return .off }
        var mode: DecisionRetrievalMode = switch kind {
        case .quick:
            .off
        case .reminder:
            .filtered
        case .balance:
            gear == .high ? .adaptive : .filtered
        case .mirror:
            .adaptive
        }

        if environmentClass == .simulator || environmentClass == .lowPower {
            if kind == .reminder {
                return .off
            }
            if mode == .adaptive {
                mode = .filtered
            }
        }

        if deviceClass == .memoryConstrainedPhone || deviceClass == .simulator {
            if mode == .adaptive {
                mode = .filtered
            }
        }

        if languageMode == .mixed || languageMode == .unknown {
            if mode == .adaptive {
                mode = .filtered
            }
        }

        return mode
    }

    private static func thinkingMode(
        for kind: DecisionIntelligenceTraceKind,
        gear: DecisionRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass,
        deviceClass: DecisionDevicePerformanceClass,
        languageMode: DecisionLanguageMode
    ) -> DecisionThinkingMode {
        guard allowsModelInvocation else { return .off }
        guard kind == .balance || kind == .mirror else { return .off }
        guard gear == .high,
              environmentClass == .normal,
              deviceClass == .fullPhone,
              languageMode != .mixed else {
            return .off
        }
        return .gated
    }

    private static func outputMode(
        for kind: DecisionIntelligenceTraceKind,
        allowsModelInvocation: Bool
    ) -> DecisionOutputMode {
        guard allowsModelInvocation else { return .deterministicTemplate }
        switch kind {
        case .quick:
            return DecisionOutputMode.guidedShort
        case .balance:
            return DecisionOutputMode.structuredBoard
        case .mirror:
            return DecisionOutputMode.reflectiveStructured
        case .reminder:
            return DecisionOutputMode.jsonShort
        }
    }

    private static func tone(
        for kind: DecisionIntelligenceTraceKind,
        allowsModelInvocation: Bool,
        environmentClass: DecisionEnvironmentClass,
        languageMode: DecisionLanguageMode
    ) -> DecisionToneProfile {
        guard allowsModelInvocation else { return .neutral }
        if environmentClass == .lowPower || environmentClass == .memoryConstrained {
            return .briefWarm
        }

        if languageMode == .mixed || languageMode == .unknown {
            switch kind {
            case .quick, .reminder:
                return .briefWarm
            case .balance, .mirror:
                return .groundedDirect
            }
        }

        switch kind {
        case .quick, .reminder:
            return DecisionToneProfile.briefWarm
        case .balance:
            return DecisionToneProfile.groundedDirect
        case .mirror:
            return DecisionToneProfile.reflectiveClear
        }
    }

    private static func actionSpace(
        for kind: DecisionIntelligenceTraceKind,
        allowFallbacks: Bool,
        environmentClass: DecisionEnvironmentClass,
        deviceClass: DecisionDevicePerformanceClass
    ) -> [String] {
        var actions: [String] = switch kind {
        case .quick:
            ["encourage", "next_step", allowFallbacks ? "fallback_to_template" : "stay_deterministic"]
        case .balance:
            ["name_tradeoff", "surface_priority", allowFallbacks ? "fallback_to_template" : "stay_deterministic"]
        case .mirror:
            ["name_pattern", "name_boundary", allowFallbacks ? "fallback_to_template" : "stay_deterministic"]
        case .reminder:
            ["select_reminder", allowFallbacks ? "fallback_to_ranked_leader" : "stay_ranked_only"]
        }

        if environmentClass != .normal && !actions.contains("save_state") {
            actions.append("save_state")
        }

        if deviceClass == .memoryConstrainedPhone && !actions.contains("stay_brief") {
            actions.append("stay_brief")
        }

        return actions
    }

    private static func responseLanguage(
        for languageMode: DecisionLanguageMode
    ) -> DecisionAdaptiveResponseLanguage {
        switch languageMode {
        case .chinese:
            return .chinese
        case .mixed:
            return .mixed
        case .english, .unknown:
            return .english
        }
    }
}
