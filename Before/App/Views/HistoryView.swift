import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \CheckEvent.createdAt, order: .reverse) private var events: [CheckEvent]
    @Query(sort: \BalanceDecisionRecord.updatedAt, order: .reverse) private var balanceBoards: [BalanceDecisionRecord]
    @Query(sort: \MirrorDecisionRecord.updatedAt, order: .reverse) private var mirrorRecords: [MirrorDecisionRecord]

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
                        LazyVStack(spacing: 14) {
                            ForEach(timelineItems) { item in
                                historyCard(for: item)
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
