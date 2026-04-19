import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Query(sort: \TomorrowBoxItem.createdAt, order: .reverse) private var tomorrowItems: [TomorrowBoxItem]
    @State private var decisionPrompt = ""
    @State private var systemFlightDeck: DecisionSystemFlightDeck?
    @State private var isLoadingSystemFlightDeck = false
    private let evolutionSurfaceContract = DecisionEvolutionSurfaceContract.home

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var evolutionSurfaceState: DecisionEvolutionSurfaceState {
        appModel.makeEvolutionSurfaceState(
            contract: evolutionSurfaceContract,
            flightDeck: systemFlightDeck
        )
    }

    private var currentEvolutionControlSurface: DecisionEvolutionControlSurface {
        evolutionSurfaceState.controlSurface
    }

    private var currentEvolutionWorkspace: DecisionEvolutionWorkspaceSnapshot {
        evolutionSurfaceState.workspace
    }

    private var currentEvolutionSpotlightSet: DecisionEvolutionSpotlightSet {
        currentEvolutionWorkspace.spotlightSet
    }

    private var currentEvolutionAttentionSignal: DecisionEvolutionAttentionSignal {
        evolutionSurfaceState.attentionSignal
    }

    private var sessionEnginePresentation: DecisionSessionEnginePresentation {
        systemFlightDeck.sessionEnginePresentationOrUnattached
    }

    private var checkpointNavigationOptions: DecisionEvolutionNavigationSurfaceOptions {
        evolutionSurfaceContract.checkpointNavigationOptions
    }

    private var runtimeRecoveryNavigationPresentation: DecisionEvolutionNavigationRowPresentation {
        DecisionEvolutionNavigationRowPresentationSupport.readFirstSurface(
            surfaceContract: evolutionSurfaceContract,
            navigationOptions: evolutionSurfaceContract.navigationSurfaceOptions(
                showHistoryShortcut: true,
                showPortraitShortcut: true
            )
        )
    }

    private var runtimeDetachedNavigationPresentation: DecisionEvolutionNavigationRowPresentation {
        DecisionEvolutionNavigationRowPresentationSupport.readFirstSurface(
            surfaceContract: evolutionSurfaceContract,
            navigationOptions: evolutionSurfaceContract.navigationSurfaceOptions(
                showPortraitShortcut: true
            )
        )
    }

    private var queueNavigationPresentation: DecisionEvolutionNavigationRowPresentation {
        DecisionEvolutionNavigationRowPresentationSupport.readFirstSurface(
            surfaceContract: evolutionSurfaceContract,
            navigationOptions: evolutionSurfaceContract.navigationSurfaceOptions()
        )
    }

    private var shouldAutoRefreshSystemFlightDeck: Bool {
        !DecisionTestingInterface.runtimeTestingContextDetected()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let startupNotice = appModel.startupNotice {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Recovery mode", systemImage: "exclamationmark.triangle.fill")
                                        .font(.headline)
                                        .foregroundStyle(BeforeTheme.ember)
                                    Text(startupNotice)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Button("Dismiss") {
                                        appModel.dismissStartupNotice()
                                    }
                                    .font(.headline)
                                }
                            }
                        }

                        SectionHeader(
                            eyebrow: "Decision OS",
                            title: "Help me see this clearly.",
                            subtitle: "Quick calls, trade-offs, and heavier questions can all start from one clean entry."
                        )

                        GuidedInputCard(
                            title: "What are you deciding?",
                            subtitle: "Write it once. Before will start at the right depth.",
                            placeholder: "Buy this? Go there? Reply now? Stay or leave?",
                            accessibilityIdentifier: "home.prompt.input",
                            text: $decisionPrompt
                        )

                        if let preview = homePromptPreview {
                            DecisionRoutePreviewCard(
                                mode: preview.mode,
                                title: preview.title,
                                detail: preview.detail,
                                isPinned: preview.isPinned
                            )
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("13-layer runtime")
                                            .font(.headline)
                                        Text("The active electronic-brain path is now part of the main shell, not just diagnostics.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if isLoadingSystemFlightDeck {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else if let deck = systemFlightDeck {
                                        Text(deck.overallHealth.title)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(healthColor(deck.overallHealth))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(healthColor(deck.overallHealth).opacity(0.12))
                                            )
                                    }
                                }

                                if let deck = systemFlightDeck,
                                   let digest = deck.eBrainDigestPresentation {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(digest.digest.compactStatusLine)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BeforeTheme.ember)

                                        Text(digest.digest.taskTitle)
                                            .font(.title3.bold())
                                            .foregroundStyle(BeforeTheme.ink)

                                        ForEach(Array(digest.summaryLines.enumerated()), id: \.offset) { index, line in
                                            Text(line)
                                                .font(index == 0 ? .caption : .caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        if !digest.layerStackLines.isEmpty {
                                            DecisionLayerStackView(
                                                lines: digest.layerStackLines,
                                                spacing: 4
                                            )
                                        }

                                        if let runtimeStatusPresentation = currentEvolutionWorkspace.runtimeStatusPresentation(
                                            attentionSignal: currentEvolutionAttentionSignal
                                        ) {
                                            if let headline = runtimeStatusPresentation.headline {
                                                Text(headline)
                                                    .font(
                                                        runtimeStatusPresentation.usesAttentionAccent
                                                        ? .caption2.weight(.semibold)
                                                        : .caption2
                                                    )
                                                    .foregroundStyle(
                                                        runtimeStatusPresentation.usesAttentionAccent
                                                        ? BeforeTheme.ember
                                                        : .secondary
                                                    )
                                            }

                                            if let detail = runtimeStatusPresentation.detail {
                                                Text(detail)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }

                                        if let localModelOverviewLine = deck.localModelLibrarySummary?.overviewLine {
                                            Text(localModelOverviewLine)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }

                                        if let alertLine = digest.alertLine {
                                            Text(alertLine)
                                                .font(.caption2)
                                                .foregroundStyle(BeforeTheme.ember)
                                        }

                                        DecisionEvolutionReleaseSummaryView(
                                            releaseSummary: deck.releaseControlSummary,
                                            controlSurface: deck.evolutionControlSurface,
                                            surfaceContract: evolutionSurfaceContract,
                                            presentationMode: evolutionSurfaceContract.releaseSummaryMode,
                                            navigationOptions: checkpointNavigationOptions,
                                            afterMutation: {
                                                Task {
                                                    await refreshSystemFlightDeck()
                                                }
                                            }
                                        )
                                    }

                                    if let activeCheckpoint = currentEvolutionWorkspace.activePresentation {
                                        DecisionEvolutionCheckpointActionBar(
                                            checkpointID: activeCheckpoint.checkpointID,
                                            checkpointPresentation: activeCheckpoint,
                                            controlSurface: currentEvolutionControlSurface,
                                            surfaceContract: evolutionSurfaceContract,
                                            applyReady: activeCheckpoint.applyReady,
                                            approvalState: activeCheckpoint.approvalState,
                                            hasLineage: activeCheckpoint.hasLineage,
                                            navigationOptions: checkpointNavigationOptions,
                                            afterMutation: {
                                                Task {
                                                    await refreshSystemFlightDeck()
                                                }
                                            }
                                        )
                                    } else if let reviewCheckpoint = currentEvolutionWorkspace.reviewPresentation {
                                        if let reviewHeadLine = currentEvolutionWorkspace.reviewHeadWithoutActiveCheckpointLine {
                                            Text(reviewHeadLine)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        DecisionEvolutionCheckpointActionBar(
                                            checkpointID: reviewCheckpoint.checkpointID,
                                            checkpointPresentation: reviewCheckpoint,
                                            controlSurface: currentEvolutionControlSurface,
                                            surfaceContract: evolutionSurfaceContract,
                                            applyReady: reviewCheckpoint.applyReady,
                                            approvalState: reviewCheckpoint.approvalState,
                                            hasLineage: reviewCheckpoint.hasLineage,
                                            navigationOptions: checkpointNavigationOptions,
                                            afterMutation: {
                                                Task {
                                                    await refreshSystemFlightDeck()
                                                }
                                            }
                                        )
                                    } else {
                                        HStack(spacing: 10) {
                                            DecisionEvolutionNavigationActionRow(
                                                presentation: runtimeRecoveryNavigationPresentation
                                            )

                                            BeforeActionButton("Refresh runtime", style: .secondary) {
                                                Task {
                                                    await refreshSystemFlightDeck()
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    Text("No live 13-layer turn is attached yet. Open a decision flow or refresh the runtime card.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 10) {
                                        DecisionEvolutionNavigationActionRow(
                                            presentation: runtimeDetachedNavigationPresentation
                                        )

                                        BeforeActionButton("Refresh runtime", style: .secondary) {
                                            Task {
                                                await refreshSystemFlightDeck()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        PanelCard {
                            DecisionSessionEngineSurfaceView(
                                presentation: sessionEnginePresentation,
                                showsTitle: true,
                                maxRecentSessions: 1,
                                correctionPlaceholder: "Describe the correction you want to branch from the active recovery line.",
                                correctionReason: "home session engine correction branch"
                            )
                        }

                        if let deck = systemFlightDeck {
                            DecisionEvolutionPilotControlPanel(
                                controlSurface: deck.evolutionControlSurface,
                                releaseSummary: deck.releaseControlSummary,
                                surfaceContract: evolutionSurfaceContract,
                                showEmbeddedReleaseSummary: evolutionSurfaceContract.showsEmbeddedReleaseSummaryInPilotPanel,
                                navigationOptions: checkpointNavigationOptions,
                                afterMutation: {
                                    Task {
                                        await refreshSystemFlightDeck()
                                    }
                                }
                            )
                        }

                        if let homeQueuePresentation {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(homeQueuePresentation.title)
                                                .font(.headline)
                                            Text(homeQueuePresentation.detail)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(homeQueuePresentation.queuedBadgeTitle)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.orange.opacity(0.12))
                                            )
                                    }

                                    if let countsLine = homeQueuePresentation.countsLine {
                                        Text(countsLine)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    ForEach(homePendingReviewPresentations) { checkpoint in
                                        DecisionEvolutionCheckpointPanelView(
                                            checkpoint: checkpoint,
                                            controlSurface: currentEvolutionControlSurface,
                                            surfaceContract: evolutionSurfaceContract,
                                            navigationOptions: checkpointNavigationOptions,
                                            afterMutation: {
                                                Task {
                                                    await refreshSystemFlightDeck()
                                                }
                                            }
                                        )
                                    }

                                    DecisionEvolutionNavigationActionRow(
                                        presentation: queueNavigationPresentation
                                    )
                                }
                            }
                        }

                        if let candidate = appModel.interventionCandidate {
                            PanelCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Label("Predictive pause", systemImage: "waveform.path.ecg")
                                        .font(.headline)
                                        .foregroundStyle(BeforeTheme.ember)

                                    Text(candidate.title)
                                        .font(.title3.bold())
                                        .foregroundStyle(BeforeTheme.ink)

                                    Text(candidate.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text(candidate.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 10) {
                                        BeforeActionButton("Use this pause") {
                                            appModel.applyInterventionCandidate(candidate)
                                        }

                                        BeforeActionButton("Not now", style: .secondary) {
                                            appModel.dismissInterventionCandidate()
                                        }
                                    }
                                }
                            }
                        }

                        PanelCard {
                            StarterPromptRow(
                                title: "Need a cleaner starting point?",
                                suggestions: DecisionStarterLibrary.homeFeatured
                            ) { suggestion in
                                appModel.startDecisionMode(suggestion.mode, entrySource: .app, prompt: suggestion.prompt)
                            }
                        }

                        BeforeActionButton(
                            appModel.preferences.homePromptAction.buttonTitle,
                            isEnabled: !trimmedPrompt.isEmpty,
                            accessibilityIdentifier: "home.prompt.submit"
                        ) {
                            _ = appModel.submitHomePrompt(trimmedPrompt, entrySource: .app)
                            decisionPrompt = ""
                        }
                        .disabled(trimmedPrompt.isEmpty)

                        VStack(spacing: 14) {
                            ForEach(DecisionMode.allCases) { mode in
                                DecisionModeCard(
                                    mode: mode,
                                    accessibilityIdentifier: "home.mode.\(mode.rawValue)"
                                ) {
                                    appModel.startDecisionMode(mode, entrySource: .app, prompt: trimmedPrompt)
                                    decisionPrompt = ""
                                }
                            }
                        }

                        SectionHeader(
                            eyebrow: "Quick surfaces",
                            title: "Named impulses still stay one tap away.",
                            subtitle: "When the shape is obvious, open the fast mode directly."
                        )

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(ScenarioType.allCases) { scenario in
                                Button {
                                    appModel.startQuickCheck(entrySource: .app, scenario: scenario)
                                } label: {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Image(systemName: scenario.symbolName)
                                            .font(.title2.weight(.bold))
                                            .foregroundStyle(BeforeTheme.ember)
                                        Text(scenario.title)
                                            .font(.headline)
                                            .foregroundStyle(BeforeTheme.ink)
                                        Text(scenario.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
                                    .padding(18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                                            .fill(.white.opacity(0.72))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Recent signal")
                                    .font(.headline)

                                if let signal = appModel.latestSignal() {
                                    Text(signal.eyebrow.uppercased())
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                    Text(signal.title)
                                        .font(.title3.bold())
                                        .foregroundStyle(BeforeTheme.ink)
                                        .lineLimit(3)
                                    Text(signal.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(4)
                                } else {
                                    Text("Your first judgment, balance board, or mirror will start building signal here.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Need distance, not denial?")
                                    .font(.headline)
                                Text("Move it into Tomorrow Box when the call matters, but not from peak blur.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if tomorrowBoxCount > 0 {
                                    Text("\(tomorrowBoxCount) \(tomorrowBoxCount == 1 ? "item is" : "items are") waiting for a clearer read.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                }

                                BeforeActionButton("Open Tomorrow Box", style: .secondary) {
                                    appModel.selectedTab = .box
                                }
                            }
                        }

                        PanelCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Need another perspective?")
                                    .font(.headline)
                                Text("Buddy keeps it personal. Shared Life keeps recurring household decisions from resetting every time.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if supportPendingCount > 0 || sharedLifePendingCount > 0 {
                                    Text("\(supportPendingCount) buddy \(supportPendingCount == 1 ? "thread" : "threads"), \(sharedLifePendingCount) shared \(sharedLifePendingCount == 1 ? "item" : "items") still active.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BeforeTheme.ember)
                                }

                                BeforeActionButton("Open Support Space", style: .secondary) {
                                    appModel.supportSurface = .buddy
                                    appModel.selectedTab = .support
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Before")
            .task {
                guard shouldAutoRefreshSystemFlightDeck else { return }
                await refreshSystemFlightDeck()
            }
            .onChange(of: appModel.selectedTab) { _, newValue in
                guard shouldAutoRefreshSystemFlightDeck, newValue == .home else { return }
                Task {
                    await refreshSystemFlightDeck()
                }
            }
            .onChange(of: appModel.evolutionControlMutationEpoch) { _, _ in
                guard shouldAutoRefreshSystemFlightDeck else { return }
                Task {
                    await refreshSystemFlightDeck()
                }
            }
        }
    }

    private var trimmedPrompt: String {
        decisionPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var homePromptPreview: HomePromptPreview? {
        guard !trimmedPrompt.isEmpty else { return nil }

        if let preferredMode = appModel.preferences.homePromptAction.preferredMode {
            return HomePromptPreview(
                mode: preferredMode,
                title: "This prompt will open in \(preferredMode.title).",
                detail: "Your home prompt preference is pinned to \(preferredMode.title.lowercased()). You can still open a different mode below when you want to.",
                isPinned: true
            )
        }

        let routed = DecisionIntelligenceCoordinator.route(
            prompt: trimmedPrompt,
            preferences: appModel.preferences
        )
        return HomePromptPreview(
            mode: routed.mode,
            title: "This looks like a \(routed.mode.title.lowercased()) question.",
            detail: routed.reason,
            isPinned: false
        )
    }

    private var tomorrowBoxCount: Int {
        tomorrowItems.count
    }

    private var supportPendingCount: Int {
        appModel.supportInbox.activeRequests.count
    }

    private var homeQueuePresentation: DecisionEvolutionHomeQueuePresentation? {
        guard currentEvolutionWorkspace.totalPendingReviewCount > 0 else {
            return nil
        }
        return DecisionEvolutionHomeQueuePresentationSupport.build(
            totalPendingReviewCount: currentEvolutionWorkspace.totalPendingReviewCount,
            spotlightedPendingReviewCount: currentEvolutionWorkspace.spotlightedPendingReviewCount,
            queuedPendingReviewCount: currentEvolutionWorkspace.queuedPendingReviewCount
        )
    }

    private var homePendingReviewPresentations: [DecisionEvolutionCheckpointPresentation] {
        Array(currentEvolutionSpotlightSet.remainingReviewQueue.prefix(3))
    }

    private var sharedLifePendingCount: Int {
        appModel.sharedLifeStore.pendingItems.count
    }

    private func healthColor(_ health: DecisionSystemLayerHealth) -> Color {
        switch health {
        case .strong:
            BeforeTheme.ember
        case .watch:
            .orange
        case .critical:
            .red
        }
    }

    @MainActor
    private func refreshSystemFlightDeck() async {
        guard shouldAutoRefreshSystemFlightDeck else {
            isLoadingSystemFlightDeck = false
            systemFlightDeck = nil
            return
        }
        isLoadingSystemFlightDeck = true
        systemFlightDeck = await appModel.systemFlightDeck()
        isLoadingSystemFlightDeck = false
    }
}

private struct HomePromptPreview {
    let mode: DecisionMode
    let title: String
    let detail: String
    let isPinned: Bool
}
