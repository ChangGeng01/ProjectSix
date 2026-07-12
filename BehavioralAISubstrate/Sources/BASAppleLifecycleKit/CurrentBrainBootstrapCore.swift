import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASCurrentBrainBootstrapTrigger: String, Codable, Equatable, Sendable, CaseIterable {
    case launch
    case sceneActive
    case watchHandoff
    case notification
    case widget
    case explicitRefresh
    case sessionBootstrap = "session_bootstrap"

    public static let sessionBootstrapID = BASCurrentBrainBootstrapTrigger.sessionBootstrap.rawValue

    public init?(identifier: String) {
        switch identifier {
        case Self.launch.rawValue:
            self = .launch
        case Self.sceneActive.rawValue:
            self = .sceneActive
        case Self.watchHandoff.rawValue:
            self = .watchHandoff
        case Self.notification.rawValue:
            self = .notification
        case Self.widget.rawValue:
            self = .widget
        case Self.explicitRefresh.rawValue:
            self = .explicitRefresh
        case Self.sessionBootstrap.rawValue:
            self = .sessionBootstrap
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let trigger = BASCurrentBrainBootstrapTrigger(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported current brain bootstrap trigger identifier: \(identifier)"
            )
        }
        self = trigger
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum BASCurrentBrainBootstrapDescriptorModeFallbackPolicy: String, Codable, Equatable, Sendable, CaseIterable {
    case useConfiguredDefault
    case usePreparationMode
    case dropDescriptor
}

public enum BASCurrentBrainBootstrapDescriptorRiskFallbackPolicy: String, Codable, Equatable, Sendable, CaseIterable {
    case useConfiguredDefault
    case usePreparationRiskLevel
}

public enum BASCurrentBrainBootstrapRequestedModeFallbackPolicy: String, Codable, Equatable, Sendable, CaseIterable {
    case useConfiguredDefault
    case reject
}

public enum BASCurrentBrainBootstrapRequestedTriggerFallbackPolicy: String, Codable, Equatable, Sendable, CaseIterable {
    case useConfiguredDefault
    case reject
}

public enum BASCurrentBrainBootstrapBehaviorIssueKind: String, Codable, Equatable, Sendable {
    case unsupportedRequestedModeID
    case unsupportedRequestedTriggerID
    case unsupportedRequestedRiskLevelID
    case unsupportedConfiguredDefaultModeID
    case unsupportedConfiguredDefaultTriggerID
    case unsupportedConfiguredDefaultRiskLevelID
    case unsupportedConfiguredDefaultSourceSurfaceID
    case unsupportedConfiguredDefaultMemorySourceID
}

public struct BASCurrentBrainBootstrapBehaviorIssue: Codable, Equatable, Sendable {
    public var kind: BASCurrentBrainBootstrapBehaviorIssueKind
    public var identifier: String
    public var fallbackIdentifier: String?

    public init(
        kind: BASCurrentBrainBootstrapBehaviorIssueKind,
        identifier: String,
        fallbackIdentifier: String? = nil
    ) {
        self.kind = kind
        self.identifier = identifier
        self.fallbackIdentifier = fallbackIdentifier
    }
}

public struct BASCurrentBrainBootstrapBehavior: Codable, Equatable, Sendable {
    public static let generic = BASCurrentBrainBootstrapBehavior(
        defaultModeID: BASDecisionMode.primaryID,
        defaultTriggerID: BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue,
        defaultRiskLevelID: BASRiskLevel.low.rawValue,
        defaultSourceSurfaceID: BASInteractionSurface.app.rawValue,
        modeIDAliasesByID: [:],
        triggerIDAliasesByID: [:],
        riskLevelIDAliasesByID: [:],
        sourceSurfaceOverridesByTriggerID: [
            BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.watch.rawValue,
            BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue,
            BASCurrentBrainBootstrapTrigger.widget.rawValue: BASInteractionSurface.widget.rawValue
        ],
        enforcedSourceSurfaceByTriggerID: [
            BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue
        ],
        defaultMemorySourceID: BASMemorySource.pattern.rawValue,
        memorySourceIDAliasesByID: [:],
        memorySourceOverridesByTriggerID: [:],
        memorySourceOverridesByModeID: [:],
        memorySourceOverridesByTriggerAndModeID: [:],
        unknownRequestedModeFallbackPolicy: .reject,
        unknownRequestedTriggerFallbackPolicy: .reject,
        unknownTemplateModeFallbackPolicy: .dropDescriptor,
        unknownFailurePatternModeFallbackPolicy: .dropDescriptor,
        unknownTemplateRiskFallbackPolicy: .usePreparationRiskLevel,
        bootstrapAdvisorBehavior: .generic
    )

    public var defaultModeID: String
    public var defaultTriggerID: String
    public var defaultRiskLevelID: String
    public var defaultSourceSurfaceID: String
    public var modeIDAliasesByID: [String: String]
    public var triggerIDAliasesByID: [String: String]
    public var riskLevelIDAliasesByID: [String: String]
    public var sourceSurfaceOverridesByTriggerID: [String: String]
    public var enforcedSourceSurfaceByTriggerID: [String: String]
    public var defaultMemorySourceID: String
    public var memorySourceIDAliasesByID: [String: String]
    public var memorySourceOverridesByTriggerID: [String: String]
    public var memorySourceOverridesByModeID: [String: String]
    public var memorySourceOverridesByTriggerAndModeID: [String: [String: String]]
    public var unknownRequestedModeFallbackPolicy: BASCurrentBrainBootstrapRequestedModeFallbackPolicy
    public var unknownRequestedTriggerFallbackPolicy: BASCurrentBrainBootstrapRequestedTriggerFallbackPolicy
    public var unknownTemplateModeFallbackPolicy: BASCurrentBrainBootstrapDescriptorModeFallbackPolicy
    public var unknownFailurePatternModeFallbackPolicy: BASCurrentBrainBootstrapDescriptorModeFallbackPolicy
    public var unknownTemplateRiskFallbackPolicy: BASCurrentBrainBootstrapDescriptorRiskFallbackPolicy
    public var bootstrapAdvisorBehavior: BASBrainBootstrapAdvisorBehavior

    private enum CodingKeys: String, CodingKey {
        case defaultModeID
        case defaultTriggerID
        case defaultRiskLevelID
        case defaultSourceSurfaceID
        case modeIDAliasesByID
        case triggerIDAliasesByID
        case riskLevelIDAliasesByID
        case sourceSurfaceOverridesByTriggerID
        case enforcedSourceSurfaceByTriggerID
        case defaultMemorySourceID
        case memorySourceIDAliasesByID
        case memorySourceOverridesByTriggerID
        case memorySourceOverridesByModeID
        case memorySourceOverridesByTriggerAndModeID
        case unknownRequestedModeFallbackPolicy
        case unknownRequestedTriggerFallbackPolicy
        case unknownTemplateModeFallbackPolicy
        case unknownFailurePatternModeFallbackPolicy
        case unknownTemplateRiskFallbackPolicy
        case bootstrapAdvisorBehavior
    }

    @available(*, unavailable, message: "Use .generic or provide explicit bootstrap behavior.")
    public init() {
        fatalError("Unavailable")
    }

    public init(
        defaultModeID: String = BASDecisionMode.primaryID,
        defaultTriggerID: String = BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue,
        defaultRiskLevelID: String = BASRiskLevel.low.rawValue,
        defaultSourceSurfaceID: String = BASInteractionSurface.app.rawValue,
        modeIDAliasesByID: [String: String] = [:],
        triggerIDAliasesByID: [String: String] = [:],
        riskLevelIDAliasesByID: [String: String] = [:],
        sourceSurfaceOverridesByTriggerID: [String: String] = [
            BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.watch.rawValue,
            BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue,
            BASCurrentBrainBootstrapTrigger.widget.rawValue: BASInteractionSurface.widget.rawValue
        ],
        enforcedSourceSurfaceByTriggerID: [String: String] = [
            BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue
        ],
        defaultMemorySourceID: String = BASMemorySource.pattern.rawValue,
        memorySourceIDAliasesByID: [String: String] = [:],
        memorySourceOverridesByTriggerID: [String: String] = [:],
        memorySourceOverridesByModeID: [String: String] = [:],
        memorySourceOverridesByTriggerAndModeID: [String: [String: String]] = [:],
        unknownRequestedModeFallbackPolicy: BASCurrentBrainBootstrapRequestedModeFallbackPolicy = .reject,
        unknownRequestedTriggerFallbackPolicy: BASCurrentBrainBootstrapRequestedTriggerFallbackPolicy = .reject,
        unknownTemplateModeFallbackPolicy: BASCurrentBrainBootstrapDescriptorModeFallbackPolicy = .dropDescriptor,
        unknownFailurePatternModeFallbackPolicy: BASCurrentBrainBootstrapDescriptorModeFallbackPolicy = .dropDescriptor,
        unknownTemplateRiskFallbackPolicy: BASCurrentBrainBootstrapDescriptorRiskFallbackPolicy = .usePreparationRiskLevel,
        bootstrapAdvisorBehavior: BASBrainBootstrapAdvisorBehavior = .generic
    ) {
        self.defaultModeID = defaultModeID
        self.defaultTriggerID = defaultTriggerID
        self.defaultRiskLevelID = defaultRiskLevelID
        self.defaultSourceSurfaceID = defaultSourceSurfaceID
        self.modeIDAliasesByID = modeIDAliasesByID
        self.triggerIDAliasesByID = triggerIDAliasesByID
        self.riskLevelIDAliasesByID = riskLevelIDAliasesByID
        self.sourceSurfaceOverridesByTriggerID = sourceSurfaceOverridesByTriggerID
        self.enforcedSourceSurfaceByTriggerID = enforcedSourceSurfaceByTriggerID
        self.defaultMemorySourceID = defaultMemorySourceID
        self.memorySourceIDAliasesByID = memorySourceIDAliasesByID
        self.memorySourceOverridesByTriggerID = memorySourceOverridesByTriggerID
        self.memorySourceOverridesByModeID = memorySourceOverridesByModeID
        self.memorySourceOverridesByTriggerAndModeID = memorySourceOverridesByTriggerAndModeID
        self.unknownRequestedModeFallbackPolicy = unknownRequestedModeFallbackPolicy
        self.unknownRequestedTriggerFallbackPolicy = unknownRequestedTriggerFallbackPolicy
        self.unknownTemplateModeFallbackPolicy = unknownTemplateModeFallbackPolicy
        self.unknownFailurePatternModeFallbackPolicy = unknownFailurePatternModeFallbackPolicy
        self.unknownTemplateRiskFallbackPolicy = unknownTemplateRiskFallbackPolicy
        self.bootstrapAdvisorBehavior = bootstrapAdvisorBehavior
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            defaultModeID: try container.decodeIfPresent(String.self, forKey: .defaultModeID) ?? BASDecisionMode.primaryID,
            defaultTriggerID: try container.decodeIfPresent(String.self, forKey: .defaultTriggerID) ?? BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue,
            defaultRiskLevelID: try container.decodeIfPresent(String.self, forKey: .defaultRiskLevelID) ?? BASRiskLevel.low.rawValue,
            defaultSourceSurfaceID: try container.decodeIfPresent(String.self, forKey: .defaultSourceSurfaceID) ?? BASInteractionSurface.app.rawValue,
            modeIDAliasesByID: try container.decodeIfPresent([String: String].self, forKey: .modeIDAliasesByID) ?? [:],
            triggerIDAliasesByID: try container.decodeIfPresent([String: String].self, forKey: .triggerIDAliasesByID) ?? [:],
            riskLevelIDAliasesByID: try container.decodeIfPresent([String: String].self, forKey: .riskLevelIDAliasesByID) ?? [:],
            sourceSurfaceOverridesByTriggerID: try container.decodeIfPresent([String: String].self, forKey: .sourceSurfaceOverridesByTriggerID) ?? [
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.watch.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASInteractionSurface.widget.rawValue
            ],
            enforcedSourceSurfaceByTriggerID: try container.decodeIfPresent([String: String].self, forKey: .enforcedSourceSurfaceByTriggerID) ?? [
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue
            ],
            defaultMemorySourceID: try container.decodeIfPresent(String.self, forKey: .defaultMemorySourceID) ?? BASMemorySource.pattern.rawValue,
            memorySourceIDAliasesByID: try container.decodeIfPresent([String: String].self, forKey: .memorySourceIDAliasesByID) ?? [:],
            memorySourceOverridesByTriggerID: try container.decodeIfPresent([String: String].self, forKey: .memorySourceOverridesByTriggerID) ?? [:],
            memorySourceOverridesByModeID: try container.decodeIfPresent([String: String].self, forKey: .memorySourceOverridesByModeID) ?? [:],
            memorySourceOverridesByTriggerAndModeID: try container.decodeIfPresent([String: [String: String]].self, forKey: .memorySourceOverridesByTriggerAndModeID) ?? [:],
            unknownRequestedModeFallbackPolicy: try container.decodeIfPresent(BASCurrentBrainBootstrapRequestedModeFallbackPolicy.self, forKey: .unknownRequestedModeFallbackPolicy) ?? .reject,
            unknownRequestedTriggerFallbackPolicy: try container.decodeIfPresent(BASCurrentBrainBootstrapRequestedTriggerFallbackPolicy.self, forKey: .unknownRequestedTriggerFallbackPolicy) ?? .reject,
            unknownTemplateModeFallbackPolicy: try container.decodeIfPresent(BASCurrentBrainBootstrapDescriptorModeFallbackPolicy.self, forKey: .unknownTemplateModeFallbackPolicy) ?? .dropDescriptor,
            unknownFailurePatternModeFallbackPolicy: try container.decodeIfPresent(BASCurrentBrainBootstrapDescriptorModeFallbackPolicy.self, forKey: .unknownFailurePatternModeFallbackPolicy) ?? .dropDescriptor,
            unknownTemplateRiskFallbackPolicy: try container.decodeIfPresent(BASCurrentBrainBootstrapDescriptorRiskFallbackPolicy.self, forKey: .unknownTemplateRiskFallbackPolicy) ?? .usePreparationRiskLevel,
            bootstrapAdvisorBehavior: try container.decodeIfPresent(BASBrainBootstrapAdvisorBehavior.self, forKey: .bootstrapAdvisorBehavior) ?? .generic
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultModeID, forKey: .defaultModeID)
        try container.encode(defaultTriggerID, forKey: .defaultTriggerID)
        try container.encode(defaultRiskLevelID, forKey: .defaultRiskLevelID)
        try container.encode(defaultSourceSurfaceID, forKey: .defaultSourceSurfaceID)
        try container.encode(modeIDAliasesByID, forKey: .modeIDAliasesByID)
        try container.encode(triggerIDAliasesByID, forKey: .triggerIDAliasesByID)
        try container.encode(riskLevelIDAliasesByID, forKey: .riskLevelIDAliasesByID)
        try container.encode(sourceSurfaceOverridesByTriggerID, forKey: .sourceSurfaceOverridesByTriggerID)
        try container.encode(enforcedSourceSurfaceByTriggerID, forKey: .enforcedSourceSurfaceByTriggerID)
        try container.encode(defaultMemorySourceID, forKey: .defaultMemorySourceID)
        try container.encode(memorySourceIDAliasesByID, forKey: .memorySourceIDAliasesByID)
        try container.encode(memorySourceOverridesByTriggerID, forKey: .memorySourceOverridesByTriggerID)
        try container.encode(memorySourceOverridesByModeID, forKey: .memorySourceOverridesByModeID)
        try container.encode(memorySourceOverridesByTriggerAndModeID, forKey: .memorySourceOverridesByTriggerAndModeID)
        try container.encode(unknownRequestedModeFallbackPolicy, forKey: .unknownRequestedModeFallbackPolicy)
        try container.encode(unknownRequestedTriggerFallbackPolicy, forKey: .unknownRequestedTriggerFallbackPolicy)
        try container.encode(unknownTemplateModeFallbackPolicy, forKey: .unknownTemplateModeFallbackPolicy)
        try container.encode(unknownFailurePatternModeFallbackPolicy, forKey: .unknownFailurePatternModeFallbackPolicy)
        try container.encode(unknownTemplateRiskFallbackPolicy, forKey: .unknownTemplateRiskFallbackPolicy)
        try container.encode(bootstrapAdvisorBehavior, forKey: .bootstrapAdvisorBehavior)
    }

    public func resolvedMode(from requestedModeID: String) -> BASDecisionMode {
        var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
        return resolvedMode(from: requestedModeID, issues: &issues)
    }

    public func resolvedMode(
        from requestedModeID: String,
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASDecisionMode {
        if let resolved = BASDecisionMode(identifier: canonicalModeID(for: requestedModeID)) {
            return resolved
        }

        switch unknownRequestedModeFallbackPolicy {
        case .useConfiguredDefault:
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedRequestedModeID,
                    identifier: requestedModeID,
                    fallbackIdentifier: defaultModeID
                )
            )
            let configuredDefault = resolvedConfiguredDefaultMode(issues: &issues)
            return configuredDefault
        case .reject:
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedRequestedModeID,
                    identifier: requestedModeID,
                    fallbackIdentifier: conservativeModeFallback.identifier
                )
            )
            return conservativeModeFallback
        }
    }

    public func resolvedTrigger(from requestedTriggerID: String) -> BASCurrentBrainBootstrapTrigger {
        var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
        return resolvedTrigger(from: requestedTriggerID, issues: &issues)
    }

    public func resolvedTrigger(
        from requestedTriggerID: String,
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASCurrentBrainBootstrapTrigger {
        if let resolved = BASCurrentBrainBootstrapTrigger(identifier: canonicalTriggerID(for: requestedTriggerID)) {
            return resolved
        }

        switch unknownRequestedTriggerFallbackPolicy {
        case .useConfiguredDefault:
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedRequestedTriggerID,
                    identifier: requestedTriggerID,
                    fallbackIdentifier: defaultTriggerID
                )
            )
            let configuredDefault = resolvedConfiguredDefaultTrigger(issues: &issues)
            return configuredDefault
        case .reject:
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedRequestedTriggerID,
                    identifier: requestedTriggerID,
                    fallbackIdentifier: conservativeTriggerFallback.rawValue
                )
            )
            return conservativeTriggerFallback
        }
    }

    public func resolvedRiskLevel(from requestedRiskLevelID: String?) -> BASRiskLevel? {
        var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
        return resolvedRiskLevel(from: requestedRiskLevelID, issues: &issues)
    }

    public func resolvedRiskLevel(
        from requestedRiskLevelID: String?,
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASRiskLevel? {
        guard let requestedRiskLevelID else { return nil }
        if let resolved = BASRiskLevel(rawValue: canonicalRiskLevelID(for: requestedRiskLevelID)) {
            return resolved
        }
        issues.append(
            BASCurrentBrainBootstrapBehaviorIssue(
                kind: .unsupportedRequestedRiskLevelID,
                identifier: requestedRiskLevelID,
                fallbackIdentifier: defaultRiskLevelID
            )
        )
        return resolvedConfiguredDefaultRiskLevel(issues: &issues)
    }

    public func resolvedTemplateMode(
        from requestedModeID: String,
        preparationMode: BASDecisionMode
    ) -> BASDecisionMode? {
        if let resolved = BASDecisionMode(identifier: canonicalModeID(for: requestedModeID)) {
            return resolved
        }

        switch unknownTemplateModeFallbackPolicy {
        case .useConfiguredDefault:
            var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
            let configuredDefault = resolvedConfiguredDefaultMode(issues: &issues)
            return configuredDefault
        case .usePreparationMode:
            return preparationMode
        case .dropDescriptor:
            return nil
        }
    }

    public func resolvedFailurePatternMode(
        from requestedModeID: String,
        preparationMode: BASDecisionMode
    ) -> BASDecisionMode? {
        if let resolved = BASDecisionMode(identifier: canonicalModeID(for: requestedModeID)) {
            return resolved
        }

        switch unknownFailurePatternModeFallbackPolicy {
        case .useConfiguredDefault:
            var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
            let configuredDefault = resolvedConfiguredDefaultMode(issues: &issues)
            return configuredDefault
        case .usePreparationMode:
            return preparationMode
        case .dropDescriptor:
            return nil
        }
    }

    public func resolvedTemplateRiskLevel(
        from requestedRiskLevelID: String,
        preparationRiskLevel: BASRiskLevel
    ) -> BASRiskLevel {
        if let resolved = BASRiskLevel(rawValue: canonicalRiskLevelID(for: requestedRiskLevelID)) {
            return resolved
        }

        switch unknownTemplateRiskFallbackPolicy {
        case .useConfiguredDefault:
            var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
            return resolvedConfiguredDefaultRiskLevel(issues: &issues)
        case .usePreparationRiskLevel:
            return preparationRiskLevel
        }
    }

    public func resolvedSourceSurface(
        for trigger: BASCurrentBrainBootstrapTrigger,
        override: BASInteractionSurface?
    ) -> BASInteractionSurface {
        var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
        return resolvedSourceSurface(for: trigger, override: override, issues: &issues)
    }

    public func resolvedSourceSurface(
        for trigger: BASCurrentBrainBootstrapTrigger,
        override: BASInteractionSurface?,
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASInteractionSurface {
        if let enforced = surface(
            in: enforcedSourceSurfaceByTriggerID,
            for: trigger.rawValue
        ) {
            return enforced
        }
        if let override {
            return override
        }
        if let overridden = surface(
            in: sourceSurfaceOverridesByTriggerID,
            for: trigger.rawValue
        ) {
            return overridden
        }
        return resolvedConfiguredDefaultSourceSurface(issues: &issues)
    }

    public func memorySource(
        for trigger: BASCurrentBrainBootstrapTrigger,
        mode: BASDecisionMode
    ) -> BASMemorySource {
        var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
        return memorySource(for: trigger, mode: mode, issues: &issues)
    }

    public func memorySource(
        for trigger: BASCurrentBrainBootstrapTrigger,
        mode: BASDecisionMode,
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASMemorySource {
        if let modeMapping = memorySourceOverridesByTriggerAndModeID[trigger.rawValue],
           let source = memorySource(
               in: modeMapping,
               candidates: [mode.identifier, mode.rawValue]
           ) {
            return source
        }
        if let source = memorySource(
            in: memorySourceOverridesByModeID,
            candidates: [mode.identifier, mode.rawValue]
        ) {
            return source
        }
        if let source = memorySource(
            in: memorySourceOverridesByTriggerID,
            candidates: [trigger.rawValue]
        ) {
            return source
        }
        return resolvedConfiguredDefaultMemorySource(issues: &issues)
    }

    public func canonicalModeID(for requestedModeID: String) -> String {
        modeIDAliasesByID[requestedModeID] ?? requestedModeID
    }

    public func canonicalTriggerID(for requestedTriggerID: String) -> String {
        triggerIDAliasesByID[requestedTriggerID] ?? requestedTriggerID
    }

    public func canonicalRiskLevelID(for requestedRiskLevelID: String) -> String {
        riskLevelIDAliasesByID[requestedRiskLevelID] ?? requestedRiskLevelID
    }

    public func canonicalMemorySourceID(for requestedMemorySourceID: String) -> String {
        memorySourceIDAliasesByID[requestedMemorySourceID] ?? requestedMemorySourceID
    }

    private func surface(
        in mapping: [String: String],
        for key: String
    ) -> BASInteractionSurface? {
        mapping[key].flatMap(BASInteractionSurface.init(rawValue:))
    }

    private func memorySource(
        in mapping: [String: String],
        candidates: [String]
    ) -> BASMemorySource? {
        for candidate in candidates {
            if let source = mapping[candidate].flatMap(memorySource(rawValue:)) {
                return source
            }
        }
        return nil
    }

    private func memorySource(rawValue: String) -> BASMemorySource? {
        BASMemorySource(identifier: canonicalMemorySourceID(for: rawValue))
    }

    private var conservativeModeFallback: BASDecisionMode {
        .primary
    }

    private var conservativeTriggerFallback: BASCurrentBrainBootstrapTrigger {
        .explicitRefresh
    }

    private var conservativeRiskFallback: BASRiskLevel {
        .low
    }

    private var conservativeSourceSurfaceFallback: BASInteractionSurface {
        .app
    }

    private var conservativeMemorySourceFallback: BASMemorySource {
        .pattern
    }

    private func resolvedConfiguredDefaultMode(
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASDecisionMode {
        guard let configuredDefault = BASDecisionMode(identifier: defaultModeID) else {
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedConfiguredDefaultModeID,
                    identifier: defaultModeID,
                    fallbackIdentifier: conservativeModeFallback.identifier
                )
            )
            return conservativeModeFallback
        }
        return configuredDefault
    }

    private func resolvedConfiguredDefaultTrigger(
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASCurrentBrainBootstrapTrigger {
        guard let configuredDefault = BASCurrentBrainBootstrapTrigger(identifier: defaultTriggerID) else {
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedConfiguredDefaultTriggerID,
                    identifier: defaultTriggerID,
                    fallbackIdentifier: conservativeTriggerFallback.rawValue
                )
            )
            return conservativeTriggerFallback
        }
        return configuredDefault
    }

    private func resolvedConfiguredDefaultRiskLevel(
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASRiskLevel {
        guard let configuredDefault = BASRiskLevel(rawValue: defaultRiskLevelID) else {
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedConfiguredDefaultRiskLevelID,
                    identifier: defaultRiskLevelID,
                    fallbackIdentifier: conservativeRiskFallback.rawValue
                )
            )
            return conservativeRiskFallback
        }
        return configuredDefault
    }

    private func resolvedConfiguredDefaultSourceSurface(
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASInteractionSurface {
        guard let configuredDefault = BASInteractionSurface(rawValue: defaultSourceSurfaceID) else {
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedConfiguredDefaultSourceSurfaceID,
                    identifier: defaultSourceSurfaceID,
                    fallbackIdentifier: conservativeSourceSurfaceFallback.rawValue
                )
            )
            return conservativeSourceSurfaceFallback
        }
        return configuredDefault
    }

    private func resolvedConfiguredDefaultMemorySource(
        issues: inout [BASCurrentBrainBootstrapBehaviorIssue]
    ) -> BASMemorySource {
        guard let configuredDefault = memorySource(rawValue: defaultMemorySourceID) else {
            issues.append(
                BASCurrentBrainBootstrapBehaviorIssue(
                    kind: .unsupportedConfiguredDefaultMemorySourceID,
                    identifier: defaultMemorySourceID,
                    fallbackIdentifier: conservativeMemorySourceFallback.rawValue
                )
            )
            return conservativeMemorySourceFallback
        }
        return configuredDefault
    }
}

