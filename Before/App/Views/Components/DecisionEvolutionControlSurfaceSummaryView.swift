import SwiftUI

struct DecisionEvolutionControlSurfaceSummaryView: View {
    let controlSurface: DecisionEvolutionControlSurface
    let surfaceContract: DecisionEvolutionSurfaceContract
    let emptyMessage: String
    let surfaceOptions: DecisionEvolutionSummarySurfaceOptions
    let afterMutation: (() -> Void)?

    init(
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract,
        emptyMessage: String = DecisionEvolutionCheckpointDetailPresentationSupport.emptyLineageMessage,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions? = nil,
        showCheckpointActionBar: Bool? = nil,
        afterMutation: (() -> Void)? = nil
    ) {
        self.controlSurface = controlSurface
        self.surfaceContract = surfaceContract
        self.emptyMessage = emptyMessage
        if let navigationOptions {
            self.surfaceOptions = surfaceContract.summarySurfaceOptions(
                navigationOptions: navigationOptions,
                showCheckpointActionBar: showCheckpointActionBar
            )
        } else {
            self.surfaceOptions = surfaceContract.summarySurfaceOptions(
                showCheckpointActionBar: showCheckpointActionBar
            )
        }
        self.afterMutation = afterMutation
    }

    var body: some View {
        let summarySections = controlSurface.summarySectionPresentations

        VStack(alignment: .leading, spacing: 12) {
            ForEach(summarySections) { section in
                checkpointSection(section: section)
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
        section: DecisionEvolutionControlSurfaceSummarySectionPresentation
    ) -> some View {
        let presentation = section.presentation

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
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
                ForEach(Array(section.summaryBadges.enumerated()), id: \.offset) { _, badge in
                    DecisionEvolutionSummaryBadge(presentation: badge)
                }
            }

            DecisionEvolutionCheckpointLineageDetailsView(
                summaryText: presentation.summaryText,
                summaryColor: presentation.usesSecondarySummaryTone ? .secondary : BeforeTheme.ember,
                metadataText: presentation.metadataText,
                ticketsLine: presentation.ticketsLine,
                auditLine: presentation.auditLine,
                killSwitchesLine: presentation.killSwitchesLine
            )

            if !presentation.diffBulletLines.isEmpty {
                ForEach(Array(presentation.diffBulletLines.enumerated()), id: \.offset) { _, diffLine in
                    Text(diffLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(presentation.recordedLine)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if surfaceOptions.showCheckpointActionBar {
                DecisionEvolutionCheckpointActionBar(
                    checkpointID: presentation.checkpointID,
                    checkpointPresentation: presentation,
                    controlSurface: controlSurface,
                    surfaceContract: surfaceContract,
                    applyReady: presentation.applyReady,
                    approvalState: presentation.approvalState,
                    hasLineage: presentation.hasLineage,
                    navigationOptions: surfaceOptions.navigationOptions,
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

    init(title: String, tint: Color) {
        self.title = title
        self.tint = tint
    }

    init(presentation: DecisionEvolutionSummaryBadgePresentation) {
        self.title = presentation.title
        switch presentation.tone {
        case .ember:
            self.tint = BeforeTheme.ember
        case .moss:
            self.tint = BeforeTheme.moss
        case .secondary:
            self.tint = .secondary
        case .blue:
            self.tint = .blue
        case .orange:
            self.tint = .orange
        case .red:
            self.tint = .red
        }
    }

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
