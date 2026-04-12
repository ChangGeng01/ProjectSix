import Foundation
import SwiftData
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASAppleCurrentBrainBootstrapHostResolutionError: Error, Equatable, Sendable {
    case unsupportedModeID(String)
    case unsupportedTriggerID(String)
    case unsupportedRiskLevelID(String)
    case unsupportedSourceSurfaceID(String)
    case unsupportedTemplateModeID(String)
    case unsupportedTemplateRiskLevelID(String)
    case unsupportedFailurePatternModeID(String)
    case incompleteTaskGraphHint
}

public struct BASAppleCurrentBrainBootstrapHostTemplateInput: Codable, Equatable, Sendable {
    public var id: String
    public var modeID: String
    public var riskLevelID: String
    public var isPinned: Bool
    public var successCount: Int
    public var updatedAt: Date

    public init(
        id: String,
        modeID: String,
        riskLevelID: String,
        isPinned: Bool,
        successCount: Int,
        updatedAt: Date
    ) {
        self.id = id
        self.modeID = modeID
        self.riskLevelID = riskLevelID
        self.isPinned = isPinned
        self.successCount = successCount
        self.updatedAt = updatedAt
    }
}

public struct BASAppleCurrentBrainBootstrapHostFailurePatternInput: Codable, Equatable, Sendable {
    public var id: String
    public var modeID: String
    public var suppressionWeight: Double
    public var evidenceCount: Int
    public var updatedAt: Date

    public init(
        id: String,
        modeID: String,
        suppressionWeight: Double,
        evidenceCount: Int,
        updatedAt: Date
    ) {
        self.id = id
        self.modeID = modeID
        self.suppressionWeight = suppressionWeight
        self.evidenceCount = evidenceCount
        self.updatedAt = updatedAt
    }
}

public struct BASAppleCurrentBrainBootstrapHostTaskGraphInput: Codable, Equatable, Sendable {
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

public struct BASAppleCurrentBrainBootstrapHostSourceInput: Codable, Equatable, Sendable {
    public var modeID: String
    public var prompt: String
    public var triggerID: String
    public var sourceSurfaceOverrideID: String?
    public var riskLevelOverrideID: String?
    public var preferredLanguages: [String]
    public var now: Date
    public var projection: BASBrainProjection
    public var embeddingScores: [BASAppleEmbeddingScoreInput]
    public var taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput?
    public var retrievalMode: String
    public var bootstrapBehavior: BASCurrentBrainBootstrapBehavior
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var recommendedTemplateIDs: [String]
    public var templates: [BASAppleCurrentBrainBootstrapHostTemplateInput]
    public var failurePatterns: [BASAppleCurrentBrainBootstrapHostFailurePatternInput]

    public init(
        modeID: String,
        prompt: String,
        triggerID: String,
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput? = nil,
        retrievalMode: String,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior,
        recommendedTemplateIDs: [String] = [],
        templates: [BASAppleCurrentBrainBootstrapHostTemplateInput],
        failurePatterns: [BASAppleCurrentBrainBootstrapHostFailurePatternInput]
    ) {
        self.modeID = modeID
        self.prompt = prompt
        self.triggerID = triggerID
        self.sourceSurfaceOverrideID = sourceSurfaceOverrideID
        self.riskLevelOverrideID = riskLevelOverrideID
        self.preferredLanguages = preferredLanguages
        self.now = now
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.bootstrapBehavior = bootstrapBehavior
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.recommendedTemplateIDs = recommendedTemplateIDs
        self.templates = templates
        self.failurePatterns = failurePatterns
    }
}

public struct BASAppleCurrentBrainBootstrapHostBuildContext: Codable, Equatable, Sendable {
    public var modeID: String
    public var prompt: String
    public var triggerID: String
    public var sourceSurfaceOverrideID: String?
    public var riskLevelOverrideID: String?
    public var preferredLanguages: [String]
    public var now: Date
    public var projection: BASBrainProjection
    public var embeddingScores: [BASAppleEmbeddingScoreInput]
    public var taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput?
    public var retrievalMode: String
    public var bootstrapBehavior: BASCurrentBrainBootstrapBehavior
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior
    public var recommendedTemplateIDs: [String]