public struct BASCurrentBrainBootstrapPreparationRequest: Codable, Equatable, Sendable {
    public var mode: BASDecisionMode
    public var prompt: String
    public var trigger: BASCurrentBrainBootstrapTrigger
    public var sourceSurfaceOverride: BASInteractionSurface?
    public var riskLevelOverride: BASRiskLevel?
    public var preferredLanguages: [String]
    public var behavior: BASCurrentBrainBootstrapBehavior
    public var now: Date

    public init(
        mode: BASDecisionMode,
        prompt: String,
        trigger: BASCurrentBrainBootstrapTrigger,
        sourceSurfaceOverride: BASInteractionSurface? = nil,
        riskLevelOverride: BASRiskLevel? = nil,
        preferredLanguages: [String] = [],
        behavior: BASCurrentBrainBootstrapBehavior = .generic,
        now: Date = .now
    ) {
        self.mode = mode
        self.prompt = prompt
        self.trigger = trigger
        self.sourceSurfaceOverride = sourceSurfaceOverride
        self.riskLevelOverride = riskLevelOverride
        self.preferredLanguages = preferredLanguages
        self.behavior = behavior
        self.now = now
    }
}

public struct BASCurrentBrainBootstrapPreparation: Codable, Equatable, Sendable {
    public var mode: BASDecisionMode
    public var prompt: String
    public var trigger: BASCurrentBrainBootstrapTrigger
    public var sourceSurface: BASInteractionSurface
    public var riskLevel: BASRiskLevel
    public var languageMode: BASLanguageMode
    public var memorySource: BASMemorySource
    public var issues: [BASCurrentBrainBootstrapBehaviorIssue]
    public var now: Date

