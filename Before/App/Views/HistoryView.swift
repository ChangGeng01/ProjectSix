import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \CheckEvent.createdAt, order: .reverse) private var events: [CheckEvent]
    @Query(sort: \BalanceDecisionRecord.updatedAt, order: .reverse) private var balanceBoards: [BalanceDecisionRecord]
    @Query(sort: \MirrorDecisionRecord.updatedAt, order: .reverse) private var mirrorRecords: [MirrorDecisionRecord]
    @Query(sort: \TomorrowBoxItem.createdAt, order: .reverse) private var tomorrowItems: [TomorrowBoxItem]
    @State private var selectedFilter: HistoryFilter = .all

    var body: some View {
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

                            if !summaryCards.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(summaryCards) { summary in
                                            summaryCard(for: summary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }

                            if !insights.isEmpty {
                                VStack(spacing: 12) {
                                    ForEach(insights) { insight in
                                        insightCard(for: insight)
                                    }
                                }
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
        }
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

    @ViewBuilder
    private func historyCard(for item: HistoryTimelineItem) -> some View {
        switch item.content {
        case .quick(let event):
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

        case .balance(let board):
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

        case .mirror(let record):
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
    }

    private func summaryCard(for summary: ReviewModeSummary) -> some View {
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
