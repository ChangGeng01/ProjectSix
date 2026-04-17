import SwiftUI

struct DecisionReviewTimelineEntryCardView: View {
    let summary: DecisionReviewTimelineEntryPresentation
    let presentation: DecisionEvolutionReplayEntryPresentation?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PanelCard {
                DecisionReplayEntrySummaryView(
                    title: summary.title,
                    secondaryLine: summary.secondaryLine,
                    presentation: presentation
                ) {
                    DecisionReplayEntryHeaderRowView(
                        labelTitle: summary.labelTitle,
                        labelSymbolName: summary.labelSymbolName,
                        trailingAccentText: summary.headerAccentText,
                        trailingAccentStyle: headerAccentStyle
                    )
                } supplementary: {
                    if let supplementaryLine = summary.supplementaryLine {
                        Text(supplementaryLine)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BeforeTheme.ember)
                    }
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