    private enum CodingKeys: String, CodingKey {
        case mode
        case prompt
        case trigger
        case sourceSurface
        case riskLevel
        case languageMode
        case memorySource
        case issues
        case now
    }

    public init(
        mode: BASDecisionMode,
        prompt: String,
        trigger: BASCurrentBrainBootstrapTrigger,
        sourceSurface: BASInteractionSurface,
        riskLevel: BASRiskLevel,
        languageMode: BASLanguageMode,
        memorySource: BASMemorySource,
        issues: [BASCurrentBrainBootstrapBehaviorIssue] = [],
        now: Date = .now
    ) {
        self.mode = mode
        self.prompt = prompt
        self.trigger = trigger
        self.sourceSurface = sourceSurface
        self.riskLevel = riskLevel
        self.languageMode = languageMode
        self.memorySource = memorySource
        self.issues = issues
        self.now = now
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            mode: try container.decode(BASDecisionMode.self, forKey: .mode),
            prompt: try container.decode(String.self, forKey: .prompt),
            trigger: try container.decode(BASCurrentBrainBootstrapTrigger.self, forKey: .trigger),
            sourceSurface: try container.decode(BASInteractionSurface.self, forKey: .sourceSurface),
            riskLevel: try container.decode(BASRiskLevel.self, forKey: .riskLevel),
            languageMode: try container.decode(BASLanguageMode.self, forKey: .languageMode),
            memorySource: try container.decode(BASMemorySource.self, forKey: .memorySource),
            issues: try container.decodeIfPresent([BASCurrentBrainBootstrapBehaviorIssue].self, forKey: .issues) ?? [],
            now: try container.decode(Date.self, forKey: .now)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(sourceSurface, forKey: .sourceSurface)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encode(languageMode, forKey: .languageMode)
        try container.encode(memorySource, forKey: .memorySource)
        try container.encode(issues, forKey: .issues)
        try container.encode(now, forKey: .now)
    }
}

