import Foundation

struct DecisionSessionEngineReviewDigestLine: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let severity: DecisionSessionEngineHealthSeverity
}

struct DecisionSessionInspectionAggregate: Equatable, Sendable {
    let sessions: Int
    let activeSessions: Int
    let stalledSessions: Int
    let branches: Int
    let checkpoints: Int
}

enum DecisionSessionRecoveryPresentationSupport {
    static func replayableRecoveryLine(
        latestRecoveryAt: Date?,
        recoveryCount: Int
    ) -> String {
        if let latestRecoveryAt {
            return "Recovered \(latestRecoveryAt.formatted(date: .omitted, time: .shortened)) • latest stable checkpoint remains replayable."
        }

        return "Recoveries \(recoveryCount) • latest stable checkpoint remains replayable."
    }

    static func recordedRecoveryLine(
        latestRecoveryAt: Date?,
        recoveryCount: Int
    ) -> String {
        if let latestRecoveryAt {
            return "Recoveries \(recoveryCount) • latest \(latestRecoveryAt.formatted(date: .omitted, time: .shortened))"
        }

        return recoveryCount > 0
            ? "Recoveries \(recoveryCount) • latest recorded"
            : "Recoveries 0"
    }

    static func compactRecoveryLine(
        latestRecoveryAt: Date?,
        recoveryCount: Int
    ) -> String {
        if let latestRecoveryAt {
            return "Recovered \(latestRecoveryAt.formatted(date: .omitted, time: .shortened))"
        }

        return "Recoveries \(recoveryCount)"
    }

    static func checkpointEventDetail(sourceCheckpointID: String?) -> String {
        "Recovered from checkpoint \(sourceCheckpointID ?? "none")"
    }

    static let watchdogExpiredLine = "Watchdog budget expired on the current open step. Recover before continuing."
    static let stalledRecoveryLine = "A stalled step was detected. Recovery should stay available from the last stable checkpoint."
    static let pausedRecoveryLine = "The session is paused, but its stable checkpoint line remains available for recovery."

    static func protectedExecutionLine(
        activeSessions: Int
    ) -> String {
        "Active sessions \(activeSessions) • Recovery line stays attached to the latest stable checkpoint."
    }
}

enum DecisionSessionStepPresentationSupport {
    static func importUnfinishedStepsLine(
        unfinishedStepCount: Int
    ) -> String {
        if unfinishedStepCount == 0 {
            return "Open steps 0 • import can start from a paused safe point."
        }

        return "Open steps \(unfinishedStepCount) • unfinished work will import as failed recovery facts."
    }

    static func importUnfinishedWorkSummary(
        unfinishedStepCount: Int,
        detailLine: String
    ) -> DecisionSessionEngineHealthSummary {
        if unfinishedStepCount == 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Recovery-safe import",
                detail: detailLine
            )
        }

        return DecisionSessionEngineHealthSummary(
            severity: .watch,
            title: "Open work will be normalized",
            detail: detailLine
        )
    }

    static func faultLine(
        isHeartbeatOverdue: Bool,
        hasStalledWork: Bool,
        recoveryCount: Int?
    ) -> String? {
        if isHeartbeatOverdue {
            return "Fault line • watchdog expired on the current open step."
        }
        if hasStalledWork {
            return "Fault line • \(DecisionSessionRecoveryPresentationSupport.stalledRecoveryLine)"
        }
        if let recoveryCount, recoveryCount > 0 {
            return "Recovery line • \(recoveryCount) recovery branch(es) were recorded on this session."
        }
        return nil
    }

    static func replayAnchorDetail(
        sessionTitle: String,
        checkpointID: String,
        checkpointGoal: String?
    ) -> String {
        let checkpointLine = DecisionSessionInspectionPresentationSupport.checkpointLine(
            checkpointID: checkpointID,
            goal: checkpointGoal
        )
        return "\(sessionTitle) • \(checkpointLine) remains available for rebuild and recovery branch creation."
    }

    static func stableCheckpointAvailabilityDetail(
        checkpointID: String
    ) -> String {
        "Checkpoint \(checkpointID) remains available for rebuild and branch recovery."
    }
}

enum DecisionSessionTimelinePresentationSupport {
    static func branchMergedDetail(
        sourceBranchID: String,
        targetBranchID: String
    ) -> String {
        "Merged branch \(sourceBranchID) into \(targetBranchID)"
    }

    static func toolStartedDetail(
        tool: String
    ) -> String {
        "Tool started: \(tool)"
    }

    static func toolFinishedDetail(
        resultSummary: String
    ) -> String {
        "Tool finished: \(resultSummary)"
    }

    static func toolFailedDetail(
        tool: String,
        errorCode: String
    ) -> String {
        "Tool failed: \(tool) • \(errorCode)"
    }

    static func checkpointCreatedDetail(
        basedOnEventSeq: Int
    ) -> String {
        "Checkpoint created at event \(basedOnEventSeq)"
    }

    static func stepStartedDetail(
        stepID: String
    ) -> String {
        "Step \(stepID) started"
    }

    static func heartbeatDetail(
        stepID: String,
        progress: Double?
    ) -> String {
        if let progress {
            return "Heartbeat \(stepID) • \(Int(progress * 100))%"
        }
        return "Heartbeat \(stepID)"
    }

    static func stepStalledDetail(
        stepID: String
    ) -> String {
        "Step stalled \(stepID)"
    }

    static func stepRecoveredDetail(
        stepID: String
    ) -> String {
        "Recovered step \(stepID)"
    }

    static let sessionPausedDetail = "Session paused"
    static let sessionResumedDetail = "Session resumed"

    static func sessionErrorDetail(
        kind: String
    ) -> String {
        "Session error: \(kind)"
    }

    static func branchCreatedDetail(
        fromCheckpointID: String?
    ) -> String {
        "Branch created from \(fromCheckpointID ?? "root")"
    }

    static func foldedMergeNotice(
        branchName: String,
        foldedSources: String,
        visibleSources: String?
    ) -> String {
        let foldedLine = "Latest checkpoint on \(branchName) already folded in merge facts from \(foldedSources)."
        guard let visibleSources else {
            return foldedLine
        }
        return "\(foldedLine) Newer merge events remain visible for \(visibleSources)."
    }

    static func visibleMergeNotice(
        visibleSources: String
    ) -> String {
        "This branch recorded merge events after the latest checkpoint from \(visibleSources)."
    }
}

enum DecisionSessionInspectionPresentationSupport {
    static func eventLine(
        latestEventType: DecisionSessionEventType?
    ) -> String {
        latestEventType?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "idle"
    }

    static func headline(
        title: String,
        status: DecisionSessionStatus,
        latestEventType: DecisionSessionEventType?
    ) -> String {
        "\(title) • \(status.rawValue) • \(latestEventType?.rawValue ?? "idle")"
    }

    static func statusLine(
        status: DecisionSessionStatus,
        latestEventType: DecisionSessionEventType?
    ) -> String {
        "\(status.rawValue.capitalized) • \(eventLine(latestEventType: latestEventType))"
    }

    static func fallbackDetailLine(
        sessionID: String,
        updatedAt: Date
    ) -> String {
        "Session \(sessionID) • updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    static func checkpointLine(
        checkpointID: String?,
        goal: String?
    ) -> String {
        guard let checkpointID else { return "Checkpoint none" }
        guard let goal, goal.isEmpty == false else { return "Checkpoint \(checkpointID)" }
        return "Checkpoint \(checkpointID) • \(goal)"
    }

    static func checkpointAnchorLine(
        checkpointID: String,
        goal: String,
        basedOnEventSeq: Int
    ) -> String {
        guard goal.isEmpty == false else {
            return "Checkpoint \(checkpointID) at event \(basedOnEventSeq)"
        }
        return "Checkpoint \(checkpointID) • \(goal)"
    }

    static func selectedCheckpointLine(
        checkpointID: String,
        goal: String
    ) -> String {
        guard goal.isEmpty == false else {
            return "Selected checkpoint \(checkpointID)"
        }
        return "Selected checkpoint \(checkpointID) • \(goal)"
    }

    static func selectedCheckpointAnchorLine(
        checkpoint: DecisionSessionCheckpoint?
    ) -> String? {
        guard let checkpoint else { return nil }
        return checkpointAnchorLine(
            checkpointID: checkpoint.id,
            goal: checkpoint.summary.goal,
            basedOnEventSeq: checkpoint.basedOnEventSeq
        )
    }

    static func openStepLine(
        count: Int,
        status: DecisionSessionStepStatus?
    ) -> String {
        if let status {
            return "Open steps \(count) • \(status.rawValue.replacingOccurrences(of: "_", with: " "))"
        }

        return "Open steps \(count)"
    }

