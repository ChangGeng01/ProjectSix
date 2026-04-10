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

public struct BASAppleFailureHistoryEventInput: Codable, Equatable, Sendable {
    public var createdAt: Date
    public var reflectionOutcomeID: String?
    public var finalActionID: String

    public init(
        createdAt: Date,
        reflectionOutcomeID: String?,
        finalActionID: String
    ) {
        self.createdAt = createdAt
        self.reflectionOutcomeID = reflectionOutcomeID
        self.finalActionID = finalActionID
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

public enum BASAppleBootstrapStrategyAdapter {
    public static func defaultTemplateSeeds(now: Date = .now) -> [BASAppleInterventionTemplateSeed] {
        [
            BASAppleInterventionTemplateSeed(
                id: "tomorrow_box_interrupt",
                createdAt: now,
                updatedAt: now,
                title: "Night-message cooling",
                summary: "Lower the heat, then move the message into tomorrow.",
                body: [
                    "Step back from the send button.",
                    "Name what this message is trying to fix right now.",
                    "Put it into Tomorrow Box before you reread it."
                ],
                modeID: BASDecisionMode.quick.rawValue,
                riskLevelID: BASRiskLevel.medium.rawValue,
                isPinned: true,
                successCount: 0
            ),
            BASAppleInterventionTemplateSeed(
                id: "brief_warm_nudge",
                createdAt: now,
                updatedAt: now,
                title: "Impulse-buy cooling",
                summary: "Short, warm friction before spending from blur.",
                body: [
                    "Pause the purchase.",
                    "Name whether this is need, relief, or reward.",
                    "Reopen it in daylight."
                ],
                modeID: BASDecisionMode.quick.rawValue,
                riskLevelID: BASRiskLevel.low.rawValue,
                isPinned: true,
                successCount: 0
            ),
            BASAppleInterventionTemplateSeed(
                id: "reflective_question",
                createdAt: now,
                updatedAt: now,
                title: "Anxiety loop interruption",
                summary: "Use one question and one grounded action instead of more spinning.",
                body: [
                    "What are you trying to make go away quickly?",
                    "Choose one small grounded action.",
                    "Do not solve the whole future right now."
                ],
                modeID: BASDecisionMode.mirror.rawValue,
                riskLevelID: BASRiskLevel.medium.rawValue,
                isPinned: true,
                successCount: 0
            ),
            BASAppleInterventionTemplateSeed(
                id: "slow_delay_guard",
                createdAt: now,
                updatedAt: now,
                title: "Self-blame recovery",
                summary: "Slow the cadence, keep it honest, and stop adding punishment.",
                body: [
                    "Name what happened without adding contempt.",
                    "Choose one boundary step, not a life sentence.",
                    "If needed, move the call into Tomorrow Box."
                ],
                modeID: BASDecisionMode.mirror.rawValue,
                riskLevelID: BASRiskLevel.high.rawValue,
                isPinned: true,
                successCount: 0
            )
        ]
    }

    public static func orderedTemplateIDs(
        modeID: String,
        riskLevelID: String,
        recommendedTemplateIDs: [String],
        templates: [BASAppleCurrentBrainBootstrapHostTemplateInput]
    ) -> [String] {
        BASBrainBootstrapAdvisor.orderedTemplateIDs(
            mode: BASDecisionMode(rawValue: modeID) ?? .quick,
            riskLevel: BASRiskLevel(rawValue: riskLevelID) ?? .low,
            recommendedTemplateIDs: recommendedTemplateIDs,
            templates: templates.map { template in
                BASInterventionTemplateDescriptor(
                    id: template.id,
                    mode: BASDecisionMode(rawValue: template.modeID) ?? .quick,
                    riskLevel: BASRiskLevel(rawValue: template.riskLevelID) ?? .low,
                    isPinned: template.isPinned,
                    successCount: template.successCount,
                    updatedAt: template.updatedAt
                )
            }
        )
    }

    public static func synthesizedFailurePatternSeeds(
        from events: [BASAppleFailureHistoryEventInput],
        now: Date = .now
    ) -> [BASAppleFailurePatternSeed] {
        let negativeEvents = events.filter {
            guard let outcomeID = $0.reflectionOutcomeID else { return false }
            return outcomeID == "regrettedIt" || outcomeID == "feltEmptier"
        }

        guard !negativeEvents.isEmpty else {
            return []
        }

        let nightFailures = negativeEvents.filter {
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: $0.createdAt)
            return hour >= 22 || hour < 5
        }
        let proceedFailures = negativeEvents.filter {
            $0.finalActionID == "goAheadAnyway" || $0.finalActionID == "continueMindfully"
        }

        var seeds: [BASAppleFailurePatternSeed] = []
        if nightFailures.count >= 2 {
            seeds.append(
                BASAppleFailurePatternSeed(
                    id: "night_fast_path_failure",
                    createdAt: now,
                    updatedAt: now,
                    modeID: BASDecisionMode.quick.rawValue,
                    title: "Night fast paths backfire",
                    detail: "Fast action at night has repeatedly ended in regret or emptiness.",
                    cadenceTag: "night_fast_path",
                    suppressionWeight: min(1, 0.4 + Double(nightFailures.count) * 0.12),
                    evidenceCount: nightFailures.count
                )
            )
        }
        if proceedFailures.count >= 2 {
            seeds.append(
                BASAppleFailurePatternSeed(
                    id: "proceed_without_pause_failure",
                    createdAt: now,
                    updatedAt: now,
                    modeID: BASDecisionMode.quick.rawValue,
                    title: "Proceeding too fast backfires",
                    detail: "Going forward without a pause has repeatedly ended badly.",
                    cadenceTag: "proceed_fast",
                    suppressionWeight: min(1, 0.4 + Double(proceedFailures.count) * 0.1),
                    evidenceCount: proceedFailures.count
                )
            )
        }
        return seeds
    }

    public static func orderedFailurePatternIDs(
        modeID: String,
        failurePatterns: [BASAppleCurrentBrainBootstrapHostFailurePatternInput]
    ) -> [String] {
        BASBrainBootstrapAdvisor.orderedFailurePatternIDs(
            mode: BASDecisionMode(rawValue: modeID) ?? .quick,
            failurePatterns: failurePatterns.map { pattern in
                BASFailurePatternDescriptor(
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
