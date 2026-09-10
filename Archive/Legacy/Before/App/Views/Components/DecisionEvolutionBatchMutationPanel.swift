import SwiftUI

struct DecisionEvolutionBatchMutationPanel: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var pendingMutation: PendingMutation?

    let selection: DecisionEvolutionBatchMutationSelection
    let surfaceContract: DecisionEvolutionSurfaceContract
    let showsHeader: Bool
    let selectAllVisible: () -> Void
    let selectReviewQueue: () -> Void
    let selectAutomatic: () -> Void
    let selectLineageBacked: () -> Void
    let clearSelection: () -> Void
    let afterMutation: (() -> Void)?

    private struct PendingMutation: Identifiable {
        let id = UUID()
        let intent: DecisionEvolutionMutationIntent
        let perform: () -> Void
    }

    init(
        selection: DecisionEvolutionBatchMutationSelection,
        surfaceContract: DecisionEvolutionSurfaceContract,
        showsHeader: Bool = true,
        selectAllVisible: @escaping () -> Void,
        selectReviewQueue: @escaping () -> Void,
        selectAutomatic: @escaping () -> Void,
        selectLineageBacked: @escaping () -> Void,
        clearSelection: @escaping () -> Void,
        afterMutation: (() -> Void)? = nil
    ) {
        self.selection = selection
        self.surfaceContract = surfaceContract
        self.showsHeader = showsHeader
        self.selectAllVisible = selectAllVisible
        self.selectReviewQueue = selectReviewQueue
        self.selectAutomatic = selectAutomatic
        self.selectLineageBacked = selectLineageBacked
        self.clearSelection = clearSelection
        self.afterMutation = afterMutation
    }

    private var presentation: DecisionEvolutionBatchMutationPresentation {
        DecisionEvolutionBatchMutationPresentationSupport.build(
            surfaceContract: surfaceContract
        )
    }

    private var selectionPresentation: DecisionEvolutionBatchMutationSelectionPresentation {
        DecisionEvolutionBatchMutationSelectionPresentationSupport.build(
            selection: selection,
            targetsPrefix: presentation.targetsPrefix
        )
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                if showsHeader {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(presentation.headerTitle)
                            .font(.headline)
                        Text(presentation.headerDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let outcome = appModel.latestEvolutionMutationOutcome,
                   outcome.affectsSelection(selection.selectedCheckpointIDs) {
                    DecisionEvolutionMutationOutcomeView(
                        outcome: outcome,
                        onDismiss: appModel.dismissEvolutionMutationOutcome
                    )
                }

                HStack(spacing: 8) {
                    selectorButton(presentation.selectAllTitle, action: selectAllVisible, isEnabled: !selection.selectablePresentations.isEmpty)
                    selectorButton(presentation.reviewQueueTitle, action: selectReviewQueue, isEnabled: !selection.reviewQueueCheckpointIDs.isEmpty)
                }

                HStack(spacing: 8) {
                    selectorButton(presentation.automaticTitle, action: selectAutomatic, isEnabled: !selection.automaticCheckpointIDs.isEmpty)
                    selectorButton(presentation.lineageBackedTitle, action: selectLineageBacked, isEnabled: !selection.lineageCheckpointIDs.isEmpty)
                    selectorButton(presentation.clearSelectionTitle, action: clearSelection, isEnabled: selection.hasSelection, style: .tertiary)
                }

                Text(selectionPresentation.summaryLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectionPresentation.usesAccentTone ? BeforeTheme.ember : .secondary)

                if let targetsLine = selectionPresentation.targetsLine {
                    Text(targetsLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if surfaceContract.allowsMutations {
                    if selection.hasSelection {
                        mutationButtons
                    } else if let emptySelectionLine = presentation.emptySelectionLine {
                        Text(emptySelectionLine)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if let readOnlyHeadline = presentation.readOnlyHeadline,
                          let readOnlyDetail = presentation.readOnlyDetail {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(readOnlyHeadline)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BeforeTheme.ember)
                        Text(readOnlyDetail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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

    @ViewBuilder
    private var mutationButtons: some View {
        let singleApplyPresentation = selection.selectedRestorablePresentation
        let approveIntent = selection.approveSelectedIntent
        let markReviewIntent = selection.markSelectedForReviewIntent
        let clearLineageIntent = selection.clearSelectedLineageIntent

        if singleApplyPresentation != nil || approveIntent != nil || markReviewIntent != nil {
            HStack(spacing: 10) {
                if let singleApplyPresentation {
                    BeforeActionButton(presentation.applySelectedTitle, style: .primary) {
                        if let intent = DecisionEvolutionMutationIntentFactory.applyCheckpoint(
                            checkpointID: singleApplyPresentation.checkpointID,
                            controlSurface: selection.controlSurface,
                            presentation: singleApplyPresentation
                        ) {
                            pendingMutation = PendingMutation(intent: intent) {
                                appModel.performEvolutionMutation(intent)
                                clearSelection()
                                afterMutation?()
                            }
                        }
                    }
                }

                if let approveIntent {
                    BeforeActionButton(presentation.approveSelectedTitle, style: .secondary) {
                        pendingMutation = PendingMutation(intent: approveIntent) {
                            appModel.performEvolutionMutation(approveIntent)
                            clearSelection()
                            afterMutation?()
                        }
                    }
                }

                if let markReviewIntent {
                    BeforeActionButton(presentation.markSelectedTitle, style: .secondary) {
                        pendingMutation = PendingMutation(intent: markReviewIntent) {
                            appModel.performEvolutionMutation(markReviewIntent)
                            clearSelection()
                            afterMutation?()
                        }
                    }
                }
            }
        }

        if let clearLineageIntent {
            HStack(spacing: 10) {
                BeforeActionButton(presentation.clearSelectedLineageTitle, style: .tertiary) {
                    pendingMutation = PendingMutation(intent: clearLineageIntent) {
                        appModel.performEvolutionMutation(clearLineageIntent)
                        clearSelection()
                        afterMutation?()
                    }
                }
            }
        }
    }

    private func selectorButton(
        _ title: String,
        action: @escaping () -> Void,
        isEnabled: Bool,
        style: BeforeActionButton.Style = .secondary
    ) -> some View {
        BeforeActionButton(title, style: style, isEnabled: isEnabled) {
            action()
        }
    }
}

private extension DecisionEvolutionMutationOutcome {
    func affectsSelection(_ checkpointIDs: Set<String>) -> Bool {
        guard !checkpointIDs.isEmpty else { return false }
        return !checkpointIDs.intersection(affectedCheckpointIDs).isEmpty
    }
}
