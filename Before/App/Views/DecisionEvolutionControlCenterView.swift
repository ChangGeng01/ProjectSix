import SwiftData
import SwiftUI

struct DecisionEvolutionControlCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: BeforeAppModel
    @Query(sort: \DecisionEvolutionCheckpoint.createdAt, order: .reverse)
    private var evolutionCheckpoints: [DecisionEvolutionCheckpoint]

    @State private var systemFlightDeck: DecisionSystemFlightDeck?
    @State private var isRefreshing = false
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

    private var operatorSnapshot: DecisionEvolutionOperatorSnapshot {
        evolutionSurfaceState.operatorSnapshot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Evolution control center")
                                    .font(.title3.bold())
                                Text("Operate the full L13 review path from one place: active checkpoint, review head, pending queue, release readiness, rollback, and persisted lineage.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                BeforeActionButton("Refresh", style: .secondary) {
                                    Task {
                                        await refreshFlightDeck()
                                    }
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            BeforeActionButton("Open History", style: .secondary) {
                                appModel.selectedTab = .history
                            }

                            BeforeActionButton("Open Portrait", style: .secondary) {
                                appModel.selectedTab = .portrait
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(operatorSnapshot.headline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ink)

                            if let primaryReason = operatorSnapshot.primaryReason {
                                Text(primaryReason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("\(operatorSnapshot.surfaceTitle) • \(operatorSnapshot.operatorHeadline)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BeforeTheme.ember)

                            Text("Active \(operatorSnapshot.activeCheckpointID ?? "none") • Review \(operatorSnapshot.reviewCheckpointID ?? "none") • Pending \(operatorSnapshot.pendingReviewCount) • Rollback-ready \(operatorSnapshot.rollbackReadyCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if !operatorSnapshot.killSwitches.isEmpty {
                                Text("Kill switches: \(operatorSnapshot.killSwitches.joined(separator: " • "))")
                                    .font(.caption2)
                                    .foregroundStyle(BeforeTheme.ember)
                            }
                        }
                    }
                }

                workspaceSection(
                    title: "Release readiness",
                    detail: "One summary strip for rollout state, blockers, rollback readiness, and kill-switch posture."
                ) {
                    if let releaseSummary = workspaceSnapshot.releaseSummary {
                        DecisionEvolutionReleaseSummaryView(
                            releaseSummary: releaseSummary,
                            controlSurface: controlSurface,
                            presentationMode: evolutionSurfaceContract.releaseSummaryMode
                        )
                    } else {
                        Text("Release readiness will appear here once a flight-deck summary is available.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                workspaceSection(
                    title: "Pilot mutations",
                    detail: "Operate queue-wide actions here before drilling into individual checkpoints."
                ) {
                    DecisionEvolutionPilotControlPanel(
                        controlSurface: controlSurface,
                        releaseSummary: workspaceSnapshot.releaseSummary,
                        interactionMode: evolutionSurfaceContract.interactionMode,
                        showEmbeddedReleaseSummary: evolutionSurfaceContract.showsEmbeddedReleaseSummaryInPilotPanel,
                        showControlCenterShortcut: false,
                        afterMutation: {
                            Task {
                                await refreshFlightDeck()
                            }
                        }
                    )
                }

                workspaceSection(
                    title: "Checkpoint spotlight",
                    detail: "Keep the current active checkpoint and review head visible even as the queue evolves."
                ) {
                    DecisionEvolutionControlSurfaceSummaryView(
                        controlSurface: controlSurface,
                        emptyMessage: "No persisted checkpoint lineage is available yet. Once a checkpoint lands, this control center will show active risk, permit, rollback and review facts.",
                        interactionMode: evolutionSurfaceContract.interactionMode,
                        showCheckpointActionBar: evolutionSurfaceContract.showsCheckpointActionBarInSummary,
                        afterMutation: {
                            Task {
                                await refreshFlightDeck()
                            }
                        }
                    )
                }

                if let activePresentation = workspaceSnapshot.activePresentation {
                    workspaceSection(
                        title: "Active checkpoint workspace",
                        detail: "Mutate the live active path without losing sight of restored lineage and rollback readiness."
                    ) {
                        DecisionEvolutionCheckpointPanelView(
                            title: "Active checkpoint",
                            checkpoint: activePresentation,
                            controlSurface: controlSurface,
                            interactionMode: evolutionSurfaceContract.interactionMode,
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
                        title: "Review head workspace",
                        detail: "Work the queue head directly without collapsing the rest of the pending review backlog."
                    ) {
                        DecisionEvolutionCheckpointPanelView(
                            title: "Review head",
                            checkpoint: reviewPresentation,
                            controlSurface: controlSurface,
                            interactionMode: evolutionSurfaceContract.interactionMode,
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
                        title: "Pending review queue",
                        detail: "The remaining review-suggested checkpoints stay operable here instead of being hidden behind the queue head."
                    ) {
                        ForEach(workspaceSnapshot.remainingReviewQueue) { checkpoint in
                            DecisionEvolutionCheckpointPanelView(
                                checkpoint: checkpoint,
                                controlSurface: controlSurface,
                                interactionMode: evolutionSurfaceContract.interactionMode,
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
                        title: "Recovered checkpoint history",
                        detail: "Recovered lineage history remains browseable here even after the active and review spotlight changes."
                    ) {
                        ForEach(workspaceSnapshot.historyPresentations) { checkpoint in
                            DecisionEvolutionCheckpointPanelView(
                                checkpoint: checkpoint,
                                controlSurface: controlSurface,
                                interactionMode: evolutionSurfaceContract.interactionMode,
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
        .navigationTitle("Evolution Control")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
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
    }

    @ViewBuilder
    private func workspaceSection<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(BeforeTheme.ink)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content()
        }
    }
}
