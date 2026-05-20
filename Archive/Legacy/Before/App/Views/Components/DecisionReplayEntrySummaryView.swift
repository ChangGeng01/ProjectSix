import SwiftUI

struct DecisionReplayEntrySummaryView<Header: View, Supplementary: View, Footer: View>: View {
    let cardCopy: DecisionEvolutionReplayCardCopy
    let presentation: DecisionEvolutionReplayEntryPresentation?
    let showsDiagnostics: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let supplementary: () -> Supplementary
    @ViewBuilder let footer: () -> Footer

    init(
        cardCopy: DecisionEvolutionReplayCardCopy,
        presentation: DecisionEvolutionReplayEntryPresentation?,
        showsDiagnostics: Bool = true,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder supplementary: @escaping () -> Supplementary = { EmptyView() },
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.cardCopy = cardCopy
        self.presentation = presentation
        self.showsDiagnostics = showsDiagnostics
        self.header = header
        self.supplementary = supplementary
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header()

            if let digestHeadlineLine = presentation?.digestHeadlineLine {
                Text(digestHeadlineLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ember)
                    .multilineTextAlignment(.leading)
            }

            Text(cardCopy.titleLine)
                .font(.headline)
                .foregroundStyle(BeforeTheme.ink)
                .multilineTextAlignment(.leading)

            if let secondaryLine = cardCopy.secondaryLine {
                Text(secondaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            if let supplementaryLine = cardCopy.supplementaryLine {
                Text(supplementaryLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BeforeTheme.ember)
                    .multilineTextAlignment(.leading)
            }

            supplementary()

            if showsDiagnostics {
                DecisionReplayDiagnosticsBlockView(
                    presentation: presentation,
                    layout: .compact
                )
                .padding(.top, 2)
            }

            footer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
