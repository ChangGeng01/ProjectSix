import SwiftUI

struct DecisionEvolutionReleaseSummaryPresentation: Equatable, Sendable {
    let state: DecisionSystemReleaseState
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
        DecisionEvolutionReleaseSummaryPresentation(
            state: releaseSummary.state,
            pendingReviewCount: releaseSummary.pendingReviewCount,
            rollbackReadyCount: releaseSummary.rollbackReadyCount,
            headline: releaseSummary.headline,
            primaryReason: releaseSummary.reasons.first,
            activeCheckpointHeadline: controlSurface.activePresentation.map { activePresentation in
                "Active: \(activePresentation.checkpointID) • \(activePresentation.approvalStateTitle) • \(activePresentation.summaryText)"
            },
            reviewCheckpointHeadline: controlSurface.spotlightReviewPresentation.map { reviewPresentation in
                "Review head: \(reviewPresentation.checkpointID) • \(reviewPresentation.approvalStateTitle) • \(reviewPresentation.summaryText)"
            },
            activeSourceText: releaseSummary.activeCheckpointID != nil && releaseSummary.activeCheckpointSource != .none
                ? "Active source: \(releaseSummary.activeCheckpointSource.title)"
                : nil,
            activeKillSwitchesText: releaseSummary.activeKillSwitches.isEmpty
                ? nil
                : "Active kill switches: \(releaseSummary.activeKillSwitches.joined(separator: " • "))",
            recommendedKillSwitchesText: releaseSummary.recommendedKillSwitches.isEmpty
                ? nil
                : "Recommended kill switches: \(releaseSummary.recommendedKillSwitches.joined(separator: " • "))",
            operatorHeadline: presentationMode.operatorHeadline,
            operatorDetail: presentationMode.operatorDetail
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

    var operatorHeadline: String? {
        switch self {
        case .mutationHub:
            "Mutation hub"
        case .surface, .compact:
            nil
        }
    }

    var operatorDetail: String? {
        switch self {
        case .mutationHub:
            "Release readiness is summarized once here. Apply, approve, rollback, and lineage-clearing actions live in the mutation workspace below."
        case .surface, .compact:
            nil
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

    private var interactionMode: DecisionEvolutionControlInteractionMode {
        surfaceContract.interactionMode
    }

    private var presentation: DecisionEvolutionReleaseSummaryPresentation {
        DecisionEvolutionReleaseSummaryPresentation.build(
            releaseSummary: releaseSummary,
            controlSurface: controlSurface,
            presentationMode: presentationMode
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DecisionEvolutionSummaryBadge(
                    title: presentation.state.title.uppercased(),
                    tint: releaseTint(presentation.state)
                )
                DecisionEvolutionSummaryBadge(
                    title: "\(presentation.pendingReviewCount) PENDING",
                    tint: presentation.pendingReviewCount > 0 ? .orange : .secondary
                )
                DecisionEvolutionSummaryBadge(
                    title: "\(presentation.rollbackReadyCount) ROLLBACK READY",
                    tint: presentation.rollbackReadyCount > 0 ? BeforeTheme.moss : .secondary
                )
            }

            Text(presentation.headline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(releaseTint(presentation.state))

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
                    .foregroundStyle(releaseTint(presentation.state))
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

            if showsAnyActionRow {
                Divider()
                    .padding(.top, 2)

                if allowsLocalMutationActions {
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

    private func releaseTint(_ state: DecisionSystemReleaseState) -> Color {
        switch state {
        case .ready:
            BeforeTheme.moss
        case .watch:
            BeforeTheme.ember
        case .blocked:
            .red
        }
    }

    private var rollbackIntent: DecisionEvolutionMutationIntent? {
        DecisionEvolutionMutationIntentFactory.rollbackActiveCheckpoint(
            controlSurface: controlSurface
        )
    }

    private var routesMutationsToControlCenter: Bool {
        surfaceContract.routesMutationsToControlCenter
    }

    private var allowsLocalMutationActions: Bool {
        !routesMutationsToControlCenter
    }

    private var approveQueueIntent: DecisionEvolutionMutationIntent? {
        DecisionEvolutionMutationIntentFactory.approvePendingCheckpoints(
            controlSurface: controlSurface
        )
    }

    private var clearReviewLineageIntent: DecisionEvolutionMutationIntent? {
        DecisionEvolutionMutationIntentFactory.clearPendingReviewLineage(
            controlSurface: controlSurface
        )
    }

    private var showsAnyActionRow: Bool {
        if allowsLocalMutationActions {
            return rollbackIntent != nil || approveQueueIntent != nil || clearReviewLineageIntent != nil
        }

        return navigationOptions.showsAnyShortcut
    }

    @ViewBuilder
    private var mutationActionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick actions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)

            HStack(spacing: 10) {
                if let rollbackIntent {
                    BeforeActionButton("Rollback active", style: .secondary) {
                        pendingMutation = PendingMutation(intent: rollbackIntent) {
                            appModel.rollbackActiveEvolutionCheckpoint(
                                to: rollbackIntent.preview.targetCheckpointIDs.first
                            )
                            afterMutation?()
                        }
                    }
                }

                if let approveQueueIntent {
                    BeforeActionButton("Approve queue", style: .primary) {
                        pendingMutation = PendingMutation(intent: approveQueueIntent) {
                            appModel.approvePendingEvolutionCheckpoints(
                                checkpointIDs: approveQueueIntent.preview.targetCheckpointIDs
                            )
                            afterMutation?()
                        }
                    }
                }
            }

            if let clearReviewLineageIntent {
                HStack(spacing: 10) {
                    BeforeActionButton("Clear review lineage", style: .tertiary) {
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
            interactionMode: interactionMode,
            navigationOptions: navigationOptions,
            routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
            showsDetail: false,
            controlCenterStyle: .primary,
            adjacentShortcutStyle: .secondary
        )
    }
}
