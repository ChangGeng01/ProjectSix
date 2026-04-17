import SwiftUI

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

            DecisionReplayDiagnosticsBlockView(
                presentation: replayPresentation,
                title: "Replay diagnostics",
                isLoading: isLoadingReplay,
                emptyMessage: "No replay-safe diagnostics have been attached to this history entry yet.",
                wrapsInPanelCard: true
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