    public init(
        modeID: String,
        prompt: String,
        triggerID: String,
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput? = nil,
        retrievalMode: String,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior,
        recommendedTemplateIDs: [String] = []
    ) {
        self.modeID = modeID
        self.prompt = prompt
        self.triggerID = triggerID
        self.sourceSurfaceOverrideID = sourceSurfaceOverrideID
        self.riskLevelOverrideID = riskLevelOverrideID
        self.preferredLanguages = preferredLanguages
        self.now = now
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHint = taskGraphHint
        self.retrievalMode = retrievalMode
        self.bootstrapBehavior = bootstrapBehavior
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
        self.recommendedTemplateIDs = recommendedTemplateIDs
    }
}

public enum BASAppleCurrentBrainBootstrapHostInputBuilder {
    public static func context<TaskGraph>(
        modeID: String,
        prompt: String,
        triggerID: String,
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraph: TaskGraph? = nil,
        headline: (TaskGraph) -> String?,
        activeNodeCount: (TaskGraph) -> Int,
        hasResumeCandidate: (TaskGraph) -> Bool,
        resumeHint: (TaskGraph) -> String?,
        retrievalMode: String,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior,
        recommendedTemplateIDs: [String] = []
    ) -> BASAppleCurrentBrainBootstrapHostBuildContext {
        BASAppleCurrentBrainBootstrapHostBuildContext(
            modeID: modeID,
            prompt: prompt,
            triggerID: triggerID,
            sourceSurfaceOverrideID: sourceSurfaceOverrideID,
            riskLevelOverrideID: riskLevelOverrideID,
            preferredLanguages: preferredLanguages,
            now: now,
            projection: projection,
            embeddingScores: embeddingScores,
            taskGraphHint: taskGraph.map { graph in
                taskGraphInput(
                    headline: headline(graph),
                    activeNodeCount: activeNodeCount(graph),
                    hasResumeCandidate: hasResumeCandidate(graph),
                    resumeHint: resumeHint(graph)
                )
            },
            retrievalMode: retrievalMode,
            bootstrapBehavior: bootstrapBehavior,
            reactionWeightSeed: reactionWeightSeed,
            identityProfileOverride: identityProfileOverride,
            cognitionBehavior: cognitionBehavior,
            recommendedTemplateIDs: recommendedTemplateIDs
        )
    }

    public static func taskGraphInput(
        headline: String?,
        activeNodeCount: Int,
        hasResumeCandidate: Bool,
        resumeHint: String?
    ) -> BASAppleCurrentBrainBootstrapHostTaskGraphInput {
        BASAppleCurrentBrainBootstrapHostTaskGraphInput(
            headline: headline,
            activeNodeCount: activeNodeCount,
            hasResumeCandidate: hasResumeCandidate,
            resumeHint: resumeHint
        )
    }

    public static func build<Template, FailurePattern>(
        context: BASAppleCurrentBrainBootstrapHostBuildContext,
        templates: [Template],
        failurePatterns: [FailurePattern],
        mapTemplate: (Template) -> BASAppleCurrentBrainBootstrapHostTemplateInput,
        mapFailurePattern: (FailurePattern) -> BASAppleCurrentBrainBootstrapHostFailurePatternInput
    ) -> BASAppleCurrentBrainBootstrapHostSourceInput {
        BASAppleCurrentBrainBootstrapHostSourceInput(
            modeID: context.modeID,
            prompt: context.prompt,
            triggerID: context.triggerID,
            sourceSurfaceOverrideID: context.sourceSurfaceOverrideID,
            riskLevelOverrideID: context.riskLevelOverrideID,
            preferredLanguages: context.preferredLanguages,
            now: context.now,
            projection: context.projection,
            embeddingScores: context.embeddingScores,
            taskGraphHint: context.taskGraphHint,
            retrievalMode: context.retrievalMode,
            bootstrapBehavior: context.bootstrapBehavior,
            reactionWeightSeed: context.reactionWeightSeed,
            identityProfileOverride: context.identityProfileOverride,
            cognitionBehavior: context.cognitionBehavior,
            recommendedTemplateIDs: context.recommendedTemplateIDs,
            templates: templates.map(mapTemplate),
            failurePatterns: failurePatterns.map(mapFailurePattern)
        )
    }
}

public enum BASAppleCurrentBrainBootstrapHostAdapter {
    public static func prepare(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) throws -> BASCurrentBrainBootstrapPreparation {
        try request(from: input).preparation
    }

