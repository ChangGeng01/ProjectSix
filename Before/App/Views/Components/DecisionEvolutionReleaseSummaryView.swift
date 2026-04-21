import SwiftUI

struct DecisionEvolutionReleaseSummaryPresentation: Equatable, Sendable {
    let state: DecisionSystemReleaseState
    let stateTone: DecisionEvolutionSummaryBadgeTone
    let badgePresentations: [DecisionEvolutionSummaryBadgePresentation]
    let pendingReviewCount: Int
    let rollbackReadyCount: Int
    let headline: String
    let primaryReason: String?
    let sovereignPostureTitle: String?
    let sovereignPostureLines: [String]
    let horizonDiagnosticsTitle: String?
    let horizonDiagnosticsLines: [String]
    let foldedLungTitle: String?
    let foldedLungLines: [String]
    let furnaceContributionTitle: String?
    let furnaceContributionLines: [String]
    let furnaceChecklistTitle: String?
    let furnaceChecklistLines: [String]
    let furnaceNextStepTitle: String?
    let furnaceNextStepDetail: String?
    let furnaceWorkbenchPresentation: DecisionEvolutionFurnaceWorkbenchPresentation?
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
    let onFocusMutationHub: ((DecisionEvolutionMutationHubFocusTarget) -> Void)?
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
        onFocusMutationHub: ((DecisionEvolutionMutationHubFocusTarget) -> Void)? = nil,
        afterMutation: (() -> Void)? = nil
    ) {
        self.releaseSummary = releaseSummary
        self.controlSurface = controlSurface
        self.surfaceContract = surfaceContract
        self.presentationMode = presentationMode
        self.navigationOptions = navigationOptions ?? surfaceContract.navigationSurfaceOptions()
        self.onFocusMutationHub = onFocusMutationHub
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

    private var furnaceNextStepActionPresentation: DecisionEvolutionFurnaceNextStepActionPresentation? {
        DecisionEvolutionFurnaceNextStepActionSupport.build(
            detail: presentation.furnaceNextStepDetail,
            surfaceContract: surfaceContract
        )
    }

    private var furnaceWorkbenchRunNowActionPresentation: DecisionEvolutionFurnaceRunNowActionPresentation? {
        DecisionEvolutionFurnaceRunNowActionSupport.build(
            detail: presentation.furnaceWorkbenchPresentation?.detail,
            controlSurface: controlSurface,
            surfaceContract: surfaceContract
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

            if let sovereignPostureTitle = presentation.sovereignPostureTitle,
               !presentation.sovereignPostureLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sovereignPostureTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    ForEach(presentation.sovereignPostureLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

            if let horizonDiagnosticsTitle = presentation.horizonDiagnosticsTitle,
               !presentation.horizonDiagnosticsLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(horizonDiagnosticsTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ink)

                    ForEach(presentation.horizonDiagnosticsLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

            if let foldedLungTitle = presentation.foldedLungTitle,
               !presentation.foldedLungLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(foldedLungTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)

                    ForEach(presentation.foldedLungLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

            if let furnaceContributionTitle = presentation.furnaceContributionTitle,
               !presentation.furnaceContributionLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(furnaceContributionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.moss)

                    ForEach(presentation.furnaceContributionLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

            if let furnaceChecklistTitle = presentation.furnaceChecklistTitle,
               !presentation.furnaceChecklistLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(furnaceChecklistTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    ForEach(presentation.furnaceChecklistLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

            if let furnaceNextStepTitle = presentation.furnaceNextStepTitle,
               let furnaceNextStepDetail = presentation.furnaceNextStepDetail {
                VStack(alignment: .leading, spacing: 6) {
                    Text(furnaceNextStepTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)

                    Text(furnaceNextStepDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if let furnaceNextStepActionPresentation {
                        BeforeActionButton(
                            furnaceNextStepActionPresentation.actionTitle,
                            style: surfaceContract.routesMutationsToControlCenter ? .primary : .secondary
                        ) {
                            performFurnaceNextStepAction(furnaceNextStepActionPresentation)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BeforeTheme.ember.opacity(0.08))
                )
            }

            if let furnaceWorkbenchPresentation = presentation.furnaceWorkbenchPresentation {
                VStack(alignment: .leading, spacing: 6) {
                    Text(furnaceWorkbenchPresentation.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.moss)

                    Text(furnaceWorkbenchPresentation.headline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ink)

                    Text(furnaceWorkbenchPresentation.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    Text(furnaceWorkbenchPresentation.availabilityTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(furnaceWorkbenchPresentation.availabilityLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    if let furnaceWorkbenchRunNowActionPresentation {
                        HStack(spacing: 10) {
                            BeforeActionButton(
                                furnaceWorkbenchRunNowActionPresentation.actionTitle,
                                style: .primary
                            ) {
                                presentMutation(furnaceWorkbenchRunNowActionPresentation.intent)
                            }

                            if let furnaceNextStepActionPresentation {
                                BeforeActionButton(
                                    furnaceNextStepActionPresentation.actionTitle,
                                    style: .secondary
                                ) {
                                    performFurnaceNextStepAction(furnaceNextStepActionPresentation)
                                }
                            }
                        }
                    } else if let furnaceNextStepActionPresentation {
                        BeforeActionButton(
                            furnaceNextStepActionPresentation.actionTitle,
                            style: .secondary
                        ) {
                            performFurnaceNextStepAction(furnaceNextStepActionPresentation)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BeforeTheme.moss.opacity(0.08))
                )
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
                        presentMutation(rollbackIntent)
                    }
                }

                if let approveQueueIntent = actionPresentation.approveQueueIntent {
                    BeforeActionButton(actionPresentation.approveQueueTitle, style: .primary) {
                        presentMutation(approveQueueIntent)
                    }
                }
            }

            if let clearReviewLineageIntent = actionPresentation.clearReviewLineageIntent {
                HStack(spacing: 10) {
                    BeforeActionButton(actionPresentation.clearReviewLineageTitle, style: .tertiary) {
                        presentMutation(clearReviewLineageIntent)
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

    private func presentMutation(_ intent: DecisionEvolutionMutationIntent) {
        pendingMutation = PendingMutation(intent: intent) {
            appModel.performEvolutionMutation(intent)
            afterMutation?()
        }
    }

    private func performFurnaceNextStepAction(
        _ action: DecisionEvolutionFurnaceNextStepActionPresentation
    ) {
        switch action.kind {
        case .navigate(let destination):
            destination.perform(using: appModel)
        case .focusMutationHub(let focusTarget):
            onFocusMutationHub?(focusTarget)
        }
    }
}
