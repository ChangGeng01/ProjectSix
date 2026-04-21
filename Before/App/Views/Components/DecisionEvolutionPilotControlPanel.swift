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
    let quickActionsAnchorID: DecisionEvolutionMutationHubFocusTarget?
    let queueLineageAnchorID: DecisionEvolutionMutationHubFocusTarget?
    let onFocusMutationHubTarget: ((DecisionEvolutionMutationHubFocusTarget) -> Void)?
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
        quickActionsAnchorID: DecisionEvolutionMutationHubFocusTarget? = nil,
        queueLineageAnchorID: DecisionEvolutionMutationHubFocusTarget? = nil,
        onFocusMutationHubTarget: ((DecisionEvolutionMutationHubFocusTarget) -> Void)? = nil,
        afterMutation: (() -> Void)? = nil
    ) {
        self.controlSurface = controlSurface
        self.releaseSummary = releaseSummary
        self.surfaceContract = surfaceContract
        self.showsHeader = showsHeader
        self.showEmbeddedReleaseSummary = showEmbeddedReleaseSummary
        let resolvedNavigationOptions = navigationOptions ?? surfaceContract.navigationSurfaceOptions()
        self.navigationOptions = resolvedNavigationOptions
        self.quickActionsAnchorID = quickActionsAnchorID
        self.queueLineageAnchorID = queueLineageAnchorID
        self.onFocusMutationHubTarget = onFocusMutationHubTarget
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

                if (releaseSummary == nil || showEmbeddedReleaseSummary == false),
                   let foldedLungTitle = pilotSnapshot.foldedLungTitle,
                   !pilotSnapshot.foldedLungLines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(foldedLungTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)

                        ForEach(pilotSnapshot.foldedLungLines, id: \.self) { line in
                            Text(line)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }

                DecisionEvolutionPilotImpactStripView(intents: pilotSnapshot.mutationIntents)

                if let guidedAction = pilotSnapshot.guidedAction {
                    guidedActionCallout(guidedAction)
                }

                if let furnaceWorkbenchSectionTitle = pilotSnapshot.furnaceWorkbenchSectionTitle,
                   let furnaceWorkbenchGuidance = pilotSnapshot.furnaceWorkbenchGuidance {
                    furnaceWorkbenchCallout(
                        sectionTitle: furnaceWorkbenchSectionTitle,
                        guidance: furnaceWorkbenchGuidance
                    )
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
                    .id(quickActionsAnchorID)

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
                    .id(queueLineageAnchorID)
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

    @ViewBuilder
    private func furnaceWorkbenchCallout(
        sectionTitle: String,
        guidance: DecisionEvolutionPilotFurnaceWorkbenchGuidance
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BeforeTheme.moss)

            Text(guidance.title)
                .font(.subheadline.bold())
                .foregroundStyle(BeforeTheme.ink)

            Text(guidance.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(guidance.availabilityTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        guidance.availabilityTitle == "Blocked"
                            ? BeforeTheme.ember
                            : BeforeTheme.moss
                    )

                ForEach(Array(guidance.availabilityLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let runNowActionTitle = guidance.runNowActionTitle,
               let runNowIntent = guidance.runNowIntent {
                HStack(spacing: 10) {
                    BeforeActionButton(runNowActionTitle, style: .primary) {
                        presentMutation(runNowIntent)
                    }

                    BeforeActionButton(
                        guidance.actionTitle,
                        style: .secondary,
                        isEnabled: onFocusMutationHubTarget != nil
                    ) {
                        onFocusMutationHubTarget?(guidance.focusTarget)
                    }
                }
            } else {
                BeforeActionButton(
                    guidance.actionTitle,
                    style: .secondary,
                    isEnabled: onFocusMutationHubTarget != nil
                ) {
                    onFocusMutationHubTarget?(guidance.focusTarget)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BeforeTheme.moss.opacity(0.08))
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