    public static func execute(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) throws -> BASCurrentBrainBootstrapExecution {
        BASAppleCurrentBrainBootstrapAdapter.bootstrap(
            request: try request(from: input)
        )
    }

    public static func artifact(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) throws -> BASAppleCurrentBrainBootstrapArtifact {
        BASAppleCurrentBrainBootstrapAdapter.artifact(
            request: try request(from: input)
        )
    }

    public static func request(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) throws -> BASAppleCurrentBrainBootstrapRequest {
        BASAppleCurrentBrainBootstrapPlanner.request(from: try planningInput(from: input))
    }

    private static func planningInput(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) throws -> BASAppleCurrentBrainBootstrapPlanningSourceInput {
        let behavior = input.bootstrapBehavior
        guard let preparationMode = BASDecisionMode(identifier: behavior.canonicalModeID(for: input.modeID)) else {
            throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedModeID(input.modeID)
        }
        guard let preparationTrigger = BASCurrentBrainBootstrapTrigger(identifier: behavior.canonicalTriggerID(for: input.triggerID)) else {
            throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedTriggerID(input.triggerID)
        }
        let sourceSurfaceOverride: BASInteractionSurface?
        if let sourceSurfaceOverrideID = input.sourceSurfaceOverrideID {
            guard let resolvedSourceSurfaceOverride = BASInteractionSurface(rawValue: sourceSurfaceOverrideID) else {
                throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedSourceSurfaceID(sourceSurfaceOverrideID)
            }
            sourceSurfaceOverride = resolvedSourceSurfaceOverride
        } else {
            sourceSurfaceOverride = nil
        }
        let preparationRiskLevel: BASRiskLevel?
        if let riskLevelOverrideID = input.riskLevelOverrideID {
            guard let resolvedRiskLevel = BASRiskLevel(rawValue: behavior.canonicalRiskLevelID(for: riskLevelOverrideID)) else {
                throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedRiskLevelID(riskLevelOverrideID)
            }
            preparationRiskLevel = resolvedRiskLevel
        } else {
            preparationRiskLevel = nil
        }
        return BASAppleCurrentBrainBootstrapPlanningSourceInput(
            preparationRequest: BASCurrentBrainBootstrapPreparationRequest(
                mode: preparationMode,
                prompt: input.prompt,
                trigger: preparationTrigger,
                sourceSurfaceOverride: sourceSurfaceOverride,
                riskLevelOverride: preparationRiskLevel,
                preferredLanguages: input.preferredLanguages,
                behavior: behavior,
                now: input.now
            ),
            projection: input.projection,
            embeddingScores: input.embeddingScores,
            taskGraphHint: input.taskGraphHint.map {
                BASAppleTaskGraphHintInput(
                    headline: $0.headline,
                    activeNodeCount: $0.activeNodeCount,
                    hasResumeCandidate: $0.hasResumeCandidate,
                    resumeHint: $0.resumeHint
                )
            },
            retrievalMode: input.retrievalMode,
            reactionWeightSeed: input.reactionWeightSeed,
            identityProfileOverride: input.identityProfileOverride,
            cognitionBehavior: input.cognitionBehavior,
            recommendedTemplateIDs: input.recommendedTemplateIDs,
            templates: try input.templates.map { template in
                guard let mode = BASDecisionMode(identifier: behavior.canonicalModeID(for: template.modeID)) else {
                    throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedTemplateModeID(template.modeID)
                }
                guard let riskLevel = BASRiskLevel(rawValue: behavior.canonicalRiskLevelID(for: template.riskLevelID)) else {
                    throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedTemplateRiskLevelID(template.riskLevelID)
                }

                return BASAppleCurrentBrainBootstrapTemplateInput(
                    id: template.id,
                    mode: mode,
                    riskLevel: riskLevel,
                    isPinned: template.isPinned,
                    successCount: template.successCount,
                    updatedAt: template.updatedAt
                )
            },
            failurePatterns: try input.failurePatterns.map { pattern in
                guard let mode = BASDecisionMode(identifier: behavior.canonicalModeID(for: pattern.modeID)) else {
                    throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedFailurePatternModeID(pattern.modeID)
                }

                return BASAppleCurrentBrainBootstrapFailurePatternInput(
                    id: pattern.id,
                    mode: mode,
                    suppressionWeight: pattern.suppressionWeight,
                    evidenceCount: pattern.evidenceCount,
                    updatedAt: pattern.updatedAt
                )
            }
        )
    }
}

public enum BASAppleCurrentBrainBootstrapCoordinator {
    public static func artifact<Template, FailurePattern>(
        context: BASAppleCurrentBrainBootstrapHostBuildContext,
        recommendTemplateIDs: (BASCurrentBrainBootstrapPreparation) -> [String],
        selectTemplates: (BASCurrentBrainBootstrapPreparation, [String]) -> [Template],
        selectFailurePatterns: (BASCurrentBrainBootstrapPreparation) -> [FailurePattern],
        mapTemplate: (Template) -> BASAppleCurrentBrainBootstrapHostTemplateInput,
        mapFailurePattern: (FailurePattern) -> BASAppleCurrentBrainBootstrapHostFailurePatternInput
    ) throws -> BASAppleCurrentBrainBootstrapArtifact {
        try artifact(
            baseInput: BASAppleCurrentBrainBootstrapHostInputBuilder.build(
                context: context,
                templates: [Template](),
                failurePatterns: [FailurePattern](),
                mapTemplate: mapTemplate,
                mapFailurePattern: mapFailurePattern
            ),
            recommendTemplateIDs: recommendTemplateIDs,
            selectTemplates: selectTemplates,
            selectFailurePatterns: selectFailurePatterns,
            mapTemplate: mapTemplate,
            mapFailurePattern: mapFailurePattern
        )
    }

