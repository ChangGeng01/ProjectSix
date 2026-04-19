import Foundation

public enum BASAdaptiveTraceKind: String, CaseIterable, Codable, Sendable {
    case primary = "primary"
    case comparative = "comparative"
    case reflective = "reflective"
    case selection = "selection"

    public static let primaryID = "primary"
    public static let comparativeID = "comparative"
    public static let reflectiveID = "reflective"
    public static let selectionID = "selection"

    public var identifier: String {
        switch self {
        case .primary:
            Self.primaryID
        case .comparative:
            Self.comparativeID
        case .reflective:
            Self.reflectiveID
        case .selection:
            Self.selectionID
        }
    }

    public init?(identifier: String) {
        switch identifier {
        case Self.primaryID:
            self = .primary
        case Self.comparativeID:
            self = .comparative
        case Self.reflectiveID:
            self = .reflective
        case Self.selectionID:
            self = .selection
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let kind = BASAdaptiveTraceKind(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported adaptive trace kind: \(identifier)"
            )
        }
        self = kind
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var title: String {
        switch self {
        case .primary:
            "Primary"
        case .comparative:
            "Comparative"
        case .reflective:
            "Reflective"
        case .selection:
            "Selection"
        }
    }
}

public enum BASEnvironmentClass: String, Codable, Equatable, Sendable {
    case simulator
    case lowPower
    case memoryConstrained
    case normal
}

public enum BASDevicePerformanceClass: String, Codable, Equatable, Sendable {
    case simulator
    case memoryConstrainedPhone
    case balancedPhone
    case fullPhone
}

public enum BASLanguageMode: String, Codable, Equatable, Sendable {
    case english
    case chinese
    case mixed
    case unknown

    public static func detect(preferredLanguages: [String]) -> BASLanguageMode {
        detect(preferredLanguages: preferredLanguages, sampleTexts: [])
    }

