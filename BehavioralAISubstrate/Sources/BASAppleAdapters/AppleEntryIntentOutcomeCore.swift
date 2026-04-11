import Foundation
import BASRuntimeCore

public struct BASAppleEntryIntentSuggestionPresentation: Codable, Equatable, Sendable {
    public var fallbackTitle: String
    public var fallbackDetail: String
    public var fallbackReason: String

    public init(
        fallbackTitle: String = "A steadier pass may help here.",
        fallbackDetail: String = "A predicted pattern suggests restoring more structure here.",
        fallbackReason: String = "A recent pattern suggests slowing this down before acting."
    ) {
        self.fallbackTitle = fallbackTitle
        self.fallbackDetail = fallbackDetail
        self.fallbackReason = fallbackReason
    }
}

public struct BASApplePredictiveInterventionSuggestion: Codable, Equatable, Sendable {
    public var riskLevelID: String
    public var title: String
    public var detail: String
    public var evidenceSignalCount: Int
    public var preferredModeID: String?
    public var reason: String
    public var expiresAt: Date

    public init(
        riskLevelID: String,
        title: String,
        detail: String,
        evidenceSignalCount: Int,
        preferredModeID: String?,
        reason: String,
        expiresAt: Date
    ) {
        self.riskLevelID = riskLevelID
        self.title = title
        self.detail = detail
        self.evidenceSignalCount = evidenceSignalCount
        self.preferredModeID = preferredModeID
        self.reason = reason
        self.expiresAt = expiresAt
    }
}

public struct BASAppleEntryIntentResolution: Codable, Equatable, Sendable {
    public var actionPlan: BASAppleEntryIntentActionPlan
    public var refreshTriggerID: String
    public var predictiveIntervention: BASApplePredictiveInterventionSuggestion?

    public init(
        actionPlan: BASAppleEntryIntentActionPlan,
        refreshTriggerID: String,
        predictiveIntervention: BASApplePredictiveInterventionSuggestion?
    ) {
        self.actionPlan = actionPlan
        self.refreshTriggerID = refreshTriggerID
        self.predictiveIntervention = predictiveIntervention
    }
}

public struct BASAppleEntryIntentRuntimeInput: Codable, Equatable, Sendable {
    public var kindID: String
    public var surfaceID: String
    public var preferredModeID: String?
    public var scenarioID: String?
    public var promptSeed: String?
    public var riskLevelID: String?
    public var triggerReason: String?
    public var predictiveInterventionPresentation: BASAppleEntryIntentSuggestionPresentation
    public var expiresAt: Date

    public init(
        kindID: String,
        surfaceID: String,
        preferredModeID: String? = nil,
        scenarioID: String? = nil,
        promptSeed: String? = nil,
        riskLevelID: String? = nil,
        triggerReason: String? = nil,
        predictiveInterventionPresentation: BASAppleEntryIntentSuggestionPresentation = BASAppleEntryIntentSuggestionPresentation(),
        expiresAt: Date
    ) {
        self.kindID = kindID
        self.surfaceID = surfaceID
        self.preferredModeID = preferredModeID
        self.scenarioID = scenarioID
        self.promptSeed = promptSeed
        self.riskLevelID = riskLevelID
        self.triggerReason = triggerReason
        self.predictiveInterventionPresentation = predictiveInterventionPresentation
        self.expiresAt = expiresAt
    }
}

public enum BASAppleEntryIntentOutcomeBuilder {
    public static func resolve(
        kindID: String,
        surfaceID: String,
        preferredModeID: String?,
        scenarioID: String?,
        promptSeed: String?,
        riskLevelID: String?,
        triggerReason: String?,
        predictiveInterventionPresentation: BASAppleEntryIntentSuggestionPresentation = BASAppleEntryIntentSuggestionPresentation(),
        expiresAt: Date
    ) -> BASAppleEntryIntentResolution {
        resolve(
            plan: BASAppleEntryIntentPlanBuilder.plan(
                kindID: kindID,
                surfaceID: surfaceID,
                preferredModeID: preferredModeID,
                scenarioID: scenarioID,
                promptSeed: promptSeed,
                riskLevelID: riskLevelID,
                triggerReason: triggerReason
            ),
            predictiveInterventionPresentation: predictiveInterventionPresentation,
            expiresAt: expiresAt
        )
    }

