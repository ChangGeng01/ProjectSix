import Foundation
import SwiftData
import BASMemory
import BASPolicy
import BASRuntimeCore

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
            recommendedTemplateIDs: context.recommendedTemplateIDs,
            templates: templates.map(mapTemplate),
            failurePatterns: failurePatterns.map(mapFailurePattern)
        )
    }
}

public enum BASAppleCurrentBrainBootstrapHostAdapter {
    public static func prepare(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) -> BASCurrentBrainBootstrapPreparation {
        BASAppleCurrentBrainBootstrapPlanner.request(from: planningInput(from: input)).preparation
    }

    public static func execute(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) -> BASCurrentBrainBootstrapExecution {
        BASAppleCurrentBrainBootstrapAdapter.bootstrap(
            request: BASAppleCurrentBrainBootstrapPlanner.request(from: planningInput(from: input))
        )
    }

    public static func artifact(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) -> BASAppleCurrentBrainBootstrapArtifact {
        BASAppleCurrentBrainBootstrapAdapter.artifact(
            request: BASAppleCurrentBrainBootstrapPlanner.request(from: planningInput(from: input))
        )
    }

    public static func request(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) -> BASAppleCurrentBrainBootstrapRequest {
        BASAppleCurrentBrainBootstrapPlanner.request(from: planningInput(from: input))
    }

    private static func planningInput(
        from input: BASAppleCurrentBrainBootstrapHostSourceInput
    ) -> BASAppleCurrentBrainBootstrapPlanningSourceInput {
        BASAppleCurrentBrainBootstrapPlanningSourceInput(
            preparationRequest: BASCurrentBrainBootstrapPreparationRequest(
                mode: BASDecisionMode(identifier: input.modeID) ?? .quick,
                prompt: input.prompt,
                trigger: BASCurrentBrainBootstrapTrigger(rawValue: input.triggerID) ?? .sessionPrime,
                sourceSurfaceOverride: input.sourceSurfaceOverrideID.flatMap(BASInteractionSurface.init(rawValue:)),
                riskLevelOverride: input.riskLevelOverrideID.flatMap(BASRiskLevel.init(rawValue:)),
                preferredLanguages: input.preferredLanguages,
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
            recommendedTemplateIDs: input.recommendedTemplateIDs,
            templates: input.templates.map { template in
                BASAppleCurrentBrainBootstrapTemplateInput(
                    id: template.id,
                    mode: BASDecisionMode(identifier: template.modeID) ?? .quick,
                    riskLevel: BASRiskLevel(rawValue: template.riskLevelID) ?? .low,
                    isPinned: template.isPinned,
                    successCount: template.successCount,
                    updatedAt: template.updatedAt
                )
            },
            failurePatterns: input.failurePatterns.map { pattern in
                BASAppleCurrentBrainBootstrapFailurePatternInput(
                    id: pattern.id,
                    mode: BASDecisionMode(identifier: pattern.modeID) ?? .quick,
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
    ) -> BASAppleCurrentBrainBootstrapArtifact {
        artifact(
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
    ) -> BASAppleCurrentBrainBootstrapArtifact {
        let preparation = BASAppleCurrentBrainBootstrapHostAdapter.prepare(from: baseInput)
        let recommendedTemplateIDs = recommendTemplateIDs(preparation)
        let templates = selectTemplates(preparation, recommendedTemplateIDs).map(mapTemplate)
        let failurePatterns = selectFailurePatterns(preparation).map(mapFailurePattern)

        return BASAppleCurrentBrainBootstrapHostAdapter.artifact(
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
        retrievalMode: String
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
        retrievalMode: String
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
            retrievalMode: retrievalMode
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
    ) -> BASAppleCurrentBrainBootstrapBridgeResult<Update, Checkpoint> {
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
            taskGraphHint: taskGraphHint(from: input),
            retrievalMode: input.retrievalMode
        )

        let committed: BASAppleCurrentBrainBootstrapCommitResult<Update, Checkpoint> =
            BASAppleCurrentBrainRuntimeCoordinator.bootstrapAndCommit(
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
    ) -> BASAppleCurrentBrainBootstrapHostTaskGraphInput? {
        guard input.taskGraphHeadline != nil ||
                input.taskGraphActiveNodeCount != nil ||
                input.taskGraphHasResumeCandidate != nil ||
                input.taskGraphResumeHint != nil
        else {
            return nil
        }

        return BASAppleCurrentBrainBootstrapHostInputBuilder.taskGraphInput(
            headline: input.taskGraphHeadline,
            activeNodeCount: input.taskGraphActiveNodeCount ?? 0,
            hasResumeCandidate: input.taskGraphHasResumeCandidate ?? false,
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
    ) -> BASAppleCurrentBrainBootstrapCommitResult<Update, Checkpoint> {
        let artifact = BASAppleCurrentBrainBootstrapCoordinator.artifact(
            context: context,
            recommendTemplateIDs: recommendTemplateIDs,
            selectTemplates: selectTemplates,
            selectFailurePatterns: selectFailurePatterns,
            mapTemplate: mapTemplate,
            mapFailurePattern: mapFailurePattern
        )

        let commit: BASAppleCurrentBrainCommitWriteResult<Update, Checkpoint> =
            BASAppleCurrentBrainCommitter.commit(
                modeName: context.modeID,
                sourceID: context.triggerID,
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
        preferredLanguages: [String] = [],
        now: Date = .now,
        retrievalMode: String
    ) -> BASBrainBootstrapRequest {
        let request = BASAppleCurrentBrainBootstrapHostAdapter.request(
            from: BASAppleCurrentBrainBootstrapHostInputBuilder.build(
                context: BASAppleCurrentBrainBootstrapHostBuildContext(
                    modeID: modeID,
                    prompt: prompt,
                    triggerID: triggerID,
                    sourceSurfaceOverrideID: sourceSurfaceOverrideID,
                    riskLevelOverrideID: riskLevelOverrideID,
                    preferredLanguages: preferredLanguages,
                    now: now,
                    projection: BASBrainProjection(records: [], candidates: [], recentEvents: []),
                    retrievalMode: retrievalMode
                ),
                templates: [BASAppleCurrentBrainBootstrapHostTemplateInput](),
                failurePatterns: [BASAppleCurrentBrainBootstrapHostFailurePatternInput](),
                mapTemplate: { $0 },
                mapFailurePattern: { $0 }
            )
        ).preparation

        return BASBrainBootstrapRequest(
            mode: request.mode,
            prompt: request.prompt,
            source: request.memorySource,
            sourceSurface: request.sourceSurface,
            riskLevel: request.riskLevel,
            retrievalMode: retrievalMode,
            now: request.now
        )
    }
}
