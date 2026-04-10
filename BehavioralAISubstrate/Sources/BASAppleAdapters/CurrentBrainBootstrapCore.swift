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
    public var recommendedTemplateIDs: [String]
    public var templates: [BASAppleCurrentBrainBootstrapTemplateInput]
    public var failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]

    public init(
        preparationRequest: BASCurrentBrainBootstrapPreparationRequest,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASAppleTaskGraphHintInput? = nil,
        retrievalMode: String,
        recommendedTemplateIDs: [String] = [],
        templates: [BASAppleCurrentBrainBootstrapTemplateInput],
        failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]
    ) {
        self.preparationRequest = preparationRequest
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
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
    public var recommendedTemplateIDs: [String]
    public var templates: [BASAppleCurrentBrainBootstrapTemplateInput]
    public var failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASAppleTaskGraphHintInput? = nil,
        retrievalMode: String,
        recommendedTemplateIDs: [String] = [],
        templates: [BASAppleCurrentBrainBootstrapTemplateInput],
        failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]
    ) {
        self.preparation = preparation
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
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
    public var recommendedTemplateIDs: [String]
    public var templates: [BASAppleCurrentBrainBootstrapTemplateInput]
    public var failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        baseProjection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        retrievalMode: String,
        recommendedTemplateIDs: [String] = [],
        templates: [BASAppleCurrentBrainBootstrapTemplateInput],
        failurePatterns: [BASAppleCurrentBrainBootstrapFailurePatternInput]
    ) {
        self.preparation = preparation
        self.baseProjection = baseProjection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
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
    public var recommendedTemplateIDs: [String]
    public var templates: [BASInterventionTemplateDescriptor]
    public var failurePatterns: [BASFailurePatternDescriptor]

    public init(
        preparationRequest: BASCurrentBrainBootstrapPreparationRequest,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        retrievalMode: String,
        recommendedTemplateIDs: [String] = [],
        templates: [BASInterventionTemplateDescriptor],
        failurePatterns: [BASFailurePatternDescriptor]
    ) {
        self.preparationRequest = preparationRequest
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
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
    public var recommendedTemplateIDs: [String]
    public var templates: [BASInterventionTemplateDescriptor]
    public var failurePatterns: [BASFailurePatternDescriptor]

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        retrievalMode: String,
        recommendedTemplateIDs: [String] = [],
        templates: [BASInterventionTemplateDescriptor],
        failurePatterns: [BASFailurePatternDescriptor]
    ) {
        self.preparation = preparation
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.recommendedTemplateIDs = recommendedTemplateIDs
        self.templates = templates
        self.failurePatterns = failurePatterns
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
                mode: input.preparation.mode.rawValue,
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