    static func branchLine(
        branchCount: Int,
        latestEventSeq: Int?,
        latestCheckpointSeq: Int?,
        mergeableBranchCount: Int
    ) -> String {
        let base = if let latestEventSeq {
            "Branches \(branchCount) • Latest seq \(latestEventSeq)"
        } else if let latestCheckpointSeq {
            "Branches \(branchCount) • Checkpoint seq \(latestCheckpointSeq)"
        } else {
            "Branches \(branchCount)"
        }

        return mergeableBranchCount > 0
            ? "\(base) • Merge-ready \(mergeableBranchCount)"
            : base
    }

    static func controlBranchLine(
        headBranchID: String,
        branchCount: Int?,
        mergeableBranchCount: Int?
    ) -> String {
        guard let branchCount else { return "Head \(headBranchID)" }

        let base = "Head \(headBranchID) • Branches \(branchCount)"
        if let mergeableBranchCount, mergeableBranchCount > 0 {
            return "\(base) • Merge-ready \(mergeableBranchCount)"
        }

        return base
    }

    static func activityLine(
        openStepCount: Int,
        openStepStatus: DecisionSessionStepStatus?,
        stalledStepCount: Int
    ) -> String {
        "\(openStepLine(count: openStepCount, status: openStepStatus)) • Stalled \(stalledStepCount)"
    }

    static func stepSignalLine(
        openStepCount: Int,
        openStepAlertLine: String?,
        openStepFreshnessLine: String?
    ) -> String {
        openStepAlertLine
            ?? openStepFreshnessLine
            ?? "Open steps \(openStepCount)"
    }

    static func detailLine(
        checkpointID: String?,
        eventSeq: Int?,
        openStepCount: Int,
        openStepStatus: DecisionSessionStepStatus?,
        openStepFreshnessLine: String?,
        recoveryCount: Int
    ) -> String {
        let checkpointDescriptor = checkpointID.map { "ckpt \($0)" } ?? "ckpt none"
        let eventDescriptor = eventSeq.map { "evt \($0)" } ?? "evt none"
        let stepDescriptor = if let openStepStatus {
            "steps \(openStepCount) • \(openStepStatus.rawValue)"
        } else {
            "steps \(openStepCount)"
        }
        let freshnessDescriptor = openStepFreshnessLine.map { " • \($0)" } ?? ""
        return "\(checkpointDescriptor) • \(eventDescriptor) • \(stepDescriptor)\(freshnessDescriptor) • recoveries \(recoveryCount)"
    }
}

enum DecisionSessionReviewPresentationSupport {
    static let importBundleTitle = "Import Session Engine bundle"
    static let pendingImportTitle = "Pending import draft"
    static let mergeReviewTitle = "Merge review queue"
    static let replayAnchorTitle = "Replay anchor ready"
    static let sovereignPostureTitle = "Sovereign posture"
    static let horizonDiagnosticsTitle = "Horizon diagnostics"
    static let importPreviewHeadline = "Importing creates a new paused recovery-safe session. Old history stays untouched, and unfinished steps become auditable recovery facts."
    static let mergeReviewCardTitle = "Merge review"
    static let auditPrefix = "Audit"
    static let killSwitchesPrefix = "Kill switches"

    static func importBundleLine(
        sourceFileName: String
    ) -> String {
        "Bundle \(sourceFileName)"
    }

    static func importSourceLine(
        sourceTitle: String
    ) -> String {
        "Source \(sourceTitle)"
    }

    static func importAsLine(
        importedTitle: String
    ) -> String {
        "Will import as \(importedTitle)"
    }

