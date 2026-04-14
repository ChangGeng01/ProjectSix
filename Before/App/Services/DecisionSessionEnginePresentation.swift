import Foundation

enum DecisionSessionEngineHealthSeverity: String, Equatable, Sendable {
    case stable
    case watch
    case critical
}

struct DecisionSessionEngineHealthSummary: Equatable, Sendable {
    let severity: DecisionSessionEngineHealthSeverity
    let title: String
    let detail: String

    static func summary(
        from summary: DecisionSystemSessionEngineSummary
    ) -> DecisionSessionEngineHealthSummary? {
        if summary.recentSessions.contains(where: \.openStepIsHeartbeatOverdue) {
            return DecisionSessionEngineHealthSummary(
                severity: .critical,
                title: "Watchdog overdue",
                detail: "At least one open step has outlived its watchdog budget. Recover from the last stable checkpoint before continuing."
            )
        }

        if summary.stalledSessions > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Recovery attention required",
                detail: "Stalled sessions \(summary.stalledSessions) • Recovery inspection should stay visible before more work is started."
            )
        }

        if summary.mergeableBranches > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Merge review pending",
                detail: "Merge-ready sessions \(summary.mergeReadySessions) • Merge-ready branches \(summary.mergeableBranches) • Review correction lines before they drift away from the current head."
            )
        }

        if summary.activeSessions > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Protected execution active",
                detail: "Active sessions \(summary.activeSessions) • Recovery line stays attached to the latest stable checkpoint."
            )
        }

        if summary.sessions > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Checkpoint lineage available",
                detail: "No active session is currently running, but checkpoint lineage remains reviewable."
            )
        }

        return nil
    }

    static func summary(
        sessionStatus: DecisionSessionStatus,
        inspection: DecisionSessionRuntimeInspectionSession?
    ) -> DecisionSessionEngineHealthSummary? {
        if inspection?.openStepIsHeartbeatOverdue == true {
            return DecisionSessionEngineHealthSummary(
                severity: .critical,
                title: "Watchdog expired",
                detail: inspection?.openStepAlertLine
                    ?? "Watchdog budget expired on the current open step. Recover before continuing."
            )
        }

        if sessionStatus == .stalled || inspection?.stalledStepCount ?? 0 > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Recovery ready",
                detail: inspection?.openStepAlertLine
                    ?? "A stalled step was detected. Recovery should stay available from the last stable checkpoint."
            )
        }

        if let inspection, inspection.recoveryCount > 0 {
            let recoveryDetail: String
            if let latestRecoveryAt = inspection.latestRecoveryAt {
                recoveryDetail = "Recovered \(latestRecoveryAt.formatted(date: .omitted, time: .shortened)) • latest stable checkpoint remains replayable."
            } else {
                recoveryDetail = "Recoveries \(inspection.recoveryCount) • latest stable checkpoint remains replayable."
            }
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Recovered checkpoint line",
                detail: recoveryDetail
            )
        }

        if let inspection, inspection.openStepCount > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Heartbeat active",
                detail: inspection.openStepFreshnessLine
                    ?? "An open step is still progressing under watchdog supervision."
            )
        }

        if let inspection, let latestCheckpointID = inspection.latestCheckpointID {
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Stable checkpoint available",
                detail: "Checkpoint \(latestCheckpointID) remains available for rebuild and branch recovery."
            )
        }

        switch sessionStatus {
        case .active:
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Session active",
                detail: "Append-only event history is live and ready for the next protected checkpoint."
            )
        case .paused:
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Session paused",
                detail: "The session is paused, but its stable checkpoint line remains available for recovery."
            )
        case .archived:
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Session archived",
                detail: "Archived sessions keep their immutable event line and checkpoint history for replay."
            )
        case .broken:
            return DecisionSessionEngineHealthSummary(
                severity: .critical,
                title: "Session broken",
                detail: "This session needs import, recovery, or archive intervention before it should be used again."
            )
        case .stalled:
            return DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Recovery ready",
                detail: "A stalled step was detected. Recovery should stay available from the last stable checkpoint."
            )
        }
    }
}

struct DecisionSessionEngineSessionPresentation: Identifiable, Equatable, Sendable {
    let sessionID: String
    let title: String
    let statusLine: String
    let healthSummary: DecisionSessionEngineHealthSummary?
    let replayRecoverySummary: DecisionSessionEngineReplayRecoverySummary
    let checkpointLine: String
    let checkpointBudgetLine: String?
    let checkpointDecisionLine: String?
    let checkpointTaskLine: String?
    let checkpointActionLine: String?
    let recoveryLine: String
    let activityLine: String
    let stepFreshnessLine: String?
    let stepAlertLine: String?
    let branchLine: String
    let mergeReviewLine: String?
    let detailLine: String
    let canRecover: Bool
    let isActive: Bool

