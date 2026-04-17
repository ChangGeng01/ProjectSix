import SwiftUI

struct DecisionReviewRecentEntriesSectionView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @State private var replayPresentationsByID: [String: DecisionEvolutionReplayEntryPresentation] = [:]

    let entries: [ReviewProfileEntry]
    var title: String = "Recent decisions"
    let selectAction: (ReviewProfileEntry) -> Void
    let reopenAction: (ReviewProfileEntry) -> Void
    let postponeAction: (ReviewProfileEntry) -> Void

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(BeforeTheme.ink)

                ForEach(entries) { entry in
                    let summary = DecisionReviewEngine.recentEntryPresentation(for: entry)
                    DecisionReviewRecentEntryCardView(
                        summary: summary,
                        presentation: replayPresentationsByID[entry.id],
                        selectAction: {
                            selectAction(entry)
                        },
                        reopenAction: {
                            reopenAction(entry)
                        },
                        postponeAction: {
                            postponeAction(entry)
                        }
                    )
                }
            }
            .task(id: replayReloadKey) {
                await loadReplayEntries()
            }
        }
    }

    private var replayReloadKey: String {
        "\(entries.map(\.id).joined(separator: "|"))-\(appModel.evolutionControlMutationEpoch)"
    }

    @MainActor
    private func loadReplayEntries() async {
        replayPresentationsByID = await appModel.replayDiagnosticsPresentationsByRecordID(
            matching: entries.map(\.id)
        )
    }
}