public extension BASCurrentBrainBootstrapBehaviorIssue {
    var summaryLine: String {
        let fallbackText = fallbackIdentifier.map { " -> \($0)" } ?? ""
        switch kind {
        case .unsupportedRequestedModeID:
            return "Requested mode \(identifier) recovered\(fallbackText)"
        case .unsupportedRequestedTriggerID:
            return "Requested trigger \(identifier) recovered\(fallbackText)"
        case .unsupportedRequestedRiskLevelID:
            return "Requested risk \(identifier) recovered\(fallbackText)"
        case .unsupportedConfiguredDefaultModeID:
            return "Configured default mode \(identifier) recovered\(fallbackText)"
        case .unsupportedConfiguredDefaultTriggerID:
            return "Configured default trigger \(identifier) recovered\(fallbackText)"
        case .unsupportedConfiguredDefaultRiskLevelID:
            return "Configured default risk \(identifier) recovered\(fallbackText)"
        case .unsupportedConfiguredDefaultSourceSurfaceID:
            return "Configured source surface \(identifier) recovered\(fallbackText)"
        case .unsupportedConfiguredDefaultMemorySourceID:
            return "Configured memory source \(identifier) recovered\(fallbackText)"
        }
    }
}

public extension BASCurrentBrainBootstrapPreparation {
    var hasRecoverableIssues: Bool {
        !issues.isEmpty
    }

