import SwiftUI

struct DecisionReplayLineageCardView: View {
    let entries: [DecisionEvolutionReplayEntryPresentation]
    var title: String = "Replay lineage"
    var emptyMessage: String = "No replay lineage has been captured yet."
    var entryLimit: Int = 3

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)

                if displayedEntries.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(displayedEntries.enumerated()), id: \.offset) { _, presentation in
                        DecisionReplayEntrySummaryView(
                            cardCopy: presentation.replayCardCopy,
                            presentation: presentation
                        ) {
                            DecisionReplayEntryHeaderRowView(
                                leadingText: presentation.modeTitle,
                                secondaryText: presentation.statusTitle,
                                trailingTimestamp: presentation.timestamp,
                                trailingTimestampStyle: .absoluteShort
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BeforeTheme.ember)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var displayedEntries: [DecisionEvolutionReplayEntryPresentation] {
        Array(entries.prefix(entryLimit))
    }
}