    public static func detect(
        preferredLanguages: [String],
        sampleTexts: [String]
    ) -> BASLanguageMode {
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

    public static func detect(sampleTexts: [String]) -> BASLanguageMode {
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

    public var retrievalTags: [String] {
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

public enum BASAdaptiveResponseLanguage: String, Codable, Equatable, Sendable {
    case english
    case chinese
    case mixed
}

public enum BASTaskEntropyClass: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

public enum BASRetrievalMode: String, Codable, Equatable, Sendable {
    case off
    case filtered
    case adaptive
}

public enum BASThinkingMode: String, Codable, Equatable, Sendable {
    case off
    case gated
}

public enum BASOutputMode: String, Codable, Equatable, Sendable {
    case deterministicTemplate
    case guidedShort
    case structuredBoard
    case reflectiveStructured
    case jsonShort
}

public enum BASToneProfile: String, Codable, Equatable, Sendable {
    case neutral
    case briefWarm
    case groundedDirect
    case reflectiveClear
}

public struct BASAdaptiveRuntimeBudget: Codable, Equatable, Sendable {
    public let contextBudget: Int
    public let outputCharacterBudget: Int
    public let timeBudgetMs: Int
    public let toolCallBudget: Int
    public let retrievalItemBudget: Int

    public init(
        contextBudget: Int,
        outputCharacterBudget: Int,
        timeBudgetMs: Int,
        toolCallBudget: Int,
        retrievalItemBudget: Int
    ) {
        self.contextBudget = contextBudget
        self.outputCharacterBudget = outputCharacterBudget
        self.timeBudgetMs = timeBudgetMs
        self.toolCallBudget = toolCallBudget
        self.retrievalItemBudget = retrievalItemBudget
    }
}

public struct BASAdaptiveTaskStrategy: Codable, Equatable, Sendable {
    public let kind: BASAdaptiveTraceKind
    public let entropy: BASTaskEntropyClass
    public let runtimeGear: BASRuntimeGear
    public let runtimeBudget: BASAdaptiveRuntimeBudget
    public let retrievalMode: BASRetrievalMode
    public let thinkingMode: BASThinkingMode
    public let outputMode: BASOutputMode
    public let tone: BASToneProfile
    public let actionSpace: [String]
    public let responseLanguage: BASAdaptiveResponseLanguage
    public let allowsModelInvocation: Bool

    public var contextBudget: Int { runtimeBudget.contextBudget }
    public var outputCharacterBudget: Int { runtimeBudget.outputCharacterBudget }
    public var timeBudgetMs: Int { runtimeBudget.timeBudgetMs }
    public var toolCallBudget: Int { runtimeBudget.toolCallBudget }
    public var retrievalItemBudget: Int { runtimeBudget.retrievalItemBudget }
    public var executionLane: BASExecutionLane {
        BASExecutionLanePlanner.classify(
            traceKind: kind,
            runtimeGear: runtimeGear,
            retrievalMode: retrievalMode,
            outputMode: outputMode,
            allowsModelInvocation: allowsModelInvocation
        )
    }

    public init(
        kind: BASAdaptiveTraceKind,
        entropy: BASTaskEntropyClass,
        runtimeGear: BASRuntimeGear = .balanced,
        contextBudget: Int,
        outputCharacterBudget: Int? = nil,
        timeBudgetMs: Int? = nil,
        toolCallBudget: Int? = nil,
        retrievalItemBudget: Int? = nil,
        retrievalMode: BASRetrievalMode,
        thinkingMode: BASThinkingMode,
        outputMode: BASOutputMode,
        tone: BASToneProfile,
        actionSpace: [String],
        responseLanguage: BASAdaptiveResponseLanguage = .english,
        allowsModelInvocation: Bool
    ) {
        self.kind = kind
        self.entropy = entropy
        self.runtimeGear = runtimeGear
        self.runtimeBudget = BASAdaptiveRuntimeBudget(
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
        for kind: BASAdaptiveTraceKind,
        gear: BASRuntimeGear,
        allowsModelInvocation: Bool,
        outputMode: BASOutputMode
    ) -> Int {
        guard allowsModelInvocation else {
            switch kind {
            case .primary, .selection:
                return 180
            case .comparative:
                return 260
            case .reflective:
                return 320
            }
        }

        let base: Int = switch (gear, kind) {
        case (.low, .primary):
            180
        case (.low, .comparative):
            260
        case (.low, .reflective):
            320
        case (.low, .selection):
            140
        case (.balanced, .primary):
            220
        case (.balanced, .comparative):
            340
        case (.balanced, .reflective):
            440
        case (.balanced, .selection):
            160
        case (.high, .primary):
            260
        case (.high, .comparative):
            420
        case (.high, .reflective):
            560
        case (.high, .selection):
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
        for kind: BASAdaptiveTraceKind,
        gear: BASRuntimeGear,
        allowsModelInvocation: Bool,
        thinkingMode: BASThinkingMode
    ) -> Int {
        guard allowsModelInvocation else {
            switch kind {
            case .primary, .selection:
                return 350
            case .comparative:
                return 500
            case .reflective:
                return 650
            }
        }

        let base: Int = switch (gear, kind) {
        case (.low, .primary):
            500
        case (.low, .comparative):
            700
        case (.low, .reflective):
            900
        case (.low, .selection):
            350
        case (.balanced, .primary):
            700
        case (.balanced, .comparative):
            1000
        case (.balanced, .reflective):
            1300
        case (.balanced, .selection):
            450
        case (.high, .primary):
            900
        case (.high, .comparative):
            1400
        case (.high, .reflective):
            1800
        case (.high, .selection):
            550
        }

        return thinkingMode == .gated ? base + 250 : base
    }

    private static func defaultToolCallBudget(
        for kind: BASAdaptiveTraceKind,
        allowsModelInvocation: Bool
    ) -> Int {
        guard allowsModelInvocation else { return 0 }
        return switch kind {
        case .primary:
            1
        case .comparative:
            2
        case .reflective:
            2
        case .selection:
            1
        }
    }

    private static func defaultRetrievalItemBudget(
        for kind: BASAdaptiveTraceKind,
        retrievalMode: BASRetrievalMode
    ) -> Int {
        switch retrievalMode {
        case .off:
            return 0
        case .filtered:
            return kind == .selection ? 2 : 3
        case .adaptive:
            return kind == .reflective ? 5 : 4
        }
    }
}

public struct BASAdaptiveRuntimeSignals: Codable, Equatable, Sendable {
    public let briefBias: Double
    public let fatigueSignal: Double
    public let hasBriefSessionBias: Bool
    public let interruptiveBias: Double
    public let boundaryBias: Double
    public let tradeoffBias: Double
    public let rebuiltSession: Bool
    public let staleFieldCount: Int
    public let screenedOutMemoryCount: Int
    public let lowTrustLoad: Bool
    public let retrievalInstability: Bool
    public let retrievalTags: [String]
    public let externallyRefreshedCandidateCount: Int
    public let quarantinedObservationCount: Int
    public let evidenceCaveatedCandidateCount: Int
    public let externalRefreshGuardTriggered: Bool
    public let observationOnlyQuarantine: Bool
    public let evidenceCaveatLoad: Bool

    public init(
        briefBias: Double,
        fatigueSignal: Double,
        hasBriefSessionBias: Bool,
        interruptiveBias: Double,
        boundaryBias: Double,
        tradeoffBias: Double,
        rebuiltSession: Bool,
        staleFieldCount: Int,
        screenedOutMemoryCount: Int,
        lowTrustLoad: Bool,
        retrievalInstability: Bool,
        retrievalTags: [String],
        externallyRefreshedCandidateCount: Int = 0,
        quarantinedObservationCount: Int = 0,
        evidenceCaveatedCandidateCount: Int = 0,
        externalRefreshGuardTriggered: Bool = false,
        observationOnlyQuarantine: Bool = false,
        evidenceCaveatLoad: Bool = false
    ) {
        self.briefBias = briefBias
        self.fatigueSignal = fatigueSignal
        self.hasBriefSessionBias = hasBriefSessionBias
        self.interruptiveBias = interruptiveBias
        self.boundaryBias = boundaryBias
        self.tradeoffBias = tradeoffBias
        self.rebuiltSession = rebuiltSession
        self.staleFieldCount = staleFieldCount
        self.screenedOutMemoryCount = screenedOutMemoryCount
        self.lowTrustLoad = lowTrustLoad
        self.retrievalInstability = retrievalInstability
        self.retrievalTags = retrievalTags
        self.externallyRefreshedCandidateCount = externallyRefreshedCandidateCount
        self.quarantinedObservationCount = quarantinedObservationCount
        self.evidenceCaveatedCandidateCount = evidenceCaveatedCandidateCount
        self.externalRefreshGuardTriggered = externalRefreshGuardTriggered
        self.observationOnlyQuarantine = observationOnlyQuarantine
        self.evidenceCaveatLoad = evidenceCaveatLoad
    }
}

public extension BASAdaptiveTaskStrategy {
    func adapting(signals: BASAdaptiveRuntimeSignals) -> BASAdaptiveTaskStrategy {
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
        case .primary:
            160
        case .comparative:
            220
        case .reflective:
            260
        case .selection:
            140
        }

        if signals.briefBias >= 0.78 || signals.fatigueSignal >= 0.68 || signals.hasBriefSessionBias {
            runtimeGear = .low
            let reduction: Int = switch kind {
            case .primary:
                40
            case .comparative:
                60
            case .reflective:
                80
            case .selection:
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

        if kind == .primary, signals.interruptiveBias >= 0.82 {
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

        if kind == .reflective, signals.boundaryBias >= 0.78, !actionSpace.contains("name_boundary") {
            actionSpace.append("name_boundary")
        }
        if kind == .reflective,
           runtimeGear != .low,
           signals.boundaryBias >= 0.88,
           signals.fatigueSignal < 0.55,
           signals.briefBias < 0.72 {
            runtimeGear = .high
            contextBudget += 40
            outputCharacterBudget += 60
            timeBudgetMs += 220
            retrievalItemBudget += 1
            if thinkingMode == .off {
                thinkingMode = .gated
            }
        }

        if kind == .comparative, signals.tradeoffBias >= 0.78, !actionSpace.contains("surface_priority") {
            actionSpace.append("surface_priority")
        }
        if kind == .comparative,
           runtimeGear == .balanced,
           signals.tradeoffBias >= 0.86,
           signals.fatigueSignal < 0.55,
           signals.briefBias < 0.72 {
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
            signals.rebuiltSession ||
            (signals.staleFieldCount > 0) ||
            (signals.screenedOutMemoryCount >= 3) ||
            signals.lowTrustLoad ||
            signals.retrievalInstability ||
            hasHorizonPressure(signals)

        if shouldGuardRetrieval {
            switch retrievalMode {
            case .adaptive:
                retrievalMode = .filtered
                retrievalItemBudget = min(retrievalItemBudget, kind == .reflective ? 3 : 2)
            case .filtered where kind == .selection:
                retrievalMode = .off
                retrievalItemBudget = 0
            case .off, .filtered:
                break
            }
        }

        if hasHorizonPressure(signals), retrievalMode != .off {
            retrievalMode = .filtered
            retrievalItemBudget = min(retrievalItemBudget, kind == .reflective ? 2 : 1)
            if !actionSpace.contains("cite_uncertainty") {
                actionSpace.append("cite_uncertainty")
            }
        }

        if let inferredResponseLanguage = inferredResponseLanguage(
            from: signals.retrievalTags,
            fallback: responseLanguage
        ) {
            responseLanguage = inferredResponseLanguage
        }

        return BASAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy,
            runtimeGear: runtimeGear,
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
        fallback: BASAdaptiveResponseLanguage
    ) -> BASAdaptiveResponseLanguage? {
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

    private func hasHorizonPressure(_ signals: BASAdaptiveRuntimeSignals) -> Bool {
        let retrievalTagSet = Set(signals.retrievalTags)
        return signals.externalRefreshGuardTriggered ||
            signals.observationOnlyQuarantine ||
            signals.evidenceCaveatLoad ||
            signals.externallyRefreshedCandidateCount > 0 ||
            signals.quarantinedObservationCount > 0 ||
            signals.evidenceCaveatedCandidateCount > 0 ||
            retrievalTagSet.contains("external_refresh") ||
            retrievalTagSet.contains("tool_observation") ||
            retrievalTagSet.contains("quarantined") ||
            retrievalTagSet.contains("evidence_caveat")
    }
}

public struct BASAdaptiveRuntimeMatrix: Codable, Equatable, Sendable {
    public let runtimeGear: BASRuntimeGear
    public let environmentClass: BASEnvironmentClass
    public let deviceClass: BASDevicePerformanceClass
    public let languageMode: BASLanguageMode
    public let strategiesByKind: [BASAdaptiveTraceKind: BASAdaptiveTaskStrategy]

    public init(
        runtimeGear: BASRuntimeGear,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode,
        strategiesByKind: [BASAdaptiveTraceKind: BASAdaptiveTaskStrategy]
    ) {
        self.runtimeGear = runtimeGear
        self.environmentClass = environmentClass
        self.deviceClass = deviceClass
        self.languageMode = languageMode
        self.strategiesByKind = strategiesByKind
    }

    public func strategy(for kind: BASAdaptiveTraceKind) -> BASAdaptiveTaskStrategy {
        strategiesByKind[kind] ?? BASAdaptiveTaskStrategy(
            kind: kind,
            entropy: .medium,
            runtimeGear: .low,
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

    public func executionLane(for kind: BASAdaptiveTraceKind) -> BASExecutionLane {
        strategy(for: kind).executionLane
    }
}

public struct BASAdaptiveRuntimeMatrixRequest: Codable, Equatable, Sendable {
    public let runtimeGear: BASRuntimeGear
    public let environmentClass: BASEnvironmentClass
    public let deviceClass: BASDevicePerformanceClass
    public let languageMode: BASLanguageMode
    public let allowFallbacks: Bool
    public let allowsModelInvocationByKind: [BASAdaptiveTraceKind: Bool]

    public init(
        runtimeGear: BASRuntimeGear,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode,
        allowFallbacks: Bool,
        allowsModelInvocationByKind: [BASAdaptiveTraceKind: Bool]
    ) {
        self.runtimeGear = runtimeGear
        self.environmentClass = environmentClass
        self.deviceClass = deviceClass
        self.languageMode = languageMode
        self.allowFallbacks = allowFallbacks
        self.allowsModelInvocationByKind = allowsModelInvocationByKind
    }
}

public enum BASAdaptiveRuntimeMatrixResolver {
    public static func resolve(request: BASAdaptiveRuntimeMatrixRequest) -> BASAdaptiveRuntimeMatrix {
        let strategies = Dictionary(
            uniqueKeysWithValues: BASAdaptiveTraceKind.allCases.map { kind in
                let allowsModelInvocation = request.allowsModelInvocationByKind[kind] ?? false
                let taskGear = taskGear(
                    for: kind,
                    runtimeGear: request.runtimeGear,
                    allowsModelInvocation: allowsModelInvocation,
                    environmentClass: request.environmentClass,
                    deviceClass: request.deviceClass
                )

                return (
                    kind,
                    BASAdaptiveTaskStrategy(
                        kind: kind,
                        entropy: entropy(for: kind),
                        runtimeGear: taskGear,
                        contextBudget: contextBudget(
                            for: kind,
                            gear: taskGear,
                            allowsModelInvocation: allowsModelInvocation,
                            environmentClass: request.environmentClass,
                            deviceClass: request.deviceClass,
                            languageMode: request.languageMode
                        ),
                        outputCharacterBudget: outputCharacterBudget(
                            for: kind,
                            gear: taskGear,
                            allowsModelInvocation: allowsModelInvocation,
                            environmentClass: request.environmentClass,
                            deviceClass: request.deviceClass
                        ),
                        timeBudgetMs: timeBudgetMs(
                            for: kind,
                            gear: taskGear,
                            allowsModelInvocation: allowsModelInvocation,
                            environmentClass: request.environmentClass,
                            deviceClass: request.deviceClass
                        ),
                        toolCallBudget: toolCallBudget(
                            for: kind,
                            allowsModelInvocation: allowsModelInvocation,
                            environmentClass: request.environmentClass
                        ),
                        retrievalItemBudget: retrievalItemBudget(
                            for: kind,
                            allowsModelInvocation: allowsModelInvocation,
                            environmentClass: request.environmentClass
                        ),
                        retrievalMode: retrievalMode(
                            for: kind,
                            gear: taskGear,
                            allowsModelInvocation: allowsModelInvocation,
                            environmentClass: request.environmentClass,
                            deviceClass: request.deviceClass,
                            languageMode: request.languageMode
                        ),
                        thinkingMode: thinkingMode(
                            for: kind,
                            gear: taskGear,
                            allowsModelInvocation: allowsModelInvocation,
                            environmentClass: request.environmentClass,
                            deviceClass: request.deviceClass,
                            languageMode: request.languageMode
                        ),
                        outputMode: outputMode(
                            for: kind,
                            allowsModelInvocation: allowsModelInvocation
                        ),
                        tone: tone(
                            for: kind,
                            allowsModelInvocation: allowsModelInvocation,
                            environmentClass: request.environmentClass,
                            languageMode: request.languageMode
                        ),
                        actionSpace: actionSpace(
                            for: kind,
                            allowFallbacks: request.allowFallbacks,
                            environmentClass: request.environmentClass,
                            deviceClass: request.deviceClass
                        ),
                        responseLanguage: responseLanguage(for: request.languageMode),
                        allowsModelInvocation: allowsModelInvocation
                    )
                )
            }
        )

        return BASAdaptiveRuntimeMatrix(
            runtimeGear: request.runtimeGear,
            environmentClass: request.environmentClass,
            deviceClass: request.deviceClass,
            languageMode: request.languageMode,
            strategiesByKind: strategies
        )
    }

    public static func environmentClass(for deviceProfile: BASDeviceProfile) -> BASEnvironmentClass {
        if deviceProfile.modelName.lowercased().contains("simulator") {
            return .simulator
        }
        if deviceProfile.lowPowerMode {
            return .lowPower
        }
        if deviceProfile.memoryMB < 7 * 1024 {
            return .memoryConstrained
        }
        return .normal
    }

    public static func deviceClass(for deviceProfile: BASDeviceProfile) -> BASDevicePerformanceClass {
        if deviceProfile.modelName.lowercased().contains("simulator") {
            return .simulator
        }
        if deviceProfile.memoryMB < 7 * 1024 {
            return .memoryConstrainedPhone
        }
        if deviceProfile.memoryMB < 8 * 1024 {
            return .balancedPhone
        }
        return .fullPhone
    }

    private static func taskGear(
        for kind: BASAdaptiveTraceKind,
        runtimeGear: BASRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass
    ) -> BASRuntimeGear {
        guard allowsModelInvocation else { return .low }

        let baseGear: BASRuntimeGear = switch kind {
        case .primary, .selection:
            .low
        case .comparative:
            runtimeGear == .low ? .low : .balanced
        case .reflective:
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

    private static func entropy(for kind: BASAdaptiveTraceKind) -> BASTaskEntropyClass {
        switch kind {
        case .primary, .selection:
            .low
        case .comparative:
            .medium
        case .reflective:
            .high
        }
    }

    private static func contextBudget(
        for kind: BASAdaptiveTraceKind,
        gear: BASRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode
    ) -> Int {
        let base: Int
        if !allowsModelInvocation {
            switch kind {
            case .primary, .selection: base = 160
            case .comparative: base = 220
            case .reflective: base = 240
            }
        } else {
            switch (gear, kind) {
            case (.low, .primary): base = 220
            case (.low, .comparative): base = 280
            case (.low, .reflective): base = 320
            case (.low, .selection): base = 160
            case (.balanced, .primary): base = 320
            case (.balanced, .comparative): base = 440
            case (.balanced, .reflective): base = 520
            case (.balanced, .selection): base = 200
            case (.high, .primary): base = 360
            case (.high, .comparative): base = 520
            case (.high, .reflective): base = 620
            case (.high, .selection): base = 240
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
        case .primary: 160
        case .comparative: 220
        case .reflective: 260
        case .selection: 140
        }

        return max(minimumBudget, base - environmentPenalty - devicePenalty - languagePenalty)
    }

    private static func outputCharacterBudget(
        for kind: BASAdaptiveTraceKind,
        gear: BASRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass
    ) -> Int {
        let base = BASAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy(for: kind),
            runtimeGear: gear,
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
        for kind: BASAdaptiveTraceKind,
        gear: BASRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass
    ) -> Int {
        let base = BASAdaptiveTaskStrategy(
            kind: kind,
            entropy: entropy(for: kind),
            runtimeGear: gear,
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
        for kind: BASAdaptiveTraceKind,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass
    ) -> Int {
        guard allowsModelInvocation else { return 0 }
        let base: Int = switch kind {
        case .primary, .selection:
            1
        case .comparative, .reflective:
            2
        }
        return environmentClass == .normal ? base : max(0, base - 1)
    }

    private static func retrievalItemBudget(
        for kind: BASAdaptiveTraceKind,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass
    ) -> Int {
        guard allowsModelInvocation else { return 0 }
        let base: Int = switch kind {
        case .primary:
            0
        case .selection:
            2
        case .comparative:
            3
        case .reflective:
            5
        }

        return environmentClass == .normal ? base : max(0, base - 1)
    }

    private static func retrievalMode(
        for kind: BASAdaptiveTraceKind,
        gear: BASRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode
    ) -> BASRetrievalMode {
        guard allowsModelInvocation else { return .off }
        var mode: BASRetrievalMode = switch kind {
        case .primary:
            .off
        case .selection:
            .filtered
        case .comparative:
            gear == .high ? .adaptive : .filtered
        case .reflective:
            .adaptive
        }

        if environmentClass == .simulator || environmentClass == .lowPower {
            if kind == .selection {
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
        for kind: BASAdaptiveTraceKind,
        gear: BASRuntimeGear,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass,
        languageMode: BASLanguageMode
    ) -> BASThinkingMode {
        guard allowsModelInvocation else { return .off }
        guard kind == .comparative || kind == .reflective else { return .off }
        guard gear == .high,
              environmentClass == .normal,
              deviceClass == .fullPhone,
              languageMode != .mixed else {
            return .off
        }
        return .gated
    }

    private static func outputMode(
        for kind: BASAdaptiveTraceKind,
        allowsModelInvocation: Bool
    ) -> BASOutputMode {
        guard allowsModelInvocation else { return .deterministicTemplate }
        switch kind {
        case .primary:
            return .guidedShort
        case .comparative:
            return .structuredBoard
        case .reflective:
            return .reflectiveStructured
        case .selection:
            return .jsonShort
        }
    }

    private static func tone(
        for kind: BASAdaptiveTraceKind,
        allowsModelInvocation: Bool,
        environmentClass: BASEnvironmentClass,
        languageMode: BASLanguageMode
    ) -> BASToneProfile {
        guard allowsModelInvocation else { return .neutral }
        if environmentClass == .lowPower || environmentClass == .memoryConstrained {
            return .briefWarm
        }

        if languageMode == .mixed || languageMode == .unknown {
            switch kind {
            case .primary, .selection:
                return .briefWarm
            case .comparative, .reflective:
                return .groundedDirect
            }
        }

        switch kind {
        case .primary, .selection:
            return .briefWarm
        case .comparative:
            return .groundedDirect
        case .reflective:
            return .reflectiveClear
        }
    }

    private static func actionSpace(
        for kind: BASAdaptiveTraceKind,
        allowFallbacks: Bool,
        environmentClass: BASEnvironmentClass,
        deviceClass: BASDevicePerformanceClass
    ) -> [String] {
        var actions: [String] = switch kind {
        case .primary:
            ["encourage", "next_step", allowFallbacks ? "fallback_to_template" : "stay_deterministic"]
        case .comparative:
            ["name_tradeoff", "surface_priority", allowFallbacks ? "fallback_to_template" : "stay_deterministic"]
        case .reflective:
            ["name_pattern", "name_boundary", allowFallbacks ? "fallback_to_template" : "stay_deterministic"]
        case .selection:
            ["select_candidate", allowFallbacks ? "fallback_to_ranked_leader" : "stay_ranked_only"]
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
        for languageMode: BASLanguageMode
    ) -> BASAdaptiveResponseLanguage {
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
