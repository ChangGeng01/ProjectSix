import SwiftUI

struct DecisionEvolutionPilotImpactStripView: View {
    let intents: [DecisionEvolutionMutationIntent]

    init(intents: [DecisionEvolutionMutationIntent]) {
        self.intents = intents
    }

    var body: some View {
        if !intents.isEmpty {
            let previewPresentation = intents.first?.previewPresentation

            VStack(alignment: .leading, spacing: 10) {
                if let previewPresentation {
                    Text(previewPresentation.impactTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    Text(previewPresentation.impactDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(intents) { intent in
                    impactRow(intent)
                }
            }
        }
    }

    @ViewBuilder
    private func impactRow(_ intent: DecisionEvolutionMutationIntent) -> some View {
        let preview = intent.preview
        let previewPresentation = intent.previewPresentation
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(intent.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ink)

                Spacer()

                DecisionEvolutionSummaryBadge(
                    title: preview.scope.badgeTitle,
                    tint: intent.isDestructive ? BeforeTheme.ember : BeforeTheme.moss
                )
            }

            Text(preview.headline)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let impactTargetsLine = previewPresentation.impactTargetsLine(preview.targetCheckpointIDs) {
                Text(impactTargetsLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                transitionBadge(
                    title: previewPresentation.activeTransitionTitle,
                    current: preview.currentActiveCheckpointID,
                    projected: preview.projectedActiveCheckpointID,
                    tint: BeforeTheme.moss,
                    previewPresentation: previewPresentation
                )

                transitionBadge(
                    title: previewPresentation.reviewTransitionTitle,
                    current: preview.currentReviewCheckpointID,
                    projected: preview.projectedReviewCheckpointID,
                    tint: BeforeTheme.ember,
                    previewPresentation: previewPresentation
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.5))
        )
    }

    @ViewBuilder
    private func transitionBadge(
        title: String,
        current: String?,
        projected: String?,
        tint: Color,
        previewPresentation: DecisionEvolutionMutationPreviewPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
            Text(previewPresentation.transitionLine(current: current, projected: projected))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}
