import SwiftUI

struct DecisionEvolutionReleaseSummaryPresentation: Equatable, Sendable {
    let state: DecisionSystemReleaseState
    let stateTone: DecisionEvolutionSummaryBadgeTone
    let badgePresentations: [DecisionEvolutionSummaryBadgePresentation]
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let headline: String
    let primaryReason: String?
    let activeCheckpointHeadline: String?
    let reviewCheckpointHeadline: String?
    let activeSourceText: String?
    let activeKillSwitchesText: String?
    let recommendedKillSwitchesText: String?
    let operatorHeadline: String?
    let operatorDetail: String?

    static func build(
        releaseSummary: DecisionSystemReleaseControlSummary,
        controlSurface: DecisionEvolutionControlSurface,
        presentationMode: DecisionEvolutionReleaseSummaryPresentationMode
    ) -> DecisionEvolutionReleaseSummaryPresentation {
        DecisionEvolutionReleaseSummaryPresentationSupport.build(
            releaseSummary: releaseSummary,
            controlSurface: controlSurface,
            presentationMode: presentationMode
        )
    }
}

enum DecisionEvolutionReleaseSummaryPresentationMode: Equatable, Sendable {
    case surface
    case compact
    case mutationHub

    var showsCheckpointHeadlines: Bool {
        switch self {
        case .surface:
            true
        case .compact, .mutationHub:
            false
        }
    }
}

struct DecisionEvolutionReleaseSummaryView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var pendingMutation: PendingMutation?

    let releaseSummary: DecisionSystemReleaseControlSummary
    let controlSurface: DecisionEvolutionControlSurface
    let surfaceContract: DecisionEvolutionSurfaceContract
    let presentationMode: DecisionEvolutionReleaseSummaryPresentationMode
    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    let afterMutation: (() -> Void)?

    private struct PendingMutation: Identifiable {
        let id = UUID()
        let intent: DecisionEvolutionMutationIntent
        let perform: () -> Void
    }

    init(
        releaseSummary: DecisionSystemReleaseControlSummary,
        controlSurface: DecisionEvolutionControlSurface,
        surfaceContract: DecisionEvolutionSurfaceContract,
        presentationMode: DecisionEvolutionReleaseSummaryPresentationMode = .surface,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions? = nil,
        afterMutation: (() -> Void)? = nil
    ) {
        self.releaseSummary = releaseSummary
        self.controlSurface = controlSurface
        self.surfaceContract = surfaceContract
        self.presentationMode = presentationMode
        self.navigationOptions = navigationOptions ?? surfaceContract.navigationSurfaceOptions()
        self.afterMutation = afterMutation
    }

    private var presentation: DecisionEvolutionReleaseSummaryPresentation {
        DecisionEvolutionReleaseSummaryPresentation.build(
            releaseSummary: releaseSummary,
            controlSurface: controlSurface,
            presentationMode: presentationMode
        )
    }

    private var actionPresentation: DecisionEvolutionReleaseSummaryActionPresentation {
        DecisionEvolutionReleaseSummaryActionSupport.build(
            controlSurface: controlSurface,
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Array(presentation.badgePresentations.enumerated()), id: \.offset) { _, badge in
                    DecisionEvolutionSummaryBadge(presentation: badge)
                }
            }

            Text(presentation.headline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(releaseTint(presentation.stateTone))

            if let reason = presentation.primaryReason {
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if presentationMode.showsCheckpointHeadlines {
                if let activeCheckpointHeadline = presentation.activeCheckpointHeadline {
                    Text(activeCheckpointHeadline)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let reviewCheckpointHeadline = presentation.reviewCheckpointHeadline {
                    Text(reviewCheckpointHeadline)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let activeSourceText = presentation.activeSourceText {
                Text(activeSourceText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let activeKillSwitchesText = presentation.activeKillSwitchesText {
                Text(activeKillSwitchesText)
                    .font(.caption2)
                    .foregroundStyle(releaseTint(presentation.stateTone))
                    .lineLimit(3)
            }

            if let recommendedKillSwitchesText = presentation.recommendedKillSwitchesText {
                Text(recommendedKillSwitchesText)
                    .font(.caption2)
                    .foregroundStyle(BeforeTheme.ember)
                    .lineLimit(3)
            }

            if let operatorHeadline = presentation.operatorHeadline,
               let operatorDetail = presentation.operatorDetail {
                VStack(alignment: .leading, spacing: 4) {
                    Text(operatorHeadline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                    Text(operatorDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if actionPresentation.showsAnyActionRow {
                Divider()
                    .padding(.top, 2)

                if actionPresentation.allowsLocalMutationActions {
                    mutationActionRow
                } else {
                    observeActionRow
                }
            }
        }
        .sheet(item: $pendingMutation) { pendingMutation in
            DecisionEvolutionMutationPreviewView(
                intent: pendingMutation.intent,
                onConfirm: {
                    pendingMutation.perform()
                    self.pendingMutation = nil
                },
                onCancel: {
                    self.pendingMutation = nil
                }
            )
        }
    }

    private func releaseTint(_ tone: DecisionEvolutionSummaryBadgeTone) -> Color {
        switch tone {
        case .moss:
            BeforeTheme.moss
        case .ember:
            BeforeTheme.ember
        case .red:
            .red
        case .secondary:
            .secondary
        case .blue:
            .blue
        case .orange:
            .orange
        }
    }

    @ViewBuilder
    private var mutationActionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let quickActionsTitle = actionPresentation.quickActionsTitle {
                Text(quickActionsTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ember)
            }

            HStack(spacing: 10) {
                if let rollbackIntent = actionPresentation.rollbackIntent {
                    BeforeActionButton(actionPresentation.rollbackTitle, style: .secondary) {
                        pendingMutation = PendingMutation(intent: rollbackIntent) {
                            appModel.rollbackActiveEvolutionCheckpoint(
                                to: rollbackIntent.preview.targetCheckpointIDs.first
                            )
                            afterMutation?()
                        }
                    }
                }

                if let approveQueueIntent = actionPresentation.approveQueueIntent {
                    BeforeActionButton(actionPresentation.approveQueueTitle, style: .primary) {
                        pendingMutation = PendingMutation(intent: approveQueueIntent) {
                            appModel.approvePendingEvolutionCheckpoints(
                                checkpointIDs: approveQueueIntent.preview.targetCheckpointIDs
                            )
                            afterMutation?()
                        }
                    }
                }
            }

            if let clearReviewLineageIntent = actionPresentation.clearReviewLineageIntent {
                HStack(spacing: 10) {
                    BeforeActionButton(actionPresentation.clearReviewLineageTitle, style: .tertiary) {
                        pendingMutation = PendingMutation(intent: clearReviewLineageIntent) {
                            appModel.clearPendingEvolutionCheckpointLineages(
                                checkpointIDs: clearReviewLineageIntent.preview.targetCheckpointIDs
                            )
                            afterMutation?()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var observeActionRow: some View {
        DecisionEvolutionOperatorActionFooterView(
            presentation: DecisionEvolutionOperatorFooterPresentationSupport.releaseSummary(
                surfaceContract: surfaceContract,
                navigationOptions: navigationOptions
            )
        )
    }
}
