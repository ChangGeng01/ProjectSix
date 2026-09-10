import Foundation

struct DecisionSessionEngineControlSessionPresentation: Identifiable, Equatable, Sendable {
    let sessionID: String
    let title: String
    let statusLine: String
    let healthSummary: DecisionSessionEngineHealthSummary?
    let checkpointLine: String
    let checkpointBudgetLine: String?
    let checkpointDecisionLine: String?
    let checkpointTaskLine: String?
    let checkpointWindGateLine: String?
    let checkpointPresenceLine: String?
    let checkpointPressureLine: String?
    let checkpointRiskFactorsLine: String?
    let checkpointReasonCodesLine: String?
    let checkpointCourtLine: String?
    let checkpointAuditLine: String?
    let checkpointSovereignVerdictLine: String?
    let checkpointSovereignAuthorityLine: String?
    let checkpointSovereignAuditLine: String?
    let checkpointKillSwitchesLine: String?
    let checkpointActionLine: String?
    let checkpointMorphLine: String?
    let checkpointLungLine: String?
    let checkpointHotColdLine: String?
    let checkpointPrecisionLine: String?
    let checkpointOrganPackageLine: String?
    let checkpointOrganDeltaLine: String?
    let checkpointSchedulerLine: String?
    let checkpointThermalExchangeLine: String?
    let checkpointIntegrityWeaveLine: String?
    let checkpointResumeLine: String?
    let checkpointRollbackLine: String?
    let checkpointSovereignBridgeLine: String?
    let checkpointSovereignBridgeDetailLines: [String]
    let branchLine: String
    let recoveryLine: String
    let mergeReviewLine: String?
    let faultLine: String?
    let stepFreshnessLine: String?
    let stepAlertLine: String?
    let detailLine: String
    let updatedAt: Date
    let canPause: Bool
    let canResume: Bool
    let canRecover: Bool
    let canArchive: Bool
    let canCorrect: Bool
    let isSelected: Bool

    init(
        sessionID: String,
        title: String,
        statusLine: String,
        healthSummary: DecisionSessionEngineHealthSummary?,
        checkpointLine: String,
        checkpointBudgetLine: String?,
        checkpointDecisionLine: String?,
        checkpointTaskLine: String?,
        checkpointWindGateLine: String? = nil,
        checkpointPresenceLine: String? = nil,
        checkpointPressureLine: String?,
        checkpointRiskFactorsLine: String?,
        checkpointReasonCodesLine: String?,
        checkpointCourtLine: String?,
        checkpointAuditLine: String?,
        checkpointSovereignVerdictLine: String?,
        checkpointSovereignAuthorityLine: String?,
        checkpointSovereignAuditLine: String?,
        checkpointKillSwitchesLine: String?,
        checkpointActionLine: String?,
        checkpointMorphLine: String? = nil,
        checkpointLungLine: String?,
        checkpointHotColdLine: String?,
        checkpointPrecisionLine: String? = nil,
        checkpointOrganPackageLine: String? = nil,
        checkpointOrganDeltaLine: String? = nil,
        checkpointSchedulerLine: String? = nil,
        checkpointThermalExchangeLine: String? = nil,
        checkpointIntegrityWeaveLine: String? = nil,
        checkpointResumeLine: String?,
        checkpointRollbackLine: String?,
        checkpointSovereignBridgeLine: String?,
        checkpointSovereignBridgeDetailLines: [String],
        branchLine: String,
        recoveryLine: String,
        mergeReviewLine: String?,
        faultLine: String?,
        stepFreshnessLine: String?,
        stepAlertLine: String?,
        detailLine: String,
        updatedAt: Date,
        canPause: Bool,
        canResume: Bool,
        canRecover: Bool,
        canArchive: Bool,
        canCorrect: Bool,
        isSelected: Bool
    ) {
        self.sessionID = sessionID
        self.title = title
        self.statusLine = statusLine
        self.healthSummary = healthSummary
        self.checkpointLine = checkpointLine
        self.checkpointBudgetLine = checkpointBudgetLine
        self.checkpointDecisionLine = checkpointDecisionLine
        self.checkpointTaskLine = checkpointTaskLine
        self.checkpointWindGateLine = checkpointWindGateLine
        self.checkpointPresenceLine = checkpointPresenceLine
        self.checkpointPressureLine = checkpointPressureLine
        self.checkpointRiskFactorsLine = checkpointRiskFactorsLine
        self.checkpointReasonCodesLine = checkpointReasonCodesLine
        self.checkpointCourtLine = checkpointCourtLine
        self.checkpointAuditLine = checkpointAuditLine
        self.checkpointSovereignVerdictLine = checkpointSovereignVerdictLine
        self.checkpointSovereignAuthorityLine = checkpointSovereignAuthorityLine
        self.checkpointSovereignAuditLine = checkpointSovereignAuditLine
        self.checkpointKillSwitchesLine = checkpointKillSwitchesLine
        self.checkpointActionLine = checkpointActionLine
        self.checkpointMorphLine = checkpointMorphLine
        self.checkpointLungLine = checkpointLungLine
        self.checkpointHotColdLine = checkpointHotColdLine
        self.checkpointPrecisionLine = checkpointPrecisionLine
        self.checkpointOrganPackageLine = checkpointOrganPackageLine
        self.checkpointOrganDeltaLine = checkpointOrganDeltaLine
        self.checkpointSchedulerLine = checkpointSchedulerLine
        self.checkpointThermalExchangeLine = checkpointThermalExchangeLine
        self.checkpointIntegrityWeaveLine = checkpointIntegrityWeaveLine
        self.checkpointResumeLine = checkpointResumeLine
        self.checkpointRollbackLine = checkpointRollbackLine
        self.checkpointSovereignBridgeLine = checkpointSovereignBridgeLine
        self.checkpointSovereignBridgeDetailLines = checkpointSovereignBridgeDetailLines
        self.branchLine = branchLine
        self.recoveryLine = recoveryLine
        self.mergeReviewLine = mergeReviewLine
        self.faultLine = faultLine
        self.stepFreshnessLine = stepFreshnessLine
        self.stepAlertLine = stepAlertLine
        self.detailLine = detailLine
        self.updatedAt = updatedAt
        self.canPause = canPause
        self.canResume = canResume
        self.canRecover = canRecover
        self.canArchive = canArchive
        self.canCorrect = canCorrect
        self.isSelected = isSelected
    }

