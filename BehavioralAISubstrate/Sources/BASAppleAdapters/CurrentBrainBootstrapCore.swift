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
}

public struct BASCurrentBrainBootstrapBehavior: Codable, Equatable, Sendable {
    public static let generic = BASCurrentBrainBootstrapBehavior()

    public var defaultSourceSurfaceID: String
    public var sourceSurfaceOverridesByTriggerID: [String: String]
    public var enforcedSourceSurfaceByTriggerID: [String: String]
    public var defaultMemorySourceID: String
    public var memorySourceOverridesByTriggerID: [String: String]
    public var memorySourceOverridesByModeID: [String: String]
    public var memorySourceOverridesByTriggerAndModeID: [String: [String: String]]
    public var bootstrapAdvisorBehavior: BASBrainBootstrapAdvisorBehavior

    public init(
        defaultSourceSurfaceID: String = BASInteractionSurface.app.rawValue,
        sourceSurfaceOverridesByTriggerID: [String: String] = [
            BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.watch.rawValue,
            BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue,
            BASCurrentBrainBootstrapTrigger.widget.rawValue: BASInteractionSurface.widget.rawValue
        ],
        enforcedSourceSurfaceByTriggerID: [String: String] = [
            BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue
        ],
        defaultMemorySourceID: String = BASMemorySource.history.rawValue,
        memorySourceOverridesByTriggerID: [String: String] = [:],
        memorySourceOverridesByModeID: [String: String] = [:],
        memorySourceOverridesByTriggerAndModeID: [String: [String: String]] = [:],
        bootstrapAdvisorBehavior: BASBrainBootstrapAdvisorBehavior = .generic
    ) {
        self.defaultSourceSurfaceID = defaultSourceSurfaceID
        self.sourceSurfaceOverridesByTriggerID = sourceSurfaceOverridesByTriggerID
        self.enforcedSourceSurfaceByTriggerID = enforcedSourceSurfaceByTriggerID
        self.defaultMemorySourceID = defaultMemorySourceID
        self.memorySourceOverridesByTriggerID = memorySourceOverridesByTriggerID
        self.memorySourceOverridesByModeID = memorySourceOverridesByModeID
        self.memorySourceOverridesByTriggerAndModeID = memorySourceOverridesByTriggerAndModeID
        self.bootstrapAdvisorBehavior = bootstrapAdvisorBehavior
    }

    public func resolvedSourceSurface(
        for trigger: BASCurrentBrainBootstrapTrigger,
        override: BASInteractionSurface?
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
        return BASInteractionSurface(rawValue: defaultSourceSurfaceID) ?? .app
    }

    public func memorySource(
        for trigger: BASCurrentBrainBootstrapTrigger,
        mode: BASDecisionMode
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
        return BASMemorySource(rawValue: defaultMemorySourceID) ?? .history
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
            if let source = mapping[candidate].flatMap(BASMemorySource.init(rawValue:)) {
                return source
            }
        }
        return nil
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
        let sourceSurface = request.behavior.resolvedSourceSurface(
            for: request.trigger,
            override: request.sourceSurfaceOverride
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
                mode: request.mode
            ),
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
    public static func sessionPrimeBrainState(
        modeID: String,
        prompt: String,
        projection: BASBrainProjection,
        retrievalMode: String,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        preferredLanguages: [String] = [],
        now: Date = .now
    ) -> BASDecisionBrainState {
        brainState(
            modeID: modeID,
            prompt: prompt,
            projection: projection,
            retrievalMode: retrievalMode,
            triggerID: BASCurrentBrainBootstrapTrigger.sessionPrime.rawValue,
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
        triggerID: String = BASCurrentBrainBootstrapTrigger.sessionPrime.rawValue,
        sourceSurfaceOverrideID: String? = BASInteractionSurface.app.rawValue,
        riskLevelOverrideID: String? = BASRiskLevel.low.rawValue,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior = .generic,
        preferredLanguages: [String] = [],
        now: Date = .now
    ) -> BASDecisionBrainState {
        let request = BASAppleBrainBootstrapRequestAdapter.request(
            modeID: modeID,
            prompt: prompt,
            triggerID: triggerID,
            sourceSurfaceOverrideID: sourceSurfaceOverrideID,
            riskLevelOverrideID: riskLevelOverrideID,
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
    ) -> BASDecisionBrainState {
        BASAppleCurrentBrainStateCompiler.sessionPrimeBrainState(
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
