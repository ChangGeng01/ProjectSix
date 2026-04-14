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
        let sessionPresentations = sessions.map { session in
            sessionPresentation(
                from: session,
                inspection: inspectionBySessionID[session.id],
                isSelected: session.id == selectedSessionID
            )
        }

        let countsLine: String
        if let runtimeSnapshot {
            countsLine = "Sessions \(runtimeSnapshot.sessions) • Active \(runtimeSnapshot.activeSessions) • Stalled \(runtimeSnapshot.stalledSessions) • Branches \(runtimeSnapshot.branches) • Checkpoints \(runtimeSnapshot.checkpoints)"
        } else {
            countsLine = "Session Engine runtime inspection is unavailable."
        }

        let selectedCheckpointLine: String?
        if let selectedCheckpoint {
            if selectedCheckpoint.summary.goal.isEmpty {
                selectedCheckpointLine = "Checkpoint \(selectedCheckpoint.id) at event \(selectedCheckpoint.basedOnEventSeq)"
            } else {
                selectedCheckpointLine = "Checkpoint \(selectedCheckpoint.id) • \(selectedCheckpoint.summary.goal)"
            }
        } else {
            selectedCheckpointLine = nil
        }

        let branchPresentations = branchPresentations(
            branches: selectedBranches,
            selectedSession: selectedSession,
            selectedBranchID: selectedBranchID
        )

        let selectedBranchesLine: String?
        if branchPresentations.isEmpty {
            selectedBranchesLine = nil
        } else {
            let headName = branchPresentations.first(where: \.isHead)?.name ?? "unknown"
            selectedBranchesLine = "Branches \(branchPresentations.count) • Head \(headName)"
        }

        let timelineItems = (selectedTimeline?.items ?? []).map { item in
            let sessionAllowsMutations = selectedSession.map {
                $0.status != .archived && $0.status != .broken
            } ?? false
            return switch item.kind {
            case .checkpoint(let checkpoint):
                DecisionSessionEngineControlTimelinePresentation(
                    id: item.id,
                    title: item.title,
                    detail: item.detail,
                    branchID: item.branchId,
                    createdAt: item.createdAt,
                    seqLine: "Checkpoint event seq \(checkpoint.basedOnEventSeq)",
                    isCheckpoint: true,
                    checkpointID: checkpoint.id,
                    eventID: nil,
                    canRestoreCheckpoint: sessionAllowsMutations,
                    canTargetCorrection: false,
                    emphasizesRecovery: false
                )
            case .event(let event):
                DecisionSessionEngineControlTimelinePresentation(
                    id: item.id,
                    title: item.title.replacingOccurrences(of: "_", with: " "),
                    detail: item.detail,
                    branchID: item.branchId,
                    createdAt: item.createdAt,
                    seqLine: "Event seq \(event.seq)",
                    isCheckpoint: false,
                    checkpointID: nil,
                    eventID: event.id,
                    canRestoreCheckpoint: false,
                    canTargetCorrection: sessionAllowsMutations && correctionTargetable(event.type),
                    emphasizesRecovery: event.type == .sessionRecovered || event.type == .stepRecovered
                )
            }
        }

        let selectedMergeReview: DecisionSessionEngineControlMergeReview?
        if let selectedSession,
           let resolvedBranchID = selectedBranchID,
           let sourceBranch = selectedBranches.first(where: { $0.id == resolvedBranchID }),
           let targetBranch = selectedBranches.first(where: { $0.id == selectedSession.headBranchId }),
           sourceBranch.id != targetBranch.id,
           sourceBranch.status == .active,
           selectedSession.status != .archived,
           selectedSession.status != .broken {
            let checkpointLine = selectedCheckpoint.map {
                $0.summary.goal.isEmpty
                    ? "Selected checkpoint \($0.id)"
                    : "Selected checkpoint \($0.id) • \($0.summary.goal)"
            }
            let detailRows = mergeReviewDetailRows(
                sourceBranch: sourceBranch,
                targetBranch: targetBranch,
                checkpointLine: checkpointLine
            )
            selectedMergeReview = DecisionSessionEngineControlMergeReview(
                sourceBranchID: sourceBranch.id,
                sourceBranchName: sourceBranch.name,
                targetBranchID: targetBranch.id,
                targetBranchName: targetBranch.name,
                sourceStatusLine: branchStatusLine(sourceBranch.status, isHead: false),
                targetStatusLine: branchStatusLine(targetBranch.status, isHead: true),
                checkpointLine: checkpointLine,
                summaryLine: "Merge will append a branch_merged fact onto the current head branch, keep the source branch inspectable, and avoid rewriting existing history.",
                detailRows: detailRows
            )
        } else {
            selectedMergeReview = nil
        }

        let reviewItems = reviewItems(
            runtimeSnapshot: runtimeSnapshot,
            inspectionBySessionID: inspectionBySessionID,
            pendingImportPreview: pendingImportPreview
        )

        return DecisionSessionEngineControlSnapshot(
            title: "Session engine control center",
            headline: "Operate local append-only sessions directly: pause, resume, recover, archive, and inspect timeline rebuilds without touching original history.",
            countsLine: countsLine,
            reviewItems: reviewItems,
            pendingImportPreview: pendingImportPreview,
            emptyMessage: "No Session Engine session has been recorded yet.",
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
        runtimeSnapshot: DecisionSessionRuntimeSnapshot?,
        inspectionBySessionID: [String: DecisionSessionRuntimeInspectionSession],
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    ) -> [DecisionSessionEngineReviewItemPresentation] {
        let recentSessions = if let runtimeSnapshot {
            runtimeSnapshot.recentSessions
        } else {
            inspectionBySessionID.values.sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            }
        }
        let derivedMergeReadySessions = recentSessions.filter { $0.mergeableBranchCount > 0 }.count
        let derivedMergeableBranches = recentSessions.reduce(into: 0) { $0 += $1.mergeableBranchCount }
        let effectiveMergeReadySessions = max(runtimeSnapshot?.mergeReadySessions ?? 0, derivedMergeReadySessions)
        let effectiveMergeableBranches = max(runtimeSnapshot?.mergeableBranches ?? 0, derivedMergeableBranches)

        let synthesizedSummary = DecisionSystemSessionEngineSummary(
            layerPlacement: runtimeSnapshot?.layerPlacement ?? .foldedLung,
            sessions: runtimeSnapshot?.sessions ?? recentSessions.count,
            activeSessions: runtimeSnapshot?.activeSessions ?? recentSessions.filter { $0.status == .active }.count,
            stalledSessions: runtimeSnapshot?.stalledSessions ?? recentSessions.filter { $0.status == .stalled || $0.stalledStepCount > 0 }.count,
            mergeReadySessions: effectiveMergeReadySessions,
            mergeableBranches: effectiveMergeableBranches,
            branches: runtimeSnapshot?.branches ?? recentSessions.reduce(into: 0) { $0 += $1.branchCount },
            checkpoints: runtimeSnapshot?.checkpoints ?? recentSessions.reduce(into: 0) { count, session in
                if session.latestCheckpointID != nil {
                    count += 1
                }
            },
            events: runtimeSnapshot?.events ?? 0,
            steps: runtimeSnapshot?.steps ?? 0,
            activeSession: recentSessions.first,
            recentSessions: recentSessions,
            headline: "Session Engine control center keeps import, replay, and merge review visible before mutation.",
            signals: [],
            pendingImportPreview: pendingImportPreview
        )

        return DecisionSessionEngineReviewDigestBuilder.build(from: synthesizedSummary).map { line in
            DecisionSessionEngineReviewItemPresentation(
                id: line.id,
                title: line.title,
                detail: line.detail,
                severity: line.severity
            )
        }
    }

    private static func branchPresentations(
        branches: [DecisionSessionBranch],
        selectedSession: DecisionSession?,
        selectedBranchID: String?
    ) -> [DecisionSessionEngineControlBranchPresentation] {
        let headBranchID = selectedSession?.headBranchId
        let sessionAllowsMutations = selectedSession.map { $0.status != .archived && $0.status != .broken } ?? false

        return branches
            .sorted { lhs, rhs in
                let lhsIsHead = lhs.id == headBranchID
                let rhsIsHead = rhs.id == headBranchID
                if lhsIsHead != rhsIsHead {
                    return lhsIsHead && !rhsIsHead
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id > rhs.id
            }
            .map { branch in
                let isHead = branch.id == headBranchID
                let canSwitch = sessionAllowsMutations && branch.status == .active && !isHead
                let canMerge = sessionAllowsMutations && branch.status == .active && !isHead && headBranchID != nil
                let canAbandon = sessionAllowsMutations && branch.status == .active && !isHead
                let detailSegments = [
                    branchOriginLine(branch),
                    branch.parentBranchId.map { "Parent \($0)" },
                    branch.baseCheckpointId.map { "Base \($0)" }
                ].compactMap { $0 }
                let detailLine = detailSegments.isEmpty
                    ? "Created \(branch.createdAt.formatted(date: .abbreviated, time: .shortened))"
                    : detailSegments.joined(separator: " • ")

                return DecisionSessionEngineControlBranchPresentation(
                    id: branch.id,
                    name: branch.name,
                    statusLine: branchStatusLine(branch.status, isHead: isHead),
                    detailLine: detailLine,
                    createdAt: branch.createdAt,
                    isHead: isHead,
                    isInspecting: branch.id == selectedBranchID,
                    canSwitch: canSwitch,
                    canMerge: canMerge,
                    canAbandon: canAbandon
                )
            }
    }

    private static func branchOriginLine(_ branch: DecisionSessionBranch) -> String? {
        if branch.name.hasPrefix("correction-") {
            return "Correction branch"
        }
        if branch.name.hasPrefix("recovery-") {
            return "Recovery branch"
        }
        if branch.parentBranchId != nil || branch.baseCheckpointId != nil {
            return "Derived branch"
        }
        return nil
    }

    private static func branchStatusLine(
        _ status: DecisionSessionBranchStatus,
        isHead: Bool
    ) -> String {
        let baseStatus = status.rawValue.capitalized
        if isHead {
            return "\(baseStatus) • current head"
        }
        return baseStatus
    }

    private static func mergeReviewDetailRows(
        sourceBranch: DecisionSessionBranch,
        targetBranch: DecisionSessionBranch,
        checkpointLine: String?
    ) -> [DecisionSessionEngineControlReviewDetail] {
        var rows: [DecisionSessionEngineControlReviewDetail] = [
            DecisionSessionEngineControlReviewDetail(
                id: "source-branch",
                label: "Source branch",
                value: "\(sourceBranch.name) • \(sourceBranch.id)"
            ),
            DecisionSessionEngineControlReviewDetail(
                id: "target-branch",
                label: "Target branch",
                value: "\(targetBranch.name) • \(targetBranch.id)"
            ),
            DecisionSessionEngineControlReviewDetail(
                id: "source-status",
                label: "Source status",
                value: branchStatusLine(sourceBranch.status, isHead: false)
            ),
            DecisionSessionEngineControlReviewDetail(
                id: "target-status",
                label: "Target status",
                value: branchStatusLine(targetBranch.status, isHead: true)
            )
        ]

        if let checkpointLine {
            rows.append(
                DecisionSessionEngineControlReviewDetail(
                    id: "checkpoint",
                    label: "Checkpoint",
                    value: checkpointLine
                )
            )
        }

        return rows
    }

    private static func correctionTargetable(_ type: DecisionSessionEventType) -> Bool {
        switch type {
        case .assistantMessage,
                .userMessage,
                .correctionAdded,
                .toolCallStarted,
                .toolCallFinished,
                .toolCallFailed:
            true
        case .branchMerged,
                .checkpointCreated,
                .stepStarted,
                .stepHeartbeat,
                .stepStalled,
                .stepRecovered,
                .sessionPaused,
                .sessionResumed,
                .sessionError,
                .sessionRecovered,
                .branchCreated:
            false
        }
    }

    private static func sessionPresentation(
        from session: DecisionSession,
        inspection: DecisionSessionRuntimeInspectionSession?,
        isSelected: Bool
    ) -> DecisionSessionEngineControlSessionPresentation {
        let checkpointLine: String
        if let latestCheckpointID = inspection?.latestCheckpointID {
            if let goal = inspection?.latestCheckpointGoal, goal.isEmpty == false {
                checkpointLine = "Checkpoint \(latestCheckpointID) • \(goal)"
            } else {
                checkpointLine = "Checkpoint \(latestCheckpointID)"
            }
        } else if let latestCheckpointID = session.latestCheckpointId {
            checkpointLine = "Checkpoint \(latestCheckpointID)"
        } else {
            checkpointLine = "Checkpoint none"
        }

        let branchLine: String
        if let inspection {
            branchLine = inspection.mergeableBranchCount > 0
                ? "Head \(session.headBranchId) • Branches \(inspection.branchCount) • Merge-ready \(inspection.mergeableBranchCount)"
                : "Head \(session.headBranchId) • Branches \(inspection.branchCount)"
        } else {
            branchLine = "Head \(session.headBranchId)"
        }
        let mergeReviewLine = inspection?.mergeReviewLine

        let recoveryLine: String
        if let inspection {
            recoveryLine = inspection.recoveryCount > 0
                ? "Recoveries \(inspection.recoveryCount) • latest recorded"
                : "Recoveries 0"
        } else {
            recoveryLine = "Recoveries unavailable"
        }

        let detailLine = inspection?.detailLine
            ?? "Session \(session.id) • updated \(session.updatedAt.formatted(date: .abbreviated, time: .shortened))"

        let faultLine: String?
        if inspection?.openStepIsHeartbeatOverdue == true {
            faultLine = "Fault line • watchdog expired on the current open step."
        } else if session.status == .stalled || inspection?.stalledStepCount ?? 0 > 0 {
            faultLine = "Fault line • stalled work was detected; recover from the last stable checkpoint before continuing."
        } else if let recoveryCount = inspection?.recoveryCount, recoveryCount > 0 {
            faultLine = "Recovery line • \(recoveryCount) recovery branch(es) were recorded on this session."
        } else {
            faultLine = nil
        }

        return DecisionSessionEngineControlSessionPresentation(
            sessionID: session.id,
            title: session.title,
            statusLine: inspection.map {
                "\($0.status.rawValue.capitalized) • \($0.latestEventType?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "idle")"
            } ?? session.status.rawValue.capitalized,
            healthSummary: DecisionSessionEngineHealthSummary.summary(
                sessionStatus: session.status,
                inspection: inspection
            ),
            checkpointLine: checkpointLine,
            checkpointBudgetLine: [inspection?.latestCheckpointBudgetLine, inspection?.latestCheckpointRouteLine]
                .compactMap { $0 }
                .joined(separator: " • ")
                .nilIfEmpty,
            checkpointDecisionLine: inspection?.latestCheckpointDecisionLine,
            checkpointTaskLine: inspection?.latestCheckpointTaskLine,
            checkpointActionLine: inspection?.latestCheckpointActionLine,
            branchLine: branchLine,
            recoveryLine: recoveryLine,
            mergeReviewLine: mergeReviewLine,
            faultLine: faultLine,
            stepFreshnessLine: inspection?.openStepFreshnessLine,
            stepAlertLine: inspection?.openStepAlertLine,
            detailLine: detailLine,
            updatedAt: session.updatedAt,
            canPause: session.status == .active,
            canResume: session.status == .paused,
            canRecover: session.status == .stalled || inspection?.stalledStepCount ?? 0 > 0 || inspection?.openStepIsHeartbeatOverdue == true,
            canArchive: session.status != .archived,
            canCorrect: session.status != .archived && session.status != .broken,
            isSelected: isSelected
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
