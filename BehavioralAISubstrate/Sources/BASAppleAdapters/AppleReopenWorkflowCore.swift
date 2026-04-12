import Foundation
import BASMemory
import BASRuntimeCore

public enum BASAppleWorkflowModeExecutor {
    @discardableResult
    public static func execute(
        modeID: String?,
        performPrimary: () -> Void,
        performComparative: () -> Void,
        performReflective: () -> Void
    ) -> Bool {
        guard let mode = modeID.flatMap(BASDecisionMode.init(identifier:)) else {
            return false
        }

        switch mode {
        case .primary:
            performPrimary()
        case .comparative:
            performComparative()
        case .reflective:
            performReflective()
        }
        return true
    }
}

public struct BASAppleReopenInterventionSuggestion: Codable, Equatable, Sendable {
    public var riskLevelID: String
    public var title: String
    public var detail: String?
    public var evidenceSignalCount: Int
    public var suggestedModeID: String?
    public var reason: String
    public var expiresAt: Date

    public init(
        riskLevelID: String,
        title: String,
        detail: String?,
        evidenceSignalCount: Int,
        suggestedModeID: String?,
        reason: String,
        expiresAt: Date
    ) {
        self.riskLevelID = riskLevelID
        self.title = title
        self.detail = detail
        self.evidenceSignalCount = evidenceSignalCount
        self.suggestedModeID = suggestedModeID
        self.reason = reason
        self.expiresAt = expiresAt
    }
}

public struct BASAppleDeferredReopenFollowUp: Codable, Equatable, Sendable {
    public var interventionSuggestion: BASAppleReopenInterventionSuggestion?

    public init(interventionSuggestion: BASAppleReopenInterventionSuggestion?) {
        self.interventionSuggestion = interventionSuggestion
    }

    public var shouldRefreshPredictedIntervention: Bool {
        interventionSuggestion == nil
    }
}

public enum BASAppleDeferredReopenFollowUpBuilder {
    public static func build(
        riskLevelID: String?,
        title: String,
        detail: String?,
        modeID: String?,
        reopenHint: String?,
        templateHint: String?,
        interventionHistorySummary: String?,
        now: Date = .now
    ) -> BASAppleDeferredReopenFollowUp {
        guard
            let riskLevelID,
            let riskLevel = BASRiskLevel(rawValue: riskLevelID),
            riskLevel > .low
        else {
            return BASAppleDeferredReopenFollowUp(interventionSuggestion: nil)
        }

        return BASAppleDeferredReopenFollowUp(
            interventionSuggestion: BASAppleReopenInterventionSuggestion(
                riskLevelID: riskLevelID,
                title: reopenHint ?? title,
                detail: interventionHistorySummary ?? detail,
                evidenceSignalCount: interventionHistorySummary == nil ? 1 : 2,
                suggestedModeID: modeID,
                reason: templateHint ?? "A previous hold suggests reopening this with more structure.",
                expiresAt: now.addingTimeInterval(60 * 30)
            )
        )
    }
}

public enum BASAppleDeferredReopenExecutor {
    public static func execute(
        modeID: String?,
        promptSeed: String,
        hasDraft: Bool,
        clearActiveDecisionFlows: () -> Void,
        activatePrimaryFromDraft: () -> Void,
        activateComparativeFromDraft: () -> Void,
        activateReflectiveFromDraft: () -> Void,
        startPrimary: (String) -> Void,
        startComparative: (String) -> Void,
        startReflective: (String) -> Void,
        removeDeferredItem: () -> Void,
        followUp: BASAppleDeferredReopenFollowUp,
        setInterventionSuggestion: (BASAppleReopenInterventionSuggestion?) -> Void,
        refreshPredictedIntervention: () -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        clearActiveDecisionFlows()

        _ = BASAppleWorkflowModeExecutor.execute(
            modeID: modeID,
            performPrimary: {
                if hasDraft {
                    activatePrimaryFromDraft()
                } else {
                    startPrimary(promptSeed)
                }
            },
            performComparative: {
                if hasDraft {
                    activateComparativeFromDraft()
                } else {
                    startComparative(promptSeed)
                }
            },
            performReflective: {
                if hasDraft {
                    activateReflectiveFromDraft()
                } else {
                    startReflective(promptSeed)
                }
            }
        )

        removeDeferredItem()
        if followUp.shouldRefreshPredictedIntervention {
            refreshPredictedIntervention()
        } else {
            setInterventionSuggestion(followUp.interventionSuggestion)
        }
        selectHomeTab()
        persistActiveWorkspaceState()
    }
}

public enum BASAppleDraftedWorkflowReopenExecutor {
    @discardableResult
    public static func execute(
        modeID: String?,
        clearActiveDecisionFlows: () -> Void,
        activatePrimary: () -> Void,
        activateComparative: () -> Void,
        activateReflective: () -> Void,
        afterSuccessfulReopen: () -> Void
    ) -> Bool {
        clearActiveDecisionFlows()
        guard BASAppleWorkflowModeExecutor.execute(
            modeID: modeID,
            performPrimary: activatePrimary,
            performComparative: activateComparative,
            performReflective: activateReflective
        ) else {
            return false
        }

        afterSuccessfulReopen()
        return true
    }
}

public enum BASAppleSimpleReopenExecutor {
    public static func execute(
        clearActiveDecisionFlows: () -> Void,
        reopen: () -> Void,
        afterSuccessfulReopen: () -> Void
    ) {
        clearActiveDecisionFlows()
        reopen()
        afterSuccessfulReopen()
    }
}
