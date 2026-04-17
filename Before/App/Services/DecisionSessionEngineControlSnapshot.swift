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
    let checkpointPressureLine: String?
    let checkpointAuditLine: String?
    let checkpointKillSwitchesLine: String?
    let checkpointActionLine: String?
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
