import SwiftUI

struct DecisionReplayDiagnosticsBlockView: View {
    let presentation: DecisionEvolutionReplayEntryPresentation?
    var title: String? = nil
    var isLoading: Bool = false
    var emptyMessage: String? = nil
    var wrapsInPanelCard: Bool = false

    var body: some View {
        Group {
            if wrapsInPanelCard {
                PanelCard {
                    content
                }
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading || presentation != nil || title != nil || emptyMessage != nil {
            VStack(alignment: .leading, spacing: 12) {
                if let title {
                    Text(title)
                        .font(.headline)
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let presentation {
                    DecisionReplayDiagnosticsView(
                        presentation: presentation
                    )
                } else if let emptyMessage, !emptyMessage.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