    static func pendingImportDetail(
        bundleLine: String,
        importedLine: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            importedLine,
            bundleLine
        ])
    }

    static func pendingImportDigestLine(
        preview: DecisionSessionEngineImportPreviewPresentation
    ) -> DecisionSessionEngineReviewDigestLine {
        DecisionSessionEngineReviewDigestLine(
            id: "pending-import",
            title: pendingImportTitle,
            detail: pendingImportDetail(
                bundleLine: preview.bundleLine,
                importedLine: preview.importedLine
            ),
            severity: preview.unfinishedWorkSummary.severity
        )
    }

    static func pendingImportSignalLines(
        preview: DecisionSessionEngineImportPreviewPresentation
    ) -> [String] {
        [
            DecisionEvolutionNarrativeFormattingSupport.joined([
                "Pending import",
                preview.bundleLine,
                preview.importedLine
            ]),
            DecisionEvolutionNarrativeFormattingSupport.joined([
                preview.unfinishedWorkSummary.title,
                preview.countsLine
            ])
        ]
    }

    static func mergeReviewDetail(
        mergeReadySessions: Int,
        mergeableBranches: Int
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Merge-ready sessions \(mergeReadySessions)",
            "Merge-ready branches \(mergeableBranches)",
            "Review correction branches before they drift from head."
        ])
    }

    static func mergeReviewDigestLine(
        mergeReadySessions: Int,
        mergeableBranches: Int
    ) -> DecisionSessionEngineReviewDigestLine {
        DecisionSessionEngineReviewDigestLine(
            id: "merge-review",
            title: mergeReviewTitle,
            detail: mergeReviewDetail(
                mergeReadySessions: mergeReadySessions,
                mergeableBranches: mergeableBranches
            ),
            severity: .watch
        )
    }

    static func replaySessionLine(
        sessionID: String,
        headBranchID: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Replay session \(sessionID)",
            "Head \(headBranchID)"
        ])
    }

    static func replaySessionRecordedLine(
        sessionID: String,
        recordedAt: Date
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Replay session \(sessionID)",
            "Recorded \(recordedAt.formatted(date: .abbreviated, time: .shortened))"
        ])
    }

    static func auditLine(
        guardrailFindings: [String]
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: auditPrefix,
            values: Array(guardrailFindings.prefix(2))
        )
    }

    static func killSwitchesLine(
        killSwitches: [String]
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.labeledLine(
            prefix: killSwitchesPrefix,
            values: killSwitches
        )
    }

    static func replayAnchorDigestLine(
        session: DecisionSessionRuntimeInspectionSession
    ) -> DecisionSessionEngineReviewDigestLine? {
        guard let checkpointID = session.latestCheckpointID else {
            return nil
        }
        return DecisionSessionEngineReviewDigestLine(
            id: "replay-anchor",
            title: replayAnchorTitle,
            detail: DecisionSessionStepPresentationSupport.replayAnchorDetail(
                sessionTitle: session.title,
                checkpointID: checkpointID,
                checkpointGoal: session.latestCheckpointGoal
            ),
            severity: .stable
        )
    }

    static func sovereignPostureDetail(
        sovereignVerdictLine: String?,
        sovereignAuthorityLine: String?,
        sovereignAuditLine: String?
    ) -> String? {
        let detail = DecisionEvolutionNarrativeFormattingSupport.joined(
            [sovereignVerdictLine, sovereignAuthorityLine, sovereignAuditLine].compactMap { $0 }
        )
        return detail.isEmpty ? nil : detail
    }

    static func sovereignPostureDigestLine(
        session: DecisionSessionRuntimeInspectionSession
    ) -> DecisionSessionEngineReviewDigestLine? {
        guard let detail = sovereignPostureDetail(
            sovereignVerdictLine: session.checkpointPresentationFacts.sovereignVerdictLine,
            sovereignAuthorityLine: session.checkpointPresentationFacts.sovereignAuthorityLine,
            sovereignAuditLine: session.checkpointPresentationFacts.sovereignAuditLine
        ) else {
            return nil
        }
        return DecisionSessionEngineReviewDigestLine(
            id: "sovereign-posture-\(session.sessionID)",
            title: sovereignPostureTitle,
            detail: detail,
            severity: .watch
        )
    }

    static func horizonDiagnosticsDigestLine(
        session: DecisionSessionRuntimeInspectionSession
    ) -> DecisionSessionEngineReviewDigestLine? {
        guard let detail = horizonDiagnosticsDetail(
            riskFactorsLine: session.checkpointPresentationFacts.riskFactorsLine,
            reasonCodesLine: session.checkpointPresentationFacts.reasonCodesLine
        ) else {
            return nil
        }
        return DecisionSessionEngineReviewDigestLine(
            id: "horizon-diagnostics-\(session.sessionID)",
            title: horizonDiagnosticsTitle,
            detail: detail,
            severity: .watch
        )
    }

    static func horizonDiagnosticsDetail(
        riskFactorsLine: String?,
        reasonCodesLine: String?
    ) -> String? {
        let detail = DecisionEvolutionNarrativeFormattingSupport.joined(
            [riskFactorsLine, reasonCodesLine].compactMap { $0 }
        )
        return detail.isEmpty ? nil : detail
    }

    static func digestLines(
        from summary: DecisionSystemSessionEngineSummary
    ) -> [DecisionSessionEngineReviewDigestLine] {
        var items: [DecisionSessionEngineReviewDigestLine] = []

        if let pendingImportPreview = summary.pendingImportPreview {
            items.append(
                pendingImportDigestLine(
                    preview: pendingImportPreview
                )
            )
        }

        if summary.mergeableBranches > 0 {
            items.append(
                mergeReviewDigestLine(
                    mergeReadySessions: summary.mergeReadySessions,
                    mergeableBranches: summary.mergeableBranches
                )
            )
        }

        let replayableSessions = summary.recentSessions.filter { $0.latestCheckpointID != nil }
        if let anchorSession = replayableSessions.first,
           let replayAnchorLine = replayAnchorDigestLine(
                session: anchorSession
           ) {
            items.append(replayAnchorLine)
        }

        if let sovereignSession = summary.recentSessions.first(where: {
            $0.checkpointPresentationFacts.sovereignVerdictLine != nil
                || $0.checkpointPresentationFacts.sovereignAuthorityLine != nil
                || $0.checkpointPresentationFacts.sovereignAuditLine != nil
        }), let sovereignLine = sovereignPostureDigestLine(session: sovereignSession) {
            items.append(sovereignLine)
        }

        if let horizonSession = summary.recentSessions.first(where: {
            $0.checkpointPresentationFacts.riskFactorsLine != nil
                || $0.checkpointPresentationFacts.reasonCodesLine != nil
        }), let horizonLine = horizonDiagnosticsDigestLine(session: horizonSession) {
            items.append(horizonLine)
        }

        return items
    }

    static func importCountsLine(
        branches: Int,
        checkpoints: Int,
        events: Int,
        steps: Int
    ) -> String {
        "Branches \(branches) • Checkpoints \(checkpoints) • Events \(events) • Steps \(steps)"
    }

    static func importBranchLine(
        headBranchName: String,
        layerPlacement: DecisionSessionLayerPlacement
    ) -> String {
        "Head \(headBranchName) • Layer \(layerPlacement.rawValue)"
    }

    static func latestCheckpointLine(
        latestCheckpointID: String?,
        goal: String?
    ) -> String {
        guard let latestCheckpointID else {
            return "No checkpoint was exported with this session."
        }
        guard let goal, goal.isEmpty == false else {
            return "Latest checkpoint \(latestCheckpointID)"
        }
        return "Latest checkpoint \(latestCheckpointID) • \(goal)"
    }

    static func importDetailRows(
        preview: DecisionSessionImportBundlePreview,
        sourceFileName: String
    ) -> [DecisionSessionEngineReviewDetailPresentation] {
        [
            DecisionSessionEngineReviewDetailPresentation(
                id: "bundle",
                label: DecisionSessionReviewDetailPresentationSupport.bundleLabel,
                value: sourceFileName
            ),
            DecisionSessionEngineReviewDetailPresentation(
                id: "source",
                label: DecisionSessionReviewDetailPresentationSupport.sourceSessionLabel,
                value: preview.sourceTitle
            ),
            DecisionSessionEngineReviewDetailPresentation(
                id: "imported",
                label: DecisionSessionReviewDetailPresentationSupport.importedTitleLabel,
                value: preview.importedTitle
            ),
            DecisionSessionEngineReviewDetailPresentation(
                id: "counts",
                label: DecisionSessionReviewDetailPresentationSupport.countsLabel,
                value: preview.countsLine
            ),
            DecisionSessionEngineReviewDetailPresentation(
                id: "integrity",
                label: DecisionSessionReviewDetailPresentationSupport.integrityLabel,
                value: preview.integrityLine
            ),
            DecisionSessionEngineReviewDetailPresentation(
                id: "checkpoint",
                label: DecisionSessionReviewDetailPresentationSupport.checkpointLabel,
                value: preview.checkpointLine
            ),
            DecisionSessionEngineReviewDetailPresentation(
                id: "branch",
                label: DecisionSessionReviewDetailPresentationSupport.branchLineLabel,
                value: preview.branchLine
            )
        ]
    }

    static func importBranchPresentations(
        previews: [DecisionSessionImportBundleBranchPreview]
    ) -> [DecisionSessionEngineImportBranchPresentation] {
        previews.map(importBranchPresentation)
    }

    static func importPreviewPresentation(
        preview: DecisionSessionImportBundlePreview,
        sourceFileName: String
    ) -> DecisionSessionEngineImportPreviewPresentation {
        let unfinishedWorkSummary = DecisionSessionStepPresentationSupport.importUnfinishedWorkSummary(
            unfinishedStepCount: preview.unfinishedStepCount,
            detailLine: preview.unfinishedStepsLine
        )

        return DecisionSessionEngineImportPreviewPresentation(
            title: importBundleTitle,
            headline: preview.headline,
            bundleLine: importBundleLine(
                sourceFileName: sourceFileName
            ),
            sourceLine: importSourceLine(
                sourceTitle: preview.sourceTitle
            ),
            importedLine: importAsLine(
                importedTitle: preview.importedTitle
            ),
            countsLine: preview.countsLine,
            integrityLine: preview.integrityLine,
            checkpointLine: preview.checkpointLine,
            branchLine: preview.branchLine,
            unfinishedWorkSummary: unfinishedWorkSummary,
            detailRows: importDetailRows(
                preview: preview,
                sourceFileName: sourceFileName
            ),
            branchPresentations: importBranchPresentations(
                previews: preview.branchPreviews
            )
        )
    }

    static func importBranchPresentation(
        _ branch: DecisionSessionImportBundleBranchPreview
    ) -> DecisionSessionEngineImportBranchPresentation {
        DecisionSessionEngineImportBranchPresentation(
            id: branch.id,
            name: branch.name,
            statusLine: branch.statusLine,
            detailLine: branch.detailLine,
            isHead: branch.isHead
        )
    }

    static func importBranchStatusLine(
        status: DecisionSessionBranchStatus,
        isHead: Bool
    ) -> String {
        DecisionSessionBranchPresentationSupport.importStatusLine(
            status: status,
            isHead: isHead
        )
    }

    static func checkpointDetailLine(
        checkpointID: String?,
        goal: String?
    ) -> String {
        DecisionSessionInspectionPresentationSupport.checkpointLine(
            checkpointID: checkpointID,
            goal: goal
        )
    }

    static func mergeReviewLine(
        mergeableBranchCount: Int
    ) -> String? {
        guard mergeableBranchCount > 0 else { return nil }
        return mergeReviewSignalLine(mergeableBranchCount: mergeableBranchCount)
    }

    static func mergeReviewSignalLine(
        mergeableBranchCount: Int
    ) -> String {
        if mergeableBranchCount == 0 {
            return "Merge review 0"
        }
        if mergeableBranchCount == 1 {
            return "Merge review 1 active correction branch can append back onto head without rewriting history."
        }
        return "Merge review \(mergeableBranchCount) active correction branches can append back onto head without rewriting history."
    }

    static func mergeRouteLine(
        sourceBranchName: String,
        targetBranchName: String
    ) -> String {
        "\(sourceBranchName) → \(targetBranchName)"
    }

    static func mergeReviewSummary(
        detail: String
    ) -> DecisionSessionEngineHealthSummary {
        DecisionSessionEngineHealthSummary(
            severity: .stable,
            title: DecisionSessionControlPresentationSupport.appendOnlyMergeSummaryTitle,
            detail: detail
        )
    }

    static func detailPresentation(
        id: String,
        label: String,
        value: String
    ) -> DecisionSessionEngineReviewDetailPresentation {
        DecisionSessionEngineReviewDetailPresentation(
            id: id,
            label: label,
            value: value
        )
    }

    static func detailPresentations(
        from rows: [DecisionSessionEngineControlReviewDetail]
    ) -> [DecisionSessionEngineReviewDetailPresentation] {
        rows.map {
            detailPresentation(
                id: $0.id,
                label: $0.label,
                value: $0.value
            )
        }
    }

    static func mergeReviewPresentation(
        review: DecisionSessionEngineControlMergeReview
    ) -> DecisionSessionEngineMergeReviewPresentation {
        DecisionSessionEngineMergeReviewPresentation(
            title: mergeReviewCardTitle,
            routeLine: mergeRouteLine(
                sourceBranchName: review.sourceBranchName,
                targetBranchName: review.targetBranchName
            ),
            sourceStatusLine: review.sourceStatusLine,
            targetStatusLine: review.targetStatusLine,
            checkpointLine: review.checkpointLine,
            summary: mergeReviewSummary(
                detail: review.summaryLine
            ),
            detailRows: detailPresentations(
                from: review.detailRows
            )
        )
    }

    static func itemPresentation(
        from line: DecisionSessionEngineReviewDigestLine
    ) -> DecisionSessionEngineReviewItemPresentation {
        DecisionSessionEngineReviewItemPresentation(
            id: line.id,
            title: line.title,
            detail: line.detail,
            severity: line.severity
        )
    }

    static func signalLine(
        from line: DecisionSessionEngineReviewDigestLine
    ) -> String {
        "\(line.title) • \(line.detail)"
    }
}

