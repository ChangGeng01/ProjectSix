import Foundation
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
                mode: BASDecisionMode(rawValue: input.modeID) ?? .quick,
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
                    mode: BASDecisionMode(rawValue: template.modeID) ?? .quick,
                    riskLevel: BASRiskLevel(rawValue: template.riskLevelID) ?? .low,
                    isPinned: template.isPinned,
                    successCount: template.successCount,
                    updatedAt: template.updatedAt
                )
            },
            failurePatterns: input.failurePatterns.map { pattern in
                BASAppleCurrentBrainBootstrapFailurePatternInput(
                    id: pattern.id,
                    mode: BASDecisionMode(rawValue: pattern.modeID) ?? .quick,
                    suppressionWeight: pattern.suppressionWeight,
                    evidenceCount: pattern.evidenceCount,
                    updatedAt: pattern.updatedAt
                )
            }
        )
    }
}
