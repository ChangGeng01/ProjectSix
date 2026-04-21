import SwiftUI

struct DecisionLayerStackView: View {
    let lines: [String]
    var title: String? = nil
    var titleFont: Font = .caption.weight(.semibold)
    var titleColor: Color = BeforeTheme.ember
    var lineFont: Font = .caption2
    var lineColor: Color = .secondary
    var spacing: CGFloat = 6

    private var displayLines: [String] {
        DecisionLayerStackPresentationSupport.displayLines(for: lines)
    }

    private var resolvedTitle: String {
        title ?? DecisionLayerStackPresentationSupport.title(for: displayLines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(resolvedTitle)
                .font(titleFont)
                .foregroundStyle(titleColor)

            ForEach(displayLines, id: \.self) { line in
                Text(line)
                    .font(lineFont)
                    .foregroundStyle(lineColor)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DecisionLayerStackCardView: View {
    let lines: [String]
    var title: String? = nil

    var body: some View {
        PanelCard {
            DecisionLayerStackView(
                lines: lines,
                title: title,
                titleFont: .headline,
                titleColor: BeforeTheme.ink,
                lineFont: .caption,
                spacing: 10
            )
        }
    }
}

private struct DecisionReplayOverviewCardView: View {
    let presentation: DecisionEvolutionReplayEntryPresentation
    var cardTitle: String = "Replay overview"

    private var overviewCardCopy: DecisionEvolutionReplayOverviewCardCopy {
        presentation.overviewCardCopy
    }

    var body: some View {
        return PanelCard {
            DecisionReplayEntrySummaryView(
                cardCopy: overviewCardCopy.summaryCardCopy,
                presentation: nil,
                showsDiagnostics: false
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cardTitle)
                        .font(.headline)
                        .foregroundStyle(BeforeTheme.ink)

                    Text(overviewCardCopy.labelLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BeforeTheme.ember)
                }
            } supplementary: {
                if let lineageMetadataText = presentation.lineageMetadataText {
                    Text(lineageMetadataText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                ForEach(presentation.overviewSupplementaryDetailLines, id: \.self) { line in
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DecisionReviewDetailSectionView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var replayPresentation: DecisionEvolutionReplayEntryPresentation?
    @State private var isLoadingReplay = false

    let presentation: DecisionReviewDetailPresentation
    let replayRecordID: String
    let reopenAction: () -> Void
    let postponeAction: () -> Void

    var body: some View {
        Group {
            SectionHeader(
                eyebrow: presentation.eyebrow,
                title: presentation.title,
                subtitle: presentation.subtitle
            )

            PanelCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(presentation.rows) { row in
                        detailPair(title: row.title, value: row.value)
                    }
                }
            }

            if let replayPresentation {
                DecisionReplayOverviewCardView(
                    presentation: replayPresentation
                )
            }

            if let replayPresentation, !replayPresentation.layerStackLines.isEmpty {
                DecisionLayerStackCardView(
                    lines: replayPresentation.layerStackLines
                )
            }

            DecisionReplayDiagnosticsBlockView(
                presentation: replayPresentation,
                title: "Replay diagnostics",
                isLoading: isLoadingReplay,
                emptyMessage: "No replay-safe diagnostics have been attached to this history entry yet.",
                wrapsInPanelCard: true,
                showsHeader: replayPresentation?.overviewPresentation == nil,
                excludesOverviewSummary: replayPresentation != nil
            )

            DecisionContinuationActions(
                reopenTitle: presentation.reopenTitle,
                postponeTitle: presentation.postponeTitle,
                reopenAction: reopenAction,
                postponeAction: postponeAction
            )
        }
        .task(id: replayReloadKey) {
            await loadReplayEntry()
        }
    }

    @ViewBuilder
    private func detailPair(title: String, value: String) -> some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BeforeTheme.ember)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(BeforeTheme.ink)
            }
        }
    }

    private var replayReloadKey: String {
        "\(replayRecordID)-\(appModel.evolutionControlMutationEpoch)"
    }

    @MainActor
    private func loadReplayEntry() async {
        guard !isLoadingReplay else { return }
        isLoadingReplay = true
        defer { isLoadingReplay = false }

        replayPresentation = await appModel.replayDiagnosticsPresentation(
            matchingRecordID: replayRecordID
        )
    }
}
