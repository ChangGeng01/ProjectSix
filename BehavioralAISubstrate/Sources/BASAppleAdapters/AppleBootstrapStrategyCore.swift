import Foundation
import BASMemory
import BASRuntimeCore

public struct BASAppleInterventionTemplateSeed: Codable, Equatable, Sendable {
    public var id: String
    public var createdAt: Date
    public var updatedAt: Date
    public var title: String
    public var summary: String
    public var body: [String]
    public var modeID: String
    public var riskLevelID: String
    public var isPinned: Bool
    public var successCount: Int

    public init(
        id: String,
        createdAt: Date,
        updatedAt: Date,
        title: String,
        summary: String,
        body: [String],
        modeID: String,
        riskLevelID: String,
        isPinned: Bool,
        successCount: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.summary = summary
        self.body = body
        self.modeID = modeID
        self.riskLevelID = riskLevelID
        self.isPinned = isPinned
        self.successCount = successCount
    }
}

public struct BASAppleFailurePatternSeed: Codable, Equatable, Sendable {
    public var id: String
    public var createdAt: Date
    public var updatedAt: Date
    public var modeID: String
    public var title: String
    public var detail: String
    public var cadenceTag: String
    public var suppressionWeight: Double
    public var evidenceCount: Int

    public init(
        id: String,
        createdAt: Date,
        updatedAt: Date,
        modeID: String,
        title: String,
        detail: String,
        cadenceTag: String,
        suppressionWeight: Double,
        evidenceCount: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modeID = modeID
        self.title = title
        self.detail = detail
        self.cadenceTag = cadenceTag
        self.suppressionWeight = suppressionWeight
        self.evidenceCount = evidenceCount
    }
}

public struct BASAppleActiveSessionSeed: Codable, Equatable, Sendable {
    public var modeID: String
    public var promptSeed: String

    public init(modeID: String, promptSeed: String) {
        self.modeID = modeID
        self.promptSeed = promptSeed
    }
}

public enum BASAppleBootstrapStrategyAdapter {
    public static func promptSeed(fragments: [String]) -> String {
        fragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func resolveActiveSessionSeed(
        promptFragmentsByModeID: [String: [String]],
        modePriority: [String],
        taskGraphModeID: String?,
        taskGraphPromptSeed: String?,
        defaultModeID: String = BASDecisionMode.primaryID
    ) -> BASAppleActiveSessionSeed {
        for modeID in modePriority {
            guard let fragments = promptFragmentsByModeID[modeID] else { continue }
            return BASAppleActiveSessionSeed(
                modeID: modeID,
                promptSeed: promptSeed(fragments: fragments)
            )
        }
        if let taskGraphModeID {
            return BASAppleActiveSessionSeed(
                modeID: taskGraphModeID,
                promptSeed: taskGraphPromptSeed ?? ""
            )
        }
        return BASAppleActiveSessionSeed(modeID: defaultModeID, promptSeed: "")
    }

    public static func orderedTemplateIDs(
        modeID: String,
        riskLevelID: String,
        recommendedTemplateIDs: [String],
        templates: [BASAppleCurrentBrainBootstrapHostTemplateInput]
    ) -> [String] {
        BASBrainBootstrapAdvisor.orderedTemplateIDs(
            mode: BASDecisionMode(identifier: modeID) ?? .primary,
            riskLevel: BASRiskLevel(rawValue: riskLevelID) ?? .low,
            recommendedTemplateIDs: recommendedTemplateIDs,
            templates: templates.map { template in
                BASInterventionTemplateDescriptor(
                    id: template.id,
                    mode: BASDecisionMode(identifier: template.modeID) ?? .primary,
                    riskLevel: BASRiskLevel(rawValue: template.riskLevelID) ?? .low,
                    isPinned: template.isPinned,
                    successCount: template.successCount,
                    updatedAt: template.updatedAt
                )
            }
        )
    }

    public static func orderedFailurePatternIDs(
        modeID: String,
        failurePatterns: [BASAppleCurrentBrainBootstrapHostFailurePatternInput]
    ) -> [String] {
        BASBrainBootstrapAdvisor.orderedFailurePatternIDs(
            mode: BASDecisionMode(identifier: modeID) ?? .primary,
            failurePatterns: failurePatterns.map { pattern in
                BASFailurePatternDescriptor(
                    id: pattern.id,
                    mode: BASDecisionMode(identifier: pattern.modeID) ?? .primary,
                    suppressionWeight: pattern.suppressionWeight,
                    evidenceCount: pattern.evidenceCount,
                    updatedAt: pattern.updatedAt
                )
            }
        )
    }
}
