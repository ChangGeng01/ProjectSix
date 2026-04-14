import SwiftUI

struct DecisionEvolutionCheckpointActionBar: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var pendingMutation: PendingMutation?

    let checkpointID: String
    let checkpointPresentation: DecisionEvolutionCheckpointPresentation?
    let controlSurface: DecisionEvolutionControlSurface
    let surfaceContract: DecisionEvolutionSurfaceContract
    let applyReady: Bool
    let approvalState: DecisionEvolutionApprovalState?
    let hasLineage: Bool
    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
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
        surfaceContract: DecisionEvolutionSurfaceContract,
        applyReady: Bool,
        approvalState: DecisionEvolutionApprovalState?,
        hasLineage: Bool,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions? = nil,
        afterMutation: (() -> Void)? = nil
    ) {
        self.checkpointID = checkpointID
        self.checkpointPresentation = checkpointPresentation
        self.controlSurface = controlSurface
        self.surfaceContract = surfaceContract
        self.applyReady = applyReady
        self.approvalState = approvalState
        self.hasLineage = hasLineage
        self.navigationOptions = navigationOptions ?? surfaceContract.navigationSurfaceOptions()
        self.afterMutation = afterMutation
    }

    private var interactionMode: DecisionEvolutionControlInteractionMode {
        surfaceContract.interactionMode
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

            if surfaceContract.allowsMutations {
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
                DecisionEvolutionOperatorActionFooterView(
                    interactionMode: interactionMode,
                    navigationOptions: navigationOptions,
                    routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
                    showsDetail: true,
                    controlCenterStyle: .primary,
                    adjacentShortcutStyle: .secondary
                )
            }

            if surfaceContract.allowsMutations && navigationOptions.showsAnyShortcut {
                DecisionEvolutionNavigationActionRow(
                    navigationOptions: navigationOptions,
                    routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
                    controlCenterStyle: surfaceContract.allowsMutations ? .secondary : .primary,
                    adjacentShortcutStyle: .secondary
                )
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
