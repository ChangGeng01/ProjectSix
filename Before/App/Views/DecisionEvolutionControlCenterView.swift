import SwiftData
import SwiftUI

struct DecisionEvolutionControlCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: BeforeAppModel
    @Query(sort: \DecisionEvolutionCheckpoint.createdAt, order: .reverse)
    private var evolutionCheckpoints: [DecisionEvolutionCheckpoint]

    @State private var systemFlightDeck: DecisionSystemFlightDeck?
    @State private var isRefreshing = false
    @State private var selectedCheckpointIDs = Set<String>()
    private let evolutionSurfaceContract = DecisionEvolutionSurfaceContract.controlCenter

    private var evolutionSurfaceState: DecisionEvolutionSurfaceState {
        appModel.makeEvolutionSurfaceState(
            contract: evolutionSurfaceContract,
            flightDeck: systemFlightDeck,
            historyCheckpoints: evolutionTrailItems
        )
    }

    private var controlSurface: DecisionEvolutionControlSurface {
        evolutionSurfaceState.controlSurface
    }

    private var evolutionTrailItems: [DecisionEvolutionCheckpoint] {
        evolutionCheckpoints
            .evolutionTrailCheckpoints()
    }

    private var workspaceSnapshot: DecisionEvolutionWorkspaceSnapshot {
        evolutionSurfaceState.workspace
    }

    private var selectablePresentations: [DecisionEvolutionCheckpointPresentation] {
        DecisionEvolutionBatchMutationSelection.orderedSelectablePresentations(
            activePresentation: workspaceSnapshot.activePresentation,
            reviewPresentation: workspaceSnapshot.reviewPresentation,
            remainingReviewQueue: workspaceSnapshot.remainingReviewQueue,
            historyPresentations: workspaceSnapshot.historyPresentations
        )
    }

    private var batchMutationSelection: DecisionEvolutionBatchMutationSelection {
        DecisionEvolutionBatchMutationSelection(
            controlSurface: controlSurface,
            selectablePresentations: selectablePresentations,
            selectedCheckpointIDs: selectedCheckpointIDs
        )
    }

    private var operatorSnapshot: DecisionEvolutionOperatorSnapshot {
        evolutionSurfaceState.operatorSnapshot
    }

    private var checkpointNavigationOptions: DecisionEvolutionNavigationSurfaceOptions {
        evolutionSurfaceContract.checkpointNavigationOptions
    }

    private var controlCenterNavigationPresentation: DecisionEvolutionNavigationRowPresentation {
        DecisionEvolutionNavigationRowPresentationSupport.controlCenterCompanion(
            surfaceContract: evolutionSurfaceContract,
            navigationOptions: evolutionSurfaceContract.navigationSurfaceOptions(
                showHistoryShortcut: true,
                showPortraitShortcut: true
            )
        )
    }

    private var operatorSummaryPresentation: DecisionEvolutionOperatorSummaryPresentation {
        operatorSnapshot.summaryPresentation
    }

    private var headerPresentation: DecisionEvolutionControlCenterHeaderPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenterHeader()
    }

    private var releaseReadinessSection: DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenter(.releaseReadiness)
    }

    private var killSwitchSection: DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenter(.killSwitchControlPlane)
    }

    private var mutationHubSection: DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenter(.operatorMutationHub)
    }

    private var checkpointSpotlightSection: DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenter(.checkpointSpotlight)
    }

    private var activeWorkspaceSection: DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenter(.activeCheckpointWorkspace)
    }

    private var reviewHeadSection: DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenter(.reviewHeadWorkspace)
    }

    private var pendingQueueSection: DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenter(.pendingReviewQueue)
    }

    private var recoveredHistorySection: DecisionEvolutionSectionPresentation {
        DecisionEvolutionSectionPresentationSupport.controlCenter(.recoveredCheckpointHistory)
    }

    private var activeCheckpointRolePresentation: DecisionEvolutionCheckpointRolePresentation {
        DecisionEvolutionSectionPresentationSupport.checkpointRole(.active)
    }

    private var reviewHeadRolePresentation: DecisionEvolutionCheckpointRolePresentation {
        DecisionEvolutionSectionPresentationSupport.checkpointRole(.reviewHead)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(headerPresentation.title)
                                    .font(.title3.bold())
                                Text(headerPresentation.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                BeforeActionButton(headerPresentation.refreshTitle, style: .secondary) {
                                    Task {
                                        await refreshFlightDeck()
                                    }
                                }
                            }
                        }

                        DecisionEvolutionNavigationActionRow(
                            presentation: controlCenterNavigationPresentation
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(operatorSummaryPresentation.headline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ink)

                            if let primaryReason = operatorSummaryPresentation.primaryReason {
                                Text(primaryReason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(operatorSummaryPresentation.modeLine)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)

                            Text(operatorSummaryPresentation.countsLine)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let killSwitchesLine = operatorSummaryPresentation.killSwitchesLine {
                                Text(killSwitchesLine)
                                    .font(.caption2)
                                    .foregroundStyle(BeforeTheme.ember)
                            }
                        }
                    }
                }

                workspaceSection(
                    presentation: releaseReadinessSection
                ) {
                    if let releaseSummary = workspaceSnapshot.releaseSummary {
                        DecisionEvolutionReleaseSummaryView(
                            releaseSummary: releaseSummary,
                            controlSurface: controlSurface,
                            surfaceContract: evolutionSurfaceContract,
                            presentationMode: evolutionSurfaceContract.releaseSummaryMode,
                            navigationOptions: checkpointNavigationOptions,
                            afterMutation: {
                                Task {
                                    await refreshFlightDeck()
                                }
                            }
                        )
                    } else {
                        Text(releaseReadinessSection.emptyMessage ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                workspaceSection(
                    presentation: killSwitchSection
                ) {
                    DecisionEvolutionKillSwitchPanelView(
                        activeKillSwitches: appModel.activeEvolutionKillSwitches,
                        recommendedKillSwitchIDs: workspaceSnapshot.effectiveRecommendedKillSwitches,
                        surfaceContract: evolutionSurfaceContract,
                        navigationOptions: checkpointNavigationOptions,
                        afterMutation: {
                            Task {
                                await refreshFlightDeck()
                            }
                        }
                    )
                }

                workspaceSection(
                    presentation: mutationHubSection
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        DecisionEvolutionPilotControlPanel(
                            controlSurface: controlSurface,
                            releaseSummary: workspaceSnapshot.releaseSummary,
                            surfaceContract: evolutionSurfaceContract,
                            showsHeader: false,
                            showEmbeddedReleaseSummary: false,
                            navigationOptions: checkpointNavigationOptions,
                            afterMutation: {
                                Task {
                                    await refreshFlightDeck()
                                }
                            }
                        )

                        DecisionEvolutionBatchMutationPanel(
                            selection: batchMutationSelection,
                            surfaceContract: evolutionSurfaceContract,
                            showsHeader: false,
                            selectAllVisible: selectAllVisibleCheckpoints,
                            selectReviewQueue: selectReviewQueueCheckpoints,
                            selectAutomatic: selectAutomaticCheckpoints,
                            selectLineageBacked: selectLineageBackedCheckpoints,
                            clearSelection: clearSelectedCheckpoints,
                            afterMutation: {
                                Task {
                                    await refreshFlightDeck()
                                }
                            }
                        )
                    }
                }

                workspaceSection(
                    presentation: checkpointSpotlightSection
                ) {
                    DecisionEvolutionControlSurfaceSummaryView(
                        controlSurface: controlSurface,
                        surfaceContract: evolutionSurfaceContract,
                        emptyMessage: DecisionEvolutionSurfaceStatusPresentationSupport.summaryEmptyMessage(
                            for: .controlCenter
                        )
                            ?? checkpointSpotlightSection.emptyMessage
                            ?? DecisionEvolutionCheckpointDetailPresentationSupport.emptyLineageMessage,
                        navigationOptions: checkpointNavigationOptions,
                        afterMutation: {
                            Task {
                                await refreshFlightDeck()
                            }
                        }
                    )
                }

                if let activePresentation = workspaceSnapshot.activePresentation {
                    workspaceSection(
                        presentation: activeWorkspaceSection
                    ) {
                        DecisionEvolutionCheckpointPanelView(
                            title: activeCheckpointRolePresentation.title,
                            checkpoint: activePresentation,
                            controlSurface: controlSurface,
                            surfaceContract: evolutionSurfaceContract,
                            navigationOptions: checkpointNavigationOptions,
                            isSelected: batchMutationSelection.contains(activePresentation.checkpointID),
                            onToggleSelection: {
                                toggleCheckpointSelection(activePresentation.checkpointID)
                            },
                            afterMutation: {
                                Task {
                                    await refreshFlightDeck()
                                }
                            }
                        )
                    }
                }

                if let reviewPresentation = workspaceSnapshot.reviewPresentation {
                    workspaceSection(
                        presentation: reviewHeadSection
                    ) {
                        DecisionEvolutionCheckpointPanelView(
                            title: reviewHeadRolePresentation.title,
                            checkpoint: reviewPresentation,
                            controlSurface: controlSurface,
                            surfaceContract: evolutionSurfaceContract,
                            navigationOptions: checkpointNavigationOptions,
                            isSelected: batchMutationSelection.contains(reviewPresentation.checkpointID),
                            onToggleSelection: {
                                toggleCheckpointSelection(reviewPresentation.checkpointID)
                            },
                            afterMutation: {
                                Task {
                                    await refreshFlightDeck()
                                }
                            }
                        )
                    }
                }

                if !workspaceSnapshot.remainingReviewQueue.isEmpty {
                    workspaceSection(
                        presentation: pendingQueueSection
                    ) {
                        ForEach(workspaceSnapshot.remainingReviewQueue) { checkpoint in
                            DecisionEvolutionCheckpointPanelView(
                                checkpoint: checkpoint,
                                controlSurface: controlSurface,
                                surfaceContract: evolutionSurfaceContract,
                                navigationOptions: checkpointNavigationOptions,
                                isSelected: batchMutationSelection.contains(checkpoint.checkpointID),
                                onToggleSelection: {
                                    toggleCheckpointSelection(checkpoint.checkpointID)
                                },
                                afterMutation: {
                                    Task {
                                        await refreshFlightDeck()
                                    }
                                }
                            )
                        }
                    }
                }

                if !workspaceSnapshot.historyPresentations.isEmpty {
                    workspaceSection(
                        presentation: recoveredHistorySection
                    ) {
                        ForEach(workspaceSnapshot.historyPresentations) { checkpoint in
                            DecisionEvolutionCheckpointPanelView(
                                checkpoint: checkpoint,
                                controlSurface: controlSurface,
                                surfaceContract: evolutionSurfaceContract,
                                navigationOptions: checkpointNavigationOptions,
                                isSelected: batchMutationSelection.contains(checkpoint.checkpointID),
                                onToggleSelection: {
                                    toggleCheckpointSelection(checkpoint.checkpointID)
                                },
                                afterMutation: {
                                    Task {
                                        await refreshFlightDeck()
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(BeforeTheme.background.ignoresSafeArea())
        .navigationTitle(headerPresentation.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(headerPresentation.dismissTitle) {
                    appModel.dismissEvolutionControlCenter()
                    dismiss()
                }
            }
        }
        .task {
            await refreshFlightDeck()
        }
        .onChange(of: appModel.evolutionControlMutationEpoch) { _, _ in
            Task {
                await refreshFlightDeck()
            }
        }
    }

    private func refreshFlightDeck() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        systemFlightDeck = await appModel.systemFlightDeck()
        pruneSelectedCheckpointIDs()
    }

    private func toggleCheckpointSelection(_ checkpointID: String) {
        if selectedCheckpointIDs.contains(checkpointID) {
            selectedCheckpointIDs.remove(checkpointID)
        } else {
            selectedCheckpointIDs.insert(checkpointID)
        }
        pruneSelectedCheckpointIDs()
    }

    private func selectAllVisibleCheckpoints() {
        selectedCheckpointIDs = batchMutationSelection.selectableCheckpointIDs
    }

    private func selectReviewQueueCheckpoints() {
        selectedCheckpointIDs = batchMutationSelection.reviewQueueCheckpointIDs
    }

    private func selectAutomaticCheckpoints() {
        selectedCheckpointIDs = batchMutationSelection.automaticCheckpointIDs
    }

    private func selectLineageBackedCheckpoints() {
        selectedCheckpointIDs = batchMutationSelection.lineageCheckpointIDs
    }

    private func clearSelectedCheckpoints() {
        selectedCheckpointIDs.removeAll()
    }

    private func pruneSelectedCheckpointIDs() {
        selectedCheckpointIDs = selectedCheckpointIDs.intersection(batchMutationSelection.selectableCheckpointIDs)
    }

    @ViewBuilder
    private func workspaceSection<Content: View>(
        presentation: DecisionEvolutionSectionPresentation,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.title)
                .font(.headline)
                .foregroundStyle(BeforeTheme.ink)

            Text(presentation.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content()
        }
    }
}