    public static func artifact<Template, FailurePattern>(
        baseInput: BASAppleCurrentBrainBootstrapHostSourceInput,
        recommendTemplateIDs: (BASCurrentBrainBootstrapPreparation) -> [String],
        selectTemplates: (BASCurrentBrainBootstrapPreparation, [String]) -> [Template],
        selectFailurePatterns: (BASCurrentBrainBootstrapPreparation) -> [FailurePattern],
        mapTemplate: (Template) -> BASAppleCurrentBrainBootstrapHostTemplateInput,
        mapFailurePattern: (FailurePattern) -> BASAppleCurrentBrainBootstrapHostFailurePatternInput
    ) throws -> BASAppleCurrentBrainBootstrapArtifact {
        let preparation = try BASAppleCurrentBrainBootstrapHostAdapter.prepare(from: baseInput)
        let recommendedTemplateIDs = recommendTemplateIDs(preparation)
        let templates = selectTemplates(preparation, recommendedTemplateIDs).map(mapTemplate)
        let failurePatterns = selectFailurePatterns(preparation).map(mapFailurePattern)

        return try BASAppleCurrentBrainBootstrapHostAdapter.artifact(
            from: BASAppleCurrentBrainBootstrapHostSourceInput(
                modeID: baseInput.modeID,
                prompt: baseInput.prompt,
                triggerID: baseInput.triggerID,
                sourceSurfaceOverrideID: baseInput.sourceSurfaceOverrideID,
                riskLevelOverrideID: baseInput.riskLevelOverrideID,
                preferredLanguages: baseInput.preferredLanguages,
                now: baseInput.now,
                projection: baseInput.projection,
                embeddingScores: baseInput.embeddingScores,
                taskGraphHint: baseInput.taskGraphHint,
                retrievalMode: baseInput.retrievalMode,
                bootstrapBehavior: baseInput.bootstrapBehavior,
                reactionWeightSeed: baseInput.reactionWeightSeed,
                identityProfileOverride: baseInput.identityProfileOverride,
                cognitionBehavior: baseInput.cognitionBehavior,
                recommendedTemplateIDs: recommendedTemplateIDs,
                templates: templates,
                failurePatterns: failurePatterns
            )
        )
    }
}

public struct BASAppleCurrentBrainBootstrapCommitResult<
    Update: BASAppleCurrentBrainUpdateEntity,
    Checkpoint: BASAppleEvolutionCheckpointEntity
> {
    public var preparation: BASCurrentBrainBootstrapPreparation
    public var brainState: BASDecisionBrainState
    public var dominantGoal: String?
    public var activeConstraints: [String]
    public var orderedTemplateIDs: [String]
    public var orderedFailurePatternIDs: [String]
    public var commit: BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint>

    public init(
        preparation: BASCurrentBrainBootstrapPreparation,
        brainState: BASDecisionBrainState,
        dominantGoal: String?,
        activeConstraints: [String],
        orderedTemplateIDs: [String],
        orderedFailurePatternIDs: [String],
        commit: BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint>
    ) {
        self.preparation = preparation
        self.brainState = brainState
        self.dominantGoal = dominantGoal
        self.activeConstraints = activeConstraints
        self.orderedTemplateIDs = orderedTemplateIDs
        self.orderedFailurePatternIDs = orderedFailurePatternIDs
        self.commit = commit
    }
}

public struct BASAppleCurrentBrainBootstrapBridgeInput: Codable, Equatable, Sendable {
    public var modeID: String
    public var prompt: String
    public var triggerID: String
    public var sourceSurfaceOverrideID: String?
    public var riskLevelOverrideID: String?
    public var preferredLanguages: [String]
    public var now: Date
    public var projection: BASBrainProjection
    public var embeddingScores: [BASAppleEmbeddingScoreInput]
    public var taskGraphHeadline: String?
    public var taskGraphActiveNodeCount: Int?
    public var taskGraphHasResumeCandidate: Bool?
    public var taskGraphResumeHint: String?
    public var retrievalMode: String
    public var bootstrapBehavior: BASCurrentBrainBootstrapBehavior
    public var reactionWeightSeed: BASReactionWeights?
    public var identityProfileOverride: BASIdentityProfile?
    public var cognitionBehavior: BASCognitionBehavior

