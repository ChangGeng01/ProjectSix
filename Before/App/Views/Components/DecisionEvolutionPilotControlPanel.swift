import SwiftUI

struct DecisionEvolutionPilotControlPanel: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var pendingMutation: PendingMutation?

    let controlSurface: DecisionEvolutionControlSurface
    let releaseSummary: DecisionSystemReleaseControlSummary?
    let surfaceContract: DecisionEvolutionSurfaceContract
    let showsHeader: Bool
    let showEmbeddedReleaseSummary: Bool
    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    let pilotSnapshot: DecisionEvolutionPilotControlSnapshot
    let afterMutation: (() -> Void)?

    private struct PendingMutation: Identifiable {
        let id = UUID()
        let intent: DecisionEvolutionMutationIntent
        let perform: () -> Void
    }
    init(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary? = nil,
        surfaceContract: DecisionEvolutionSurfaceContract,
        showsHeader: Bool = true,
        showEmbeddedReleaseSummary: Bool = true,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions? = nil,
        afterMutation: (() -> Void)? = nil
    ) {
        self.controlSurface = controlSurface
        self.releaseSummary = releaseSummary
        self.surfaceContract = surfaceContract
        self.showsHeader = showsHeader
        self.showEmbeddedReleaseSummary = showEmbeddedReleaseSummary
        let resolvedNavigationOptions = navigationOptions ?? surfaceContract.navigationSurfaceOptions()
        self.navigationOptions = resolvedNavigationOptions
        self.pilotSnapshot = DecisionEvolutionPilotControlSnapshot.build(
            controlSurface: controlSurface,
            releaseSummary: releaseSummary,
            surfaceContract: surfaceContract,
            navigationOptions: resolvedNavigationOptions
        )
        self.afterMutation = afterMutation
    }

    private var allowsLocalMutationActions: Bool {
        pilotSnapshot.allowsLocalMutationActions
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                if showsHeader {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pilotSnapshot.headerTitle)
                            .font(.headline)
                        Text(pilotSnapshot.headerDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let outcome = appModel.latestEvolutionMutationOutcome,
                   outcome.isVisible(in: controlSurface) {
                    DecisionEvolutionMutationOutcomeView(
                        outcome: outcome,
                        onDismiss: appModel.dismissEvolutionMutationOutcome
                    )
                }

                if let releaseSummary,
                   showEmbeddedReleaseSummary,
                   let releaseSummaryMode = pilotSnapshot.embeddedReleaseSummaryMode {
                    DecisionEvolutionReleaseSummaryView(
                        releaseSummary: releaseSummary,
                        controlSurface: controlSurface,
                        surfaceContract: surfaceContract,
                        presentationMode: releaseSummaryMode,
                        navigationOptions: navigationOptions,
                        afterMutation: afterMutation
                    )
                } else {
                    HStack(spacing: 8) {
                        ForEach(Array(pilotSnapshot.summaryBadgePresentations.enumerated()), id: \.offset) { _, badge in
                            DecisionEvolutionSummaryBadge(presentation: badge)
                        }
                    }
                }

                DecisionEvolutionPilotImpactStripView(intents: pilotSnapshot.mutationIntents)

                if let guidedAction = pilotSnapshot.guidedAction {
                    guidedActionCallout(guidedAction)
                }

                if !allowsLocalMutationActions {
                    DecisionEvolutionOperatorActionFooterView(
                        presentation: DecisionEvolutionOperatorFooterPresentationSupport.pilotControl(
                            surfaceContract: surfaceContract,
                            navigationOptions: navigationOptions
                        )
                    )
                }

                if let pendingReviewLineageNotice = pilotSnapshot.pendingReviewLineageNotice {
                    Text(pendingReviewLineageNotice)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if allowsLocalMutationActions {
                    HStack(spacing: 10) {
                        BeforeActionButton(
                            pilotSnapshot.restoreActiveTitle,
                            style: .primary,
                            isEnabled: pilotSnapshot.restoreActiveIntent != nil && allowsLocalMutationActions
                        ) {
                            guard let intent = pilotSnapshot.restoreActiveIntent else { return }
                            presentMutation(intent)
                        }

                        BeforeActionButton(
                            pilotSnapshot.rollbackActiveTitle,
                            style: .secondary,
                            isEnabled: pilotSnapshot.rollbackActiveIntent != nil && allowsLocalMutationActions
                        ) {
                            guard let intent = pilotSnapshot.rollbackActiveIntent else { return }
                            presentMutation(intent)
                        }

                        BeforeActionButton(
                            pilotSnapshot.approveQueueTitle,
                            style: .secondary,
                            isEnabled: pilotSnapshot.approveQueueIntent != nil && allowsLocalMutationActions
                        ) {
                            guard let intent = pilotSnapshot.approveQueueIntent else { return }
                            presentMutation(intent)
                        }
                    }

                    HStack(spacing: 10) {
                        BeforeActionButton(
                            pilotSnapshot.clearQueueLineageTitle,
                            style: .secondary,
                            isEnabled: pilotSnapshot.clearReviewLineageIntent != nil && allowsLocalMutationActions
                        ) {
                            guard let intent = pilotSnapshot.clearReviewLineageIntent else { return }
                            presentMutation(intent)
                        }
                    }
                }

                if allowsLocalMutationActions {
                    DecisionEvolutionNavigationActionRow(
                        presentation: DecisionEvolutionNavigationRowPresentationSupport.pilotMutationHub(
                            surfaceContract: surfaceContract,
                            navigationOptions: navigationOptions
                        )
                    )
                }

                if let reviewAuditLine = pilotSnapshot.reviewAuditLine {
                    Text(reviewAuditLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let recommendedKillSwitchesLine = pilotSnapshot.recommendedKillSwitchesLine {
                    Text(recommendedKillSwitchesLine)
                        .font(.caption2)
                        .foregroundStyle(BeforeTheme.ember)
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

    @ViewBuilder
    private func guidedActionCallout(_ guidedAction: DecisionEvolutionPilotGuidedAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pilotSnapshot.guidedActionSectionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.ember)

            Text(guidedAction.title)
                .font(.subheadline.bold())
                .foregroundStyle(BeforeTheme.ink)

            Text(guidedAction.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            BeforeActionButton(guidedAction.actionTitle, style: .secondary) {
                runGuidedAction(guidedAction)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BeforeTheme.ember.opacity(0.08))
        )
    }

    private func runGuidedAction(_ guidedAction: DecisionEvolutionPilotGuidedAction) {
        switch guidedAction.route {
        case let .mutation(intent):
            presentMutation(intent)
        case let .navigation(destination):
            destination.perform(using: appModel)
        }
    }

    private func presentMutation(_ intent: DecisionEvolutionMutationIntent) {
        pendingMutation = PendingMutation(intent: intent) {
            appModel.performEvolutionMutation(intent)
            afterMutation?()
        }
    }
}