    var id: String { sessionID }
}

struct DecisionSessionEngineReplayRecoverySummary: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let title: String
    let replayLine: String
    let recoveryLine: String
    let detailLine: String
    let budgetLine: String?
    let taskLine: String?
    let actionLine: String?
    let auditLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?

    var headlineLine: String {
        "\(title) • \(recoveryLine)"
    }
}

extension DeveloperDecisionReplayEBrainSummary {
    var replayRecoverySummary: DecisionSessionEngineReplayRecoverySummary {
        DecisionSessionEngineReplayRecoverySummary(
            sourceDescriptor: sourceDescriptor,
            title: sourceDescriptor.title,
            replayLine: "Replay session \(sessionID) • Recorded \(recordedAt.formatted(date: .abbreviated, time: .shortened))",
            recoveryLine: "\(riskLevel.uppercased()) → \(permitMode.uppercased()) • host gate \(hostGatePercent)% • fold \(thoughtFoldChecksum)",
            detailLine: updateTicketSummaries.first ?? "Recovered lineage remains inspectable.",
            budgetLine: checkpointBudgetLine,
            taskLine: checkpointTaskLine,
            actionLine: nil,
            auditLine: guardrailFindings.isEmpty
                ? nil
                : "Audit: \(guardrailFindings.prefix(2).joined(separator: " • "))",
            activeKillSwitchesLine: activeKillSwitches.isEmpty
                ? nil
                : "Active kill switches: \(activeKillSwitches.joined(separator: " • "))",
            killSwitchesLine: killSwitches.isEmpty
                ? nil
                : "Kill switches: \(killSwitches.joined(separator: " • "))"
        )
    }
}

extension DecisionSessionRuntimeInspectionSession {
    var replayRecoverySummary: DecisionSessionEngineReplayRecoverySummary {
        let sourceDescriptor: DecisionEvolutionSourceDescriptor = if recoveryCount > 0 || stalledStepCount > 0 || openStepIsHeartbeatOverdue {
            .checkpointRecoveryDefault
        } else {
            .liveRuntimeDefault
        }

        let recoveryLine: String
        if let latestRecoveryAt {
            recoveryLine = "Recovered \(latestRecoveryAt.formatted(date: .omitted, time: .shortened)) • latest stable checkpoint remains replayable."
        } else {
            recoveryLine = "Recoveries \(recoveryCount) • latest stable checkpoint remains replayable."
        }

        let detailLine: String
        if let latestCheckpointID = latestCheckpointID {
            if let latestCheckpointGoal, latestCheckpointGoal.isEmpty == false {
                detailLine = "Checkpoint \(latestCheckpointID) • \(latestCheckpointGoal)"
            } else {
                detailLine = "Checkpoint \(latestCheckpointID)"
            }
        } else {
            detailLine = "Checkpoint none"
        }

        return DecisionSessionEngineReplayRecoverySummary(
            sourceDescriptor: sourceDescriptor,
            title: sourceDescriptor.title,
            replayLine: "Replay session \(sessionID) • Head \(headBranchID)",
            recoveryLine: recoveryLine,
            detailLine: detailLine,
            budgetLine: latestCheckpointBudgetLine,
            taskLine: latestCheckpointTaskLine,
            actionLine: latestCheckpointActionLine,
            auditLine: openStepAlertLine,
            activeKillSwitchesLine: nil,
            killSwitchesLine: nil
        )
    }

    var replayRecoveryPresentation: DecisionSessionEngineReplayRecoverySummary {
        replayRecoverySummary
    }
}

struct DecisionSessionEngineReviewItemPresentation: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let severity: DecisionSessionEngineHealthSeverity
}

struct DecisionSessionEnginePresentation: Equatable, Sendable {
    let title: String
    let headline: String
    let countsLine: String
    let healthSummary: DecisionSessionEngineHealthSummary?
    let healthLine: String?
    let reviewItems: [DecisionSessionEngineReviewItemPresentation]
    let pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    let activeSession: DecisionSessionEngineSessionPresentation?
    let recentSessions: [DecisionSessionEngineSessionPresentation]
    let emptyMessage: String

    static let unattached = DecisionSessionEnginePresentation(
        title: "Session engine",
        headline: "Append-only events, checkpoints, and branch recovery keep local history salvageable.",
        countsLine: "No session-engine inspection is attached yet.",
        healthSummary: nil,
        healthLine: nil,
        reviewItems: [],
        pendingImportPreview: nil,
        activeSession: nil,
        recentSessions: [],
        emptyMessage: "Session Engine inspection appears here once local execution history is attached to the runtime export."
    )

