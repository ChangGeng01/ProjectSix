import SwiftUI
import UniformTypeIdentifiers

struct DecisionSessionEngineControlCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: BeforeAppModel

    @State private var snapshot = DecisionSessionEngineControlSnapshot.build(
        runtimeSnapshot: nil,
        sessions: [],
        inspectionBySessionID: [:],
        selectedSessionID: nil,
        selectedBranchID: nil,
        selectedBranches: [],
        selectedCheckpoint: nil,
        selectedTimeline: nil
    )
    @State private var selectedSessionID: String?
    @State private var selectedBranchID: String?
    @State private var correctionText = ""
    @State private var selectedCorrectionTargetEventID: String?
    @State private var isRefreshing = false
    @State private var isMutating = false
    @State private var isImportingSessionBundle = false
    @State private var exportedSessionBundleURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(snapshot.title)
                                    .font(.title3.bold())
                                Text(snapshot.headline)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(snapshot.countsLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isRefreshing || isMutating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        HStack(spacing: 10) {
                            BeforeActionButton("Refresh", style: .secondary) {
                                Task { await refresh() }
                            }

                            BeforeActionButton("Import bundle", style: .secondary) {
                                isImportingSessionBundle = true
                            }

                            BeforeActionButton("Sweep watchdog", style: .secondary) {
                                Task { await sweepWatchdog() }
                            }

                            BeforeActionButton("Close", style: .tertiary) {
                                appModel.dismissSessionEngineControlCenter()
                                dismiss()
                            }
                        }

                        if let exportedSessionBundleURL {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Latest export")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(exportedSessionBundleURL.lastPathComponent)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                ShareLink(item: exportedSessionBundleURL) {
                                    Label("Share exported bundle", systemImage: "square.and.arrow.up")
                                }
                                .font(.caption)
                            }
                        }

                        DecisionSessionEngineReviewSurfaceView(
                            items: snapshot.reviewItems,
                            pendingImportPreview: snapshot.pendingImportPreview
                        )
                    }
                }

                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session inventory")
                            .font(.headline)

                        if snapshot.sessions.isEmpty {
                            Text(snapshot.emptyMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshot.sessions) { session in
                                Button {
                                    Task {
                                        await selectSession(session.sessionID)
                                    }
                                } label: {
                                    sessionInventoryRow(session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if let selectedSession = snapshot.sessions.first(where: { $0.sessionID == snapshot.selectedSessionID }) {
                    selectedSessionSection(selectedSession)
                }

                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timeline rebuild")
                            .font(.headline)

                        if snapshot.timelineItems.isEmpty {
                            Text("Select a session to inspect checkpoint recovery and post-checkpoint events.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshot.timelineItems) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(item.emphasizesRecovery ? BeforeTheme.ember : BeforeTheme.ink)
                                        Spacer()
                                        if item.canRestoreCheckpoint, let checkpointID = item.checkpointID {
                                            BeforeActionButton("Restore", style: .secondary) {
                                                Task {
                                                    await mutate {
                                                        await appModel.restoreSessionEngineCheckpoint(checkpointID)
                                                    }
                                                }
                                            }
                                        }
                                        Text(item.createdAt, style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let seqLine = item.seqLine {
                                        Text(seqLine)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text("Branch \(item.branchID)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if item.canTargetCorrection, let eventID = item.eventID {
                                        HStack(spacing: 10) {
                                            BeforeActionButton(
                                                selectedCorrectionTargetEventID == eventID
                                                    ? "Selected correction target"
                                                    : "Use as correction target",
                                                style: selectedCorrectionTargetEventID == eventID ? .primary : .secondary
                                            ) {
                                                selectedCorrectionTargetEventID = eventID
                                            }
                                            .disabled(selectedCorrectionTargetEventID == eventID)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session Engine")
        .task {
            await refresh()
        }
        .fileImporter(
            isPresented: $isImportingSessionBundle,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    appModel.presentSessionEngineBundleIssue("Choose a Session Engine bundle to import.")
                    return
                }
                Task {
                    guard await appModel.stageSessionEngineBundleImport(from: url) != nil else {
                        return
                    }
                }
            case .failure(let error):
                appModel.presentSessionEngineBundleIssue(error.localizedDescription)
            }
        }
        .sheet(
            item: Binding(
                get: { appModel.pendingSessionEngineImportDraft },
                set: { draft in
                    if draft == nil {
                        appModel.clearPendingSessionEngineImportDraft()
                    }
                }
            )
        ) { draft in
            NavigationStack {
                DecisionSessionEngineImportPreviewSheetView(draft: draft) { session in
                    Task { @MainActor in
                        selectedSessionID = session.id
                        selectedBranchID = session.headBranchId
                        await refresh()
                    }
                }
                .environmentObject(appModel)
            }
        }
        .alert(
            "Session Engine bundle",
            isPresented: Binding(
                get: { appModel.sessionEngineBundleIssue != nil },
                set: {
                    if !$0 {
                        appModel.dismissSessionEngineBundleIssue()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                appModel.dismissSessionEngineBundleIssue()
            }
        } message: {
            Text(appModel.sessionEngineBundleIssue ?? "Session Engine bundle action failed.")
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if selectedSessionID == nil {
            selectedSessionID = appModel.activeDecisionSessionEngineSessionID
        }
        snapshot = await appModel.sessionEngineControlSnapshot(
            selectedSessionID: selectedSessionID,
            selectedBranchID: selectedBranchID
        )
        selectedSessionID = snapshot.selectedSessionID
        selectedBranchID = snapshot.selectedBranchID
        if let selectedCorrectionTargetEventID,
           snapshot.timelineItems.contains(where: {
               $0.eventID == selectedCorrectionTargetEventID && $0.canTargetCorrection
           }) == false {
            self.selectedCorrectionTargetEventID = nil
        }
    }

    private func selectSession(_ sessionID: String) async {
        selectedSessionID = sessionID
        selectedBranchID = nil
        await refresh()
    }

    private func mutate(_ action: @escaping () async -> Void) async {
        isMutating = true
        await action()
        await refresh()
        isMutating = false
    }

    private func sweepWatchdog() async {
        await mutate {
            await appModel.sweepSessionEngineWatchdog()
        }
    }

    @ViewBuilder
    private func sessionInventoryRow(
        _ session: DecisionSessionEngineControlSessionPresentation
    ) -> some View {
        DecisionSessionEngineSessionSummaryView(
            title: session.title,
            healthSummary: session.healthSummary,
            checkpointLine: session.checkpointLine,
            checkpointBudgetLine: session.checkpointBudgetLine,
            checkpointDecisionLine: session.checkpointDecisionLine,
            checkpointTaskLine: session.checkpointTaskLine,
            checkpointPressureLine: session.checkpointPressureLine,
            checkpointRiskFactorsLine: session.checkpointRiskFactorsLine,
            checkpointReasonCodesLine: session.checkpointReasonCodesLine,
            checkpointAuditLine: session.checkpointAuditLine,
            checkpointSovereignVerdictLine: session.checkpointSovereignVerdictLine,
            checkpointSovereignAuthorityLine: session.checkpointSovereignAuthorityLine,
            checkpointSovereignAuditLine: session.checkpointSovereignAuditLine,
            checkpointKillSwitchesLine: session.checkpointKillSwitchesLine,
            checkpointActionLine: session.checkpointActionLine,
            checkpointLungLine: session.checkpointLungLine,
            checkpointHotColdLine: session.checkpointHotColdLine,
            checkpointResumeLine: session.checkpointResumeLine,
            checkpointRollbackLine: session.checkpointRollbackLine,
            checkpointSovereignBridgeLine: session.checkpointSovereignBridgeLine,
            checkpointSovereignBridgeDetailLines: session.checkpointSovereignBridgeDetailLines,
            branchLine: session.branchLine,
            mergeReviewLine: session.mergeReviewLine,
            recoveryLine: session.recoveryLine,
            faultLine: session.faultLine,
            stepFreshnessLine: session.stepFreshnessLine,
            stepAlertLine: session.stepAlertLine
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Spacer()
                Text(session.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(sessionInventoryBackground(session))
        .overlay(sessionInventoryBorder(session))
    }

    private func sessionInventoryBackground(
        _ session: DecisionSessionEngineControlSessionPresentation
    ) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(session.isSelected ? BeforeTheme.ember.opacity(0.10) : Color.secondary.opacity(0.08))
    }

    private func sessionInventoryBorder(
        _ session: DecisionSessionEngineControlSessionPresentation
    ) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(session.isSelected ? BeforeTheme.ember.opacity(0.45) : Color.secondary.opacity(0.15), lineWidth: 1)
    }

    private var selectedCorrectionTarget: DecisionSessionEngineControlTimelinePresentation? {
        guard let selectedCorrectionTargetEventID else { return nil }
        return snapshot.timelineItems.first(where: {
            $0.eventID == selectedCorrectionTargetEventID && $0.canTargetCorrection
        })
    }

    @ViewBuilder
    private func selectedSessionSection(
        _ selectedSession: DecisionSessionEngineControlSessionPresentation
    ) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Selected session")
                    .font(.headline)

                DecisionSessionEngineSessionSummaryView(
                    title: selectedSession.title,
                    healthSummary: selectedSession.healthSummary,
                    checkpointLine: selectedSession.checkpointLine,
                    checkpointBudgetLine: selectedSession.checkpointBudgetLine,
                    checkpointDecisionLine: selectedSession.checkpointDecisionLine,
                    checkpointTaskLine: selectedSession.checkpointTaskLine,
                    checkpointPressureLine: selectedSession.checkpointPressureLine,
                    checkpointRiskFactorsLine: selectedSession.checkpointRiskFactorsLine,
                    checkpointReasonCodesLine: selectedSession.checkpointReasonCodesLine,
                    checkpointAuditLine: selectedSession.checkpointAuditLine,
                    checkpointSovereignVerdictLine: selectedSession.checkpointSovereignVerdictLine,
                    checkpointSovereignAuthorityLine: selectedSession.checkpointSovereignAuthorityLine,
                    checkpointSovereignAuditLine: selectedSession.checkpointSovereignAuditLine,
                    checkpointKillSwitchesLine: selectedSession.checkpointKillSwitchesLine,
                    checkpointActionLine: selectedSession.checkpointActionLine,
                    checkpointLungLine: selectedSession.checkpointLungLine,
                    checkpointHotColdLine: selectedSession.checkpointHotColdLine,
                    checkpointResumeLine: selectedSession.checkpointResumeLine,
                    checkpointRollbackLine: selectedSession.checkpointRollbackLine,
                    checkpointSovereignBridgeLine: selectedSession.checkpointSovereignBridgeLine,
                    checkpointSovereignBridgeDetailLines: selectedSession.checkpointSovereignBridgeDetailLines,
                    activityLine: nil,
                    branchLine: selectedSession.branchLine,
                    mergeReviewLine: selectedSession.mergeReviewLine,
                    recoveryLine: selectedSession.recoveryLine,
                    faultLine: selectedSession.faultLine,
                    stepFreshnessLine: selectedSession.stepFreshnessLine,
                    stepAlertLine: selectedSession.stepAlertLine,
                    detailLine: selectedSession.detailLine,
                    header: {
                        EmptyView()
                    },
                    footer: {
                        selectedSessionSummaryFooter()
                    }
                )

                HStack(spacing: 10) {
                    BeforeActionButton("Export session", style: .secondary) {
                        Task {
                            guard let exportURL = await appModel.exportSessionEngineSession(selectedSession.sessionID) else {
                                appModel.presentSessionEngineBundleIssue(
                                    "Session Engine could not export the selected session bundle."
                                )
                                return
                            }
                            exportedSessionBundleURL = exportURL
                        }
                    }

                    if selectedSession.canPause {
                        BeforeActionButton("Pause", style: .secondary) {
                            Task {
                                await mutate {
                                    await appModel.pauseSessionEngineSession(selectedSession.sessionID)
                                }
                            }
                        }
                    }

                    if selectedSession.canResume {
                        BeforeActionButton("Resume", style: .secondary) {
                            Task {
                                await mutate {
                                    await appModel.resumeSessionEngineSession(selectedSession.sessionID)
                                }
                            }
                        }
                    }

                    if selectedSession.canRecover {
                        BeforeActionButton("Recover", style: .primary) {
                            Task {
                                await mutate {
                                    await appModel.recoverSessionEngineSession(selectedSession.sessionID)
                                }
                            }
                        }
                    }

                    if selectedSession.canArchive {
                        BeforeActionButton("Archive", style: .tertiary) {
                            Task {
                                await mutate {
                                    await appModel.archiveSessionEngineSession(selectedSession.sessionID)
                                }
                            }
                        }
                    }
                }

                if snapshot.selectedBranches.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Branch inventory")
                            .font(.subheadline.weight(.semibold))

                        ForEach(snapshot.selectedBranches) { branch in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(branch.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if branch.isInspecting {
                                        Text("Inspecting")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(BeforeTheme.ember)
                                    }
                                    Text(branch.createdAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Text(branch.statusLine)
                                    .font(.caption)
                                    .foregroundStyle(branch.isHead ? BeforeTheme.ember : .secondary)

                                Text(branch.detailLine)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if branch.isInspecting == false || branch.canSwitch || branch.canMerge || branch.canAbandon {
                                    HStack(spacing: 10) {
                                        if branch.isInspecting == false {
                                            BeforeActionButton("Inspect", style: .secondary) {
                                                Task {
                                                    selectedBranchID = branch.id
                                                    await refresh()
                                                }
                                            }
                                        }

                                        if branch.canSwitch {
                                            BeforeActionButton("Switch", style: .secondary) {
                                                Task {
                                                    await mutate {
                                                        await appModel.switchSessionEngineBranch(
                                                            sessionID: selectedSession.sessionID,
                                                            branchID: branch.id
                                                        )
                                                    }
                                                    selectedBranchID = branch.id
                                                }
                                            }
                                        }

                                        if branch.canMerge {
                                            BeforeActionButton("Merge", style: .primary) {
                                                Task {
                                                    await mutate {
                                                        await appModel.mergeSessionEngineBranch(
                                                            sessionID: selectedSession.sessionID,
                                                            sourceBranchID: branch.id
                                                        )
                                                    }
                                                }
                                            }
                                        }

                                        if branch.canAbandon {
                                            BeforeActionButton("Abandon", style: .tertiary) {
                                                Task {
                                                    await mutate {
                                                        await appModel.abandonSessionEngineBranch(
                                                            sessionID: selectedSession.sessionID,
                                                            branchID: branch.id
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(branch.isHead ? BeforeTheme.ember.opacity(0.08) : Color.secondary.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        branch.isInspecting
                                            ? BeforeTheme.ember.opacity(0.45)
                                            : (branch.isHead ? BeforeTheme.ember.opacity(0.35) : Color.secondary.opacity(0.12)),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }

                if selectedSession.canCorrect {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Correction branch")
                            .font(.subheadline.weight(.semibold))

                        Text("Add a correction event and continue on a new branch without rewriting the old session history.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            "Describe the corrected requirement or new version line",
                            text: $correctionText,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)

                        if let selectedCorrectionTarget = selectedCorrectionTarget {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Targeting selected history point")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BeforeTheme.ember)

                                Text(selectedCorrectionTarget.title)
                                    .font(.caption)
                                    .foregroundStyle(BeforeTheme.ink)

                                if let seqLine = selectedCorrectionTarget.seqLine {
                                    Text(seqLine)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Text(selectedCorrectionTarget.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                BeforeActionButton("Clear selected target", style: .secondary) {
                                    selectedCorrectionTargetEventID = nil
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(BeforeTheme.ember.opacity(0.08))
                            )
                        }

                        BeforeActionButton("Create correction branch", style: .primary) {
                            let pendingCorrection = correctionText
                            let pendingTargetEventID = selectedCorrectionTargetEventID
                            Task {
                                await mutate {
                                    await appModel.appendSessionEngineCorrection(
                                        selectedSession.sessionID,
                                        targetEventID: pendingTargetEventID,
                                        newText: pendingCorrection
                                    )
                                }
                                correctionText = ""
                                selectedCorrectionTargetEventID = nil
                            }
                        }
                        .disabled(correctionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if let mergeReview = snapshot.selectedMergeReview {
                    DecisionSessionEngineControlMergeReviewCard(
                        review: mergeReview,
                        actionTitle: "Merge selected branch into head"
                    ) {
                        Task {
                            await mutate {
                                await appModel.mergeSessionEngineBranch(
                                    sessionID: selectedSession.sessionID,
                                    sourceBranchID: mergeReview.sourceBranchID
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func selectedSessionSummaryFooter() -> some View {
        if let selectedCheckpointLine = snapshot.selectedCheckpointLine {
            Text(selectedCheckpointLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let selectedBranchesLine = snapshot.selectedBranchesLine {
            Text(selectedBranchesLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

        if let selectedRecoveryNotice = snapshot.selectedRecoveryNotice {
            Text(selectedRecoveryNotice)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)
        }

        if let selectedMergeNotice = snapshot.selectedMergeNotice {
            Text(selectedMergeNotice)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