    static func make(
        sessionID: String,
        title: String,
        statusLine: String,
        healthSummary: DecisionSessionEngineHealthSummary?,
        checkpointLine: String,
        checkpointBudgetLine: String?,
        checkpointDecisionLine: String?,
        checkpointTaskLine: String?,
        checkpointWindGateLine: String? = nil,
        checkpointPresenceLine: String? = nil,
        checkpointPressureLine: String?,
        checkpointRiskFactorsLine: String?,
        checkpointReasonCodesLine: String?,
        checkpointCourtLine: String?,
        checkpointAuditLine: String?,
        checkpointSovereignVerdictLine: String?,
        checkpointSovereignAuthorityLine: String?,
        checkpointSovereignAuditLine: String?,
        checkpointKillSwitchesLine: String?,
        checkpointActionLine: String?,
        checkpointMorphLine: String? = nil,
        checkpointLungLine: String?,
        checkpointHotColdLine: String?,
        checkpointPrecisionLine: String? = nil,
        checkpointOrganPackageLine: String? = nil,
        checkpointOrganDeltaLine: String? = nil,
        checkpointSchedulerLine: String? = nil,
        checkpointThermalExchangeLine: String? = nil,
        checkpointIntegrityWeaveLine: String? = nil,
        checkpointResumeLine: String?,
        checkpointRollbackLine: String?,
        checkpointSovereignBridgeLine: String?,
        checkpointSovereignBridgeDetailLines: [String],
        branchLine: String,
        recoveryLine: String,
        mergeReviewLine: String?,
        faultLine: String?,
        stepFreshnessLine: String?,
        stepAlertLine: String?,
        detailLine: String,
        updatedAt: Date,
        canPause: Bool,
        canResume: Bool,
        canRecover: Bool,
        canArchive: Bool,
        canCorrect: Bool,
        isSelected: Bool
    ) -> DecisionSessionEngineControlSessionPresentation {
        DecisionSessionEngineControlSessionPresentation(
            sessionID: sessionID,
            title: title,
            statusLine: statusLine,
            healthSummary: healthSummary,
            checkpointLine: checkpointLine,
            checkpointBudgetLine: checkpointBudgetLine,
            checkpointDecisionLine: checkpointDecisionLine,
            checkpointTaskLine: checkpointTaskLine,
            checkpointWindGateLine: checkpointWindGateLine,
            checkpointPresenceLine: checkpointPresenceLine,
            checkpointPressureLine: checkpointPressureLine,
            checkpointRiskFactorsLine: checkpointRiskFactorsLine,
            checkpointReasonCodesLine: checkpointReasonCodesLine,
            checkpointCourtLine: checkpointCourtLine,
            checkpointAuditLine: checkpointAuditLine,
            checkpointSovereignVerdictLine: checkpointSovereignVerdictLine,
            checkpointSovereignAuthorityLine: checkpointSovereignAuthorityLine,
            checkpointSovereignAuditLine: checkpointSovereignAuditLine,
            checkpointKillSwitchesLine: checkpointKillSwitchesLine,
            checkpointActionLine: checkpointActionLine,
            checkpointMorphLine: checkpointMorphLine,
            checkpointLungLine: checkpointLungLine,
            checkpointHotColdLine: checkpointHotColdLine,
            checkpointPrecisionLine: checkpointPrecisionLine,
            checkpointOrganPackageLine: checkpointOrganPackageLine,
            checkpointOrganDeltaLine: checkpointOrganDeltaLine,
            checkpointSchedulerLine: checkpointSchedulerLine,
            checkpointThermalExchangeLine: checkpointThermalExchangeLine,
            checkpointIntegrityWeaveLine: checkpointIntegrityWeaveLine,
            checkpointResumeLine: checkpointResumeLine,
            checkpointRollbackLine: checkpointRollbackLine,
            checkpointSovereignBridgeLine: checkpointSovereignBridgeLine,
            checkpointSovereignBridgeDetailLines: checkpointSovereignBridgeDetailLines,
            branchLine: branchLine,
            recoveryLine: recoveryLine,
            mergeReviewLine: mergeReviewLine,
            faultLine: faultLine,
            stepFreshnessLine: stepFreshnessLine,
            stepAlertLine: stepAlertLine,
            detailLine: detailLine,
            updatedAt: updatedAt,
            canPause: canPause,
            canResume: canResume,
            canRecover: canRecover,
            canArchive: canArchive,
            canCorrect: canCorrect,
            isSelected: isSelected
        )
    }

