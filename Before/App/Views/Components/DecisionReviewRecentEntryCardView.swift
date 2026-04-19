import SwiftUI

struct DecisionReviewRecentEntryCardView: View {
    let summary: DecisionReviewRecentEntryPresentation
    let presentation: DecisionEvolutionReplayEntryPresentation?
    let selectAction: () -> Void
    let reopenAction: () -> Void
    let postponeAction: () -> Void

    private var replayCardCopy: DecisionReviewReplayCardCopy {
        summary.replayCardCopy(replayPresentation: presentation)
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: selectAction) {
                    DecisionReplayEntrySummaryView(
                        cardCopy: replayCardCopy,
                        presentation: presentation
                    ) {
                        DecisionReplayEntryHeaderRowView(
                            labelTitle: summary.labelTitle,
                            labelSymbolName: summary.labelSymbolName,
                            trailingTimestamp: summary.timestamp,
                            trailingTimestampStyle: .relative
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                    } footer: {
                        DecisionReplayEntryFooterRowView(accentText: summary.footerText)
                    }
                }
                .buttonStyle(.plain)

                DecisionContinuationActions(
                    reopenTitle: summary.reopenTitle,
                    reopenStyle: .secondary,
                    postponeTitle: summary.postponeTitle,
                    postponeStyle: .secondary,
                    reopenAction: reopenAction,
                    postponeAction: postponeAction
                )
            }
        }
    }
}
