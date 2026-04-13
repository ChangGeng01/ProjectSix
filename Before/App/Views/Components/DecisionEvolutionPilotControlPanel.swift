import SwiftUI

struct DecisionEvolutionPilotControlPanel: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var pendingMutation: PendingMutation?

    let controlSurface: DecisionEvolutionControlSurface
    let releaseSummary: DecisionSystemReleaseControlSummary?
    let interactionMode: DecisionEvolutionControlInteractionMode
    let showEmbeddedReleaseSummary: Bool
    let showHistoryShortcut: Bool
    let showPortraitShortcut: Bool
    let showControlCenterShortcut: Bool
    let afterMutation: (() -> Void)?

    private struct PendingMutation: Identifiable {
        let id = UUID()
        let intent: DecisionEvolutionMutationIntent
        let perform: () -> Void
    }

    private struct GuidedAction {
        let title: String
        let detail: String
        let actionTitle: String
        let action: () -> Void
    }

    init(
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary? = nil,
        interactionMode: DecisionEvolutionControlInteractionMode = .mutationHub,
        showEmbeddedReleaseSummary: Bool = true,
        showHistoryShortcut: Bool = false,
        showPortraitShortcut: Bool = false,
        showControlCenterShortcut: Bool = false,
        afterMutation: (() -> Void)? = nil
    ) {
        self.controlSurface = controlSurface
        self.releaseSummary = releaseSummary
        self.interactionMode = interactionMode
        self.showEmbeddedReleaseSummary = showEmbeddedReleaseSummary
        self.showHistoryShortcut = showHistoryShortcut
        self.showPortraitShortcut = showPortraitShortcut
        self.showControlCenterShortcut = showControlCenterShortcut
        self.afterMutation = afterMutation
    }

    private var pendingReviewLineageCount: Int {
        controlSurface.pendingReviewLineagePresentations.count
    }

    private var pilotMutationIntents: [DecisionEvolutionMutationIntent] {
        DecisionEvolutionMutationIntentFactory.pilotMutationIntents(
            controlSurface: controlSurface
        )
    }

    private var guidedAction: GuidedAction? {
        guard let releaseSummary else { return nil }

        if releaseSummary.pendingReviewCount > 0 {
            if interactionMode.allowsMutations,
               let intent = DecisionEvolutionMutationIntentFactory.approvePendingCheckpoints(
                   controlSurface: controlSurface
               ) {
                return GuidedAction(
                    title: "Pending review is the next blocker",
                    detail: "Clear or approve the review queue before treating this release path as ready.",
                    actionTitle: "Approve review queue",
                    action: {
                        pendingMutation = PendingMutation(intent: intent) {
                            appModel.approvePendingEvolutionCheckpoints(
                                checkpointIDs: intent.preview.targetCheckpointIDs
                            )
                            afterMutation?()
                        }
                    }
                )
            }

            return GuidedAction(
                title: "Pending review is the next blocker",
                detail: interactionMode.allowsMutations
                    ? "Open the checkpoint workspace and work the queue before widening rollout."
                    : "This surface stays read-first. Open Evolution Control and work the queue there before widening rollout.",
                actionTitle: navigationActionTitle,
                action: navigateToBestControlSurface
            )
        }

        if !releaseSummary.killSwitches.isEmpty {
            return GuidedAction(
                title: "Kill switches are holding the release path",
                detail: "Inspect the active checkpoint and its guardrails before trying to widen rollout.",
                actionTitle: navigationActionTitle,
                action: navigateToBestControlSurface
            )
        }

        if !releaseSummary.canRestoreActiveCheckpoint {
            return GuidedAction(
                title: "The active path is not restorable yet",
                detail: "Open the control surface and recover a checkpoint with a valid brain-state snapshot.",
                actionTitle: navigationActionTitle,
                action: navigateToBestControlSurface
            )
        }

        return nil
    }

    private var navigationActionTitle: String {
        if showControlCenterShortcut {
            return "Open control center"
        }

        if showHistoryShortcut {
            return "Open History"
        }

        if showPortraitShortcut {
            return "Open Portrait"
        }

        return "Open control surface"
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Evolution pilot controls")
                        .font(.headline)
                    Text(
                        interactionMode.allowsMutations
                            ? "Work the review queue, restore the active checkpoint, and clear stale lineage from the dedicated mutation hub."
                            : "See release blockers and queue state here, then jump into Evolution Control for checkpoint mutations."
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                        presentationMode: interactionMode.allowsMutations ? .mutationHub : .surface
                    )
                } else {
                    HStack(spacing: 8) {
                        DecisionEvolutionSummaryBadge(
                            title: "\(controlSurface.pendingReviewCount) PENDING",
                            tint: controlSurface.pendingReviewCount > 0 ? .orange : .secondary
                        )
                        DecisionEvolutionSummaryBadge(
                            title: "\(controlSurface.rollbackReadyCount) ROLLBACK READY",
                            tint: controlSurface.rollbackReadyCount > 0 ? BeforeTheme.moss : .secondary
                        )

                        if pendingReviewLineageCount > 0 {
                            DecisionEvolutionSummaryBadge(
                                title: "\(pendingReviewLineageCount) LINEAGE-BACKED",
                                tint: BeforeTheme.ember
                            )
                        }
                    }
                }

                DecisionEvolutionPilotImpactStripView(intents: pilotMutationIntents)

                if let guidedAction {
                    guidedActionCallout(guidedAction)
                }

                if !interactionMode.allowsMutations {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(interactionMode.operatorHeadline)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BeforeTheme.ember)
                        Text(interactionMode.operatorDetail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if pendingReviewLineageCount > 0, releaseSummary != nil {
                    Text("\(pendingReviewLineageCount) pending checkpoints still carry recovered lineage.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if interactionMode.allowsMutations {
                    HStack(spacing: 10) {
                        BeforeActionButton(
                            "Restore active path",
                            style: .primary,
                            isEnabled: controlSurface.activePresentation?.applyReady == true
                        ) {
                            guard let checkpointID = controlSurface.activePresentation?.checkpointID else { return }
                            if let intent = DecisionEvolutionMutationIntentFactory.restoreActiveCheckpoint(
                                controlSurface: controlSurface
                            ) {
                                pendingMutation = PendingMutation(intent: intent) {
                                    appModel.applyEvolutionCheckpoint(checkpointID: checkpointID)
                                    afterMutation?()
                                }
                            }
                        }

                        BeforeActionButton(
                            "Rollback active path",
                            style: .secondary,
                            isEnabled: controlSurface.canRollbackActiveCheckpoint
                        ) {
                            if let intent = DecisionEvolutionMutationIntentFactory.rollbackActiveCheckpoint(
                                controlSurface: controlSurface
                            ) {
                                pendingMutation = PendingMutation(intent: intent) {
                                    appModel.rollbackActiveEvolutionCheckpoint(
                                        to: intent.preview.targetCheckpointIDs.first
                                    )
                                    afterMutation?()
                                }
                            }
                        }

                        BeforeActionButton(
                            "Approve review queue",
                            style: .secondary,
                            isEnabled: controlSurface.pendingReviewCount > 0
                        ) {
                            if let intent = DecisionEvolutionMutationIntentFactory.approvePendingCheckpoints(
                                controlSurface: controlSurface
                            ) {
                                pendingMutation = PendingMutation(intent: intent) {
                                    appModel.approvePendingEvolutionCheckpoints(
                                        checkpointIDs: intent.preview.targetCheckpointIDs
                                    )
                                    afterMutation?()
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        BeforeActionButton(
                            "Clear queue lineage",
                            style: .secondary,
                            isEnabled: pendingReviewLineageCount > 0
                        ) {
                            if let intent = DecisionEvolutionMutationIntentFactory.clearPendingReviewLineage(
                                controlSurface: controlSurface
                            ) {
                                pendingMutation = PendingMutation(intent: intent) {
                                    appModel.clearPendingEvolutionCheckpointLineages(
                                        checkpointIDs: intent.preview.targetCheckpointIDs
                                    )
                                    afterMutation?()
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    if showControlCenterShortcut {
                        BeforeActionButton(
                            interactionMode.allowsMutations ? "Control center" : "Open control center",
                            style: interactionMode.allowsMutations ? .tertiary : .primary
                        ) {
                            appModel.presentEvolutionControlCenter()
                        }
                    }

                    if showHistoryShortcut {
                        BeforeActionButton("Open History", style: .tertiary) {
                            appModel.selectedTab = .history
                        }
                    }

                    if showPortraitShortcut {
                        BeforeActionButton("Open Portrait", style: .tertiary) {
                            appModel.selectedTab = .portrait
                        }
                    }
                }

                if !controlSurface.reviewAuditFindings.isEmpty {
                    Text("Review audit: \(controlSurface.reviewAuditFindings.joined(separator: " • "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !controlSurface.reviewKillSwitches.isEmpty {
                    Text("Suggested kill switches: \(controlSurface.reviewKillSwitches.joined(separator: " • "))")
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
    private func guidedActionCallout(_ guidedAction: GuidedAction) -> some View {
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
                guidedAction.action()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BeforeTheme.ember.opacity(0.08))
        )
    }

    private func navigateToBestControlSurface() {
        if showControlCenterShortcut {
            appModel.presentEvolutionControlCenter()
        } else if showHistoryShortcut {
            appModel.selectedTab = .history
        } else if showPortraitShortcut {
            appModel.selectedTab = .portrait
        }
    }

}