enum DecisionSessionSummaryPresentationSupport {
    struct SignalBreakdown: Equatable, Sendable {
        let inventoryLine: String?
        let branchLine: String?
        let progressLine: String?
        let supplementalLines: [String]

        var allSignals: [String] {
            [inventoryLine, branchLine, progressLine].compactMap { $0 } + supplementalLines
        }

        func runtimeLayerSignals(
            headline: String
        ) -> [String] {
            [headline, inventoryLine].compactMap { $0 }
        }

        func dataLayerSignals(
            reviewDigestLines: [String]
        ) -> [String] {
            [branchLine, progressLine].compactMap { $0 }
                + supplementalLines
                + reviewDigestLines
        }

        static func legacy(
            _ signals: [String]
        ) -> SignalBreakdown {
            SignalBreakdown(
                inventoryLine: signals.indices.contains(0) ? signals[0] : nil,
                branchLine: signals.indices.contains(1) ? signals[1] : nil,
                progressLine: signals.indices.contains(2) ? signals[2] : nil,
                supplementalLines: Array(signals.dropFirst(min(3, signals.count)))
            )
        }
    }

    static func runtimeHeadline(
        layerPlacement: DecisionSessionLayerPlacement
    ) -> String {
        "Session Engine \(layerPlacement.rawValue) protects edits, checkpoints, and recovery."
    }

    static func pendingImportHeadline(
        layerPlacement: DecisionSessionLayerPlacement = .foldedLung
    ) -> String {
        "Session Engine \(layerPlacement.rawValue) has a pending import draft ready for review before local recovery state is attached."
    }

    static func inventorySignalLine(
        sessions: Int,
        activeSessions: Int,
        stalledSessions: Int,
        layerPlacement: DecisionSessionLayerPlacement
    ) -> String {
        "Session Engine \(layerPlacement.rawValue) • Sessions \(sessions) • Active \(activeSessions) • Stalled \(stalledSessions)"
    }

    static func branchSignalLine(
        branches: Int,
        mergeReadySessions: Int,
        mergeableBranches: Int
    ) -> String {
        "Branches \(branches) • Merge-ready sessions \(mergeReadySessions) • Merge-ready branches \(mergeableBranches)"
    }

    static func progressSignalLine(
        checkpoints: Int,
        events: Int,
        steps: Int
    ) -> String {
        "Checkpoints \(checkpoints) • Events \(events) • Steps \(steps)"
    }

    static func summarySignalBreakdown(
        layerPlacement: DecisionSessionLayerPlacement,
        sessions: Int,
        activeSessions: Int,
        stalledSessions: Int,
        mergeReadySessions: Int,
        mergeableBranches: Int,
        branches: Int,
        checkpoints: Int,
        events: Int,
        steps: Int,
        recentSessions: [DecisionSessionRuntimeInspectionSession],
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    ) -> SignalBreakdown {
        SignalBreakdown(
            inventoryLine: inventorySignalLine(
                sessions: sessions,
                activeSessions: activeSessions,
                stalledSessions: stalledSessions,
                layerPlacement: layerPlacement
            ),
            branchLine: branchSignalLine(
                branches: branches,
                mergeReadySessions: mergeReadySessions,
                mergeableBranches: mergeableBranches
            ),
            progressLine: progressSignalLine(
                checkpoints: checkpoints,
                events: events,
                steps: steps
            ),
            supplementalLines: (pendingImportPreview.map {
                DecisionSessionReviewPresentationSupport.pendingImportSignalLines(preview: $0)
            } ?? [])
                + replayRecoverySignalLines(sessions: recentSessions)
                + checkpointDigestSignalLines(sessions: recentSessions)
                + recentSessions.prefix(2).map(recentSessionSignalLine)
        )
    }

    static func summarySignalLines(
        layerPlacement: DecisionSessionLayerPlacement,
        sessions: Int,
        activeSessions: Int,
        stalledSessions: Int,
        mergeReadySessions: Int,
        mergeableBranches: Int,
        branches: Int,
        checkpoints: Int,
        events: Int,
        steps: Int,
        recentSessions: [DecisionSessionRuntimeInspectionSession],
        pendingImportPreview: DecisionSessionEngineImportPreviewPresentation?
    ) -> [String] {
        summarySignalBreakdown(
            layerPlacement: layerPlacement,
            sessions: sessions,
            activeSessions: activeSessions,
            stalledSessions: stalledSessions,
            mergeReadySessions: mergeReadySessions,
            mergeableBranches: mergeableBranches,
            branches: branches,
            checkpoints: checkpoints,
            events: events,
            steps: steps,
            recentSessions: recentSessions,
            pendingImportPreview: pendingImportPreview
        ).allSignals
    }

    static func runtimeLayerSignals(
        summary: DecisionSystemSessionEngineSummary
    ) -> [String] {
        summary.signalBreakdown.runtimeLayerSignals(
            headline: summary.headline
        ) + (summary.pendingImportPreview.map {
            DecisionSessionReviewPresentationSupport.pendingImportSignalLines(
                preview: $0
            )
        } ?? [])
    }

    static func dataLayerSignals(
        summary: DecisionSystemSessionEngineSummary
    ) -> [String] {
        summary.signalBreakdown.dataLayerSignals(
            reviewDigestLines: DecisionSessionReviewPresentationSupport.digestLines(from: summary)
                .map(DecisionSessionReviewPresentationSupport.signalLine)
        )
    }

    static func inspectionAggregate(
        sessions: [DecisionSessionRuntimeInspectionSession]
    ) -> DecisionSessionInspectionAggregate {
        DecisionSessionInspectionAggregate(
            sessions: sessions.count,
            activeSessions: sessions.filter { $0.status == .active }.count,
            stalledSessions: sessions.filter { $0.status == .stalled || $0.stalledStepCount > 0 }.count,
            branches: sessions.reduce(into: 0) { $0 += $1.branchCount },
            checkpoints: sessions.reduce(into: 0) { count, session in
                if session.latestCheckpointID != nil {
                    count += 1
                }
            }
        )
    }

    static func recentSessionSignalLine(
        session: DecisionSessionRuntimeInspectionSession
    ) -> String {
        let checkpointDescriptor = DecisionSessionInspectionPresentationSupport.checkpointLine(
            checkpointID: session.latestCheckpointID,
            goal: nil
        )
        let recoveryDescriptor = DecisionSessionRecoveryPresentationSupport.compactRecoveryLine(
            latestRecoveryAt: session.latestRecoveryAt,
            recoveryCount: session.recoveryCount
        )
        let stepDescriptor = DecisionSessionInspectionPresentationSupport.stepSignalLine(
            openStepCount: session.openStepCount,
            openStepAlertLine: session.openStepAlertLine,
            openStepFreshnessLine: session.openStepFreshnessLine
        )
        let mergeDescriptor = DecisionSessionReviewPresentationSupport.mergeReviewSignalLine(
            mergeableBranchCount: session.mergeableBranchCount
        )
        return "\(session.headline) • \(checkpointDescriptor) • \(recoveryDescriptor) • \(stepDescriptor) • \(mergeDescriptor)"
    }

    static func replayRecoverySignalLines(
        sessions: [DecisionSessionRuntimeInspectionSession]
    ) -> [String] {
        sessions.prefix(2).flatMap { session in
            session.replayRecoverySummary.digestLines
        }
    }

    static func checkpointDigestSignalLines(
        sessions: [DecisionSessionRuntimeInspectionSession]
    ) -> [String] {
        sessions.prefix(2).flatMap { session in
            session.checkpointPresentationFacts.digestLines.map { line in
                "\(session.title) • \(line)"
            }
        }
    }
}

typealias DecisionSessionSummarySignalBreakdown = DecisionSessionSummaryPresentationSupport.SignalBreakdown

enum DecisionSessionControlPresentationSupport {
    static let title = "Session engine control center"
    static let headline = "Operate local append-only sessions directly: pause, resume, recover, archive, and inspect timeline rebuilds without touching original history."
    static let summaryHeadline = "Session Engine control center keeps import, replay, and merge review visible before mutation."
    static let unavailableCountsLine = "Session Engine runtime inspection is unavailable."
    static let emptyMessage = "No Session Engine session has been recorded yet."
    static let appendOnlyMergeSummaryTitle = "Append-only merge"
    static let appendOnlyMergeSummaryLine = "Merge will append a branch_merged fact onto the current head branch, keep the source branch inspectable, and avoid rewriting existing history."