    var issueLines: [String] {
        issues.map(\.summaryLine)
    }
}

public struct BASCurrentBrainBootstrapExecutionRequest: Codable, Equatable, Sendable {
    public var preparation: BASCurrentBrainBootstrapPreparation
    public var projection: BASBrainProjection
    public var taskGraphHint: BASBrainTaskGraphHint?
    public var retrievalMode: String
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var recommendedTemplateIDs: [String]
    public var templates: [BASInterventionTemplateDescriptor]
    public var failurePatterns: [BASFailurePatternDescriptor]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        projection: BASBrainProjection,
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        recommendedTemplateIDs: [String] = [],
        templates: [BASInterventionTemplateDescriptor],
        failurePatterns: [BASFailurePatternDescriptor]
    ) {
        self.preparation = preparation
        self.projection = projection
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.recommendedTemplateIDs = recommendedTemplateIDs
        self.templates = templates
        self.failurePatterns = failurePatterns
    }
}

public struct BASCurrentBrainBootstrapExecution: Codable, Equatable, Sendable {
    public var preparation: BASCurrentBrainBootstrapPreparation
    public var bootstrapped: BASBootstrappedBrainState
    public var orderedTemplateIDs: [String]
    public var orderedFailurePatternIDs: [String]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        bootstrapped: BASBootstrappedBrainState,
        orderedTemplateIDs: [String],
        orderedFailurePatternIDs: [String]
    ) {
        self.preparation = preparation
        self.bootstrapped = bootstrapped
        self.orderedTemplateIDs = orderedTemplateIDs
        self.orderedFailurePatternIDs = orderedFailurePatternIDs
    }
}

public struct BASAppleCurrentBrainBootstrapTemplateInput: Codable, Equatable, Sendable {
    public var id: String
    public var mode: BASDecisionMode
    public var riskLevel: BASRiskLevel
    public var isPinned: Bool
    public var successCount: Int
    public var updatedAt: Date

    public init(
        id: String,
        mode: BASDecisionMode,
        riskLevel: BASRiskLevel,
        isPinned: Bool,
        successCount: Int,
        updatedAt: Date
    ) {
        self.id = id
        self.mode = mode
        self.riskLevel = riskLevel
        self.isPinned = isPinned
        self.successCount = successCount
        self.updatedAt = updatedAt
    }
}

