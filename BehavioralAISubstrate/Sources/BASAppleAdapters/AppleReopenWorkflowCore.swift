import Foundation
import BASMemory
import BASRuntimeCore

public enum BASAppleDecisionModeExecutor {
    @discardableResult
    public static func execute(
        modeID: String?,
        performQuick: () -> Void,
        performBalance: () -> Void,
        performMirror: () -> Void
    ) -> Bool {
        switch modeID {
        case BASDecisionMode.quick.rawValue:
            performQuick()
            return true
        case BASDecisionMode.balance.rawValue:
            performBalance()
            return true
        case BASDecisionMode.mirror.rawValue:
            performMirror()
            return true
        default:
            return false
        }
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

public struct BASAppleTomorrowBoxReopenFollowUp: Codable, Equatable, Sendable {
    public var interventionSuggestion: BASAppleReopenInterventionSuggestion?

    public init(interventionSuggestion: BASAppleReopenInterventionSuggestion?) {
        self.interventionSuggestion = interventionSuggestion
    }

    public var shouldRefreshPredictedIntervention: Bool {
        interventionSuggestion == nil
    }
}

public enum BASAppleTomorrowBoxReopenFollowUpBuilder {
    public static func build(
        riskLevelID: String?,
        title: String,
        detail: String?,
        modeID: String?,
        reopenHint: String?,
        templateHint: String?,
        interventionHistorySummary: String?,
        now: Date = .now
    ) -> BASAppleTomorrowBoxReopenFollowUp {
        guard
            let riskLevelID,
            let riskLevel = BASRiskLevel(rawValue: riskLevelID),
            riskLevel > .low
        else {
            return BASAppleTomorrowBoxReopenFollowUp(interventionSuggestion: nil)
        }

        return BASAppleTomorrowBoxReopenFollowUp(
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

public enum BASAppleTomorrowBoxReopenExecutor {
    public static func execute(
        modeID: String?,
        promptSeed: String,
        hasDraft: Bool,
        clearActiveDecisionFlows: () -> Void,
        activateQuickFromDraft: () -> Void,
        activateBalanceFromDraft: () -> Void,
        activateMirrorFromDraft: () -> Void,
        startQuick: (String) -> Void,
        startBalance: (String) -> Void,
        startMirror: (String) -> Void,
        removeTomorrowBoxItem: () -> Void,
        followUp: BASAppleTomorrowBoxReopenFollowUp,
        setInterventionSuggestion: (BASAppleReopenInterventionSuggestion?) -> Void,
        refreshPredictedIntervention: () -> Void,
        selectHomeTab: () -> Void,
        persistActiveWorkspaceState: () -> Void
    ) {
        clearActiveDecisionFlows()

        _ = BASAppleDecisionModeExecutor.execute(
            modeID: modeID,
            performQuick: {
                if hasDraft {
                    activateQuickFromDraft()
                } else {
                    startQuick(promptSeed)
                }
            },
            performBalance: {
                if hasDraft {
                    activateBalanceFromDraft()
                } else {
                    startBalance(promptSeed)
                }
            },
            performMirror: {
                if hasDraft {
                    activateMirrorFromDraft()
                } else {
                    startMirror(promptSeed)
                }
            }
        )

        removeTomorrowBoxItem()
        if followUp.shouldRefreshPredictedIntervention {
            refreshPredictedIntervention()
        } else {
            setInterventionSuggestion(followUp.interventionSuggestion)
        }
        selectHomeTab()
        persistActiveWorkspaceState()
    }
}

public enum BASAppleDraftedModeReopenExecutor {
    @discardableResult
    public static func execute(
        modeID: String?,
        clearActiveDecisionFlows: () -> Void,
        activateQuick: () -> Void,
        activateBalance: () -> Void,
        activateMirror: () -> Void,
        afterSuccessfulReopen: () -> Void
    ) -> Bool {
        clearActiveDecisionFlows()
        guard BASAppleDecisionModeExecutor.execute(
            modeID: modeID,
            performQuick: activateQuick,
            performBalance: activateBalance,
            performMirror: activateMirror
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
