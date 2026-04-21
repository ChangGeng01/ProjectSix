import SwiftUI

struct DecisionEvolutionCheckpointPanelView: View {
    let title: String?
    let checkpoint: DecisionEvolutionCheckpointPresentation
    let controlSurface: DecisionEvolutionControlSurface
    let surfaceContract: DecisionEvolutionSurfaceContract
    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    let isSelected: Bool
    let onToggleSelection: (() -> Void)?
    let afterMutation: (() -> Void)?

    init(
        title: String? = nil,
        checkpoint: DecisionEvolutionCheckpointPresentation,
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions? = nil,
        isSelected: Bool = false,
        onToggleSelection: (() -> Void)? = nil,
        afterMutation: (() -> Void)? = nil
    ) {
        self.title = title
        self.checkpoint = checkpoint
        self.controlSurface = controlSurface
        self.surfaceContract = surfaceContract
        self.navigationOptions = navigationOptions ?? surfaceContract.navigationSurfaceOptions()
        self.isSelected = isSelected
        self.onToggleSelection = onToggleSelection
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
                    let selectionPresentation = checkpoint.selectionActionPresentation(
                        isSelected: isSelected
                    )

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
                        Text(checkpoint.approvalStateTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(approvalColor(checkpoint.approvalState))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(approvalColor(checkpoint.approvalState).opacity(0.12))
                            )

                        Text(checkpoint.rollbackStateTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(checkpoint.rollbackReady ? BeforeTheme.moss : .secondary)

                        if let onToggleSelection {
                            BeforeActionButton(
                                selectionPresentation.title,
                                style: selectionPresentation.usesPrimaryStyle ? .primary : .tertiary
                            ) {
                                onToggleSelection()
                            }
                        }
                    }
                }

                DecisionEvolutionCheckpointLineageDetailsView(
                    summaryText: checkpoint.summaryText,
                    summaryColor: checkpoint.usesSecondarySummaryTone ? .secondary : BeforeTheme.ember,
                    metadataText: checkpoint.metadataText,
                    foldedLungTitle: checkpoint.foldedLungTitle,
                    foldedLungLines: checkpoint.foldedLungLines,
                    ticketsLine: checkpoint.ticketsLine,
                    auditLine: checkpoint.auditLine,
                    killSwitchesLine: checkpoint.killSwitchesLine
                )

                if let diffLine = checkpoint.diffLine {
                    Text(diffLine)
                        .font(.caption2)
                        .foregroundStyle(BeforeTheme.ember)
                }

                DecisionEvolutionCheckpointActionBar(
                    checkpointID: checkpoint.checkpointID,
                    checkpointPresentation: checkpoint,
                    controlSurface: controlSurface,
                    surfaceContract: surfaceContract,
                    applyReady: checkpoint.applyReady,
                    approvalState: checkpoint.approvalState,
                    hasLineage: checkpoint.hasLineage,
                    navigationOptions: navigationOptions,
                    afterMutation: afterMutation
                )
            }
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
