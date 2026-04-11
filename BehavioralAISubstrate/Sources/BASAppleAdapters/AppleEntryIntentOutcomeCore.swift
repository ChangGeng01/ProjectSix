import Foundation
import BASRuntimeCore

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
    public var expiresAt: Date

    public init(
        kindID: String,
        surfaceID: String,
        preferredModeID: String? = nil,
        scenarioID: String? = nil,
        promptSeed: String? = nil,
        riskLevelID: String? = nil,
        triggerReason: String? = nil,
        expiresAt: Date
    ) {
        self.kindID = kindID
        self.surfaceID = surfaceID
        self.preferredModeID = preferredModeID
        self.scenarioID = scenarioID
        self.promptSeed = promptSeed
        self.riskLevelID = riskLevelID
        self.triggerReason = triggerReason
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
            expiresAt: expiresAt
        )
    }

    public static func resolve(
        plan: BASAppleEntryIntentActionPlan,
        expiresAt: Date
    ) -> BASAppleEntryIntentResolution {
        BASAppleEntryIntentResolution(
            actionPlan: plan,
            refreshTriggerID: refreshTriggerID(for: plan),
            predictiveIntervention: predictiveIntervention(for: plan, expiresAt: expiresAt)
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
        expiresAt: Date
    ) -> BASApplePredictiveInterventionSuggestion? {
        guard plan.actionKind == .predictiveIntervention else { return nil }

        return BASApplePredictiveInterventionSuggestion(
            riskLevelID: plan.riskLevelID ?? BASRiskLevel.medium.rawValue,
            title: plan.promptSeed.isEmpty ? "Pause before you decide." : plan.promptSeed,
            detail: "A predicted pattern says a slower move is safer here.",
            evidenceSignalCount: plan.triggerReason == nil ? 1 : 2,
            preferredModeID: plan.preferredModeID,
            reason: plan.triggerReason ?? "A recent pattern suggests more friction before acting.",
            expiresAt: expiresAt
        )
    }
}

public enum BASAppleEntryIntentRuntimeExecutor {
    public static func execute(
        input: BASAppleEntryIntentRuntimeInput,
        performQuickCapture: (BASAppleEntryIntentActionPlan) -> Void,
        performOpenMode: (BASAppleEntryIntentActionPlan) -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestoreWorkspace: () -> Void,
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
                expiresAt: input.expiresAt
            ),
            performQuickCapture: performQuickCapture,
            performOpenMode: performOpenMode,
            performPredictiveIntervention: performPredictiveIntervention,
            performRestoreWorkspace: performRestoreWorkspace,
            refreshCurrentBrain: refreshCurrentBrain
        )
    }
}

public enum BASAppleEntryIntentOutcomeExecutor {
    public static func execute(
        resolution: BASAppleEntryIntentResolution,
        performQuickCapture: (BASAppleEntryIntentActionPlan) -> Void,
        performOpenMode: (BASAppleEntryIntentActionPlan) -> Void,
        performPredictiveIntervention: (BASApplePredictiveInterventionSuggestion?) -> Void,
        performRestoreWorkspace: () -> Void,
        refreshCurrentBrain: (String) -> Void
    ) {
        let actionPlan = resolution.actionPlan

        switch actionPlan.actionKind {
        case .quickCapture:
            performQuickCapture(actionPlan)
        case .openMode:
            performOpenMode(actionPlan)
        case .predictiveIntervention:
            performPredictiveIntervention(resolution.predictiveIntervention)
        case .restoreWorkspace:
            performRestoreWorkspace()
        }

        refreshCurrentBrain(resolution.refreshTriggerID)
    }
}
