import SwiftUI

enum HistoryDetailSelection: Identifiable {
    case quick(CheckEvent)
    case balance(BalanceDecisionRecord)
    case mirror(MirrorDecisionRecord)

    var id: String {
        switch self {
        case .quick(let event): "quick-\(event.id.uuidString)"
        case .balance(let record): "balance-\(record.id.uuidString)"
        case .mirror(let record): "mirror-\(record.id.uuidString)"
        }
    }

    func matches(_ record: DeveloperDecisionReplayRecord) -> Bool {
        switch (self, record) {
        case (.quick(let selected), .quick(let event)):
            selected.id == event.id
        case (.balance(let selected), .balance(let record)):
            selected.id == record.id
        case (.mirror(let selected), .mirror(let record)):
            selected.id == record.id
        default:
            false
        }
    }
}

struct HistoryDetailView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var replayDiagnostics: DecisionEvolutionReplayEntryPresentation?
    @State private var isLoadingReplay = false

    let selection: HistoryDetailSelection

    var body: some View {
        NavigationStack {
            ZStack {
                BeforeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch selection {
                        case .quick(let event):
                            quickDetail(event)
                        case .balance(let record):
                            balanceDetail(record)
                        case .mirror(let record):
                            mirrorDetail(record)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: replayReloadKey) {
                await loadReplayEntry()
            }
        }
    }

    private var replayReloadKey: String {
        "\(selection.id)-\(appModel.evolutionControlMutationEpoch)"
    }

    @ViewBuilder
    private func quickDetail(_ event: CheckEvent) -> some View {
        let presentation = DecisionReviewEngine.detailPresentation(for: event)
        detailSection(
            presentation: presentation,
            reopenAction: {
                appModel.reopenCheckEvent(event)
                dismiss()
            },
            postponeAction: {
                appModel.moveCheckEventToTomorrow(event)
                dismiss()
            }
        ) {
            ForEach(presentation.rows) { row in
                detailPair(row.title, row.value)
            }
        }
    }

    @ViewBuilder
    private func balanceDetail(_ record: BalanceDecisionRecord) -> some View {
        let presentation = DecisionReviewEngine.detailPresentation(for: record)
        detailSection(
            presentation: presentation,
            reopenAction: {
                appModel.reopenBalanceRecord(record)
                dismiss()
            },
            postponeAction: {
                appModel.moveBalanceRecordToTomorrow(record)
                dismiss()
            }
        ) {
            ForEach(presentation.rows) { row in
                detailPair(row.title, row.value)
            }
        }
    }

    @ViewBuilder
    private func mirrorDetail(_ record: MirrorDecisionRecord) -> some View {
        let presentation = DecisionReviewEngine.detailPresentation(for: record)
        detailSection(
            presentation: presentation,
            reopenAction: {
                appModel.reopenMirrorRecord(record)
                dismiss()
            },
            postponeAction: {
                appModel.moveMirrorRecordToTomorrow(record)
                dismiss()
            }
        ) {
            ForEach(presentation.rows) { row in
                detailPair(row.title, row.value)
            }
        }
    }

    @ViewBuilder
    private func detailSection<Content: View>(
        presentation: DecisionReviewDetailPresentation,
        reopenAction: @escaping () -> Void,
        postponeAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SectionHeader(
            eyebrow: presentation.eyebrow,
            title: presentation.title,
            subtitle: presentation.subtitle
        )

        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }

        replayDiagnosticsCard()

        DecisionContinuationActions(
            reopenTitle: presentation.reopenTitle,
            reopenAction: reopenAction,
            postponeAction: postponeAction
        )
    }

    @ViewBuilder
    private func detailPair(_ title: String, _ value: String) -> some View {
        if !trimmed(value).isEmpty {
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

    @ViewBuilder
    private func replayDiagnosticsCard() -> some View {
        DecisionReplayDiagnosticsBlockView(
            presentation: replayDiagnostics,
            title: "Replay diagnostics",
            isLoading: isLoadingReplay,
            emptyMessage: "No replay-safe diagnostics have been attached to this history entry yet.",
            wrapsInPanelCard: true
        )
    }

    @MainActor
    private func loadReplayEntry() async {
        guard !isLoadingReplay else { return }
        isLoadingReplay = true
        defer { isLoadingReplay = false }

        replayDiagnostics = await appModel.replayDiagnosticsPresentation(
            matchingRecordID: selection.id
        )
    }
}

private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
}