    static func countsLine(
        sessions: Int,
        activeSessions: Int,
        stalledSessions: Int,
        mergeableBranches: Int,
        branches: Int,
        checkpoints: Int
    ) -> String {
        "Sessions \(sessions) • Active \(activeSessions) • Stalled \(stalledSessions) • Merge-ready \(mergeableBranches) • Branches \(branches) • Checkpoints \(checkpoints)"
    }

    static func countsLine(
        from summary: DecisionSystemSessionEngineSummary
    ) -> String {
        countsLine(
            sessions: summary.sessions,
            activeSessions: summary.activeSessions,
            stalledSessions: summary.stalledSessions,
            mergeableBranches: summary.mergeableBranches,
            branches: summary.branches,
            checkpoints: summary.checkpoints
        )
    }

    static func countsLine(
        runtimeSnapshot: DecisionSessionRuntimeSnapshot?,
        synthesizedSummary: DecisionSystemSessionEngineSummary
    ) -> String {
        if let runtimeSnapshot {
            return countsLine(
                sessions: runtimeSnapshot.sessions,
                activeSessions: runtimeSnapshot.activeSessions,
                stalledSessions: runtimeSnapshot.stalledSessions,
                mergeableBranches: synthesizedSummary.mergeableBranches,
                branches: runtimeSnapshot.branches,
                checkpoints: runtimeSnapshot.checkpoints
            )
        }
        return unavailableCountsLine
    }

    static func selectedBranchesLine(
        branchCount: Int,
        headName: String
    ) -> String {
        "Branches \(branchCount) • Head \(headName)"
    }

    static func selectedBranchesLine(
        branchPresentations: [DecisionSessionEngineControlBranchPresentation]
    ) -> String? {
        guard branchPresentations.isEmpty == false else {
            return nil
        }
        let headName = branchPresentations.first(where: \.isHead)?.name ?? "unknown"
        return selectedBranchesLine(
            branchCount: branchPresentations.count,
            headName: headName
        )
    }

    static func selectedCheckpointLine(
        checkpoint: DecisionSessionCheckpoint?
    ) -> String? {
        DecisionSessionInspectionPresentationSupport.selectedCheckpointAnchorLine(
            checkpoint: checkpoint
        )
    }

    static func checkpointSeqLine(
        _ seq: Int
    ) -> String {
        "Checkpoint event seq \(seq)"
    }

    static func eventSeqLine(
        _ seq: Int
    ) -> String {
        "Event seq \(seq)"
    }

    static func correctionTargetable(
        _ type: DecisionSessionEventType
    ) -> Bool {
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

    static func timelinePresentation(
        item: DecisionSessionTimelineItem,
        sessionAllowsMutations: Bool
    ) -> DecisionSessionEngineControlTimelinePresentation {
        switch item.kind {
        case .checkpoint(let checkpoint):
            DecisionSessionEngineControlTimelinePresentation(
                id: item.id,
                title: item.title,
                detail: item.detail,
                branchID: item.branchId,
                createdAt: item.createdAt,
                seqLine: checkpointSeqLine(checkpoint.basedOnEventSeq),
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
                seqLine: eventSeqLine(event.seq),
                isCheckpoint: false,
                checkpointID: nil,
                eventID: event.id,
                canRestoreCheckpoint: false,
                canTargetCorrection: sessionAllowsMutations && correctionTargetable(event.type),
                emphasizesRecovery: event.type == .sessionRecovered || event.type == .stepRecovered
            )
        }
    }

    static func branchPresentation(
        branch: DecisionSessionBranch,
        headBranchID: String?,
        selectedBranchID: String?,
        sessionAllowsMutations: Bool
    ) -> DecisionSessionEngineControlBranchPresentation {
        let isHead = branch.id == headBranchID
        let canSwitch = sessionAllowsMutations && branch.status == .active && !isHead
        let canMerge = sessionAllowsMutations && branch.status == .active && !isHead && headBranchID != nil
        let canAbandon = sessionAllowsMutations && branch.status == .active && !isHead
        let detailLine = DecisionSessionBranchPresentationSupport.detailLine(
            originLine: DecisionSessionBranchPresentationSupport.originLine(
                branchName: branch.name,
                parentBranchID: branch.parentBranchId,
                baseCheckpointID: branch.baseCheckpointId
            ),
            parentBranchID: branch.parentBranchId,
            baseCheckpointID: branch.baseCheckpointId,
            createdAt: branch.createdAt
        )

        return DecisionSessionEngineControlBranchPresentation(
            id: branch.id,
            name: branch.name,
            statusLine: DecisionSessionBranchPresentationSupport.controlStatusLine(
                status: branch.status,
                isHead: isHead
            ),
            detailLine: detailLine,
            createdAt: branch.createdAt,
            isHead: isHead,
            isInspecting: branch.id == selectedBranchID,
            canSwitch: canSwitch,
            canMerge: canMerge,
            canAbandon: canAbandon
        )
    }

    static func branchPresentations(
        branches: [DecisionSessionBranch],
        headBranchID: String?,
        selectedBranchID: String?,
        sessionAllowsMutations: Bool
    ) -> [DecisionSessionEngineControlBranchPresentation] {
        branches
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
                branchPresentation(
                    branch: branch,
                    headBranchID: headBranchID,
                    selectedBranchID: selectedBranchID,
                    sessionAllowsMutations: sessionAllowsMutations
                )
            }
    }

    static func timelinePresentations(
        items: [DecisionSessionTimelineItem],
        sessionAllowsMutations: Bool
    ) -> [DecisionSessionEngineControlTimelinePresentation] {
        items.map { item in
            timelinePresentation(
                item: item,
                sessionAllowsMutations: sessionAllowsMutations
            )
        }
    }

    static func selectedMergeReview(
        session: DecisionSession?,
        selectedBranchID: String?,
        branches: [DecisionSessionBranch],
        selectedCheckpoint: DecisionSessionCheckpoint?
    ) -> DecisionSessionEngineControlMergeReview? {
        guard let session,
              let resolvedBranchID = selectedBranchID,
              let sourceBranch = branches.first(where: { $0.id == resolvedBranchID }),
              let targetBranch = branches.first(where: { $0.id == session.headBranchId }),
              sourceBranch.id != targetBranch.id,
              sourceBranch.status == .active,
              session.status != .archived,
              session.status != .broken else {
            return nil
        }

        let checkpointLine = selectedCheckpoint.map {
            DecisionSessionInspectionPresentationSupport.selectedCheckpointLine(
                checkpointID: $0.id,
                goal: $0.summary.goal
            )
        }
        return DecisionSessionControlReviewPresentationSupport.mergeReview(
            sourceBranch: sourceBranch,
            targetBranch: targetBranch,
            checkpointLine: checkpointLine
        )
    }