    public static func resolve(
        plan: BASAppleEntryIntentActionPlan,
        predictiveInterventionPresentation: BASAppleEntryIntentSuggestionPresentation = BASAppleEntryIntentSuggestionPresentation(),
        expiresAt: Date
    ) -> BASAppleEntryIntentResolution {
        BASAppleEntryIntentResolution(
            actionPlan: plan,
            refreshTriggerID: refreshTriggerID(for: plan),
            predictiveIntervention: predictiveIntervention(
                for: plan,
                predictiveInterventionPresentation: predictiveInterventionPresentation,
                expiresAt: expiresAt
            )
        )
    }

    private static func refreshTriggerID(
        for plan: BASAppleEntryIntentActionPlan
    ) -> String {
        switch plan.refreshTriggerKind {
        case .watchHandoff:
            BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue
        case .explicitRefresh:
            BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue
        }
    }

    private static func predictiveIntervention(
        for plan: BASAppleEntryIntentActionPlan,
        predictiveInterventionPresentation: BASAppleEntryIntentSuggestionPresentation,
        expiresAt: Date
    ) -> BASApplePredictiveInterventionSuggestion? {
        guard plan.actionKind == .predictiveIntervention else { return nil }

        return BASApplePredictiveInterventionSuggestion(
            riskLevelID: plan.riskLevelID ?? BASRiskLevel.medium.rawValue,
            title: plan.promptSeed.isEmpty ? predictiveInterventionPresentation.fallbackTitle : plan.promptSeed,
            detail: predictiveInterventionPresentation.fallbackDetail,
            evidenceSignalCount: plan.triggerReason == nil ? 1 : 2,
            preferredModeID: plan.preferredModeID,
            reason: plan.triggerReason ?? predictiveInterventionPresentation.fallbackReason,
            expiresAt: expiresAt
        )
    }
}

public enum BASAppleEntryIntentRuntimeExecutor {
    public static func execute(
        input: BASAppleEntryIntentRuntimeInput,
        performCapture: (BASAppleEntryIntentActionPlan) -> Void,
        performPresent: (BASAppleEntryIntentActionPlan) -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestore: () -> Void,
        refreshCurrentBrain: (String) -> Void
    ) {
        BASAppleEntryIntentOutcomeExecutor.execute(
            resolution: BASAppleEntryIntentOutcomeBuilder.resolve(
                kindID: input.kindID,
                surfaceID: input.surfaceID,
                preferredModeID: input.preferredModeID,
                scenarioID: input.scenarioID,
                promptSeed: input.promptSeed,
                riskLevelID: input.riskLevelID,
                triggerReason: input.triggerReason,
                predictiveInterventionPresentation: input.predictiveInterventionPresentation,
                expiresAt: input.expiresAt
            ),
            performCapture: performCapture,
            performPresent: performPresent,
            performPredictiveIntervention: performPredictiveIntervention,
            performRestore: performRestore,
            refreshCurrentBrain: refreshCurrentBrain
        )
    }
}

public enum BASAppleEntryIntentOutcomeExecutor {
    public static func execute(
        resolution: BASAppleEntryIntentResolution,
        performCapture: (BASAppleEntryIntentActionPlan) -> Void,
        performPresent: (BASAppleEntryIntentActionPlan) -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestore: () -> Void,
        refreshCurrentBrain: (String) -> Void
    ) {
        let actionPlan = resolution.actionPlan

        switch actionPlan.actionKind {
        case .capture:
            performCapture(actionPlan)
        case .present:
            performPresent(actionPlan)
        case .predictiveIntervention:
            performPredictiveIntervention(resolution.predictiveIntervention)
        case .restore:
            performRestore()
        }

        refreshCurrentBrain(resolution.refreshTriggerID)
    }
}
