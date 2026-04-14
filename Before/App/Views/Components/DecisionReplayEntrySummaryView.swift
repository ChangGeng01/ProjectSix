import SwiftUI

struct DecisionReplayEntrySummaryView<Header: View, Supplementary: View, Footer: View>: View {
    let title: String
    let secondaryLine: String?
    let presentation: DecisionEvolutionReplayEntryPresentation?
    @ViewBuilder let header: () -> Header
    @ViewBuilder let supplementary: () -> Supplementary
    @ViewBuilder let footer: () -> Footer

    init(
        title: String,
        secondaryLine: String? = nil,
        presentation: DecisionEvolutionReplayEntryPresentation?,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder supplementary: @escaping () -> Supplementary = { EmptyView() },
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.secondaryLine = secondaryLine
        self.presentation = presentation
        self.header = header
        self.supplementary = supplementary
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header()

            Text(title)
                .font(.headline)
                .foregroundStyle(BeforeTheme.ink)
                .multilineTextAlignment(.leading)

            if let secondaryLine, !secondaryLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(secondaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            supplementary()

            DecisionReplayDiagnosticsBlockView(
                presentation: presentation
            )
            .padding(.top, 2)

            footer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
