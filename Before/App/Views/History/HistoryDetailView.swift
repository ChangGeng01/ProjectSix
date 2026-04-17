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
        }
    }

    @ViewBuilder
    private func quickDetail(_ event: CheckEvent) -> some View {
        let presentation = DecisionReviewEngine.detailPresentation(for: event)
        DecisionReviewDetailSectionView(
            presentation: presentation,
            replayRecordID: selection.id,
            reopenAction: {
                appModel.reopenCheckEvent(event)
                dismiss()
            },
            postponeAction: {
                appModel.moveCheckEventToTomorrow(event)
                dismiss()
            }
        )
    }

    @ViewBuilder
    private func balanceDetail(_ record: BalanceDecisionRecord) -> some View {
        let presentation = DecisionReviewEngine.detailPresentation(for: record)
        DecisionReviewDetailSectionView(
            presentation: presentation,
            replayRecordID: selection.id,
            reopenAction: {
                appModel.reopenBalanceRecord(record)
                dismiss()
            },
            postponeAction: {
                appModel.moveBalanceRecordToTomorrow(record)
                dismiss()
            }
        )
    }

    @ViewBuilder
    private func mirrorDetail(_ record: MirrorDecisionRecord) -> some View {
        let presentation = DecisionReviewEngine.detailPresentation(for: record)
        DecisionReviewDetailSectionView(
            presentation: presentation,
            replayRecordID: selection.id,
            reopenAction: {
                appModel.reopenMirrorRecord(record)
                dismiss()
            },
            postponeAction: {
                appModel.moveMirrorRecordToTomorrow(record)
                dismiss()
            }
        )
    }

}
