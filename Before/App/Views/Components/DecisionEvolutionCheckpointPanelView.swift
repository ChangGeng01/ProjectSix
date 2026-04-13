import SwiftUI

struct DecisionEvolutionCheckpointPanelView: View {
    let title: String?
    let checkpoint: DecisionEvolutionCheckpointPresentation
    let controlSurface: DecisionEvolutionControlSurface
    let interactionMode: DecisionEvolutionControlInteractionMode
    let showControlCenterShortcut: Bool
    let showHistoryShortcut: Bool
    let showPortraitShortcut: Bool
    let afterMutation: (() -> Void)?

    init(
        title: String? = nil,
        checkpoint: DecisionEvolutionCheckpointPresentation,
        controlSurface: DecisionEvolutionControlSurface,
        interactionMode: DecisionEvolutionControlInteractionMode = .mutationHub,
        showControlCenterShortcut: Bool = false,
        showHistoryShortcut: Bool = false,
        showPortraitShortcut: Bool = false,
        afterMutation: (() -> Void)? = nil
    ) {
        self.title = title
        self.checkpoint = checkpoint
        self.controlSurface = controlSurface
        self.interactionMode = interactionMode
        self.showControlCenterShortcut = showControlCenterShortcut
        self.showHistoryShortcut = showHistoryShortcut
        self.showPortraitShortcut = showPortraitShortcut
        self.afterMutation = afterMutation
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                if let title {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                }

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(checkpoint.mode.title, systemImage: checkpoint.mode.symbolName)
                            .font(.headline)
                            .foregroundStyle(BeforeTheme.ink)

                        Text(checkpoint.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(approvalTitle(checkpoint.approvalState))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(approvalColor(checkpoint.approvalState))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(approvalColor(checkpoint.approvalState).opacity(0.12))
                            )

                        Text(checkpoint.rollbackReady ? "Rollback ready" : "Rollback unavailable")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(checkpoint.rollbackReady ? BeforeTheme.moss : .secondary)
                    }
                }

                DecisionEvolutionCheckpointLineageDetailsView(
                    summaryText: checkpoint.summaryText,
                    summaryColor: checkpoint.usesSecondarySummaryTone ? .secondary : BeforeTheme.ember,
                    metadataText: checkpoint.metadataText,
                    ticketSummaries: checkpoint.updateTicketSummaries,
                    auditFindings: checkpoint.auditFindings,
                    killSwitches: checkpoint.killSwitches
                )

                if !checkpoint.diffSummary.isEmpty {
                    Text("Diff: \(checkpoint.diffSummary.joined(separator: " • "))")
                        .font(.caption2)
                        .foregroundStyle(BeforeTheme.ember)
                }

                DecisionEvolutionCheckpointActionBar(
                    checkpointID: checkpoint.checkpointID,
                    checkpointPresentation: checkpoint,
                    controlSurface: controlSurface,
                    interactionMode: interactionMode,
                    applyReady: checkpoint.applyReady,
                    approvalState: checkpoint.approvalState,
                    hasLineage: checkpoint.hasLineage,
                    showControlCenterShortcut: showControlCenterShortcut,
                    showHistoryShortcut: showHistoryShortcut,
                    showPortraitShortcut: showPortraitShortcut,
                    afterMutation: afterMutation
                )
            }
        }
    }

    private func approvalTitle(_ state: DecisionEvolutionApprovalState) -> String {
        switch state {
        case .automatic:
            "Automatic"
        case .reviewSuggested:
            "Review suggested"
        }
    }

    private func approvalColor(_ state: DecisionEvolutionApprovalState) -> Color {
        switch state {
        case .automatic:
            BeforeTheme.moss
        case .reviewSuggested:
            .orange
        }
    }
}