    static func build(
        from summary: DecisionSystemSessionEngineSummary?
    ) -> DecisionSessionEnginePresentation {
        guard let summary else {
            return .unattached
        }

        let sessionPresentations = summary.recentSessions.enumerated().map { index, session in
            sessionPresentation(from: session, isActive: index == 0)
        }

        let healthSummary = DecisionSessionEngineHealthSummary.summary(from: summary)

        return DecisionSessionEnginePresentation(
            title: "Session engine",
            headline: summary.headline,
            countsLine: "Sessions \(summary.sessions) • Active \(summary.activeSessions) • Stalled \(summary.stalledSessions) • Merge-ready \(summary.mergeableBranches) • Branches \(summary.branches) • Checkpoints \(summary.checkpoints)",
            healthSummary: healthSummary,
            healthLine: healthSummary?.detail,
            reviewItems: reviewItems(from: summary),
            pendingImportPreview: summary.pendingImportPreview,
            activeSession: sessionPresentations.first,
            recentSessions: Array(sessionPresentations.dropFirst()),
            emptyMessage: "No local session inspection has been recorded yet."
        )
    }

    private static func reviewItems(
        from summary: DecisionSystemSessionEngineSummary
    ) -> [DecisionSessionEngineReviewItemPresentation] {
        DecisionSessionEngineReviewDigestBuilder.build(from: summary).map { line in
            DecisionSessionEngineReviewItemPresentation(
                id: line.id,
                title: line.title,
                detail: line.detail,
                severity: line.severity
            )
        }
    }

    private static func sessionPresentation(
        from session: DecisionSessionRuntimeInspectionSession,
        isActive: Bool
    ) -> DecisionSessionEngineSessionPresentation {
        let eventDescriptor = session.latestEventType?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "idle"
        let checkpointDescriptor: String
        if let checkpointID = session.latestCheckpointID {
            if let latestCheckpointGoal = session.latestCheckpointGoal,
               latestCheckpointGoal.isEmpty == false {
                checkpointDescriptor = "Checkpoint \(checkpointID) • \(latestCheckpointGoal)"
            } else {
                checkpointDescriptor = "Checkpoint \(checkpointID)"
            }
        } else {
            checkpointDescriptor = "Checkpoint none"
        }

        let recoveryDescriptor = session.recoveryCount > 0
            ? "Recoveries \(session.recoveryCount) • latest recorded"
            : "Recoveries 0"
        let openStepDescriptor: String
        if let openStepStatus = session.openStepStatus {
            let openStepTitle = openStepStatus.rawValue.replacingOccurrences(of: "_", with: " ")
            openStepDescriptor = "Open steps \(session.openStepCount) • \(openStepTitle)"
        } else {
            openStepDescriptor = "Open steps \(session.openStepCount)"
        }
        let branchDescriptor = if let latestEventSeq = session.latestEventSeq {
            "Branches \(session.branchCount) • Latest seq \(latestEventSeq)"
        } else if let latestCheckpointSeq = session.latestCheckpointSeq {
            "Branches \(session.branchCount) • Checkpoint seq \(latestCheckpointSeq)"
        } else {
            "Branches \(session.branchCount)"
        }
        let mergeReviewLine = session.mergeReviewLine

        return DecisionSessionEngineSessionPresentation(
            sessionID: session.sessionID,
            title: session.title,
            statusLine: "\(session.status.rawValue.capitalized) • \(eventDescriptor)",
            healthSummary: DecisionSessionEngineHealthSummary.summary(
                sessionStatus: session.status,
                inspection: session
            ),
            replayRecoverySummary: session.replayRecoverySummary,
            checkpointLine: checkpointDescriptor,
            checkpointBudgetLine: [session.latestCheckpointBudgetLine, session.latestCheckpointRouteLine]
                .compactMap { $0 }
                .joined(separator: " • ")
                .nilIfEmpty,
            checkpointDecisionLine: session.latestCheckpointDecisionLine,
            checkpointTaskLine: session.latestCheckpointTaskLine,
            checkpointActionLine: session.latestCheckpointActionLine,
            recoveryLine: recoveryDescriptor,
            activityLine: "\(openStepDescriptor) • Stalled \(session.stalledStepCount)",
            stepFreshnessLine: session.openStepFreshnessLine,
            stepAlertLine: session.openStepAlertLine,
            branchLine: session.mergeableBranchCount > 0
                ? "\(branchDescriptor) • Merge-ready \(session.mergeableBranchCount)"
                : branchDescriptor,
            mergeReviewLine: mergeReviewLine,
            detailLine: session.detailLine,
            canRecover: session.status == .stalled || session.stalledStepCount > 0 || session.openStepIsHeartbeatOverdue,
            isActive: isActive
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
