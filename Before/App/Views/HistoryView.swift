import SwiftData
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Query(sort: \CheckEvent.createdAt, order: .reverse) private var events: [CheckEvent]
    @Query(sort: \BalanceDecisionRecord.updatedAt, order: .reverse) private var balanceBoards: [BalanceDecisionRecord]
    @Query(sort: \MirrorDecisionRecord.updatedAt, order: .reverse) private var mirrorRecords: [MirrorDecisionRecord]
    @Query(sort: \DecisionEvolutionCheckpoint.createdAt, order: .reverse) private var evolutionCheckpoints: [DecisionEvolutionCheckpoint]
    @Query(sort: \TomorrowBoxItem.createdAt, order: .reverse) private var tomorrowItems: [TomorrowBoxItem]
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedDetail: HistoryDetailSelection?
    @State private var selectedProfile: ReviewProfileSelection?
    @State private var systemFlightDeck: DecisionSystemFlightDeck?
    @State private var isRefreshingSystemFlightDeck = false
    private let evolutionSurfaceContract = DecisionEvolutionSurfaceContract.history

    var body: some View {
        let evolutionWorkspace = currentEvolutionWorkspace

        NavigationStack {
            ZStack {
                BeforeBackground()

                if timelineItems.isEmpty {
                    ContentUnavailableView(
                        "No saved decisions yet",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("Quick calls, balance boards, and mirrors will all stay readable here.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(
                                eyebrow: "Review",
                                title: "Patterns beat raw logs.",
                                subtitle: "The useful part is not every entry. It is what keeps repeating."
                            )

                            if appModel.preferences.showReviewInsights && !summaryCards.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(summaryCards) { summary in
                                            summaryCard(for: summary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }

                            if appModel.preferences.showReviewInsights && !insights.isEmpty {
                                VStack(spacing: 12) {
                                    ForEach(insights) { insight in
                                        insightCard(for: insight)
                                    }
                                }
                            }

                            if !evolutionTrailItems.isEmpty {
                                evolutionTrailSection(evolutionWorkspace)
                            }

                            Picker("History filter", selection: $selectedFilter) {
                                ForEach(HistoryFilter.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)

                            if filteredTimelineItems.isEmpty {
                                PanelCard {
                                    Text("No saved items match this view yet.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                LazyVStack(spacing: 14) {
                                    ForEach(filteredTimelineItems) { item in
                                        historyCard(for: item)
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedDetail) { selection in
                HistoryDetailView(selection: selection)
                    .environmentObject(appModel)
            }
            .sheet(item: $selectedProfile) { selection in
                if let profile = profile(for: selection) {
                    ReviewProfileView(
                        profile: profile,
                        recentEntries: recentEntries(for: selection)
                    )
                    .environmentObject(appModel)
                }
            }
            .task {
                await refreshSystemFlightDeck()
            }
            .onChange(of: appModel.evolutionControlMutationEpoch) { _, _ in
                Task {
                    await refreshSystemFlightDeck()
                }
            }
        }
    }

    private var currentEvolutionWorkspace: DecisionEvolutionWorkspaceSnapshot {
        DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: systemFlightDeck?.evolutionControlSurface ?? appModel.makeEvolutionControlSurface(),
            releaseSummary: systemFlightDeck?.releaseControlSummary,
            historyPresentations: evolutionTrailPresentations
        )
    }

    private var timelineItems: [HistoryTimelineItem] {
        let quickItems = events.map { HistoryTimelineItem(date: $0.createdAt, content: .quick($0)) }
        let balanceItems = balanceBoards.map { HistoryTimelineItem(date: $0.updatedAt, content: .balance($0)) }
        let mirrorItems = mirrorRecords.map { HistoryTimelineItem(date: $0.updatedAt, content: .mirror($0)) }
        return (quickItems + balanceItems + mirrorItems).sorted { $0.date > $1.date }
    }

    private var filteredTimelineItems: [HistoryTimelineItem] {
        timelineItems.filter { selectedFilter.matches($0.content) }
    }

    private var summaryCards: [ReviewModeSummary] {
        DecisionReviewEngine.summaries(
            quick: events,
            balance: balanceBoards,
            mirror: mirrorRecords
        )
    }

    private var insights: [ReviewInsight] {
        DecisionReviewEngine.insights(
            quick: events,
            balance: balanceBoards,
            mirror: mirrorRecords,
            tomorrowCount: tomorrowItems.count
        )
    }

    private var evolutionTrailItems: [DecisionEvolutionCheckpoint] {
        evolutionCheckpoints.filter { $0.lineageSummary != nil || !$0.diffSummary.isEmpty }
    }

    private var evolutionTrailPresentations: [DecisionEvolutionCheckpointPresentation] {
        evolutionTrailItems.map(\.presentation)
    }

    private func evolutionTrailSection(
        _ workspace: DecisionEvolutionWorkspaceSnapshot
    ) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                eyebrow: "Evolution",
                title: "Evolution control center",
                subtitle: "Checkpoint lineage, risk permits, review state, rollback readiness, and queue operations now stay visible in one full workspace."
            )

            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Evolution trail")
                                .font(.headline)
                                .foregroundStyle(BeforeTheme.ink)
                            Text("\(evolutionTrailItems.count) checkpoints • \(workspace.controlSurface.pendingReviewCount) pending review • \(workspace.controlSurface.rollbackReadyCount) rollback-ready")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                            HStack(spacing: 10) {
                                if isRefreshingSystemFlightDeck {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                BeforeActionButton("Refresh", style: .secondary) {
                                    Task {
                                        await refreshSystemFlightDeck()
                                    }
                                    }
                                }

                                BeforeActionButton("Open control center", style: .primary) {
                                    appModel.presentEvolutionControlCenter()
                                }

                                BeforeActionButton("Open Portrait", style: .secondary) {
                                    appModel.selectedTab = .portrait
                                }
                            }
                    }

                    if let releaseSummary = workspace.releaseSummary {
                        DecisionEvolutionReleaseSummaryView(
                            releaseSummary: releaseSummary,
                            controlSurface: workspace.controlSurface,
                            presentationMode: evolutionSurfaceContract.releaseSummaryMode
                        )
                    }

                    DecisionEvolutionControlSurfaceSummaryView(
                        controlSurface: workspace.controlSurface,
                        emptyMessage: "No persisted checkpoint lineage is available yet. Once a checkpoint lands, this summary will show its risk, permit, tickets, audit, and rollback readiness.",
                        interactionMode: evolutionSurfaceContract.interactionMode,
                        showControlCenterShortcut: true,
                        showPortraitShortcut: true,
                        afterMutation: {
                            Task {
                                await refreshSystemFlightDeck()
                            }
                        }
                    )
                }
            }

            DecisionEvolutionPilotControlPanel(
                controlSurface: workspace.controlSurface,
                releaseSummary: workspace.releaseSummary,
                interactionMode: evolutionSurfaceContract.interactionMode,
                showEmbeddedReleaseSummary: evolutionSurfaceContract.showsEmbeddedReleaseSummaryInPilotPanel,
                showPortraitShortcut: true,
                showControlCenterShortcut: true,
                afterMutation: {
                    Task {
                        await refreshSystemFlightDeck()
                    }
                }
            )

            if let activePresentation = workspace.activePresentation {
                DecisionEvolutionCheckpointPanelView(
                    title: "Active checkpoint",
                    checkpoint: activePresentation,
                    controlSurface: workspace.controlSurface,
                    interactionMode: evolutionSurfaceContract.interactionMode,
                    showControlCenterShortcut: true,
                    showPortraitShortcut: true,
                    afterMutation: {
                        Task {
                            await refreshSystemFlightDeck()
                        }
                    }
                )
            }

            if let reviewPresentation = workspace.reviewPresentation {
                DecisionEvolutionCheckpointPanelView(
                    title: "Review head",
                    checkpoint: reviewPresentation,
                    controlSurface: workspace.controlSurface,
                    interactionMode: evolutionSurfaceContract.interactionMode,
                    showControlCenterShortcut: true,
                    showPortraitShortcut: true,
                    afterMutation: {
                        Task {
                            await refreshSystemFlightDeck()
                        }
                    }
                )
            }

            if !workspace.remainingReviewQueue.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pending review queue")
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)

                    Text("Every remaining review-suggested checkpoint stays operable here, not just the queue head.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(workspace.remainingReviewQueue) { checkpoint in
                        DecisionEvolutionCheckpointPanelView(
                            checkpoint: checkpoint,
                            controlSurface: workspace.controlSurface,
                            interactionMode: evolutionSurfaceContract.interactionMode,
                            showControlCenterShortcut: true,
                            showPortraitShortcut: true,
                            afterMutation: {
                                Task {
                                    await refreshSystemFlightDeck()
                                }
                            }
                        )
                    }
                }
            }

            if !workspace.historyPresentations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Checkpoint history")
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)

                    Text("The full recovered trail stays browseable here even after the active/review spotlight changes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(workspace.historyPresentations) { checkpoint in
                        DecisionEvolutionCheckpointPanelView(
                            checkpoint: checkpoint,
                            controlSurface: workspace.controlSurface,
                            interactionMode: evolutionSurfaceContract.interactionMode,
                            showControlCenterShortcut: true,
                            showPortraitShortcut: true,
                            afterMutation: {
                                Task {
                                    await refreshSystemFlightDeck()
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func refreshSystemFlightDeck() async {
        guard !isRefreshingSystemFlightDeck else { return }
        isRefreshingSystemFlightDeck = true
        defer { isRefreshingSystemFlightDeck = false }
        systemFlightDeck = await appModel.systemFlightDeck()
    }

    @ViewBuilder
    private func historyCard(for item: HistoryTimelineItem) -> some View {
        switch item.content {
        case .quick(let event):
            Button {
                selectedDetail = .quick(event)
            } label: {
                PanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(event.scenario.title, systemImage: event.scenario.symbolName)
                            Spacer()
                            Text(event.verdict.title)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(BeforeTheme.ember.opacity(0.18))
                                )
                        }

                        Text(event.currentPerspective)
                            .font(.headline)
                            .foregroundStyle(BeforeTheme.ink)

                        Text(event.afterPerspective)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(event.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let reflection = event.reflectionOutcome {
                                Text(reflection.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(BeforeTheme.moss)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

        case .balance(let board):
            Button {
                selectedDetail = .balance(board)
            } label: {
                PanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Balance board", systemImage: DecisionMode.balance.symbolName)
                            Spacer()
                            Text(board.focusTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.moss)
                        }

                        Text(board.prompt)
                            .font(.headline)
                            .foregroundStyle(BeforeTheme.ink)

                        Text(board.focusSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(board.nextAction)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BeforeTheme.ember)

                        Text(board.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

        case .mirror(let record):
            Button {
                selectedDetail = .mirror(record)
            } label: {
                PanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Mirror", systemImage: DecisionMode.mirror.symbolName)
                            Spacer()
                            Text(record.nextActionTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BeforeTheme.moss)
                        }

                        Text(record.prompt)
                            .font(.headline)
                            .foregroundStyle(BeforeTheme.ink)

                        Text(record.coreTension)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(record.nextAction)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BeforeTheme.ember)

                        Text(record.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func summaryCard(for summary: ReviewModeSummary) -> some View {
        Button {
            selectedProfile = profileSelection(for: summary.mode)
        } label: {
            PanelCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(summary.title, systemImage: summary.mode.symbolName)
                            .font(.headline)
                        Spacer()
                        Text("\(summary.count)")
                            .font(.title3.bold())
                            .foregroundStyle(BeforeTheme.ember)
                    }

                    Text(summary.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 220, alignment: .leading)
                }
            }
            .frame(width: 270)
        }
        .buttonStyle(.plain)
    }

    private func insightCard(for insight: ReviewInsight) -> some View {
        PanelCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: insight.symbolName)
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ember)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text(insight.eyebrow.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(BeforeTheme.ember)
                    Text(insight.title)
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)
                    Text(insight.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func profileSelection(for mode: DecisionMode) -> ReviewProfileSelection {
        switch mode {
        case .quick: .quick
        case .balance: .balance
        case .mirror: .mirror
        }
    }

    private func profile(for selection: ReviewProfileSelection) -> ReviewProfile? {
        switch selection {
        case .quick:
            DecisionReviewEngine.profile(for: .quick, quick: events, balance: balanceBoards, mirror: mirrorRecords)
        case .balance:
            DecisionReviewEngine.profile(for: .balance, quick: events, balance: balanceBoards, mirror: mirrorRecords)
        case .mirror:
            DecisionReviewEngine.profile(for: .mirror, quick: events, balance: balanceBoards, mirror: mirrorRecords)
        }
    }

    private func recentEntries(for selection: ReviewProfileSelection) -> [ReviewProfileEntry] {
        switch selection {
        case .quick:
            DecisionReviewEngine.recentEntries(for: .quick, quick: events, balance: balanceBoards, mirror: mirrorRecords)
        case .balance:
            DecisionReviewEngine.recentEntries(for: .balance, quick: events, balance: balanceBoards, mirror: mirrorRecords)
        case .mirror:
            DecisionReviewEngine.recentEntries(for: .mirror, quick: events, balance: balanceBoards, mirror: mirrorRecords)
        }
    }

}

private enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case quick
    case balance
    case mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .quick: "Quick"
        case .balance: "Balance"
        case .mirror: "Mirror"
        }
    }

    func matches(_ content: HistoryTimelineItem.Content) -> Bool {
        switch (self, content) {
        case (.all, _):
            true
        case (.quick, .quick):
            true
        case (.balance, .balance):
            true
        case (.mirror, .mirror):
            true
        default:
            false
        }
    }
}

private struct HistoryTimelineItem: Identifiable {
    enum Content {
        case quick(CheckEvent)
        case balance(BalanceDecisionRecord)
        case mirror(MirrorDecisionRecord)
    }

    let date: Date
    let content: Content

    var id: String {
        switch content {
        case .quick(let event):
            "quick-\(event.id.uuidString)"
        case .balance(let record):
            "balance-\(record.id.uuidString)"
        case .mirror(let record):
            "mirror-\(record.id.uuidString)"
        }
    }
}

private struct EvolutionTrailBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
            )
    }
}
