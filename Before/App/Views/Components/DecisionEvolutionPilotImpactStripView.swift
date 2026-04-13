import SwiftUI

struct DecisionEvolutionPilotImpactStripView: View {
    let intents: [DecisionEvolutionMutationIntent]

    init(intents: [DecisionEvolutionMutationIntent]) {
        self.intents = intents
    }

    var body: some View {
        if !intents.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preflight impact")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ember)

                Text("See the active/review shift before you open the guarded confirmation sheet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(intents) { intent in
                    impactRow(intent)
                }
            }
        }
    }

    @ViewBuilder
    private func impactRow(_ intent: DecisionEvolutionMutationIntent) -> some View {
        let preview = intent.preview
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

            if !preview.targetCheckpointIDs.isEmpty {
                Text("Targets: \(preview.targetCheckpointIDs.joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                transitionBadge(
                    title: "Active",
                    current: preview.currentActiveCheckpointID,
                    projected: preview.projectedActiveCheckpointID,
                    tint: BeforeTheme.moss
                )

                transitionBadge(
                    title: "Review",
                    current: preview.currentReviewCheckpointID,
                    projected: preview.projectedReviewCheckpointID,
                    tint: BeforeTheme.ember
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
        tint: Color
    ) -> some View {
        let currentToken = current ?? "none"
        let projectedToken = projected ?? "none"

        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
            Text("\(currentToken) → \(projectedToken)")
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