    public init(
        modeID: String,
        prompt: String,
        triggerID: String,
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHeadline: String? = nil,
        taskGraphActiveNodeCount: Int? = nil,
        taskGraphHasResumeCandidate: Bool? = nil,
        taskGraphResumeHint: String? = nil,
        retrievalMode: String,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior
    ) {
        self.modeID = modeID
        self.prompt = prompt
        self.triggerID = triggerID
        self.sourceSurfaceOverrideID = sourceSurfaceOverrideID
        self.riskLevelOverrideID = riskLevelOverrideID
        self.preferredLanguages = preferredLanguages
        self.now = now
        self.projection = projection
        self.embeddingScores = embeddingScores
        self.taskGraphHeadline = taskGraphHeadline
        self.taskGraphActiveNodeCount = taskGraphActiveNodeCount
        self.taskGraphHasResumeCandidate = taskGraphHasResumeCandidate
        self.taskGraphResumeHint = taskGraphResumeHint
        self.retrievalMode = retrievalMode
        self.bootstrapBehavior = bootstrapBehavior
        self.reactionWeightSeed = reactionWeightSeed
        self.identityProfileOverride = identityProfileOverride
        self.cognitionBehavior = cognitionBehavior
    }
}

public enum BASAppleCurrentBrainBootstrapBridgeInputBuilder {
    public static func build(
        modeID: String,
        prompt: String,
        triggerID: String,
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        preferredLanguages: [String] = [],
        now: Date = .now,
        projection: BASBrainProjection,
        embeddingScores: [BASAppleEmbeddingScoreInput] = [],
        taskGraphHint: BASAppleCurrentBrainBootstrapHostTaskGraphInput? = nil,
        retrievalMode: String,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior
    ) -> BASAppleCurrentBrainBootstrapBridgeInput {
        BASAppleCurrentBrainBootstrapBridgeInput(
            modeID: modeID,
            prompt: prompt,
            triggerID: triggerID,
            sourceSurfaceOverrideID: sourceSurfaceOverrideID,
            riskLevelOverrideID: riskLevelOverrideID,
            preferredLanguages: preferredLanguages,
            now: now,
            projection: projection,
            embeddingScores: embeddingScores,
            taskGraphHeadline: taskGraphHint?.headline,
            taskGraphActiveNodeCount: taskGraphHint?.activeNodeCount,
            taskGraphHasResumeCandidate: taskGraphHint?.hasResumeCandidate,
            taskGraphResumeHint: taskGraphHint?.resumeHint,
            retrievalMode: retrievalMode,
            bootstrapBehavior: bootstrapBehavior,
            reactionWeightSeed: reactionWeightSeed,
            identityProfileOverride: identityProfileOverride,
            cognitionBehavior: cognitionBehavior
        )
    }
}

public struct BASAppleCurrentBrainBootstrapBridgeResult<
    Update: BASAppleCurrentBrainUpdateEntity,
    Checkpoint: BASAppleEvolutionCheckpointEntity
> {
    public var sourceSurfaceID: String
    public var riskLevelID: String
    public var brainState: BASDecisionBrainState
    public var dominantGoal: String?
    public var activeConstraints: [String]
    public var activeTemplateIDs: [String]
    public var failureGuardIDs: [String]
    public var commit: BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint>

    public init(
        sourceSurfaceID: String,
        riskLevelID: String,
        brainState: BASDecisionBrainState,
        dominantGoal: String?,
        activeConstraints: [String],
        activeTemplateIDs: [String],
        failureGuardIDs: [String],
        commit: BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint>
    ) {
        self.sourceSurfaceID = sourceSurfaceID
        self.riskLevelID = riskLevelID
        self.brainState = brainState
        self.dominantGoal = dominantGoal
        self.activeConstraints = activeConstraints
        self.activeTemplateIDs = activeTemplateIDs
        self.failureGuardIDs = failureGuardIDs
        self.commit = commit
    }
}

public enum BASAppleCurrentBrainBootstrapBridgeBuilder {
    public static func bootstrapAndCommit<
        Template,
        FailurePattern,
        Update: BASAppleCurrentBrainUpdateEntity,
        Checkpoint: BASAppleEvolutionCheckpointEntity
    >(
        input: BASAppleCurrentBrainBootstrapBridgeInput,
        in modelContext: ModelContext,
        createdAt: Date = .now,
        checkpointLimit: Int = BASEvolutionCheckpointPlanner.defaultCheckpointLimit,
        checkpointRetentionInterval: TimeInterval = BASEvolutionCheckpointPlanner.defaultRetentionInterval,
        recommendTemplateIDs: (BASCurrentBrainBootstrapPreparation) -> [String],
        selectTemplates: (BASCurrentBrainBootstrapPreparation, [String]) -> [Template],
        selectFailurePatterns: (BASCurrentBrainBootstrapPreparation) -> [FailurePattern],
        mapTemplate: (Template) -> BASAppleCurrentBrainBootstrapHostTemplateInput,
        mapFailurePattern: (FailurePattern) -> BASAppleCurrentBrainBootstrapHostFailurePatternInput,
        onCheckpointSaveError: ((Error) -> Void)? = nil,
        onUpdateSaveError: ((Error) -> Void)? = nil
    ) throws -> BASAppleCurrentBrainBootstrapBridgeResult<Update, Checkpoint> {
        let context = BASAppleCurrentBrainBootstrapHostBuildContext(
            modeID: input.modeID,
            prompt: input.prompt,
            triggerID: input.triggerID,
            sourceSurfaceOverrideID: input.sourceSurfaceOverrideID,
            riskLevelOverrideID: input.riskLevelOverrideID,
            preferredLanguages: input.preferredLanguages,
            now: input.now,
            projection: input.projection,
            embeddingScores: input.embeddingScores,
            taskGraphHint: try taskGraphHint(from: input),
            retrievalMode: input.retrievalMode,
            bootstrapBehavior: input.bootstrapBehavior,
            reactionWeightSeed: input.reactionWeightSeed,
            identityProfileOverride: input.identityProfileOverride,
            cognitionBehavior: input.cognitionBehavior
        )

        let committed: BASAppleCurrentBrainBootstrapCommitResult<Update, Checkpoint> =
            try BASAppleCurrentBrainRuntimeCoordinator.bootstrapAndCommit(
                context: context,
                in: modelContext,
                createdAt: createdAt,
                checkpointLimit: checkpointLimit,
                checkpointRetentionInterval: checkpointRetentionInterval,
                recommendTemplateIDs: recommendTemplateIDs,
                selectTemplates: selectTemplates,
                selectFailurePatterns: selectFailurePatterns,
                mapTemplate: mapTemplate,
                mapFailurePattern: mapFailurePattern,
                onCheckpointSaveError: onCheckpointSaveError,
                onUpdateSaveError: onUpdateSaveError
            )

        return BASAppleCurrentBrainBootstrapBridgeResult(
            sourceSurfaceID: committed.preparation.sourceSurface.rawValue,
            riskLevelID: committed.preparation.riskLevel.rawValue,
            brainState: committed.brainState,
            dominantGoal: committed.dominantGoal,
            activeConstraints: committed.activeConstraints,
            activeTemplateIDs: committed.orderedTemplateIDs,
            failureGuardIDs: committed.orderedFailurePatternIDs,
            commit: committed.commit
        )
    }