    static func sessionPresentation(
        session: DecisionSession,
        inspection: DecisionSessionRuntimeInspectionSession?,
        isSelected: Bool
    ) -> DecisionSessionEngineControlSessionPresentation {
        let checkpointFacts = inspection?.checkpointPresentationFacts
        let checkpointLine = DecisionSessionInspectionPresentationSupport.checkpointLine(
            checkpointID: inspection?.latestCheckpointID ?? session.latestCheckpointId,
            goal: inspection?.latestCheckpointGoal
        )

        let branchLine = DecisionSessionInspectionPresentationSupport.controlBranchLine(
            headBranchID: session.headBranchId,
            branchCount: inspection?.branchCount,
            mergeableBranchCount: inspection?.mergeableBranchCount
        )
        let mergeReviewLine = inspection?.mergeReviewLine

        let recoveryLine: String
        if let inspection {
            recoveryLine = DecisionSessionRecoveryPresentationSupport.recordedRecoveryLine(
                latestRecoveryAt: inspection.latestRecoveryAt,
                recoveryCount: inspection.recoveryCount
            )
        } else {
            recoveryLine = "Recoveries unavailable"
        }

        let detailLine = inspection?.detailLine
            ?? DecisionSessionInspectionPresentationSupport.fallbackDetailLine(
                sessionID: session.id,
                updatedAt: session.updatedAt
            )

        let faultLine = DecisionSessionStepPresentationSupport.faultLine(
            isHeartbeatOverdue: inspection?.openStepIsHeartbeatOverdue == true,
            hasStalledWork: session.status == .stalled || inspection?.stalledStepCount ?? 0 > 0,
            recoveryCount: inspection?.recoveryCount
        )

        return DecisionSessionEngineControlSessionPresentation(
            sessionID: session.id,
            title: session.title,
            statusLine: inspection.map {
                DecisionSessionInspectionPresentationSupport.statusLine(
                    status: $0.status,
                    latestEventType: $0.latestEventType
                )
            } ?? session.status.rawValue.capitalized,
            healthSummary: DecisionSessionEngineHealthSummary.summary(
                sessionStatus: session.status,
                inspection: inspection
            ),
            checkpointLine: checkpointLine,
            checkpointBudgetLine: checkpointFacts?.runtimeLine,
            checkpointDecisionLine: checkpointFacts?.decisionLine,
            checkpointTaskLine: checkpointFacts?.taskLine,
            checkpointPressureLine: checkpointFacts?.pressureLine,
            checkpointRiskFactorsLine: checkpointFacts?.riskFactorsLine,
            checkpointReasonCodesLine: checkpointFacts?.reasonCodesLine,
            checkpointAuditLine: checkpointFacts?.auditLine,
            checkpointSovereignVerdictLine: checkpointFacts?.sovereignVerdictLine,
            checkpointSovereignAuthorityLine: checkpointFacts?.sovereignAuthorityLine,
            checkpointSovereignAuditLine: checkpointFacts?.sovereignAuditLine,
            checkpointKillSwitchesLine: checkpointFacts?.killSwitchesLine,
            checkpointActionLine: checkpointFacts?.actionLine,
            checkpointLungLine: checkpointFacts?.lungLine,
            checkpointHotColdLine: checkpointFacts?.hotColdLine,
            checkpointResumeLine: checkpointFacts?.resumeLine,
            checkpointRollbackLine: checkpointFacts?.rollbackLine,
            checkpointSovereignBridgeLine: checkpointFacts?.sovereignBridgeLine,
            checkpointSovereignBridgeDetailLines: checkpointFacts?.sovereignBridgeDetailLines ?? [],
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

enum DecisionSessionReviewDetailPresentationSupport {
    static let bundleLabel = "Bundle"
    static let sourceSessionLabel = "Source session"
    static let importedTitleLabel = "Imported title"
    static let countsLabel = "Counts"
    static let integrityLabel = "Integrity"
    static let checkpointLabel = "Checkpoint"
    static let branchLineLabel = "Branch line"
    static let sourceBranchLabel = "Source branch"
    static let targetBranchLabel = "Target branch"
    static let sourceStatusLabel = "Source status"
    static let targetStatusLabel = "Target status"

    static func branchIdentityLine(
        branchName: String,
        branchID: String
    ) -> String {
        "\(branchName) • \(branchID)"
    }
}

enum DecisionSessionControlReviewPresentationSupport {
    static let sourceBranchLabel = DecisionSessionReviewDetailPresentationSupport.sourceBranchLabel
    static let targetBranchLabel = DecisionSessionReviewDetailPresentationSupport.targetBranchLabel
    static let sourceStatusLabel = DecisionSessionReviewDetailPresentationSupport.sourceStatusLabel
    static let targetStatusLabel = DecisionSessionReviewDetailPresentationSupport.targetStatusLabel
    static let checkpointLabel = DecisionSessionReviewDetailPresentationSupport.checkpointLabel

    static func branchValueLine(
        branchName: String,
        branchID: String
    ) -> String {
        DecisionSessionReviewDetailPresentationSupport.branchIdentityLine(
            branchName: branchName,
            branchID: branchID
        )
    }

    static func detailRow(
        id: String,
        label: String,
        value: String
    ) -> DecisionSessionEngineControlReviewDetail {
        DecisionSessionEngineControlReviewDetail(
            id: id,
            label: label,
            value: value
        )
    }

    static func detailRows(
        sourceBranch: DecisionSessionBranch,
        targetBranch: DecisionSessionBranch,
        checkpointLine: String?
    ) -> [DecisionSessionEngineControlReviewDetail] {
        var rows: [DecisionSessionEngineControlReviewDetail] = [
            detailRow(
                id: "source-branch",
                label: sourceBranchLabel,
                value: branchValueLine(
                    branchName: sourceBranch.name,
                    branchID: sourceBranch.id
                )
            ),
            detailRow(
                id: "target-branch",
                label: targetBranchLabel,
                value: branchValueLine(
                    branchName: targetBranch.name,
                    branchID: targetBranch.id
                )
            ),
            detailRow(
                id: "source-status",
                label: sourceStatusLabel,
                value: DecisionSessionBranchPresentationSupport.controlStatusLine(
                    status: sourceBranch.status,
                    isHead: false
                )
            ),
            detailRow(
                id: "target-status",
                label: targetStatusLabel,
                value: DecisionSessionBranchPresentationSupport.controlStatusLine(
                    status: targetBranch.status,
                    isHead: true
                )
            )
        ]

        if let checkpointLine {
            rows.append(
                detailRow(
                    id: "checkpoint",
                    label: checkpointLabel,
                    value: checkpointLine
                )
            )
        }

        return rows
    }

    static func mergeReview(
        sourceBranch: DecisionSessionBranch,
        targetBranch: DecisionSessionBranch,
        checkpointLine: String?
    ) -> DecisionSessionEngineControlMergeReview {
        DecisionSessionEngineControlMergeReview(
            sourceBranchID: sourceBranch.id,
            sourceBranchName: sourceBranch.name,
            targetBranchID: targetBranch.id,
            targetBranchName: targetBranch.name,
            sourceStatusLine: DecisionSessionBranchPresentationSupport.controlStatusLine(
                status: sourceBranch.status,
                isHead: false
            ),
            targetStatusLine: DecisionSessionBranchPresentationSupport.controlStatusLine(
                status: targetBranch.status,
                isHead: true
            ),
            checkpointLine: checkpointLine,
            summaryLine: DecisionSessionControlPresentationSupport.appendOnlyMergeSummaryLine,
            detailRows: detailRows(
                sourceBranch: sourceBranch,
                targetBranch: targetBranch,
                checkpointLine: checkpointLine
            )
        )
    }
}

enum DecisionSessionBranchPresentationSupport {
    static func originLine(
        branchName: String,
        parentBranchID: String?,
        baseCheckpointID: String?
    ) -> String? {
        if branchName.hasPrefix("correction-") {
            return "Correction branch"
        }
        if branchName.hasPrefix("recovery-") {
            return "Recovery branch"
        }
        if parentBranchID != nil || baseCheckpointID != nil {
            return "Derived branch"
        }
        return nil
    }

    static func detailLine(
        originLine: String?,
        parentBranchID: String?,
        baseCheckpointID: String?,
        createdAt: Date
    ) -> String {
        let detailSegments = [
            originLine,
            parentBranchID.map { "Parent \($0)" },
            baseCheckpointID.map { "Base \($0)" }
        ].compactMap { $0 }

        if detailSegments.isEmpty {
            return "Created \(createdAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(detailSegments)
    }

    static func controlStatusLine(
        status: DecisionSessionBranchStatus,
        isHead: Bool
    ) -> String {
        let baseStatus = status.rawValue.capitalized
        return isHead
            ? DecisionEvolutionNarrativeFormattingSupport.joined([
                baseStatus,
                "current head"
            ])
            : baseStatus
    }

    static func importStatusLine(
        status: DecisionSessionBranchStatus,
        isHead: Bool
    ) -> String {
        let statusLine = status.rawValue.capitalized
        return isHead
            ? DecisionEvolutionNarrativeFormattingSupport.joined([
                statusLine,
                "exported head"
            ])
            : statusLine
    }
}

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
                detail: DecisionEvolutionNarrativeFormattingSupport.joined([
                    "Stalled sessions \(summary.stalledSessions)",
                    "Recovery inspection should stay visible before more work is started."
                ])
            )
        }

        if summary.mergeableBranches > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Merge review pending",
                detail: DecisionSessionReviewPresentationSupport.mergeReviewDetail(
                    mergeReadySessions: summary.mergeReadySessions,
                    mergeableBranches: summary.mergeableBranches
                )
            )
        }

        let horizonSession = summary.activeSession.flatMap { session in
            DecisionSessionReviewPresentationSupport.horizonDiagnosticsDetail(
                riskFactorsLine: session.checkpointPresentationFacts.riskFactorsLine,
                reasonCodesLine: session.checkpointPresentationFacts.reasonCodesLine
            ).map { (session, $0) }
        } ?? summary.recentSessions.lazy.compactMap { session in
            DecisionSessionReviewPresentationSupport.horizonDiagnosticsDetail(
                riskFactorsLine: session.checkpointPresentationFacts.riskFactorsLine,
                reasonCodesLine: session.checkpointPresentationFacts.reasonCodesLine
            ).map { (session, $0) }
        }.first

        if let (_, horizonDetail) = horizonSession {
            return DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Horizon diagnostics active",
                detail: horizonDetail
            )
        }

        if summary.activeSessions > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Protected execution active",
                detail: DecisionSessionRecoveryPresentationSupport.protectedExecutionLine(
                    activeSessions: summary.activeSessions
                )
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
                    ?? DecisionSessionRecoveryPresentationSupport.stalledRecoveryLine
            )
        }

        if let inspection, inspection.recoveryCount > 0 {
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Recovered checkpoint line",
                detail: DecisionSessionRecoveryPresentationSupport.replayableRecoveryLine(
                    latestRecoveryAt: inspection.latestRecoveryAt,
                    recoveryCount: inspection.recoveryCount
                )
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

        if let inspection,
           let horizonDetail = DecisionSessionReviewPresentationSupport.horizonDiagnosticsDetail(
                riskFactorsLine: inspection.checkpointPresentationFacts.riskFactorsLine,
                reasonCodesLine: inspection.checkpointPresentationFacts.reasonCodesLine
           ) {
            return DecisionSessionEngineHealthSummary(
                severity: .watch,
                title: "Horizon diagnostics active",
                detail: horizonDetail
            )
        }

        if let inspection, let latestCheckpointID = inspection.latestCheckpointID {
            return DecisionSessionEngineHealthSummary(
                severity: .stable,
                title: "Stable checkpoint available",
                detail: DecisionSessionStepPresentationSupport.stableCheckpointAvailabilityDetail(
                    checkpointID: latestCheckpointID
                )
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
                detail: DecisionSessionRecoveryPresentationSupport.pausedRecoveryLine
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
                detail: DecisionSessionRecoveryPresentationSupport.stalledRecoveryLine
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
    let checkpointPressureLine: String?
    let checkpointRiskFactorsLine: String?
    let checkpointReasonCodesLine: String?
    let checkpointAuditLine: String?
    let checkpointSovereignVerdictLine: String?
    let checkpointSovereignAuthorityLine: String?
    let checkpointSovereignAuditLine: String?
    let checkpointKillSwitchesLine: String?
    let checkpointActionLine: String?
    let morphLine: String?
    let hotColdLine: String?
    let precisionLine: String?
    let lungLine: String?
    let schedulerLine: String?
    let resumeLine: String?
    let rollbackLine: String?
    let sovereignBridgeLine: String?
    let sovereignBridgeDetailLines: [String]
    let recoveryLine: String
    let activityLine: String
    let stepFreshnessLine: String?
    let stepAlertLine: String?
    let branchLine: String
    let mergeReviewLine: String?
    let detailLine: String
    let canRecover: Bool
    let isActive: Bool

    init(
        sessionID: String,
        title: String,
        statusLine: String,
        healthSummary: DecisionSessionEngineHealthSummary?,
        replayRecoverySummary: DecisionSessionEngineReplayRecoverySummary,
        checkpointLine: String,
        checkpointBudgetLine: String?,
        checkpointDecisionLine: String?,
        checkpointTaskLine: String?,
        checkpointPressureLine: String?,
        checkpointRiskFactorsLine: String? = nil,
        checkpointReasonCodesLine: String? = nil,
        checkpointAuditLine: String?,
        checkpointSovereignVerdictLine: String? = nil,
        checkpointSovereignAuthorityLine: String? = nil,
        checkpointSovereignAuditLine: String? = nil,
        checkpointKillSwitchesLine: String?,
        checkpointActionLine: String?,
        morphLine: String? = nil,
        hotColdLine: String? = nil,
        precisionLine: String? = nil,
        lungLine: String? = nil,
        schedulerLine: String? = nil,
        resumeLine: String? = nil,
        rollbackLine: String? = nil,
        sovereignBridgeLine: String? = nil,
        sovereignBridgeDetailLines: [String] = [],
        recoveryLine: String,
        activityLine: String,
        stepFreshnessLine: String?,
        stepAlertLine: String?,
        branchLine: String,
        mergeReviewLine: String?,
        detailLine: String,
        canRecover: Bool,
        isActive: Bool
    ) {
        self.sessionID = sessionID
        self.title = title
        self.statusLine = statusLine
        self.healthSummary = healthSummary
        self.replayRecoverySummary = replayRecoverySummary
        self.checkpointLine = checkpointLine
        self.checkpointBudgetLine = checkpointBudgetLine
        self.checkpointDecisionLine = checkpointDecisionLine
        self.checkpointTaskLine = checkpointTaskLine
        self.checkpointPressureLine = checkpointPressureLine
        self.checkpointRiskFactorsLine = checkpointRiskFactorsLine
        self.checkpointReasonCodesLine = checkpointReasonCodesLine
        self.checkpointAuditLine = checkpointAuditLine
        self.checkpointSovereignVerdictLine = checkpointSovereignVerdictLine
        self.checkpointSovereignAuthorityLine = checkpointSovereignAuthorityLine
        self.checkpointSovereignAuditLine = checkpointSovereignAuditLine
        self.checkpointKillSwitchesLine = checkpointKillSwitchesLine
        self.checkpointActionLine = checkpointActionLine
        self.morphLine = morphLine
        self.hotColdLine = hotColdLine
        self.precisionLine = precisionLine
        self.lungLine = lungLine
        self.schedulerLine = schedulerLine
        self.resumeLine = resumeLine
        self.rollbackLine = rollbackLine
        self.sovereignBridgeLine = sovereignBridgeLine
        self.sovereignBridgeDetailLines = sovereignBridgeDetailLines
        self.recoveryLine = recoveryLine
        self.activityLine = activityLine
        self.stepFreshnessLine = stepFreshnessLine
        self.stepAlertLine = stepAlertLine
        self.branchLine = branchLine
        self.mergeReviewLine = mergeReviewLine
        self.detailLine = detailLine
        self.canRecover = canRecover
        self.isActive = isActive
    }

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
    let pressureLine: String?
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let auditLine: String?
    let sovereignVerdictLine: String?
    let sovereignAuthorityLine: String?
    let sovereignAuditLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?
    let morphLine: String?
    let hotColdLine: String?
    let precisionLine: String?
    let lungLine: String?
    let schedulerLine: String?
    let resumeLine: String?
    let rollbackLine: String?
    let sovereignBridgeLine: String?
    let sovereignBridgeDetailLines: [String]

    init(
        sourceDescriptor: DecisionEvolutionSourceDescriptor,
        title: String,
        replayLine: String,
        recoveryLine: String,
        detailLine: String,
        budgetLine: String?,
        taskLine: String?,
        actionLine: String?,
        pressureLine: String?,
        riskFactorsLine: String? = nil,
        reasonCodesLine: String? = nil,
        auditLine: String?,
        sovereignVerdictLine: String? = nil,
        sovereignAuthorityLine: String? = nil,
        sovereignAuditLine: String? = nil,
        activeKillSwitchesLine: String?,
        killSwitchesLine: String?,
        morphLine: String? = nil,
        hotColdLine: String? = nil,
        precisionLine: String? = nil,
        lungLine: String? = nil,
        schedulerLine: String? = nil,
        resumeLine: String? = nil,
        rollbackLine: String? = nil,
        sovereignBridgeLine: String? = nil,
        sovereignBridgeDetailLines: [String] = []
    ) {
        self.sourceDescriptor = sourceDescriptor
        self.title = title
        self.replayLine = replayLine
        self.recoveryLine = recoveryLine
        self.detailLine = detailLine
        self.budgetLine = budgetLine
        self.taskLine = taskLine
        self.actionLine = actionLine
        self.pressureLine = pressureLine
        self.riskFactorsLine = riskFactorsLine
        self.reasonCodesLine = reasonCodesLine
        self.auditLine = auditLine
        self.sovereignVerdictLine = sovereignVerdictLine
        self.sovereignAuthorityLine = sovereignAuthorityLine
        self.sovereignAuditLine = sovereignAuditLine
        self.activeKillSwitchesLine = activeKillSwitchesLine
        self.killSwitchesLine = killSwitchesLine
        self.morphLine = morphLine
        self.hotColdLine = hotColdLine
        self.precisionLine = precisionLine
        self.lungLine = lungLine
        self.schedulerLine = schedulerLine
        self.resumeLine = resumeLine
        self.rollbackLine = rollbackLine
        self.sovereignBridgeLine = sovereignBridgeLine
        self.sovereignBridgeDetailLines = sovereignBridgeDetailLines
    }

    var headlineLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            title,
            recoveryLine
        ])
    }

    var digestLines: [String] {
        return [
            DecisionEvolutionNarrativeFormattingSupport.joined([
                title,
                replayLine,
                recoveryLine
            ]).nilIfEmpty,
            DecisionEvolutionNarrativeFormattingSupport.joined(
                [detailLine, killSwitchesLine].compactMap { $0 }
            ).nilIfEmpty,
            DecisionEvolutionNarrativeFormattingSupport.joined(
                [riskFactorsLine, reasonCodesLine].compactMap { $0 }
            ).nilIfEmpty,
            sovereignVerdictLine,
            sovereignAuthorityLine,
            sovereignAuditLine,
            DecisionEvolutionNarrativeFormattingSupport.joined(
                [lungLine, morphLine, hotColdLine, precisionLine, schedulerLine, resumeLine, rollbackLine, sovereignBridgeLine].compactMap { $0 }
            ).nilIfEmpty
        ]
        .compactMap { $0?.nilIfEmpty }
        + sovereignBridgeDetailLines
    }
}

