import SwiftUI

struct DecisionEvolutionCheckpointActionBar: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var pendingMutation: PendingMutation?

    let checkpointID: String
    let checkpointPresentation: DecisionEvolutionCheckpointPresentation?
    let controlSurface: DecisionEvolutionControlSurface
    let interactionMode: DecisionEvolutionControlInteractionMode
    let applyReady: Bool
    let approvalState: DecisionEvolutionApprovalState?
    let hasLineage: Bool
    let showControlCenterShortcut: Bool
    let showHistoryShortcut: Bool
    let showPortraitShortcut: Bool
    let afterMutation: (() -> Void)?

    private struct PendingMutation: Identifiable {
        let id = UUID()
        let intent: DecisionEvolutionMutationIntent
        let perform: () -> Void
    }

    init(
        checkpointID: String,
        checkpointPresentation: DecisionEvolutionCheckpointPresentation? = nil,
        controlSurface: DecisionEvolutionControlSurface,
        interactionMode: DecisionEvolutionControlInteractionMode = .mutationHub,
        applyReady: Bool,
        approvalState: DecisionEvolutionApprovalState?,
        hasLineage: Bool,
        showControlCenterShortcut: Bool = false,
        showHistoryShortcut: Bool = false,
        showPortraitShortcut: Bool = false,
        afterMutation: (() -> Void)? = nil
    ) {
        self.checkpointID = checkpointID
        self.checkpointPresentation = checkpointPresentation
        self.controlSurface = controlSurface
        self.interactionMode = interactionMode
        self.applyReady = applyReady
        self.approvalState = approvalState
        self.hasLineage = hasLineage
        self.showControlCenterShortcut = showControlCenterShortcut
        self.showHistoryShortcut = showHistoryShortcut
        self.showPortraitShortcut = showPortraitShortcut
        self.afterMutation = afterMutation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let outcome = appModel.latestEvolutionMutationOutcome,
               outcome.affects(checkpointID: checkpointID) {
                DecisionEvolutionMutationOutcomeView(
                    outcome: outcome,
                    onDismiss: appModel.dismissEvolutionMutationOutcome
                )
            }

            if interactionMode.allowsMutations {
                HStack(spacing: 10) {
                    if applyReady {
                        BeforeActionButton("Apply checkpoint", style: .primary) {
                            if let intent = DecisionEvolutionMutationIntentFactory.applyCheckpoint(
                                checkpointID: checkpointID,
                                controlSurface: controlSurface,
                                presentation: checkpointPresentation
                            ) {
                                pendingMutation = PendingMutation(intent: intent) {
                                    appModel.applyEvolutionCheckpoint(checkpointID: checkpointID)
                                    afterMutation?()
                                }
                            }
                        }
                    }

                    if approvalState == .reviewSuggested {
                        BeforeActionButton("Approve checkpoint", style: .secondary) {
                            if let intent = DecisionEvolutionMutationIntentFactory.approveCheckpoint(
                                checkpointID: checkpointID,
                                controlSurface: controlSurface,
                                presentation: checkpointPresentation
                            ) {
                                pendingMutation = PendingMutation(intent: intent) {
                                    appModel.approveEvolutionCheckpoint(checkpointID: checkpointID)
                                    afterMutation?()
                                }
                            }
                        }
                    } else {
                        BeforeActionButton("Mark checkpoint", style: .secondary) {
                            if let intent = DecisionEvolutionMutationIntentFactory.markCheckpointForReview(
                                checkpointID: checkpointID,
                                controlSurface: controlSurface,
                                presentation: checkpointPresentation
                            ) {
                                pendingMutation = PendingMutation(intent: intent) {
                                    appModel.markEvolutionCheckpointForReview(checkpointID: checkpointID)
                                    afterMutation?()
                                }
                            }
                        }
                    }

                    if hasLineage {
                        BeforeActionButton("Clear checkpoint lineage", style: .tertiary) {
                            if let intent = DecisionEvolutionMutationIntentFactory.clearCheckpointLineage(
                                checkpointID: checkpointID,
                                controlSurface: controlSurface,
                                presentation: checkpointPresentation
                            ) {
                                pendingMutation = PendingMutation(intent: intent) {
                                    appModel.clearEvolutionCheckpointLineage(checkpointID: checkpointID)
                                    afterMutation?()
                                }
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(interactionMode.operatorHeadline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                    Text(interactionMode.operatorDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if showControlCenterShortcut || showHistoryShortcut || showPortraitShortcut {
                HStack(spacing: 10) {
                    if showControlCenterShortcut {
                        BeforeActionButton(
                            "Open control center",
                            style: interactionMode.allowsMutations ? .secondary : .primary
                        ) {
                            appModel.presentEvolutionControlCenter()
                        }
                    }

                    if showHistoryShortcut {
                        BeforeActionButton("Open History", style: .secondary) {
                            appModel.selectedTab = .history
                        }
                    }

                    if showPortraitShortcut {
                        BeforeActionButton("Open Portrait", style: .secondary) {
                            appModel.selectedTab = .portrait
                        }
                    }
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
}
