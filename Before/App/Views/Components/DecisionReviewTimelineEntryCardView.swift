import SwiftUI

struct DecisionReviewTimelineEntryCardView: View {
    let summary: DecisionReviewTimelineEntryPresentation
    let presentation: DecisionEvolutionReplayEntryPresentation?
    let action: () -> Void

    private var replayCardCopy: DecisionReviewReplayCardCopy {
        summary.replayCardCopy(replayPresentation: presentation)
    }

    var body: some View {
        Button(action: action) {
            PanelCard {
                DecisionReplayEntrySummaryView(
                    cardCopy: replayCardCopy,
                    presentation: presentation
                ) {
                    DecisionReplayEntryHeaderRowView(
                        labelTitle: summary.labelTitle,
                        labelSymbolName: summary.labelSymbolName,
                        trailingAccentText: summary.headerAccentText,
                        trailingAccentStyle: headerAccentStyle
                    )
                } footer: {
                    DecisionReplayEntryFooterRowView(
                        timestamp: summary.timestamp,
                        accentText: summary.footerAccentText
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var headerAccentStyle: DecisionReplayEntryHeaderRowView.AccentStyle {
        switch summary.headerAccentStyle {
        case .capsule:
            .pill
        case .accent:
            .text(BeforeTheme.moss)
        }
    }
}
