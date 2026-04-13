import SwiftUI

struct DecisionEvolutionMutationPreviewView: View {
    let intent: DecisionEvolutionMutationIntent
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(intent.title)
                                    .font(.title3.bold())
                                    .foregroundStyle(BeforeTheme.ink)

                                Text(intent.preview.headline)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(actionTint)

                                Text(intent.preview.scope.summaryTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                DecisionEvolutionSummaryBadge(
                                    title: intent.preview.scope.badgeTitle,
                                    tint: actionTint
                                )

                                if intent.isDestructive {
                                    DecisionEvolutionSummaryBadge(
                                        title: "DESTRUCTIVE",
                                        tint: .red
                                    )
                                } else {
                                    DecisionEvolutionSummaryBadge(
                                        title: "GUARDED",
                                        tint: BeforeTheme.moss
                                    )
                                }
                            }
                        }

                        Text(intent.preview.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(intent.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if shouldShowCheckpointTransitions {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Control-surface impact")
                                .font(.headline)
                                .foregroundStyle(BeforeTheme.ink)

                            checkpointTransitionRow(
                                title: "Active checkpoint",
                                current: intent.preview.currentActiveCheckpointID,
                                projected: intent.preview.projectedActiveCheckpointID
                            )

                            checkpointTransitionRow(
                                title: "Review head",
                                current: intent.preview.currentReviewCheckpointID,
                                projected: intent.preview.projectedReviewCheckpointID
                            )
                        }
                    }
                }

                if !intent.preview.changeHighlights.isEmpty {
                    bulletSection(
                        title: "Will change",
                        items: intent.preview.changeHighlights,
                        tint: actionTint
                    )
                }

                if !intent.preview.retainedHighlights.isEmpty {
                    bulletSection(
                        title: "Will remain",
                        items: intent.preview.retainedHighlights,
                        tint: BeforeTheme.moss
                    )
                }

                if !intent.preview.warningHighlights.isEmpty {
                    bulletSection(
                        title: "Watch",
                        items: intent.preview.warningHighlights,
                        tint: intent.isDestructive ? .red : BeforeTheme.ember
                    )
                }

                HStack(spacing: 10) {
                    BeforeActionButton("Cancel", style: .secondary) {
                        onCancel()
                    }

                    BeforeActionButton(intent.confirmTitle, style: .primary) {
                        onConfirm()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(BeforeTheme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var actionTint: Color {
        intent.isDestructive ? .red : BeforeTheme.ember
    }

    private var shouldShowCheckpointTransitions: Bool {
        intent.preview.currentActiveCheckpointID != nil
            || intent.preview.projectedActiveCheckpointID != nil
            || intent.preview.currentReviewCheckpointID != nil
            || intent.preview.projectedReviewCheckpointID != nil
    }

    @ViewBuilder
    private func checkpointTransitionRow(
        title: String,
        current: String?,
        projected: String?
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ink)
                .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Current: \(current ?? "none")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Projected: \(projected ?? "none")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(current == projected ? .secondary : actionTint)
            }
        }
    }

    @ViewBuilder
    private func bulletSection(
        title: String,
        items: [String],
        tint: Color
    ) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(tint)

                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