    var id: String { sessionID }
}

struct DecisionSessionEngineControlTimelinePresentation: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let branchID: String
    let createdAt: Date
    let seqLine: String?
    let isCheckpoint: Bool
    let checkpointID: String?
    let eventID: String?
    let canRestoreCheckpoint: Bool
    let canTargetCorrection: Bool
    let emphasizesRecovery: Bool
}

struct DecisionSessionEngineControlBranchPresentation: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let statusLine: String
    let detailLine: String
    let createdAt: Date
    let isHead: Bool
    let isInspecting: Bool
    let canSwitch: Bool
    let canMerge: Bool
    let canAbandon: Bool
}

struct DecisionSessionEngineControlMergeReview: Equatable, Sendable {
    let sourceBranchID: String
    let sourceBranchName: String
    let targetBranchID: String
    let targetBranchName: String
    let sourceStatusLine: String
    let targetStatusLine: String
    let checkpointLine: String?
    let summaryLine: String
    let detailRows: [DecisionSessionEngineControlReviewDetail]
}

struct DecisionSessionEngineControlReviewDetail: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let value: String
}

struct DecisionSessionEngineControlSnapshot: Equatable, Sendable {
    let title: String
    let headline: String
    let countsLine: String
    let reviewItems: [DecisionSessionEngineReviewItemPresentation]
    let pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    let emptyMessage: String
    let sessions: [DecisionSessionEngineControlSessionPresentation]
    let selectedSessionID: String?
    let selectedBranchID: String?
    let selectedCheckpointID: String?
    let selectedCheckpointLine: String?
    let selectedBranchesLine: String?
    let selectedRecoveryNotice: String?
    let selectedMergeNotice: String?
    let selectedBranches: [DecisionSessionEngineControlBranchPresentation]
    let selectedMergeReview: DecisionSessionEngineControlMergeReview?
    let timelineItems: [DecisionSessionEngineControlTimelinePresentation]

