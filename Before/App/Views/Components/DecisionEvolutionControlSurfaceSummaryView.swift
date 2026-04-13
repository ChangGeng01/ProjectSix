import SwiftUI

struct DecisionEvolutionControlSurfaceSummaryView: View {
    let controlSurface: DecisionEvolutionControlSurface
    let emptyMessage: String
    let interactionMode: DecisionEvolutionControlInteractionMode
    let showCheckpointActionBar: Bool
    let showControlCenterShortcut: Bool
    let showHistoryShortcut: Bool
    let showPortraitShortcut: Bool
    let afterMutation: (() -> Void)?

    init(
        controlSurface: DecisionEvolutionControlSurface,
        emptyMessage: String = "No persisted checkpoint lineage is available yet.",
        interactionMode: DecisionEvolutionControlInteractionMode = .mutationHub,
        showCheckpointActionBar: Bool = true,
        showControlCenterShortcut: Bool = false,
        showHistoryShortcut: Bool = false,
        showPortraitShortcut: Bool = false,
        afterMutation: (() -> Void)? = nil
    ) {
        self.controlSurface = controlSurface
        self.emptyMessage = emptyMessage
        self.interactionMode = interactionMode
        self.showCheckpointActionBar = showCheckpointActionBar
        self.showControlCenterShortcut = showControlCenterShortcut
        self.showHistoryShortcut = showHistoryShortcut
        self.showPortraitShortcut = showPortraitShortcut
        self.afterMutation = afterMutation
    }

    var body: some View {
        let spotlightSet = controlSurface.spotlightSet

        VStack(alignment: .leading, spacing: 12) {
            if let activePresentation = spotlightSet.activePresentation {
                checkpointSection(
                    title: "Active checkpoint",
                    presentation: activePresentation
                )
            }

            if let reviewPresentation = spotlightSet.reviewPresentation {
                checkpointSection(
                    title: "Review head",
                    presentation: reviewPresentation
                )
            }

            if !controlSurface.hasAnyCheckpoint {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func checkpointSection(
        title: String,
        presentation: DecisionEvolutionCheckpointPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                    Text(presentation.headline)
                        .font(.subheadline.bold())
                        .foregroundStyle(BeforeTheme.ink)
                }

                Spacer()

                Text(presentation.approvalStateTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(presentation.primarySummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let riskLevel = presentation.displayRiskLevel {
                    DecisionEvolutionSummaryBadge(title: riskLevel.uppercased(), tint: BeforeTheme.ember)
                }

                if let permitMode = presentation.displayPermitMode {
                    DecisionEvolutionSummaryBadge(title: permitMode.uppercased(), tint: BeforeTheme.moss)
                }

                DecisionEvolutionSummaryBadge(
                    title: presentation.rollbackReady ? "ROLLBACK READY" : "ROLLBACK WATCH",
                    tint: presentation.rollbackReady ? BeforeTheme.moss : BeforeTheme.ember
                )
            }

            DecisionEvolutionCheckpointLineageDetailsView(
                summaryText: presentation.summaryText,
                summaryColor: presentation.usesSecondarySummaryTone ? .secondary : BeforeTheme.ember,
                metadataText: presentation.metadataText,
                ticketSummaries: presentation.updateTicketSummaries,
                auditFindings: presentation.auditFindings,
                killSwitches: presentation.killSwitches
            )

            if !presentation.diffSummary.isEmpty {
                ForEach(presentation.diffSummary, id: \.self) { diff in
                    Text("• \(diff)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Recorded \(presentation.createdAt, style: .relative) • \(presentation.checkpointID)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if showCheckpointActionBar {
                DecisionEvolutionCheckpointActionBar(
                    checkpointID: presentation.checkpointID,
                    checkpointPresentation: presentation,
                    controlSurface: controlSurface,
                    interactionMode: interactionMode,
                    applyReady: presentation.applyReady,
                    approvalState: presentation.approvalState,
                    hasLineage: presentation.hasLineage,
                    showControlCenterShortcut: showControlCenterShortcut,
                    showHistoryShortcut: showHistoryShortcut,
                    showPortraitShortcut: showPortraitShortcut,
                    afterMutation: afterMutation
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.55))
        )
    }
}

struct DecisionEvolutionSummaryBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
            )
    }
}