    private static func taskGraphHint(
        from input: BASAppleCurrentBrainBootstrapBridgeInput
    ) throws -> BASAppleCurrentBrainBootstrapHostTaskGraphInput? {
        guard input.taskGraphHeadline != nil ||
                input.taskGraphActiveNodeCount != nil ||
                input.taskGraphHasResumeCandidate != nil ||
                input.taskGraphResumeHint != nil
        else {
            return nil
        }

        guard let activeNodeCount = input.taskGraphActiveNodeCount,
              let hasResumeCandidate = input.taskGraphHasResumeCandidate else {
            throw BASAppleCurrentBrainBootstrapHostResolutionError.incompleteTaskGraphHint
        }

        return BASAppleCurrentBrainBootstrapHostInputBuilder.taskGraphInput(
            headline: input.taskGraphHeadline,
            activeNodeCount: activeNodeCount,
            hasResumeCandidate: hasResumeCandidate,
            resumeHint: input.taskGraphResumeHint
        )
    }
}

public enum BASAppleCurrentBrainRuntimeCoordinator {
    public static func bootstrapAndCommit<
        Template,
        FailurePattern,
        Update: BASAppleCurrentBrainUpdateEntity,
        Checkpoint: BASAppleEvolutionCheckpointEntity
    >(
        context: BASAppleCurrentBrainBootstrapHostBuildContext,
        in modelContext: ModelContext,
        createdAt: Date = .now,
        checkpointLimit: Int = BASEvolutionCheckpointPlanner.defaultCheckpointLimit,
        checkpointRetentionInterval: TimeInterval = BASEvolutionCheckpointPlanner.defaultRetentionInterval,
        recommendTemplateIDs: (BASCurrentBrainBootstrapPreparation) -> [String],
        selectTemplates: (BASCurrentBrainBootstrapPreparation, [String]) -> [Template],
        selectFailurePatterns: (BASCurrentBrainBootstrapPreparation) -> [FailurePattern],
        mapTemplate: (Template) -> BASAppleCurrentBrainBootstrapHostTemplateInput,
        mapFailurePattern: (FailurePattern) -> BASAppleCurrentBrainBootstrapHostFailurePatternInput,
        onCheckpointSaveError: ((Error) -> Void)? = nil,
        onUpdateSaveError: ((Error) -> Void)? = nil
    ) throws -> BASAppleCurrentBrainBootstrapCommitResult<Update, Checkpoint> {
        let artifact = try BASAppleCurrentBrainBootstrapCoordinator.artifact(
            context: context,
            recommendTemplateIDs: recommendTemplateIDs,
            selectTemplates: selectTemplates,
            selectFailurePatterns: selectFailurePatterns,
            mapTemplate: mapTemplate,
            mapFailurePattern: mapFailurePattern
        )

        let commit: BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint> =
            BASAppleCurrentBrainCommitter.commit(
                modeName: artifact.execution.preparation.mode.identifier,
                sourceID: artifact.execution.preparation.trigger.rawValue,
                brainState: artifact.execution.bootstrapped.brainState,
                persistenceInput: artifact.persistenceInput,
                in: modelContext,
                createdAt: createdAt,
                checkpointLimit: checkpointLimit,
                checkpointRetentionInterval: checkpointRetentionInterval,
                onCheckpointSaveError: onCheckpointSaveError,
                onUpdateSaveError: onUpdateSaveError
            )

        return BASAppleCurrentBrainBootstrapCommitResult(
            preparation: artifact.execution.preparation,
            brainState: commit.brainState,
            dominantGoal: artifact.execution.bootstrapped.dominantGoal,
            activeConstraints: artifact.execution.bootstrapped.activeConstraints,
            orderedTemplateIDs: artifact.execution.orderedTemplateIDs,
            orderedFailurePatternIDs: artifact.execution.orderedFailurePatternIDs,
            commit: commit
        )
    }
}

public enum BASAppleBrainBootstrapRequestAdapter {
    public static func request(
        modeID: String,
        prompt: String,
        triggerID: String,
        sourceSurfaceOverrideID: String? = nil,
        riskLevelOverrideID: String? = nil,
        bootstrapBehavior: BASCurrentBrainBootstrapBehavior,
        reactionWeightSeed: BASReactionWeights? = nil,
        identityProfileOverride: BASIdentityProfile? = nil,
        cognitionBehavior: BASCognitionBehavior,
        preferredLanguages: [String] = [],
        now: Date = .now,
        retrievalMode: String
    ) throws -> BASBrainBootstrapRequest {
        let canonicalModeID = bootstrapBehavior.canonicalModeID(for: modeID)
        guard let mode = BASDecisionMode(identifier: canonicalModeID) else {
            throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedModeID(modeID)
        }
        let canonicalTriggerID = bootstrapBehavior.canonicalTriggerID(for: triggerID)
        guard let trigger = BASCurrentBrainBootstrapTrigger(identifier: canonicalTriggerID) else {
            throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedTriggerID(triggerID)
        }

        let sourceSurfaceOverride: BASInteractionSurface?
        if let sourceSurfaceOverrideID {
            guard let resolvedSourceSurface = BASInteractionSurface(rawValue: sourceSurfaceOverrideID) else {
                throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedSourceSurfaceID(sourceSurfaceOverrideID)
            }
            sourceSurfaceOverride = resolvedSourceSurface
        } else {
            sourceSurfaceOverride = nil
        }

        let riskLevel: BASRiskLevel
        if let riskLevelOverrideID {
            let canonicalRiskLevelID = bootstrapBehavior.canonicalRiskLevelID(for: riskLevelOverrideID)
            guard let resolvedRiskLevel = BASRiskLevel(rawValue: canonicalRiskLevelID) else {
                throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedRiskLevelID(riskLevelOverrideID)
            }
            riskLevel = resolvedRiskLevel
        } else {
            guard let resolvedRiskLevel = BASRiskLevel(rawValue: bootstrapBehavior.defaultRiskLevelID) else {
                throw BASAppleCurrentBrainBootstrapHostResolutionError.unsupportedRiskLevelID(
                    bootstrapBehavior.defaultRiskLevelID
                )
            }
            riskLevel = resolvedRiskLevel
        }

        return BASBrainBootstrapRequest(
            mode: mode,
            prompt: prompt,
            source: bootstrapBehavior.memorySource(for: trigger, mode: mode),
            sourceSurface: bootstrapBehavior.resolvedSourceSurface(for: trigger, override: sourceSurfaceOverride),
            riskLevel: riskLevel,
            retrievalMode: retrievalMode,
            reactionWeightSeed: reactionWeightSeed,
            identityProfileOverride: identityProfileOverride,
            cognitionBehavior: cognitionBehavior,
            goalHints: [prompt].filter { !$0.isEmpty },
            constraintHints: [],
            now: now
        )
    }
}