public struct BASAppleCurrentBrainBootstrapFailurePatternInput: Codable, Equatable, Sendable {
    public var id: String
    public var mode: BASDecisionMode
    public var suppressionWeight: Double
    public var evidenceCount: Int
    public var updatedAt: Date

    public init(
        id: String,
        mode: BASDecisionMode,
        suppressionWeight: Double,
        evidenceCount: Int,
        updatedAt: Date
    ) {
        self.id = id
        self.mode = mode
        self.suppressionWeight = suppressionWeight
        self.evidenceCount = evidenceCount
        self.updatedAt = updatedAt
    }
}

public struct BASAppleTaskGraphHintInput: Codable, Equatable, Sendable {
    public var headline: String?
    public var activeNodeCount: Int
    public var hasResumeCandidate: Bool
    public var resumeHint: String?

    public init(
        headline: String?,
        activeNodeCount: Int,
        hasResumeCandidate: Bool,
        resumeHint: String?
    ) {
        self.headline = headline
        self.activeNodeCount = activeNodeCount
        self.hasResumeCandidate = hasResumeCandidate
        self.resumeHint = resumeHint
    }
}

public struct BASAppleCurrentBrainBootstrapPlanningSourceInput: Codable, Equatable, Sendable {
    public var preparationRequest: BASCurrentBrainBootstrapPreparationRequest
    public var projection: BASBrainProjection
    public var embeddingScores: [BASAppleEmbeddingScoreInput]
    public var taskGraphHint: BASAppleTaskGraphHintInput?
    public var retrievalMode: String
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var recommendedTemplateIDs: [String]
    public var templates: [BASAppleCurrentBrainBootstrapTemplateInput]
    public var failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]

    public init(
        preparationRequest: BASCurrentBrainBootstrapPreparationRequest,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASAppleTaskGraphHintInput? = nil,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        recommendedTemplateIDs: [String] = [],
        templates: [BASAppleCurrentBrainBootstrapTemplateInput],
        failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]
    ) {
        self.preparationRequest = preparationRequest
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.recommendedTemplateIDs = recommendedTemplateIDs
        self.templates = templates
        self.failurePatterns = failurePatterns
    }
}

public struct BASAppleCurrentBrainBootstrapPlanningPreparedInput: Codable, Equatable, Sendable {
    public var preparation: BASCurrentBrainBootstrapPreparation
    public var projection: BASBrainProjection
    public var embeddingScores: [BASAppleEmbeddingScoreInput]
    public var taskGraphHint: BASAppleTaskGraphHintInput?
    public var retrievalMode: String
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var recommendedTemplateIDs: [String]
    public var templates: [BASAppleCurrentBrainBootstrapTemplateInput]
    public var failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASAppleTaskGraphHintInput? = nil,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        recommendedTemplateIDs: [String] = [],
        templates: [BASAppleCurrentBrainBootstrapTemplateInput],
        failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]
    ) {
        self.preparation = preparation
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.recommendedTemplateIDs = recommendedTemplateIDs
        self.templates = templates
        self.failurePatterns = failurePatterns
    }
}

public struct BASAppleCurrentBrainBootstrapRequest: Codable, Equatable, Sendable {
    public var preparation: BASCurrentBrainBootstrapPreparation
    public var baseProjection: BASBrainProjection
    public var embeddingScores: [BASAppleEmbeddingScoreInput]
    public var taskGraphHint: BASBrainTaskGraphHint?
    public var retrievalMode: String
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var recommendedTemplateIDs: [String]
    public var templates: [BASAppleCurrentBrainBootstrapTemplateInput]
    public var failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        baseProjection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        recommendedTemplateIDs: [String] = [],
        templates: [BASAppleCurrentBrainBootstrapTemplateInput],
        failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]
    ) {
        self.preparation = preparation
        self.baseProjection = baseProjection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.recommendedTemplateIDs = recommendedTemplateIDs
        self.templates = templates
        self.failurePatterns = failurePatterns
    }
}

public struct BASAppleCurrentBrainBootstrapArtifact: Codable, Equatable, Sendable {
    public var execution: BASCurrentBrainBootstrapExecution
    public var persistenceInput: BASCurrentBrainUpdatePersistenceInput

    public init(
        execution: BASCurrentBrainBootstrapExecution,
        persistenceInput: BASCurrentBrainUpdatePersistenceInput
    ) {
        self.execution = execution
        self.persistenceInput = persistenceInput
    }
}

public struct BASAppleCurrentBrainBootstrapSourceInput: Codable, Equatable, Sendable {
    public var preparationRequest: BASCurrentBrainBootstrapPreparationRequest
    public var projection: BASBrainProjection
    public var embeddingScores: [BASAppleEmbeddingScoreInput]
    public var taskGraphHint: BASBrainTaskGraphHint?
    public var retrievalMode: String
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var recommendedTemplateIDs: [String]
    public var templates: [BASInterventionTemplateDescriptor]
    public var failurePatterns: [BASFailurePatternDescriptor]

    public init(
        preparationRequest: BASCurrentBrainBootstrapPreparationRequest,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        recommendedTemplateIDs: [String] = [],
        templates: [BASInterventionTemplateDescriptor],
        failurePatterns: [BASFailurePatternDescriptor]
    ) {
        self.preparationRequest = preparationRequest
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.recommendedTemplateIDs = recommendedTemplateIDs
        self.templates = templates
        self.failurePatterns = failurePatterns
    }
}

public struct BASAppleCurrentBrainBootstrapPreparedSourceInput: Codable, Equatable, Sendable {
    public var preparation: BASCurrentBrainBootstrapPreparation
    public var projection: BASBrainProjection
    public var embeddingScores: [BASAppleEmbeddingScoreInput]
    public var taskGraphHint: BASBrainTaskGraphHint?
    public var retrievalMode: String
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var recommendedTemplateIDs: [String]
    public var templates: [BASInterventionTemplateDescriptor]
    public var failurePatterns: [BASFailurePatternDescriptor]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        recommendedTemplateIDs: [String] = [],
        templates: [BASInterventionTemplateDescriptor],
        failurePatterns: [BASFailurePatternDescriptor]
    ) {
        self.preparation = preparation
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.recommendedTemplateIDs = recommendedTemplateIDs
        self.templates = templates
        self.failurePatterns = failurePatterns
    }
}

public enum BASCurrentBrainBootstrapCoordinator {
    public static func prepare(
        request: BASCurrentBrainBootstrapPreparationRequest
    ) -> BASCurrentBrainBootstrapPreparation {
        var issues: [BASCurrentBrainBootstrapBehaviorIssue] = []
        let sourceSurface = request.behavior.resolvedSourceSurface(
            for: request.trigger,
            override: request.sourceSurfaceOverride,
            issues: &issues
        )
        let languageMode = BASLanguageMode.detect(
            preferredLanguages: request.preferredLanguages,
            sampleTexts: [request.prompt]
        )
        let riskLevel = request.riskLevelOverride ?? BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: request.mode,
            prompt: request.prompt,
            now: request.now,
            behavior: request.behavior.bootstrapAdvisorBehavior
        )

