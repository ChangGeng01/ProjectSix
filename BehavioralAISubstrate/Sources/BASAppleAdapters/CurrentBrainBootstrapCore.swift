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
    case sessionPrime

    public var defaultSourceSurface: BASInteractionSurface {
        switch self {
        case .watchHandoff:
            .watch
        case .notification:
            .notification
        case .widget:
            .widget
        case .launch, .sceneActive, .explicitRefresh, .sessionPrime:
            .app
        }
    }

    public func memorySource(for mode: BASDecisionMode) -> BASMemorySource {
        if mode == .mirror {
            return .reflection
        }

        switch self {
        case .watchHandoff, .notification, .widget:
            return .reminder
        case .explicitRefresh, .sessionPrime:
            return .pattern
        case .launch, .sceneActive:
            return .history
        }
    }
}

public struct BASCurrentBrainBootstrapPreparationRequest: Codable, Equatable, Sendable {
    public var mode: BASDecisionMode
    public var prompt: String
    public var trigger: BASCurrentBrainBootstrapTrigger
    public var sourceSurfaceOverride: BASInteractionSurface?
    public var riskLevelOverride: BASRiskLevel?
    public var preferredLanguages: [String]
    public var now: Date

    public init(
        mode: BASDecisionMode,
        prompt: String,
        trigger: BASCurrentBrainBootstrapTrigger,
        sourceSurfaceOverride: BASInteractionSurface? = nil,
        riskLevelOverride: BASRiskLevel? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now
    ) {
        self.mode = mode
        self.prompt = prompt
        self.trigger = trigger
        self.sourceSurfaceOverride = sourceSurfaceOverride
        self.riskLevelOverride = riskLevelOverride
        self.preferredLanguages = preferredLanguages
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
    public var now: Date

    public init(
        mode: BASDecisionMode,
        prompt: String,
        trigger: BASCurrentBrainBootstrapTrigger,
        sourceSurface: BASInteractionSurface,
        riskLevel: BASRiskLevel,
        languageMode: BASLanguageMode,
        memorySource: BASMemorySource,
        now: Date = .now
    ) {
        self.mode = mode
        self.prompt = prompt
        self.trigger = trigger
        self.sourceSurface = sourceSurface
        self.riskLevel = riskLevel
        self.languageMode = languageMode
        self.memorySource = memorySource
        self.now = now
    }
}

public struct BASCurrentBrainBootstrapExecutionRequest: Codable, Equatable, Sendable {
    public var preparation: BASCurrentBrainBootstrapPreparation
    public var projection: BASBrainProjection
    public var taskGraphHint: BASBrainTaskGraphHint?
    public var retrievalMode: String
    public var recommendedTemplateIDs: [String]
    public var templates: [BASInterventionTemplateDescriptor]
    public var failurePatterns: [BASFailurePatternDescriptor]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        projection: BASBrainProjection,
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        retrievalMode: String,
        recommendedTemplateIDs: [String] = [],
        templates: [BASInterventionTemplateDescriptor],
        failurePatterns: [BASFailurePatternDescriptor]
    ) {
        self.preparation = preparation
        self.projection = projection
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
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

public enum BASCurrentBrainBootstrapCoordinator {
    public static func prepare(
        request: BASCurrentBrainBootstrapPreparationRequest
    ) -> BASCurrentBrainBootstrapPreparation {
        let sourceSurface = request.sourceSurfaceOverride ?? request.trigger.defaultSourceSurface
        let languageMode = BASLanguageMode.detect(
            preferredLanguages: request.preferredLanguages,
            sampleTexts: [request.prompt]
        )
        let riskLevel = request.riskLevelOverride ?? BASBrainBootstrapAdvisor.inferRiskLevel(
            mode: request.mode,
            prompt: request.prompt,
            now: request.now
        )

        return BASCurrentBrainBootstrapPreparation(
            mode: request.mode,
            prompt: request.prompt,
            trigger: request.trigger,
            sourceSurface: sourceSurface,
            riskLevel: riskLevel,
            languageMode: languageMode,
            memorySource: request.trigger.memorySource(for: request.mode),
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
                sourceSurface: resolvedSourceSurface(
                    trigger: request.preparation.trigger,
                    sourceSurface: request.preparation.sourceSurface
                ),
                riskLevel: request.preparation.riskLevel,
                retrievalMode: request.retrievalMode,
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

    private static func resolvedSourceSurface(
        trigger: BASCurrentBrainBootstrapTrigger,
        sourceSurface: BASInteractionSurface
    ) -> BASInteractionSurface {
        switch trigger {
        case .notification:
            .notification
        default:
            sourceSurface
        }
    }
}