    static func build(
        runtimeSnapshot: DecisionSessionRuntimeSnapshot?,
        sessions: [DecisionSession],
        inspectionBySessionID: [String: DecisionSessionRuntimeInspectionSession],
        selectedSessionID: String?,
        selectedBranchID: String?,
        selectedBranches: [DecisionSessionBranch],
        selectedCheckpoint: DecisionSessionCheckpoint?,
        selectedTimeline: DecisionSessionTimeline?,
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation? = nil
    ) -> DecisionSessionEngineControlSnapshot {
        let selectedSession = sessions.first(where: { $0.id == selectedSessionID })
        let synthesizedSummary = synthesizedSummary(
            runtimeSnapshot: runtimeSnapshot,
            inspectionBySessionID: inspectionBySessionID,
            pendingImportPreview: pendingImportPreview
        )
        let sessionPresentations = sessions.map { session in
            DecisionSessionControlPresentationSupport.sessionPresentation(
                session: session,
                inspection: inspectionBySessionID[session.id],
                isSelected: session.id == selectedSessionID
            )
        }

        let countsLine = DecisionSessionControlPresentationSupport.countsLine(
            runtimeSnapshot: runtimeSnapshot,
            synthesizedSummary: synthesizedSummary
        )

        let sessionAllowsMutations = selectedSession.map {
            $0.status != .archived && $0.status != .broken
        } ?? false
        let selectedCheckpointLine = DecisionSessionControlPresentationSupport.selectedCheckpointLine(
            checkpoint: selectedCheckpoint
        )

        let branchPresentations = DecisionSessionControlPresentationSupport.branchPresentations(
            branches: selectedBranches,
            headBranchID: selectedSession?.headBranchId,
            selectedBranchID: selectedBranchID,
            sessionAllowsMutations: sessionAllowsMutations
        )

        let selectedBranchesLine = DecisionSessionControlPresentationSupport.selectedBranchesLine(
            branchPresentations: branchPresentations
        )

        let timelineItems = DecisionSessionControlPresentationSupport.timelinePresentations(
            items: selectedTimeline?.items ?? [],
            sessionAllowsMutations: sessionAllowsMutations
        )

        let selectedMergeReview = DecisionSessionControlPresentationSupport.selectedMergeReview(
            session: selectedSession,
            selectedBranchID: selectedBranchID,
            branches: selectedBranches,
            selectedCheckpoint: selectedCheckpoint
        )

        let reviewItems = reviewItems(
            from: synthesizedSummary
        )

        return DecisionSessionEngineControlSnapshot(
            title: DecisionSessionControlPresentationSupport.title,
            headline: DecisionSessionControlPresentationSupport.headline,
            countsLine: countsLine,
            reviewItems: reviewItems,
            pendingImportPreview: pendingImportPreview,
            emptyMessage: DecisionSessionControlPresentationSupport.emptyMessage,
            sessions: sessionPresentations,
            selectedSessionID: selectedSessionID,
            selectedBranchID: selectedBranchID,
            selectedCheckpointID: selectedCheckpoint?.id,
            selectedCheckpointLine: selectedCheckpointLine,
            selectedBranchesLine: selectedBranchesLine,
            selectedRecoveryNotice: selectedTimeline?.recoveryNotice,
            selectedMergeNotice: selectedTimeline?.mergeNotice,
            selectedBranches: branchPresentations,
            selectedMergeReview: selectedMergeReview,
            timelineItems: timelineItems
        )
    }

    private static func reviewItems(
        from summary: DecisionSystemSessionEngineSummary
    ) -> [DecisionSessionEngineReviewItemPresentation] {
        DecisionSessionEngineReviewDigestBuilder.presentations(from: summary)
    }

    private static func synthesizedSummary(
        runtimeSnapshot: DecisionSessionRuntimeSnapshot?,
        inspectionBySessionID: [String: DecisionSessionRuntimeInspectionSession],
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    ) -> DecisionSystemSessionEngineSummary {
        DecisionSystemSessionEngineSummary.controlCenterSummary(
            runtimeSnapshot: runtimeSnapshot,
            inspectionBySessionID: inspectionBySessionID,
            pendingImportPreview: pendingImportPreview
        )
    }

}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