        return BASCurrentBrainBootstrapPreparation(
            mode: request.mode,
            prompt: request.prompt,
            trigger: request.trigger,
            sourceSurface: sourceSurface,
            riskLevel: riskLevel,
            languageMode: languageMode,
            memorySource: request.behavior.memorySource(
                for: request.trigger,
                mode: request.mode,
                issues: &issues
            ),
            issues: issues,
            now: request.now
        )
    }

    public static func bootstrap(
        request: BASCurrentBrainBootstrapExecutionRequest
    ) -> BASCurrentBrainBootstrapExecution {
        let orderedTemplateIDs = BASBrainBootstrapAdvisor.orderedTemplateIDs(
            mode: request.preparation.mode,
            riskLevel: request.preparation.riskLevel,
            recommendedTemplateIDs: request.recommendedTemplateIDs,
            templates: request.templates
        )
        let orderedFailurePatternIDs = BASBrainBootstrapAdvisor.orderedFailurePatternIDs(
            mode: request.preparation.mode,
            failurePatterns: request.failurePatterns
        )

        var projection = request.projection
        projection.taskGraphHint = request.taskGraphHint
        projection.activeTemplateIDs = orderedTemplateIDs
        projection.failureGuardIDs = orderedFailurePatternIDs

        let bootstrapped = BASCognitionBootstrapper.bootstrap(
            request: BASBrainBootstrapRequest(
                mode: request.preparation.mode,
                prompt: request.preparation.prompt,
                source: request.preparation.memorySource,
                sourceSurface: request.preparation.sourceSurface,
                riskLevel: request.preparation.riskLevel,
                retrievalMode: request.retrievalMode,
                reactionWeightSeed: request.reactionWeightSeed,
                identityProfileOverride: request.identityProfileOverride,
                cognitionBehavior: request.cognitionBehavior,
                now: request.preparation.now
            ),
            projection: projection
        )

        return BASCurrentBrainBootstrapExecution(
            preparation: request.preparation,
            bootstrapped: bootstrapped,
            orderedTemplateIDs: orderedTemplateIDs,
            orderedFailurePatternIDs: orderedFailurePatternIDs
        )
    }
}

public enum BASAppleCurrentBrainBootstrapAdapter {
    public static func prepare(
        source input: BASAppleCurrentBrainBootstrapSourceInput
    ) -> BASCurrentBrainBootstrapPreparation {
        BASCurrentBrainBootstrapCoordinator.prepare(
            request: input.preparationRequest
        )
    }

    public static func execute(
        source input: BASAppleCurrentBrainBootstrapPreparedSourceInput
    ) -> BASCurrentBrainBootstrapExecution {
        BASCurrentBrainBootstrapCoordinator.bootstrap(
            request: BASCurrentBrainBootstrapExecutionRequest(
                preparation: input.preparation,
                projection: BASAppleMemoryProjectionAdapter.overlayEmbeddingScores(
                    input.embeddingScores,
                    on: input.projection
                ),
                taskGraphHint: input.taskGraphHint,
                retrievalMode: input.retrievalMode,
                reactionWeightSeed: input.reactionWeightSeed,
                identityProfileOverride: input.identityProfileOverride,
                cognitionBehavior: input.cognitionBehavior,
                recommendedTemplateIDs: input.recommendedTemplateIDs,
                templates: input.templates,
                failurePatterns: input.failurePatterns
            )
        )
    }

    public static func artifact(
        source input: BASAppleCurrentBrainBootstrapPreparedSourceInput
    ) -> BASAppleCurrentBrainBootstrapArtifact {
        let execution = execute(source: input)
        return BASAppleCurrentBrainBootstrapArtifact(
            execution: execution,
            persistenceInput: BASCurrentBrainPersistenceApplier.updateInput(
                mode: input.preparation.mode.identifier,
                bootstrapped: execution.bootstrapped
            )
        )
    }

    public static func artifact(
        source input: BASAppleCurrentBrainBootstrapSourceInput
    ) -> BASAppleCurrentBrainBootstrapArtifact {
        let preparation = prepare(source: input)
        return artifact(
            source: BASAppleCurrentBrainBootstrapPreparedSourceInput(
                preparation: preparation,
                projection: input.projection,
                embeddingScores: input.embeddingScores,
                taskGraphHint: input.taskGraphHint,
                retrievalMode: input.retrievalMode,
                reactionWeightSeed: input.reactionWeightSeed,
                identityProfileOverride: input.identityProfileOverride,
                cognitionBehavior: input.cognitionBehavior,
                recommendedTemplateIDs: input.recommendedTemplateIDs,
                templates: input.templates,
                failurePatterns: input.failurePatterns
            )
        )
    }

    public static func bootstrap(
        request: BASAppleCurrentBrainBootstrapRequest
    ) -> BASCurrentBrainBootstrapExecution {
        execute(
            source: BASAppleCurrentBrainBootstrapPreparedSourceInput(
                preparation: request.preparation,
                projection: request.baseProjection,
                embeddingScores: request.embeddingScores,
                taskGraphHint: request.taskGraphHint,
                retrievalMode: request.retrievalMode,
                reactionWeightSeed: request.reactionWeightSeed,
                identityProfileOverride: request.identityProfileOverride,
                cognitionBehavior: request.cognitionBehavior,
                recommendedTemplateIDs: request.recommendedTemplateIDs,
                templates: request.templates.map { template in
                    BASInterventionTemplateDescriptor(
                        id: template.id,
                        mode: template.mode,
                        riskLevel: template.riskLevel,
                        isPinned: template.isPinned,
                        successCount: template.successCount,
                        updatedAt: template.updatedAt
                    )
                },
                failurePatterns: request.failurePatterns.map { pattern in
                    BASFailurePatternDescriptor(
                        id: pattern.id,
                        mode: pattern.mode,
                        suppressionWeight: pattern.suppressionWeight,
                        evidenceCount: pattern.evidenceCount,
                        updatedAt: pattern.updatedAt
                    )
                }
            )
        )
    }

    public static func artifact(
        request: BASAppleCurrentBrainBootstrapRequest
    ) -> BASAppleCurrentBrainBootstrapArtifact {
        artifact(
            source: BASAppleCurrentBrainBootstrapPreparedSourceInput(
                preparation: request.preparation,
                projection: request.baseProjection,
                embeddingScores: request.embeddingScores,
                taskGraphHint: request.taskGraphHint,
                retrievalMode: request.retrievalMode,
                reactionWeightSeed: request.reactionWeightSeed,
                identityProfileOverride: request.identityProfileOverride,
                cognitionBehavior: request.cognitionBehavior,
                recommendedTemplateIDs: request.recommendedTemplateIDs,
                templates: request.templates.map { template in
                    BASInterventionTemplateDescriptor(
                        id: template.id,
                        mode: template.mode,
                        riskLevel: template.riskLevel,
                        isPinned: template.isPinned,
                        successCount: template.successCount,
                        updatedAt: template.updatedAt
                    )
                },
                failurePatterns: request.failurePatterns.map { pattern in
                    BASFailurePatternDescriptor(
                        id: pattern.id,
                        mode: pattern.mode,
                        suppressionWeight: pattern.suppressionWeight,
                        evidenceCount: pattern.evidenceCount,
                        updatedAt: pattern.updatedAt
                    )
                }
            )
        )
    }
}

