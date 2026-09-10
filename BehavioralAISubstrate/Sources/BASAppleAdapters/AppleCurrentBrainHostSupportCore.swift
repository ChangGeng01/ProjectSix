import Foundation
import SwiftData
import BASMemory

public struct BASAppleCurrentBrainHostTemplateMapper<Template> {
    public var id: (Template) -> String
    public var modeID: (Template) -> String
    public var riskLevelID: (Template) -> String
    public var isPinned: (Template) -> Bool
    public var successCount: (Template) -> Int
    public var updatedAt: (Template) -> Date

    public init(
        id: @escaping (Template) -> String,
        modeID: @escaping (Template) -> String,
        riskLevelID: @escaping (Template) -> String,
        isPinned: @escaping (Template) -> Bool,
        successCount: @escaping (Template) -> Int,
        updatedAt: @escaping (Template) -> Date
    ) {
        self.id = id
        self.modeID = modeID
        self.riskLevelID = riskLevelID
        self.isPinned = isPinned
        self.successCount = successCount
        self.updatedAt = updatedAt
    }

    public func map(_ template: Template) -> BASAppleCurrentBrainBootstrapHostTemplateInput {
        BASAppleCurrentBrainBootstrapHostTemplateInput(
            id: id(template),
            modeID: modeID(template),
            riskLevelID: riskLevelID(template),
            isPinned: isPinned(template),
            successCount: successCount(template),
            updatedAt: updatedAt(template)
        )
    }
}

public struct BASAppleCurrentBrainHostFailurePatternMapper<FailurePattern> {
    public var id: (FailurePattern) -> String
    public var modeID: (FailurePattern) -> String
    public var suppressionWeight: (FailurePattern) -> Double
    public var evidenceCount: (FailurePattern) -> Int
    public var updatedAt: (FailurePattern) -> Date

    public init(
        id: @escaping (FailurePattern) -> String,
        modeID: @escaping (FailurePattern) -> String,
        suppressionWeight: @escaping (FailurePattern) -> Double,
        evidenceCount: @escaping (FailurePattern) -> Int,
        updatedAt: @escaping (FailurePattern) -> Date
    ) {
        self.id = id
        self.modeID = modeID
        self.suppressionWeight = suppressionWeight
        self.evidenceCount = evidenceCount
        self.updatedAt = updatedAt
    }

    public func map(
        _ failurePattern: FailurePattern
    ) -> BASAppleCurrentBrainBootstrapHostFailurePatternInput {
        BASAppleCurrentBrainBootstrapHostFailurePatternInput(
            id: id(failurePattern),
            modeID: modeID(failurePattern),
            suppressionWeight: suppressionWeight(failurePattern),
            evidenceCount: evidenceCount(failurePattern),
            updatedAt: updatedAt(failurePattern)
        )
    }
}

public struct BASAppleCurrentBrainHostSupportDescriptor<Template, FailurePattern> {
    public var prepareLifecycleState: () -> Void
    public var recommendTemplateIDs: (BASCurrentBrainBootstrapPreparation) -> [String]
    public var selectTemplates: (BASCurrentBrainBootstrapPreparation, [String]) -> [Template]
    public var selectFailurePatterns: (BASCurrentBrainBootstrapPreparation) -> [FailurePattern]
    public var templateMapper: BASAppleCurrentBrainHostTemplateMapper<Template>
    public var failurePatternMapper: BASAppleCurrentBrainHostFailurePatternMapper<FailurePattern>

    public init(
        prepareLifecycleState: @escaping () -> Void = {},
        recommendTemplateIDs: @escaping (BASCurrentBrainBootstrapPreparation) -> [String],
        selectTemplates: @escaping (BASCurrentBrainBootstrapPreparation, [String]) -> [Template],
        selectFailurePatterns: @escaping (BASCurrentBrainBootstrapPreparation) -> [FailurePattern],
        templateMapper: BASAppleCurrentBrainHostTemplateMapper<Template>,
        failurePatternMapper: BASAppleCurrentBrainHostFailurePatternMapper<FailurePattern>
    ) {
        self.prepareLifecycleState = prepareLifecycleState
        self.recommendTemplateIDs = recommendTemplateIDs
        self.selectTemplates = selectTemplates
        self.selectFailurePatterns = selectFailurePatterns
        self.templateMapper = templateMapper
        self.failurePatternMapper = failurePatternMapper
    }
}

public enum BASAppleCurrentBrainHostSupportRuntimeExecutor {
    public static func bootstrapAndBuildCurrentBrain<
        Template,
        FailurePattern,
        Update: BASAppleCurrentBrainUpdateEntity,
        Checkpoint: BASAppleEvolutionCheckpointEntity,
        CurrentBrain
    >(
        input: BASAppleCurrentBrainHostLifecycleRuntimeInput,
        in modelContext: ModelContext,
        support: BASAppleCurrentBrainHostSupportDescriptor<Template, FailurePattern>,
        buildCurrentBrain: (BASAppleCurrentBrainLifecycleResult<Update, Checkpoint>) -> CurrentBrain
    ) throws -> CurrentBrain {
        try BASAppleCurrentBrainHostLifecycleRuntimeExecutor.bootstrapAndBuildCurrentBrain(
            input: input,
            in: modelContext,
            prepareLifecycleState: support.prepareLifecycleState,
            recommendTemplateIDs: support.recommendTemplateIDs,
            selectTemplates: support.selectTemplates,
            selectFailurePatterns: support.selectFailurePatterns,
            mapTemplate: support.templateMapper.map,
            mapFailurePattern: support.failurePatternMapper.map,
            buildCurrentBrain: buildCurrentBrain
        )
    }
}