extension DeveloperDecisionReplayEBrainSummary {
    var replayRecoverySummary: DecisionSessionEngineReplayRecoverySummary {
        DecisionSessionEngineReplayRecoverySummary(
            sourceDescriptor: sourceDescriptor,
            title: sourceDescriptor.title,
            replayLine: DecisionSessionReviewPresentationSupport.replaySessionRecordedLine(
                sessionID: sessionID,
                recordedAt: recordedAt
            ),
            recoveryLine: DecisionEvolutionEBrainPresentationSupport.riskPermitHostFoldLine(
                riskLevel: riskLevel,
                permitMode: permitMode,
                hostGatePercent: hostGatePercent,
                foldChecksum: thoughtFoldChecksum
            ),
            detailLine: reviewDirectiveLine?.evolutionTrimmedNonEmpty
                ?? updateTicketSummaries.first?.evolutionTrimmedNonEmpty
                ?? "Recovered lineage remains inspectable.",
            budgetLine: checkpointBudgetLine,
            taskLine: checkpointTaskLine,
            actionLine: nil,
            pressureLine: checkpointPressureLine,
            riskFactorsLine: riskFactorsLine,
            reasonCodesLine: reasonCodesLine,
            auditLine: DecisionSessionReviewPresentationSupport.auditLine(
                guardrailFindings: guardrailFindings
            ),
            sovereignVerdictLine: sovereignVerdictLine,
            sovereignAuthorityLine: sovereignAuthorityLine,
            sovereignAuditLine: sovereignAuditLine,
            activeKillSwitchesLine: DecisionEvolutionKillSwitchPresentationSupport.activeLine(
                killSwitches: activeKillSwitches
            ),
            killSwitchesLine: DecisionSessionReviewPresentationSupport.killSwitchesLine(
                killSwitches: killSwitches
            ),
            morphLine: morphLine,
            hotColdLine: hotColdLine,
            precisionLine: precisionLine,
            lungLine: lungLine,
            schedulerLine: schedulerLine,
            resumeLine: resumeLine,
            rollbackLine: rollbackLine,
            sovereignBridgeLine: sovereignBridgeLine,
            sovereignBridgeDetailLines: sovereignBridgeSupplementalLines
        )
    }
}

