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

    private var presentation: DecisionEvolutionCheckpointActionPresentation {
        DecisionEvolutionCheckpointActionPresentationSupport.build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            applyReady: applyReady,
            approvalState: approvalState,
            hasLineage: hasLineage
        )
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

            if presentation.showsMutationActions {
                HStack(spacing: 10) {
                    if presentation.showsApplyAction {
                        BeforeActionButton(presentation.applyTitle, style: .primary) {
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

                    if presentation.secondaryActionKind == .approve {
                        BeforeActionButton(presentation.approveTitle, style: .secondary) {
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
                    } else if presentation.secondaryActionKind == .markForReview {
                        BeforeActionButton(presentation.markTitle, style: .secondary) {
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

                    if presentation.showsClearLineageAction {
                        BeforeActionButton(presentation.clearLineageTitle, style: .tertiary) {
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
            } else if let footerPresentation = presentation.footerPresentation {
                DecisionEvolutionOperatorActionFooterView(presentation: footerPresentation)
            }

            if let navigationPresentation = presentation.navigationPresentation {
                DecisionEvolutionNavigationActionRow(presentation: navigationPresentation)
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