public enum BASAppleBrainBootstrapRuntime {
    public static func bootstrap(
        request: BASBrainBootstrapRequest,
        projection: BASBrainProjection,
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        activeTemplateIDs: [String] = [],
        failureGuardIDs: [String] = []
    ) -> BASBootstrappedBrainState {
        var enrichedProjection = projection
        enrichedProjection.taskGraphHint = taskGraphHint
        enrichedProjection.activeTemplateIDs = activeTemplateIDs
        enrichedProjection.failureGuardIDs = failureGuardIDs
        return BASCognitionBootstrapper.bootstrap(
            request: request,
            projection: enrichedProjection
        )
    }
}

public enum BASAppleCurrentBrainStateCompiler {
    public static func sessionBootstrapBrainState(
        modeID: String,
        prompt: String,
        projection: BASBrainProjection,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        preferredLanguages: [String] = [],
        now: Date = .now
    ) throws -> BASDecisionBrainState {
        try brainState(
            modeID: modeID,
            prompt: prompt,
            projection: projection,
            retrievalMode: retrievalMode,
            triggerID: BASCurrentBrainBootstrapTrigger.sessionBootstrapID,
            sourceSurfaceOverrideID: BASInteractionSurface.app.rawValue,
            riskLevelOverrideID: BASRiskLevel.low.rawValue,
            reactionWeightSeed: reactionWeightSeed,
            identityProfileOverride: identityProfileOverride,
            cognitionBehavior: cognitionBehavior,
            preferredLanguages: preferredLanguages,
            now: now
        )
    }

    public static func brainState(
        modeID: String,
        prompt: String,
        projection: BASBrainProjection,
        retrievalMode: String,
        triggerID: String = BASCurrentBrainBootstrapTrigger.sessionBootstrapID,
        sourceSurfaceOverrideID: String? = BASInteractionSurface.app.rawValue,
        riskLevelOverrideID: String? = BASRiskLevel.low.rawValue,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        preferredLanguages: [String] = [],
        now: Date = .now
    ) throws -> BASDecisionBrainState {
        let request = try BASAppleBrainBootstrapRequestAdapter.request(
            modeID: modeID,
            prompt: prompt,
            triggerID: triggerID,
            sourceSurfaceOverrideID: sourceSurfaceOverrideID,
            riskLevelOverrideID: riskLevelOverrideID,
            bootstrapBehavior: .generic,
            reactionWeightSeed: reactionWeightSeed,
            identityProfileOverride: identityProfileOverride,
            cognitionBehavior: cognitionBehavior,
            preferredLanguages: preferredLanguages,
            now: now,
            retrievalMode: retrievalMode
        )
        return BASAppleBrainBootstrapRuntime.bootstrap(
            request: request,
            projection: projection
        ).brainState
    }
}

public enum BASAppleCurrentBrainProjectionStateCompiler {
    public static func appSessionBrainState(
        modeID: String,
        prompt: String,
        projection: BASBrainProjection,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        preferredLanguages: [String] = [],
        now: Date = .now
    ) throws -> BASDecisionBrainState {
        try BASAppleCurrentBrainStateCompiler.sessionBootstrapBrainState(
            modeID: modeID,
            prompt: prompt,
            projection: projection,
            retrievalMode: retrievalMode,
            reactionWeightSeed: reactionWeightSeed,
            identityProfileOverride: identityProfileOverride,
            cognitionBehavior: cognitionBehavior,
            preferredLanguages: preferredLanguages,
            now: now
        )
    }
}

public enum BASAppleCurrentBrainBootstrapPlanner {
    public static func request(
        from input: BASAppleCurrentBrainBootstrapPlanningSourceInput
    ) -> BASAppleCurrentBrainBootstrapRequest {
        BASAppleCurrentBrainBootstrapRequest(
            preparation: BASCurrentBrainBootstrapCoordinator.prepare(
                request: input.preparationRequest
            ),
            baseProjection: input.projection,
            embeddingScores: input.embeddingScores,
            taskGraphHint: taskGraphHint(from: input.taskGraphHint),
            retrievalMode: input.retrievalMode,
            reactionWeightSeed: input.reactionWeightSeed,
            identityProfileOverride: input.identityProfileOverride,
            cognitionBehavior: input.cognitionBehavior,
            recommendedTemplateIDs: input.recommendedTemplateIDs,
            templates: input.templates,
            failurePatterns: input.failurePatterns
        )
    }

    public static func request(
        from input: BASAppleCurrentBrainBootstrapPlanningPreparedInput
    ) -> BASAppleCurrentBrainBootstrapRequest {
        BASAppleCurrentBrainBootstrapRequest(
            preparation: input.preparation,
            baseProjection: input.projection,
            embeddingScores: input.embeddingScores,
            taskGraphHint: taskGraphHint(from: input.taskGraphHint),
            retrievalMode: input.retrievalMode,
            reactionWeightSeed: input.reactionWeightSeed,
            identityProfileOverride: input.identityProfileOverride,
            cognitionBehavior: input.cognitionBehavior,
            recommendedTemplateIDs: input.recommendedTemplateIDs,
            templates: input.templates,
            failurePatterns: input.failurePatterns
        )
    }

    public static func execute(
        source input: BASAppleCurrentBrainBootstrapPlanningPreparedInput
    ) -> BASCurrentBrainBootstrapExecution {
        BASAppleCurrentBrainBootstrapAdapter.bootstrap(request: request(from: input))
    }

    public static func artifact(
        source input: BASAppleCurrentBrainBootstrapPlanningPreparedInput
    ) -> BASAppleCurrentBrainBootstrapArtifact {
        BASAppleCurrentBrainBootstrapAdapter.artifact(request: request(from: input))
    }

    public static func artifact(
        source input: BASAppleCurrentBrainBootstrapPlanningSourceInput
    ) -> BASAppleCurrentBrainBootstrapArtifact {
        BASAppleCurrentBrainBootstrapAdapter.artifact(request: request(from: input))
    }

    private static func taskGraphHint(
        from input: BASAppleTaskGraphHintInput?
    ) -> BASBrainTaskGraphHint? {
        guard let input else { return nil }
        return BASBrainTaskGraphHint(
            headline: input.headline ?? input.resumeHint ?? "Resume current work",
            activeNodeCount: input.activeNodeCount,
            hasResumeCandidate: input.hasResumeCandidate,
            resumeHint: input.resumeHint
        )
    }
}
