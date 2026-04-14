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

    private var interactionMode: DecisionEvolutionControlInteractionMode {
        pilotSnapshot.interactionMode
    }

    private var allowsLocalMutationActions: Bool {
        pilotSnapshot.allowsLocalMutationActions
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                if showsHeader {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Evolution pilot controls")
                            .font(.headline)
                        Text(
                            allowsLocalMutationActions
                                ? "Work the review queue, restore the active checkpoint, and clear stale lineage from the dedicated mutation hub."
                                : "See release blockers and queue state here, then jump into Evolution Control for checkpoint mutations."
                        )
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

                if let releaseSummary, showEmbeddedReleaseSummary {
                    DecisionEvolutionReleaseSummaryView(
                        releaseSummary: releaseSummary,
                        controlSurface: controlSurface,
                        surfaceContract: surfaceContract,
                        presentationMode: allowsLocalMutationActions ? .mutationHub : .surface,
                        navigationOptions: navigationOptions,
                        afterMutation: afterMutation
                    )
                } else {
                    HStack(spacing: 8) {
                        DecisionEvolutionSummaryBadge(
                            title: "\(pilotSnapshot.pendingReviewCount) PENDING",
                            tint: pilotSnapshot.pendingReviewCount > 0 ? .orange : .secondary
                        )
                        DecisionEvolutionSummaryBadge(
                            title: "\(pilotSnapshot.rollbackReadyCount) ROLLBACK READY",
                            tint: pilotSnapshot.rollbackReadyCount > 0 ? BeforeTheme.moss : .secondary
                        )

                        if pilotSnapshot.pendingReviewLineageCount > 0 {
                            DecisionEvolutionSummaryBadge(
                                title: "\(pilotSnapshot.pendingReviewLineageCount) LINEAGE-BACKED",
                                tint: BeforeTheme.ember
                            )
                        }
                    }
                }

                DecisionEvolutionPilotImpactStripView(intents: pilotSnapshot.mutationIntents)

                if let guidedAction = pilotSnapshot.guidedAction {
                    guidedActionCallout(guidedAction)
                }

                if !allowsLocalMutationActions {
                    DecisionEvolutionOperatorActionFooterView(
                        interactionMode: interactionMode,
                        navigationOptions: navigationOptions,
                        routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
                        showsDetail: true,
                        controlCenterStyle: .primary,
                        adjacentShortcutStyle: .tertiary
                    )
                }

                if pilotSnapshot.pendingReviewLineageCount > 0, releaseSummary != nil {
                    Text("\(pilotSnapshot.pendingReviewLineageCount) pending checkpoints still carry recovered lineage.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if allowsLocalMutationActions {
                    HStack(spacing: 10) {
                        BeforeActionButton(
                            "Restore active path",
                            style: .primary,
                            isEnabled: pilotSnapshot.restoreActiveIntent != nil && allowsLocalMutationActions
                        ) {
                            guard let intent = pilotSnapshot.restoreActiveIntent else { return }
                            presentMutation(intent)
                        }

                        BeforeActionButton(
                            "Rollback active path",
                            style: .secondary,
                            isEnabled: pilotSnapshot.rollbackActiveIntent != nil && allowsLocalMutationActions
                        ) {
                            guard let intent = pilotSnapshot.rollbackActiveIntent else { return }
                            presentMutation(intent)
                        }

                        BeforeActionButton(
                            "Approve review queue",
                            style: .secondary,
                            isEnabled: pilotSnapshot.approveQueueIntent != nil && allowsLocalMutationActions
                        ) {
                            guard let intent = pilotSnapshot.approveQueueIntent else { return }
                            presentMutation(intent)
                        }
                    }

                    HStack(spacing: 10) {
                        BeforeActionButton(
                            "Clear queue lineage",
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
                        navigationOptions: navigationOptions,
                        routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
                        controlCenterStyle: .tertiary,
                        adjacentShortcutStyle: .tertiary
                    )
                }

                if !pilotSnapshot.reviewAuditFindings.isEmpty {
                    Text("Review audit: \(pilotSnapshot.reviewAuditFindings.joined(separator: " • "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let recommendedKillSwitches = pilotSnapshot.recommendedKillSwitches
                if !recommendedKillSwitches.isEmpty {
                    Text("Suggested kill switches: \(recommendedKillSwitches.joined(separator: " • "))")
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
            Text("Recommended next step")
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
            performMutation(intent)
            afterMutation?()
        }
    }

    private func performMutation(_ intent: DecisionEvolutionMutationIntent) {
        switch intent.kind {
        case .restoreActiveCheckpoint:
            guard let checkpointID = intent.preview.targetCheckpointIDs.first else { return }
            appModel.applyEvolutionCheckpoint(checkpointID: checkpointID)
        case .rollbackActiveCheckpoint:
            appModel.rollbackActiveEvolutionCheckpoint(to: intent.preview.targetCheckpointIDs.first)
        case .approvePendingCheckpoints:
            appModel.approvePendingEvolutionCheckpoints(
                checkpointIDs: intent.preview.targetCheckpointIDs
            )
        case .clearPendingReviewLineage:
            appModel.clearPendingEvolutionCheckpointLineages(
                checkpointIDs: intent.preview.targetCheckpointIDs
            )
        default:
            break
        }
    }

}