extension DecisionSessionRuntimeInspectionSession {
    var replayRecoverySummary: DecisionSessionEngineReplayRecoverySummary {
        let checkpointFacts = checkpointPresentationFacts
        let sourceDescriptor: DecisionEvolutionSourceDescriptor = if recoveryCount > 0 || stalledStepCount > 0 || openStepIsHeartbeatOverdue {
            .checkpointRecoveryDefault
        } else {
            .liveRuntimeDefault
        }

        let recoveryLine = DecisionSessionRecoveryPresentationSupport.replayableRecoveryLine(
            latestRecoveryAt: latestRecoveryAt,
            recoveryCount: recoveryCount
        )

        let detailLine: String
        detailLine = DecisionSessionReviewPresentationSupport.checkpointDetailLine(
            checkpointID: latestCheckpointID,
            goal: latestCheckpointGoal
        )

        return DecisionSessionEngineReplayRecoverySummary(
            sourceDescriptor: sourceDescriptor,
            title: sourceDescriptor.title,
            replayLine: DecisionSessionReviewPresentationSupport.replaySessionLine(
                sessionID: sessionID,
                headBranchID: headBranchID
            ),
            recoveryLine: recoveryLine,
            detailLine: detailLine,
            budgetLine: checkpointFacts.budgetLine,
            taskLine: checkpointFacts.resolvedTaskLine,
            actionLine: checkpointFacts.actionLine,
            pressureLine: checkpointFacts.pressureLine,
            riskFactorsLine: checkpointFacts.riskFactorsLine,
            reasonCodesLine: checkpointFacts.reasonCodesLine,
            auditLine: checkpointFacts.combinedAuditLine(addition: openStepAlertLine),
            sovereignVerdictLine: checkpointFacts.sovereignVerdictLine,
            sovereignAuthorityLine: checkpointFacts.sovereignAuthorityLine,
            sovereignAuditLine: checkpointFacts.sovereignAuditLine,
            activeKillSwitchesLine: checkpointFacts.activeKillSwitchesLine,
            killSwitchesLine: checkpointFacts.killSwitchesLine,
            morphLine: checkpointFacts.morphLine,
            hotColdLine: checkpointFacts.hotColdLine,
            precisionLine: checkpointFacts.precisionLine,
            lungLine: checkpointFacts.lungLine,
            schedulerLine: checkpointFacts.schedulerLine,
            resumeLine: checkpointFacts.resumeLine,
            rollbackLine: checkpointFacts.rollbackLine,
            sovereignBridgeLine: checkpointFacts.sovereignBridgeLine,
            sovereignBridgeDetailLines: checkpointFacts.sovereignBridgeDetailLines
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
            countsLine: DecisionSessionControlPresentationSupport.countsLine(from: summary),
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
        DecisionSessionEngineReviewDigestBuilder.presentations(from: summary)
    }

    private static func sessionPresentation(
        from session: DecisionSessionRuntimeInspectionSession,
        isActive: Bool
    ) -> DecisionSessionEngineSessionPresentation {
        let checkpointFacts = session.checkpointPresentationFacts
        let checkpointDescriptor = DecisionSessionInspectionPresentationSupport.checkpointLine(
            checkpointID: session.latestCheckpointID,
            goal: session.latestCheckpointGoal
        )

        let recoveryDescriptor = DecisionSessionRecoveryPresentationSupport.recordedRecoveryLine(
            latestRecoveryAt: session.latestRecoveryAt,
            recoveryCount: session.recoveryCount
        )
        let branchDescriptor = DecisionSessionInspectionPresentationSupport.branchLine(
            branchCount: session.branchCount,
            latestEventSeq: session.latestEventSeq,
            latestCheckpointSeq: session.latestCheckpointSeq,
            mergeableBranchCount: session.mergeableBranchCount
        )
        let mergeReviewLine = session.mergeReviewLine

        return DecisionSessionEngineSessionPresentation(
            sessionID: session.sessionID,
            title: session.title,
            statusLine: DecisionSessionInspectionPresentationSupport.statusLine(
                status: session.status,
                latestEventType: session.latestEventType
            ),
            healthSummary: DecisionSessionEngineHealthSummary.summary(
                sessionStatus: session.status,
                inspection: session
            ),
            replayRecoverySummary: session.replayRecoverySummary,
            checkpointLine: checkpointDescriptor,
            checkpointBudgetLine: checkpointFacts.runtimeLine,
            checkpointDecisionLine: checkpointFacts.resolvedDecisionLine,
            checkpointTaskLine: checkpointFacts.resolvedTaskLine,
            checkpointPressureLine: checkpointFacts.pressureLine,
            checkpointRiskFactorsLine: checkpointFacts.riskFactorsLine,
            checkpointReasonCodesLine: checkpointFacts.reasonCodesLine,
            checkpointAuditLine: checkpointFacts.auditLine,
            checkpointSovereignVerdictLine: checkpointFacts.sovereignVerdictLine,
            checkpointSovereignAuthorityLine: checkpointFacts.sovereignAuthorityLine,
            checkpointSovereignAuditLine: checkpointFacts.sovereignAuditLine,
            checkpointKillSwitchesLine: checkpointFacts.killSwitchesLine,
            checkpointActionLine: checkpointFacts.actionLine,
            morphLine: checkpointFacts.morphLine,
            hotColdLine: checkpointFacts.hotColdLine,
            precisionLine: checkpointFacts.precisionLine,
            lungLine: checkpointFacts.lungLine,
            resumeLine: checkpointFacts.resumeLine,
            rollbackLine: checkpointFacts.rollbackLine,
            sovereignBridgeLine: checkpointFacts.sovereignBridgeLine,
            sovereignBridgeDetailLines: checkpointFacts.sovereignBridgeDetailLines,
            recoveryLine: recoveryDescriptor,
            activityLine: DecisionSessionInspectionPresentationSupport.activityLine(
                openStepCount: session.openStepCount,
                openStepStatus: session.openStepStatus,
                stalledStepCount: session.stalledStepCount
            ),
            stepFreshnessLine: session.openStepFreshnessLine,
            stepAlertLine: session.openStepAlertLine,
            branchLine: branchDescriptor,
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
